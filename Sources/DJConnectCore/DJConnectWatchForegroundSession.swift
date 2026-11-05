import Combine
import Foundation

/// Apple companion transport only. The iPhone reads using the Watch's paired
/// identity, never by copying its own Session, grant, history or credentials.
public struct DJConnectWatchSessionSnapshot: Codable, Sendable {
    public let settings: DJConnectProfileDJSettingsResponse
    public let session: DJConnectSessionRuntime?
    public let speechSources: [DJConnectWatchSpeechSource]
    enum CodingKeys: String, CodingKey { case settings, session; case speechSources = "speech_sources" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = try c.decode(DJConnectProfileDJSettingsResponse.self, forKey: .settings)
        session = try c.decodeIfPresent(DJConnectSessionRuntime.self, forKey: .session)
        speechSources = try c.decodeIfPresent([DJConnectWatchSpeechSource].self, forKey: .speechSources) ?? []
        guard speechSources.count <= 9 else { throw DJConnectError.invalidResponse }
    }
    public init(settings: DJConnectProfileDJSettingsResponse, session: DJConnectSessionRuntime?, at date: Date = Date()) {
        self.settings = settings
        if var value = session {
            // Bulletins require a qualified delivery path beyond this companion snapshot.
            let projectedCurrent = value.broadcast.nativeCurrentMoment(at: date, spotifyAttributionAvailable: true)
            let current = projectedCurrent?.type == "dj_bulletin" ? nil : projectedCurrent
            let flow = value.broadcast.nativeFlowMoments(at: date).filter { $0.id != current?.id && $0.type != "dj_bulletin" }
            let ids = Set(([current].compactMap { $0 } + Array(flow.prefix(8))).map(\.id))
            // Only compact original speech revisions accompany visible cards;
            // no speech segments, hidden history, future labels, media or actions.
            speechSources = value.broadcast.djMoments.filter { ids.contains($0.id) }.compactMap { moment in
                let reference = DJConnectSpeechReference.moment(sessionID: value.id, momentID: moment.id)
                guard settings.allowsSpeech(.local, manualMomentType: moment.isMusicAnnouncementV1 ? moment.type : nil),
                      value.broadcast.nativeMomentSpeechIsAdmitted(reference, at: date, automatic: false),
                      let original = value.broadcast.sessionSpeech.first(where: { $0.reference == reference }) else { return nil }
                return DJConnectWatchSpeechSource(original, text: moment.content, at: date)
            }
            value.broadcast.sessionSpeech = []
            value.broadcast.djMoments = value.broadcast.djMoments.filter { ids.contains($0.id) }.map { moment in
                var visible = moment; visible.actions = []; visible.artwork = nil; return visible
            }
            value.broadcast.sessionMedia = []; value.broadcast.presentations = []
            value.broadcast.sessionFlow.items = value.broadcast.sessionFlow.items.filter { $0.momentID.map(ids.contains) == true }
            value.broadcast.nativeDelivery?.admissions.removeAll { !ids.contains($0.momentID) }
            value.broadcast.playback?.artworkURL = nil
            self.session = value
        } else { self.session = nil; speechSources = [] }
    }
    /// A concurrent phone edit can split the two contracts. Retry reads once,
    /// retaining neither half of an inconsistent Profile/Session pair.
    @MainActor public static func read(settings: () async throws -> DJConnectProfileDJSettingsResponse,
                            session: () async throws -> DJConnectSessionResponse) async throws -> Self {
        for _ in 0..<2 {
            let before = try await settings()
            let runtime = try await session()
            let after = try await settings()
            guard runtime.success else { throw DJConnectError.invalidResponse }
            let result = Self(settings: after, session: runtime.resolvedSession)
            if before.binding == after.binding, before.snapshot == after.snapshot, result.isValid { return result }
        }
        throw DJConnectError.invalidResponse
    }

