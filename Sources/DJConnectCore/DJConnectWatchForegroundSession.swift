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
            let current = value.broadcast.nativeCurrentMoment(at: date, spotifyAttributionAvailable: true)
            let flow = value.broadcast.nativeFlowMoments(at: date).filter { $0.id != current?.id }
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
        owner = value; active = enabled && value != nil; generation = UUID()
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
        guard active, !isRefreshing else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard force || lastAttemptUptime.map({ now - $0 >= 15 }) != false else { return }
        lastAttemptUptime = now; isRefreshing = true
        let epoch = generation
        defer { if generation == epoch { isRefreshing = false } }
        do {
            let incoming = try await read()
            guard epoch == generation, active else { return }
            guard incoming.isValid else { throw DJConnectError.invalidResponse }
            snapshot = incoming; unavailable = false
            receivedDate = Date(); receivedUptime = ProcessInfo.processInfo.systemUptime
            expiration?.cancel()
            expiration = Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self, self.generation == epoch else { return }
                self.snapshot = nil; self.receivedDate = nil; self.receivedUptime = nil
            }
        } catch {
            guard epoch == generation, active else { return }
            // A failed owner read must not keep presenting a withdrawn Profile.
            snapshot = nil; receivedUptime = nil; receivedDate = nil
            expiration?.cancel(); expiration = nil; unavailable = true
        }
    }
}
