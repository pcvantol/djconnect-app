import SwiftUI
import DJConnectCore

/// A transient projection of Core's one Session offer; never a local recommender.
@MainActor final class SessionForYouModel: ObservableObject {
    struct Scope: Equatable {
        let session: String
        let owner: String
        let epoch: UUID
        let origin: String
        let language: String
    }
    @Published private(set) var offer: DJConnectForYou?
    @Published private(set) var busy = false
    @Published private(set) var uncertain = false
    @Published private(set) var expired = false
    private weak var host: DJConnectAppModel?
    private var captured: Scope?
    private var qualified = false
    private var ownedOutputs = Set<String>()
    @Published private var pendingOutputs: [DJConnectAskDJPlaybackAction] = []
    private var outputResultSetID: String?
    private var submittedOutputs = Set<String>()
    private var outputContext: DJConnectConversationContext?
    private var outputDeadline: Date?
    private var outputInstant: ContinuousClock.Instant?
    private var generation = UUID()
    private var readCompleted = false
    private var expiryTask: Task<Void, Never>?
    private var wallDeadline: Date?
    private var monotonicDeadline: ContinuousClock.Instant?
    private var settings: Data?
    private var settingsChanged = false
    var now: () -> Date = { Date() }
    var instant: () -> ContinuousClock.Instant = { .now }
    init(host: DJConnectAppModel) { self.host = host }
    var scope: Scope? {
        guard let host, !host.isDemoMode,
              host.canRefreshSessionHistory, host.canUseProfileConversation,
              host.isConnected, host.backendAvailable,
              let session = host.activeDJSession, session.runtimeState == "active",
              let owner = host.sessionHistory.authorizedProfileID else { return nil }
        return Scope(session: session.id, owner: owner, epoch: host.sessionHistory.responseEpoch,
                     origin: host.homeAssistantURL + "|" + host.haLocalURL + "|" + host.haRemoteURL,
                     language: host.language)
    }
    private static func settingsData(_ session: DJConnectSessionRuntime) -> Data? {
        struct Settings: Encodable {
            let backend: String
            let mood: String
            let moodRevision: Int?
            let persona: DJConnectSessionPersonaValue?
            let personaRevision: Int?
            let presence: DJConnectSessionPresenceValue?
            let presenceRevision: Int?
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(Settings(backend: session.musicBackend, mood: session.selectedMood,
            moodRevision: session.moodRevision, persona: session.selectedPersona, personaRevision: session.personaRevision,
            presence: session.selectedPresence, presenceRevision: session.presenceRevision))
    }
    func reconcile() {
        guard scope == captured else {
            expiryTask?.cancel(); expiryTask = nil
            captured = scope; generation = UUID(); qualified = false; readCompleted = false
            offer = nil; ownedOutputs = []; pendingOutputs = []; outputDeadline = nil; outputInstant = nil; busy = false; uncertain = false; expired = false
            wallDeadline = nil; monotonicDeadline = nil; settings = nil; settingsChanged = false
            outputResultSetID = nil; submittedOutputs = []; outputContext = nil
            return
        }
        if let session = host?.activeDJSession, let settings,
           Self.settingsData(session) != settings { settingsChanged = true; expired = true }
    }
    private func current(_ scope: Scope, _ token: UUID) -> Bool {
        self.scope == scope && captured == scope && generation == token
    }
    func refresh() async {
        reconcile()
        guard !readCompleted, let host, let captured else { return }
        readCompleted = true
        let token = generation
        do {
            let capabilities = try await host.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                try await $0.activeSessionMoodCapabilities()
            }
            guard current(captured, token), capabilities.forYouAvailable else { return }
            qualified = true
            let response = try await host.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                try await $0.activeSession(language: captured.language)
            }
            guard current(captured, token), response.success, response.resolvedSession?.id == captured.session else { return }
            observe(response.forYou, session: response.resolvedSession)
        } catch {
            // No effect or automatic generation retry. A later explicit visit can read again.
            if current(captured, token) { readCompleted = false }
        }
    }
    /// Active-session reads are cached Core projections. They never prepare or
    /// renew an offer, including after expiry or an unknown playback outcome.
    func observeWhileVisible() async {
        await refresh()
        guard let host, let captured, qualified else { return }
        let token = generation
        while current(captured, token), isPresented, !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            guard current(captured, token), !Task.isCancelled else { return }
            if busy { continue }
            do {
                let response = try await host.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                    try await $0.activeSession(language: captured.language)
                }
                guard current(captured, token), response.success, response.resolvedSession?.id == captured.session else { return }
                observe(response.forYou, session: response.resolvedSession)
            } catch { return }
        }
    }
    func observe(_ incoming: DJConnectForYou?, session: DJConnectSessionRuntime? = nil) {
        reconcile()
        guard qualified, let captured, scope == captured, let incoming,
              incoming.isSupported, incoming.session_id == captured.session else { return }
        if let session, Self.settingsData(session) != host?.activeDJSession.flatMap(Self.settingsData) { return }
        if let policy = incoming.refresh_policy, policy.mood_revision != host?.activeDJSession?.moodRevision { return }
        let replacement = offer?.offer_id != incoming.offer_id
        // A pending/unknown operation cannot be made executable by a normal poll.
        if replacement {
            uncertain = false; settingsChanged = false
            settings = host?.activeDJSession.flatMap(Self.settingsData)
            pendingOutputs = []; outputContext = nil; outputResultSetID = nil
            outputDeadline = nil; outputInstant = nil
        }
        offer = incoming
        let remaining = incoming.expires_in ?? 0
        let wall = now().addingTimeInterval(remaining)
        let mono = instant().advanced(by: .seconds(remaining))
        wallDeadline = replacement ? wall : min(wallDeadline ?? wall, wall)
        monotonicDeadline = replacement ? mono : min(monotonicDeadline ?? mono, mono)
        expired = settingsChanged || !withinDeadline
        if let continuation = incoming.continuation, incoming.state == "awaiting_output", !settingsChanged,
           continuation.mood_revision == host?.activeDJSession?.moodRevision,
           let result = continuation.result_set, let first = continuation.first_play {
            admitOutputs(continuation.admittedOutputActions, resultID: result.resultSetID,
                         context: continuation.conversation_context,
                         remaining: min(remaining, continuation.expires_in, first.expires_in, result.expiresIn))
        } else if incoming.continuation != nil || ["confirmed", "closed", "dismissed", "uncertain", "attempted"].contains(incoming.state) {
            pendingOutputs = []
        }
        expiryTask?.cancel()
        let wallRemaining = Duration.seconds(max(0, min(wallDeadline ?? now(), outputDeadline ?? wallDeadline ?? now()).timeIntervalSince(now())))
        let monoEnd = min(monotonicDeadline ?? instant(), outputInstant ?? monotonicDeadline ?? instant())
        let delay = min(wallRemaining, max(.zero, instant().duration(to: monoEnd)))
        let token = generation
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, generation == token else { return }
            expired = true
            pendingOutputs = []
        }
    }
    private var withinDeadline: Bool {
        guard let wallDeadline, let monotonicDeadline else { return false }
        return now() < wallDeadline && instant() < monotonicDeadline
    }
    /// Terminal Core states close presentation, even if an older server leaves
    /// its visible bit set. An unknown/unavailable outcome is never success.
    var isPresented: Bool {
        offer?.visible == true && !["confirmed", "closed", "dismissed"].contains(offer?.state ?? "")
    }
    var canChoose: Bool {
        offer?.visible == true && offer?.actions_available == true && !busy && !uncertain &&
        !settingsChanged && withinDeadline && scope == captured && host?.isSendingAskDJText == false
    }
    var canRefresh: Bool {
        offer?.refresh_request?.automatic == false && !busy && !uncertain &&
        scope == captured && host?.isSendingAskDJText == false &&
        !["attempted", "awaiting_output", "uncertain"].contains(offer?.state ?? "")
    }
    /// Present only the original, still-admitted speaker choices beside the offer.
    var outputChoices: [DJConnectAskDJPlaybackAction] {
        guard !busy, !settingsChanged, host?.isSendingAskDJText == false, scope == captured, withinDeadline,
              let outputDeadline, outputDeadline > now(), let outputInstant, outputInstant > instant() else { return [] }
        return pendingOutputs
    }
    func choose(_ option: DJConnectForYou.Option) {
        guard canChoose, let offer, offer.options.contains(option),
              let context = offer.conversation_context else { return }
        submit(text: option.label, choice: .init(resultSetID: offer.offer_id, actionID: option.action_id), context: context)
    }
    /// Intercept only original For-you speaker bubble actions. They must never
    /// fall through to the legacy direct playback command adapter.
    func handleOutput(_ action: DJConnectAskDJPlaybackAction) -> Bool {
        guard ownedOutputs.contains(action.id) else { return false }
        guard pendingOutputs.contains(action) else { return true }
        guard !busy, !settingsChanged, host?.isSendingAskDJText == false, scope == captured, withinDeadline,
              let outputDeadline, outputDeadline > now(), let outputInstant, outputInstant > instant(),
              let context = outputContext,
              let result = action.resultSetID, let id = action.actionID else { return true }
        submittedOutputs.insert(result + "|" + id)
        submit(text: action.buttonLabel ?? action.title,
               choice: .init(resultSetID: result, actionID: id), context: context)
        return true
    }
    func renew() {
        guard canRefresh, let offer, let prompt = offer.refresh_request?.prompt,
              let context = offer.conversation_context else { return }
        submit(text: prompt, choice: nil, context: context)
    }
    private func admitOutputs(_ actions: [DJConnectAskDJPlaybackAction], resultID: String,
                              context: DJConnectConversationContext, remaining: Double) {
        guard remaining.isFinite, remaining > 0, remaining <= 60 else { pendingOutputs = []; return }
        let wall = now().addingTimeInterval(remaining)
        let mono = instant().advanced(by: .seconds(remaining))
        let same = outputResultSetID == resultID && outputContext == context
        outputDeadline = same ? min(outputDeadline ?? wall, wall) : wall
        outputInstant = same ? min(outputInstant ?? mono, mono) : mono
        outputResultSetID = resultID; outputContext = context
        pendingOutputs = actions.filter { action in
            guard let result = action.resultSetID, let id = action.actionID else { return false }
            return !submittedOutputs.contains(result + "|" + id)
        }
        ownedOutputs.formUnion(actions.map(\.id))
    }
    private func submit(text: String, choice: DJConnectConversationChoice?, context: DJConnectConversationContext) {
        guard let host, let captured else { return }
        let token = generation
        let submittedSettings = host.activeDJSession.flatMap(Self.settingsData)
        busy = true
        pendingOutputs = [] // Consume the original speaker choice synchronously.
        // One synchronous latch; an unknown outcome is never replayed.
        Task { [weak self] in
            guard let self else { return }
            defer { if current(captured, token) { busy = false } }
            do {
                let response = try await host.sessionHistory.sendStartupChoice(text: text, choice: choice,
                    sessionID: captured.session, suppliedContext: context, isCurrent: { [weak self] in
                        self?.current(captured, token) == true && host.activeDJSession.flatMap(Self.settingsData) == submittedSettings &&
                        (choice == nil || self?.withinDeadline == true)
                    })
                guard current(captured, token), host.activeDJSession.flatMap(Self.settingsData) == submittedSettings else { return }
                // The ordinary reducer renders an output choice as a Session speaker bubble.
                // Only an authenticated projection may hide the card; an ACK cannot.
                if let next = response.forYou { observe(next) }
                if response.firstPlay?.state == "output", let result = response.resultSet,
                   !result.admittedPlaybackActions.isEmpty,
                   result.admittedPlaybackActions.allSatisfy({ $0.kind == "output" && $0.command == "set_output" }),
                   let lease = host.resolveConversationPresentationDeadline(response), lease > now() {
                    let remaining = min(result.expiresIn, lease.timeIntervalSince(now()), response.firstPlay?.expires_in ?? 0)
                    admitOutputs(result.admittedPlaybackActions, resultID: result.resultSetID, context: context, remaining: remaining)
                }
                uncertain = response.forYou == nil || ["attempted", "uncertain", "awaiting_output"].contains(response.forYou?.state ?? "")
                _ = await host.refreshActiveDJSession()
            } catch {
                if current(captured, token) { uncertain = true }
            }
        }
    }
    func dismiss() {
        guard !busy, let host, let offer, let context = offer.conversation_context,
              let captured, scope == captured else { return }
        let token = generation
        busy = true
        Task { [weak self] in
            guard let self else { return }
            defer { if current(captured, token) { busy = false } }
            do {
                var payload = host.profileConversationPayload(text: "", clientMessageID: "", context: context)
                payload.clientMessageID = nil; payload.audioResponse = .never
                payload.choiceAction = .dismiss(offerID: offer.offer_id)
                let response = try await host.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                    try await $0.sendAskDJMessage(payload)
                }
                guard current(captured, token) else { return }
                if response.forYouDismissed { self.offer = nil }
            } catch { /* Dismissal failure grants no new playback operation. */ }
        }
    }
}