    public var isValid: Bool {
        guard settings.isValid else { return false }
        guard let session else { return settings.snapshot.session == nil }
        return session.runtimeState == "active" && !session.id.isEmpty &&
            session.id == session.broadcast.session.sessionID &&
            settings.snapshot.session?.session_id == session.id &&
            settings.snapshot.effective.mood == session.selectedMood &&
            session.selectedPersona.map { $0 == settings.snapshot.effective.persona } != false &&
            session.selectedPresence.map { $0 == settings.snapshot.effective.presence } != false
    }
}

/// Watch-local widget projection. It contains no Profile, Session or media identifiers.
public struct DJConnectWatchStackEntry: Codable, Equatable, Sendable {
    public enum Destination: String, Codable, Sendable {
        case session, askDJ

        public var url: URL {
            switch self {
            case .session: URL(string: "djconnect://watch/session")!
            case .askDJ: URL(string: "djconnect://watch/ask-dj")!
            }
        }
    }

    public static let storageKey = "DJConnectWatchStackEntry.v1"
    public static let lifetime: TimeInterval = 30
    public let destination: Destination
    public let observedAt: Date

    public var expiresAt: Date { observedAt.addingTimeInterval(Self.lifetime) }

    init?(snapshot: DJConnectWatchSessionSnapshot, observedAt: Date) {
        guard snapshot.isValid, !snapshot.settings.requiresSelection else { return nil }
        destination = snapshot.session == nil ? .askDJ : .session
        self.observedAt = observedAt
    }

    public static func load(from defaults: UserDefaults, at now: Date) -> Self? {
        guard let data = defaults.data(forKey: storageKey),
              let entry = try? JSONDecoder().decode(Self.self, from: data),
              entry.observedAt <= now, now < entry.expiresAt else { return nil }
        return entry
    }
}

/// The companion revalidates this owner before issuing a non-replayed write.
public struct DJConnectWatchSessionAction: Codable, Sendable {
    public let binding: String
    public let sessionID: String?
    public let mood: String
    public let language: String
    public init(snapshot: DJConnectWatchSessionSnapshot, language: String) {
        binding = snapshot.settings.binding; sessionID = snapshot.session?.id
        mood = snapshot.settings.snapshot.effective.mood; self.language = language
    }
    /// Revalidate the original Watch owner before the sole non-replayed write.
    /// A consistent read fence is not an atomic server write precondition.
    @MainActor public func perform(settings: () async throws -> DJConnectProfileDJSettingsResponse,
                                   session: () async throws -> DJConnectSessionResponse,
                                   write: (Self) async throws -> Bool) async throws {
        guard sessionID != nil else { throw DJConnectError.invalidResponse } // Watch never starts a Session.
        let current = try await DJConnectWatchSessionSnapshot.read(settings: settings, session: session)
        guard matches(current) else { throw DJConnectError.invalidResponse }
        try Task.checkCancellation()
        guard try await write(self) else { throw DJConnectError.invalidResponse }
    }
    public func matches(_ current: DJConnectWatchSessionSnapshot) -> Bool {
        current.isValid && binding == current.settings.binding && sessionID == current.session?.id &&
        mood == current.settings.snapshot.effective.mood && !current.settings.requiresSelection
    }
}

public struct DJConnectWatchSettingsUpdate: Codable, Sendable {
    public let current: DJConnectProfileDJSettingsResponse
    public let patch: DJConnectProfileDJSettings.Patch
    public let operationID: String
    public init(current: DJConnectProfileDJSettingsResponse, patch: DJConnectProfileDJSettings.Patch, operationID: String) {
        self.current = current; self.patch = patch; self.operationID = operationID
    }
}

public struct DJConnectWatchSettingsReceipt: Codable, Sendable {
    public let binding: String
    public let operationID: String
    public init(binding: String, operationID: String) { self.binding = binding; self.operationID = operationID }
}

