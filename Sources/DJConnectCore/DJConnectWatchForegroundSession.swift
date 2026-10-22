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
            let projectedCurrent = value.broadcast.nativeCurrentMoment(at: date, spotifyAttributionAvailable: true)
            let current = projectedCurrent?.type == "dj_bulletin" ? nil : projectedCurrent
            let flow = value.broadcast.nativeFlowMoments(at: date).filter { $0.id != current?.id && $0.type != "dj_bulletin" }
            let ids = Set(([current].compactMap { $0 } + Array(flow.prefix(8))).map(\.id))
            // Only compact original speech revisions accompany visible cards;
            // no speech segments, hidden history, future labels, media or actions.
            speechSources = value.broadcast.djMoments.filter { ids.contains($0.id) }.compactMap { moment in
                guard settings.allowsSpeech(.local), let original = value.broadcast.sessionSpeech.first(where: {
                    $0.reference == .moment(sessionID: value.id, momentID: moment.id)
                }) else { return nil }
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
            case .missingToken, .authStale, .notConfigured: failureKey = "watch.session.pair_again"
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
              !current.settings.requiresSelection else { return }
        let epoch = generation
        expectedActive = current.session == nil; isChanging = true
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