struct SessionForYouCard: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var projection: SessionForYouModel
    init(model: DJConnectAppModel) { self.model = model; projection = model.sessionForYou }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    var body: some View {
        VStack(spacing: 0) {
            if let offer = projection.offer, projection.isPresented {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(offer.title).font(.headline).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if projection.busy { ProgressView() }
                        if offer.refresh_request?.automatic == false {
                            Button(action: projection.renew) {
                                Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                            }
                            .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                            .disabled(!projection.canRefresh)
                            .accessibilityLabel(text("ui.for_you.refresh"))
                            .accessibilityIdentifier("session-for-you-refresh")
                        }
                        Button(action: projection.dismiss) { Image(systemName: "xmark") }
                            .buttonStyle(.plain).frame(width: 44, height: 44)
                            .disabled(projection.busy).accessibilityLabel(text("ui.close"))
                    }
                    if let intro = offer.intro, !intro.isEmpty { Text(intro).font(.subheadline) }
                    if !offer.options.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(offer.options) { option in
                                Button { projection.choose(option) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForYouLandscape(recipe: option.visual_recipe, sessionID: offer.session_id, language: model.language,
                                                        sessionMood: model.activeDJSession?.selectedMood)
                                            .frame(height: 92).clipShape(RoundedRectangle(cornerRadius: 14))
                                        Text(option.label).font(.subheadline.weight(.semibold))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }.frame(maxWidth: .infinity, alignment: .topLeading)
                                }.buttonStyle(.plain).disabled(!projection.canChoose)
                                    .accessibilityIdentifier("session-for-you-option-" + option.id)
                            }
                        }
                    }
                    if offer.refresh_policy?.state == "pending" {
                        Text(text("ui.for_you.preparing")).font(.caption).foregroundStyle(.secondary)
                    } else if !projection.outputChoices.isEmpty {
                        Text(text("ui.for_you.choose_output")).font(.subheadline)
                        ForEach(projection.outputChoices) { action in
                            Button { _ = projection.handleOutput(action) } label: {
                                Label(action.buttonLabel ?? action.title, systemImage: "speaker.wave.2")
                                    .frame(maxWidth: .infinity)
                            }
                            .djConnectButtonStyle(DJConnectButtonStyle(expands: true))
                            .accessibilityIdentifier("session-for-you-output-" + action.id)
                        }
                    } else if projection.uncertain || ["attempted", "awaiting_output", "uncertain"].contains(offer.state) {
                        Text(text("ui.for_you.pending")).font(.caption).foregroundStyle(.secondary)
                    } else if projection.expired || offer.state == "unavailable" {
                        Text(text("ui.for_you.unavailable")).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).djSessionFrostedSurface()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("session-for-you")
            }
        }
    }
}