/// Visible Watch app only; no passive/locked-screen replication and no disk
/// cache. Both the owner generation and a monotonic 30-second freshness fence
/// must still hold in addition to every original native Moment deadline.
@MainActor public final class DJConnectWatchForegroundSession: ObservableObject {
    @Published public private(set) var snapshot: DJConnectWatchSessionSnapshot?
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var unavailable = false
    @Published public private(set) var failureKey: String?
    @Published public private(set) var isChanging = false
    @Published public private(set) var outcomeUnknown = false
    private var expectedActive: Bool?
    public private(set) var active = false
    private var owner: String?
    private var generation = UUID()
    private var receivedUptime: TimeInterval?
    private var receivedDate: Date?
    private var expiration: Task<Void, Never>?
    private var lastAttemptUptime: TimeInterval?
    public init() {}

    public var displayDeadlines: [Date] {
        let admissions = snapshot?.session?.broadcast.nativeDelivery?.admissions ?? []
        return Array(Set(admissions.flatMap { [$0.sourceExpiresAt, $0.displayExpiresAt].compactMap { $0.flatMap(DJConnectHistoryEntry.date) } })).sorted()
    }

    public func bind(owner value: String?, active enabled: Bool) {
        guard value != owner || active != enabled else { return }
        if isChanging { outcomeUnknown = true }
        if owner != value { expectedActive = nil; outcomeUnknown = false }
        owner = value; active = enabled && value != nil; generation = UUID()
        isChanging = false; failureKey = nil
        expiration?.cancel(); expiration = nil
        snapshot = nil; receivedUptime = nil; receivedDate = nil
        lastAttemptUptime = nil; isRefreshing = false; unavailable = false
    }

    public func current(at date: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DJConnectWatchSessionSnapshot? {
        guard active, let start = receivedUptime, let receivedDate,
              date >= receivedDate, uptime >= start, uptime - start < 30 else { return nil }
        return snapshot
    }

    public func stackEntry() -> DJConnectWatchStackEntry? {
        guard !outcomeUnknown, !isChanging, let current = current(), let receivedDate else { return nil }
        return .init(snapshot: current, observedAt: receivedDate)
    }

    public func refresh(force: Bool = false, read: () async throws -> DJConnectWatchSessionSnapshot) async {
        guard active, !isRefreshing, !isChanging else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard force || lastAttemptUptime.map({ now - $0 >= 15 }) != false else { return }
        lastAttemptUptime = now; isRefreshing = true
        let epoch = generation
        defer { if generation == epoch { isRefreshing = false } }
        do {
            let incoming = try await read()
            guard epoch == generation, active else { return }
            guard incoming.isValid else { throw DJConnectError.invalidResponse }
            snapshot = incoming; unavailable = false; failureKey = nil
            if let expectedActive, (incoming.session != nil) == expectedActive {
                self.expectedActive = nil; outcomeUnknown = false
            }
            receivedDate = Date(); receivedUptime = ProcessInfo.processInfo.systemUptime
            expiration?.cancel()
            expiration = Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self, self.generation == epoch else { return }
                self.snapshot = nil; self.receivedDate = nil; self.receivedUptime = nil
                self.unavailable = true; self.failureKey = "watch.session.expired"
            }
        } catch {
            guard epoch == generation, active else { return }
            // A failed owner read must not keep presenting a withdrawn Profile.
            snapshot = nil; receivedUptime = nil; receivedDate = nil
            expiration?.cancel(); expiration = nil; unavailable = true
            switch error as? DJConnectError {
            case .missingToken, .authStale: failureKey = "watch.session.pair_again"
            case .invalidConfiguration: failureKey = "watch.session.connect_phone"
            default: failureKey = "watch.session.retry"
            }
        }
    }

    /// One user action, one write. A lost response can only trigger GET readback.
    public func change(language: String,
                       write: (DJConnectWatchSessionAction) async throws -> Void,
                       read: () async throws -> DJConnectWatchSessionSnapshot) async {
        guard !isChanging, !outcomeUnknown, !isRefreshing, let current = current(),
              current.session != nil, !current.settings.requiresSelection else { return }
        let epoch = generation
        expectedActive = false; isChanging = true
        do { try await write(.init(snapshot: current, language: language)) }
        catch { /* A transport failure does not prove that the write failed. */ }
        guard epoch == generation, active else { return }
        isChanging = false; outcomeUnknown = true
        await refresh(force: true, read: read)
    }


    /// Explicitly accept a fresh server state after an uncertain action. This
    /// discards the local intent; it never resends its POST.
    public func useCurrent(read: () async throws -> DJConnectWatchSessionSnapshot) async {
        guard active, !isChanging, !isRefreshing else { return }
        let epoch = generation
        await refresh(force: true, read: read)
        guard epoch == generation, current() != nil else { return }
        expectedActive = nil; outcomeUnknown = false
    }

}

/// Compact, ephemeral rows from the same retained tail and admitted live Bulletins as iPhone.
public struct DJConnectWatchFlowRow: Codable, Identifiable, Sendable {
    public static let maximumCount = 20
    public let id: String
    public let date: Date
    public let expiresAt: Date
    public let labelKey: String
    public let text: String
    public let momentID: String?
    public let reference: DJConnectSessionEntryReference?
    public let spotifyAttribution: Bool
    public let sources: [DJConnectBulletinSource]

    public static func latest(history: [DJConnectHistoryEntry], session: DJConnectSessionRuntime, at now: Date) -> [Self] {
        let entries = history.filter { $0.sessionID == session.id && $0.isRetained(at: now) }
        let withdrawn = Set(entries.filter(\.isPublicationReceipt).compactMap(\.momentID))
        let broadcast = session.broadcast
        let current = broadcast.nativeCurrentMoment(at: now)
        let bulletins = ([current].compactMap { $0 } + broadcast.nativeFlowMoments(at: now)).filter {
            $0.isBulletinV1 && !withdrawn.contains($0.id)
        }
        var seen = Set<String>()
        let live: [Self] = bulletins.compactMap { moment in
            guard seen.insert(moment.id).inserted, let date = DJConnectHistoryEntry.date(moment.createdAt),
                  let admission = broadcast.nativeDelivery?.admissions.first(where: { $0.momentID == moment.id }),
                  let sourceDeadline = admission.sourceExpiresAt.flatMap(DJConnectHistoryEntry.date) else { return nil }
            let deadline = current?.id == moment.id
                ? min(sourceDeadline, admission.displayExpiresAt.flatMap(DJConnectHistoryEntry.date) ?? now)
                : sourceDeadline
            guard deadline > now else { return nil }
            return .init(id: "bulletin:" + moment.id, date: date, expiresAt: deadline,
                         labelKey: "ui.session.moment.dj_bulletin", text: moment.content, momentID: moment.id,
                         reference: nil, spotifyAttribution: false, sources: moment.sources)
        }
        let liveIDs = Set(live.compactMap(\.momentID))
        let retained: [Self] = entries.reversed().compactMap { entry in
            guard let date = DJConnectHistoryEntry.date(entry.occurredAt),
                  let deadline = DJConnectHistoryEntry.date(entry.retainedUntil),
                  !liveIDs.contains(entry.momentID ?? "") else { return nil }
            let label: String
            let content: String
            switch entry.kind {
            case .playbackObserved:
                label = "ui.session.history.playback"
                content = [entry.playback?.title, entry.playback?.artist, entry.playback?.album]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            case .djMoment:
                label = entry.momentType == "music_announcement" ? "ui.session.moment.music_announcement" : "ui.session.moment.generic"; content = entry.text ?? ""
            case .conversationUser:
                label = "watch.v2.flow.question"; content = entry.text ?? ""
            case .conversationDJ:
                label = "watch.v2.flow.answer"; content = entry.text ?? ""
            case .djPublication:
                label = "ui.session.moment.generic"; content = ""
            case .djSilence:
                label = "ui.session.history.silence"; content = ""
            }
            let preview = String(content.unicodeScalars.prefix(500)) + (content.unicodeScalars.count > 500 ? "…" : "")
            return .init(id: entry.id, date: date, expiresAt: deadline, labelKey: label,
                         text: preview, momentID: entry.momentID,
                         reference: entry.isPublicationReceipt ? nil : entry.reference,
                         spotifyAttribution: entry.requiresSpotifyAttribution == true, sources: [])
        }
        let ordered = (retained + live).enumerated().sorted {
            $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date > $1.element.date
        }
        return ordered.prefix(maximumCount).map(\.element)
    }
}


// Local demo presentation sent over WatchConnectivity. It carries no HA binding.
public struct DJConnectWatchDemoSession: Codable, Sendable {
    public static let contextKey = "djconnect_demo_session_v1"
    public static let playbackMessageType = "watch_demo_session_playback"
    public static let choiceMessageType = "watch_demo_session_choice"

    public enum Choice: String, Sendable { case mood, persona, presence }
    public let observedAt: Date?
    public let id: String
    public let mood: String
    public let persona: DJConnectSessionPersonaValue
    public let presence: DJConnectSessionPresenceValue
    public let track: String
    public let artist: String?
    public let album: String?
    public let playback: DJConnectPlayback?
    public let outputs: [DJConnectOutputDevice]?
    public let rows: [DJConnectWatchFlowRow]

    public init(id: String, mood: String, persona: DJConnectSessionPersonaValue, presence: DJConnectSessionPresenceValue, track: String, artist: String?, album: String?, playback: DJConnectPlayback?, outputs: [DJConnectOutputDevice]?, rows: [DJConnectWatchFlowRow]) {
        self.observedAt = Date()
        self.id = id
        self.mood = mood
        self.persona = persona
        self.presence = presence
        self.track = track
        self.artist = artist
        self.album = album
        self.playback = playback
        self.outputs = outputs
        self.rows = rows
    }
}

/// Explicit local demo transport only; never dispatched through the HA proxy.
public struct DJConnectWatchDemoTextRequest: Codable, Equatable, Sendable {
    public static let messageKind = "watch_demo_text_v1"
    public let kind: String
    public let requestID: UUID
    public let sessionID: String
    public let text: String
    public init(requestID: UUID = UUID(), sessionID: String, text: String) {
        kind = Self.messageKind; self.requestID = requestID; self.sessionID = sessionID; self.text = text
    }
}
public struct DJConnectWatchDemoTextReply: Codable, Equatable, Sendable {
    public let requestID: UUID
    public let sessionID: String
    public let answer: String
    public init(requestID: UUID, sessionID: String, answer: String) {
        self.requestID = requestID; self.sessionID = sessionID; self.answer = answer
    }
}

/// Foreground demo playback goes through the iPhone's demo queue.
public struct DJConnectWatchDemoPlaybackRequest: Codable, Sendable {
    public let kind: String
    public let sessionID: String
    public let command: String
    public let value: DJConnectCommandValue?
    public init(sessionID: String, command: String, value: DJConnectCommandValue? = nil) {
        kind = "watch_demo_playback_v1"; self.sessionID = sessionID
        self.command = command; self.value = value
    }
}

/// Device diagnostics only, shared with the OS-paired iPhone through WatchConnectivity.
public struct DJConnectWatchLoggingConfiguration: Codable, Sendable {
    public static let contextKey = "djconnect_watch_logging_v1"
    public let epoch: UUID
    public let updatedAt: Date
    public let level: String
    public let collect: Bool
    public init(epoch: UUID, level: String, collect: Bool) {
        self.epoch = epoch; self.updatedAt = Date(); self.level = level; self.collect = collect
    }
    public func permits(_ level: String) -> Bool {
        let levels = ["debug", "info", "warning", "error"]
        guard let configured = levels.firstIndex(of: self.level), let candidate = levels.firstIndex(of: level) else { return false }
        return candidate >= configured
    }
}
public struct DJConnectWatchDiagnosticLine: Codable, Sendable {
    public let id: UUID
    public let text: String
    public init(id: UUID = UUID(), text: String) { self.id = id; self.text = text }
}
public struct DJConnectWatchDiagnosticBatch: Codable, Sendable {
    public let epoch: UUID
    public let lines: [DJConnectWatchDiagnosticLine]
    public init(epoch: UUID, lines: [DJConnectWatchDiagnosticLine]) { self.epoch = epoch; self.lines = lines }
}
