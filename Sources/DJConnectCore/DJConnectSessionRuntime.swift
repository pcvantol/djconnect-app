import Foundation

public struct DJConnectSessionStartRequest: Codable, Equatable, Sendable {
    public var mood: String
    public var language: String

    public init(mood: String, language: String) {
        self.mood = mood
        self.language = language
    }
}

public struct DJConnectSessionEndRequest: Codable, Equatable, Sendable {
    public var sessionID: String

    public init(sessionID: String) {
        self.sessionID = sessionID
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}

public struct DJConnectVibeCastHandoffApprovalRequest: Codable, Equatable, Sendable {
    public var sessionID: String
    public var code: String

    public init(sessionID: String, code: String) {
        self.sessionID = sessionID
        self.code = code
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case code
    }
}

public struct DJConnectVibeCastHandoffApprovalResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var sessionID: String?
    public var handoff: String?
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case success, handoff, error
        case sessionID = "session_id"
    }
}

public struct DJConnectSessionFlowItem: Codable, Equatable, Sendable, Identifiable {
    public var itemID: String
    public var itemType: String
    public var position: String
    public var label: String
    public var momentID: String? = nil
    public var momentType: String? = nil

    public var id: String { itemID }

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case itemType = "item_type"
        case position, label
        case momentID = "moment_id", momentType = "moment_type"
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try c.decode(String.self, forKey: .itemID)
        itemType = try c.decode(String.self, forKey: .itemType)
        position = try c.decode(String.self, forKey: .position)
        label = try c.decode(String.self, forKey: .label)
        momentID = try? c.decode(String.self, forKey: .momentID)
        momentType = try? c.decode(String.self, forKey: .momentType)
    }
    public init(itemID: String, itemType: String, position: String, label: String, momentID: String? = nil, momentType: String? = nil) {
        self.itemID = itemID; self.itemType = itemType; self.position = position; self.label = label
        self.momentID = momentID; self.momentType = momentType
    }
}

public struct DJConnectSessionFlow: Codable, Equatable, Sendable {
    public var flowRevision: Int? = nil
    public var flowID: String
    public var planningHorizonMinutes: Int
    public var createdAt: String
    public var items: [DJConnectSessionFlowItem]

    enum CodingKeys: String, CodingKey {
        case flowRevision = "flow_revision"
        case flowID = "flow_id"
        case planningHorizonMinutes = "planning_horizon_minutes"
        case createdAt = "created_at"
        case items
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        flowID = try c.decode(String.self, forKey: .flowID)
        planningHorizonMinutes = try c.decode(Int.self, forKey: .planningHorizonMinutes)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        flowRevision = try? c.decode(Int.self, forKey: .flowRevision)
        items = (try? c.decode([LossyBroadcastValue<DJConnectSessionFlowItem>].self, forKey: .items))?.compactMap(\.value) ?? []
    }
    public init(flowRevision: Int? = nil, flowID: String, planningHorizonMinutes: Int, createdAt: String, items: [DJConnectSessionFlowItem]) {
        self.flowRevision = flowRevision; self.flowID = flowID
        self.planningHorizonMinutes = planningHorizonMinutes; self.createdAt = createdAt; self.items = items
    }
}

public struct DJConnectBroadcastState: Codable, Equatable, Sendable {
    public struct Session: Codable, Equatable, Sendable {
        public var sessionID: String
        public var runtimeState: String
        public var selectedMood: String
        public var moodRevision: Int? = nil
        public var selectedPresence: DJConnectSessionPresenceValue? = nil
        public var presenceRevision: Int? = nil
        public var locale: String? = nil

        enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
            case runtimeState = "runtime_state"
            case selectedMood = "selected_mood"
            case locale, moodRevision = "mood_revision"
            case selectedPresence = "selected_presence", presenceRevision = "presence_revision"
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            sessionID = try c.decode(String.self, forKey: .sessionID)
            runtimeState = try c.decode(String.self, forKey: .runtimeState)
            selectedMood = try c.decode(String.self, forKey: .selectedMood)
            moodRevision = try c.decodeIfPresent(Int.self, forKey: .moodRevision)
            if let moodRevision, moodRevision < 0 { throw DJConnectError.invalidResponse }
            selectedPresence = try c.decodeIfPresent(DJConnectSessionPresenceValue.self, forKey: .selectedPresence)
            presenceRevision = try c.decodeIfPresent(Int.self, forKey: .presenceRevision)
            if let presenceRevision, presenceRevision < 0 { throw DJConnectError.invalidResponse }
            locale = try? c.decode(String.self, forKey: .locale)
        }
        public init(sessionID: String, runtimeState: String, selectedMood: String, locale: String? = nil, moodRevision: Int? = nil,
                    selectedPresence: DJConnectSessionPresenceValue? = nil, presenceRevision: Int? = nil) {
            self.sessionID = sessionID; self.runtimeState = runtimeState; self.selectedMood = selectedMood; self.locale = locale; self.moodRevision = moodRevision
            self.selectedPresence = selectedPresence; self.presenceRevision = presenceRevision
        }
    }

    public struct Planner: Codable, Equatable, Sendable {
        public var planningState: String
        public var planningHorizonMinutes: Int
        public var currentDirection: String

        enum CodingKeys: String, CodingKey {
            case planningState = "planning_state"
            case planningHorizonMinutes = "planning_horizon_minutes"
            case currentDirection = "current_direction"
        }
    }

    public struct Delivery: Codable, Equatable, Sendable {
        public var snapshotWatermark: Int?
        enum CodingKeys: String, CodingKey { case snapshotWatermark = "snapshot_watermark" }
    }
    public var nativeDelivery: DJConnectNativeMomentDelivery? = nil
    public var djMoments: [DJConnectMoment] = []
    public var presentations: [DJConnectPresentation] = []
    public var playback: DJConnectSessionPlayback? = nil
    public var delivery: Delivery? = nil
    // Local certainty fence, never decoded from or encoded onto the wire.
    var presenceConflictRevision: Int? = nil
    public var session: Session
    public var planner: Planner
    public var sessionFlow: DJConnectSessionFlow

    enum CodingKeys: String, CodingKey {
        case session, planner
        case nativeDelivery = "native_delivery"
        case djMoments = "dj_moments", presentations, playback
        case delivery = "broadcast"
        case sessionFlow = "session_flow"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        session = try c.decode(Session.self, forKey: .session)
        planner = try c.decode(Planner.self, forKey: .planner)
        sessionFlow = try c.decode(DJConnectSessionFlow.self, forKey: .sessionFlow)
        var seen = Set<String>()
        djMoments = ((try? c.decode([LossyBroadcastValue<DJConnectMoment>].self, forKey: .djMoments))?.compactMap(\.value) ?? []).filter {
            $0.sessionID == session.sessionID && !$0.id.isEmpty && seen.insert($0.id).inserted
        }
        presentations = (try? c.decode([LossyBroadcastValue<DJConnectPresentation>].self, forKey: .presentations))?.compactMap(\.value) ?? []
        playback = try? c.decode(DJConnectSessionPlayback.self, forKey: .playback)
        delivery = try? c.decode(Delivery.self, forKey: .delivery)
        nativeDelivery = try? c.decode(DJConnectNativeMomentDelivery.self, forKey: .nativeDelivery)
    }
    public init(session: Session, planner: Planner, sessionFlow: DJConnectSessionFlow) {
        self.session = session; self.planner = planner; self.sessionFlow = sessionFlow
    }
}

public struct DJConnectSessionRuntime: Codable, Equatable, Sendable, Identifiable {
    public var sessionID: String
    public var room: String
    public var selectedMood: String
    public var moodRevision: Int? = nil
    public var selectedPresence: DJConnectSessionPresenceValue? = nil
    public var presenceRevision: Int? = nil
    public var musicBackend: String
    public var runtimeState: String
    public var startedAt: String
    public var planner: DJConnectPlannerRuntime
    public var broadcast: DJConnectBroadcastState

    public var id: String { sessionID }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case room
        case selectedMood = "selected_mood"
        case moodRevision = "mood_revision"
        case selectedPresence = "selected_presence", presenceRevision = "presence_revision"
        case musicBackend = "music_backend"
        case runtimeState = "runtime_state"
        case startedAt = "started_at"
        case planner, broadcast
    }
}

public struct DJConnectPlannerRuntime: Codable, Equatable, Sendable {
    public var planningHorizonMinutes: Int

    enum CodingKeys: String, CodingKey {
        case planningHorizonMinutes = "planning_horizon_minutes"
    }
}

public struct DJConnectSessionResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var session: DJConnectSessionRuntime?
    public var activeSession: DJConnectSessionRuntime?
    public var error: String?
    public var message: String?

    enum CodingKeys: String, CodingKey {
        case success, session
        case activeSession = "active_session"
        case error, message
    }

    public var resolvedSession: DJConnectSessionRuntime? { session ?? activeSession }
}

public struct DJConnectSessionBroadcastSubscription: Codable, Equatable, Sendable {
    public var success: Bool
    public var subscriptionID: String
    public var sessionID: String
    public var snapshot: DJConnectBroadcastState

    enum CodingKeys: String, CodingKey {
        case success, snapshot
        case subscriptionID = "subscription_id"
        case sessionID = "session_id"
    }
}

public struct DJConnectSessionBroadcastEvent: Codable, Equatable, Sendable {
    public struct Payload: Codable, Equatable, Sendable {
        public var session: DJConnectBroadcastState.Session?
        public var planner: DJConnectBroadcastState.Planner?
        public var sessionFlow: DJConnectSessionFlow?
        public var nativeDelivery: DJConnectNativeMomentDelivery? = nil
        public var djMoment: DJConnectMoment? = nil
        public var presentation: DJConnectPresentation? = nil
        public var playback: DJConnectSessionPlayback? = nil

        enum CodingKeys: String, CodingKey {
            case session, planner, playback, presentation
            case nativeDelivery = "native_delivery"
            case djMoment = "dj_moment"
            case sessionFlow = "session_flow"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            session = try? c.decode(DJConnectBroadcastState.Session.self, forKey: .session)
            planner = try? c.decode(DJConnectBroadcastState.Planner.self, forKey: .planner)
            sessionFlow = try? c.decode(DJConnectSessionFlow.self, forKey: .sessionFlow)
            nativeDelivery = try? c.decode(DJConnectNativeMomentDelivery.self, forKey: .nativeDelivery)
            djMoment = try? c.decode(DJConnectMoment.self, forKey: .djMoment)
            presentation = try? c.decode(DJConnectPresentation.self, forKey: .presentation)
            playback = try? c.decode(DJConnectSessionPlayback.self, forKey: .playback)
        }
        public init(session: DJConnectBroadcastState.Session? = nil, planner: DJConnectBroadcastState.Planner? = nil, sessionFlow: DJConnectSessionFlow? = nil) {
            self.session = session; self.planner = planner; self.sessionFlow = sessionFlow
        }
    }

    public var deliverySequence: Int? = nil
    public var eventType: String
    public var sessionID: String
    public var payload: Payload

    enum CodingKeys: String, CodingKey {
        case deliverySequence = "delivery_sequence"
        case eventType = "event_type"
        case sessionID = "session_id"
        case payload
    }
}

public extension DJConnectSessionRuntime {
    func applying(broadcastState: DJConnectBroadcastState) -> DJConnectSessionRuntime {
        var runtime = self
        guard broadcastState.session.sessionID == sessionID,
              (broadcastState.delivery?.snapshotWatermark ?? 0) >= (broadcast.delivery?.snapshotWatermark ?? 0) else { return self }
        runtime.runtimeState = broadcastState.session.runtimeState
        let priorRevision = confirmedMoodRevision
        let incomingRevision = broadcastState.session.moodRevision
        let acceptMood = priorRevision == nil || incomingRevision.map { revision in
            revision > priorRevision! || (revision == priorRevision! && broadcastState.session.selectedMood == selectedMood)
        } == true
        if acceptMood {
            runtime.selectedMood = broadcastState.session.selectedMood
            runtime.moodRevision = incomingRevision
        }
        runtime.planner = DJConnectPlannerRuntime(
            planningHorizonMinutes: broadcastState.planner.planningHorizonMinutes
        )
        runtime.broadcast = broadcastState
        runtime.broadcast.presenceConflictRevision = [broadcast.presenceConflictRevision, broadcastState.presenceConflictRevision].compactMap { $0 }.max()
        if let priorRevision, !acceptMood {
            runtime.broadcast.session.selectedMood = selectedMood
            runtime.broadcast.session.moodRevision = priorRevision
        }
        // Presence is ordered independently of Mood, through every snapshot/event/recovery.
        runtime.selectedPresence = selectedPresence
        runtime.presenceRevision = presenceRevision
        runtime.broadcast.session.selectedPresence = broadcast.session.selectedPresence
        runtime.broadcast.session.presenceRevision = broadcast.session.presenceRevision
        if let value = broadcastState.session.selectedPresence, let revision = broadcastState.session.presenceRevision {
            runtime = runtime.applying(presence: .init(sessionID: sessionID, selectedPresence: value, presenceRevision: revision))
        }
        return runtime
    }

    func applying(broadcastEvent: DJConnectSessionBroadcastEvent) -> DJConnectSessionRuntime {
        guard broadcastEvent.sessionID == sessionID else { return self }
        if broadcastEvent.eventType == "runtime_ended" || broadcastEvent.eventType == "broadcast_stopped" {
            var result = self
            result.broadcast.clearNativeAuthority()
            if broadcastEvent.payload.nativeDelivery?.revocationScope != "subscription" {
                result.runtimeState = "ended"; result.broadcast.session.runtimeState = "ended"
            }
            return result
        }
        guard let sequence = broadcastEvent.deliverySequence else {
            var denied = self; denied.broadcast.clearNativeAuthority(); return denied
        }
        guard sequence > (broadcast.delivery?.snapshotWatermark ?? -1) else { return self }
        var state = broadcast
        state.nativeDelivery = broadcastEvent.payload.nativeDelivery
        if let sequence = broadcastEvent.deliverySequence { state.delivery = .init(snapshotWatermark: sequence) }
        if let playback = broadcastEvent.payload.playback { state.playback = playback }
        if let moment = broadcastEvent.payload.djMoment, moment.sessionID == sessionID,
           !state.djMoments.contains(where: { $0.id == moment.id }) { state.djMoments.append(moment) }
        if let presentation = broadcastEvent.payload.presentation,
           !state.presentations.contains(where: { $0.id == presentation.id }) { state.presentations.append(presentation) }
        if let session = broadcastEvent.payload.session { state.session = session }
        if let planner = broadcastEvent.payload.planner { state.planner = planner }
        if let sessionFlow = broadcastEvent.payload.sessionFlow { state.sessionFlow = sessionFlow }
        if let authority = state.nativeDelivery {
            let allowed = Set(authority.activeFlowMomentIDs + [authority.currentMomentID].compactMap { $0 })
            state.djMoments.removeAll { !allowed.contains($0.id) }
            state.presentations.removeAll { !allowed.contains($0.momentID) }
        }
        return applying(broadcastState: state)
    }
}

public struct DJConnectActiveMoodCapabilities: Decodable, Sendable {
    public struct Contract: Decodable, Sendable {
        let available: Bool
        let version: Int
        let path: String
        let method: String
        let authentication: String
        let moods: [String]
        let ordering: String
        let scope: String
    }
    let capabilities: [String: Bool]?
    let contractVersions: [String: Int]?
    let contract: Contract?
    let presenceContract: DJConnectPresenceCapability?
    enum CodingKeys: String, CodingKey {
        case capabilities, contractVersions = "contract_versions", contract = "active_session_mood"
        case presenceContract = "active_session_presence"
    }
    public var presenceAvailable: Bool {
        capabilities?["active_session_presence"] == true && contractVersions?["active_session_presence"] == 1 &&
        presenceContract?.isSupported == true
    }
    public var available: Bool {
        guard capabilities?["active_session_mood"] == true, contractVersions?["active_session_mood"] == 1,
              let contract else { return false }
        return contract.available && contract.version == 1 && contract.path == "/api/djconnect/v1/session/mood" &&
            contract.method == "POST" && contract.authentication == "paired_device_bearer" &&
            contract.moods == ["chill", "groove", "energy", "party"] && contract.ordering == "expected_mood_revision" &&
            contract.scope == "active_device_bound_owner_session"
    }
}

public struct DJConnectSessionMoodResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let contractVersion: Int
    public let sessionID: String
    public let selectedMood: String
    public let moodRevision: Int
    public let changed: Bool
    enum CodingKeys: String, CodingKey {
        case success, changed, contractVersion = "contract_version", sessionID = "session_id", selectedMood = "selected_mood", moodRevision = "mood_revision"
    }
}

public extension DJConnectSessionRuntime {
    var confirmedMoodRevision: Int? {
        [moodRevision, broadcast.session.moodRevision].compactMap { $0 }.filter { $0 >= 0 }.max()
    }
    func applying(mood response: DJConnectSessionMoodResponse) -> Self {
        guard response.success, response.contractVersion == 1, response.sessionID == sessionID,
              response.moodRevision >= 0, response.moodRevision >= (confirmedMoodRevision ?? 0),
              response.moodRevision != confirmedMoodRevision || response.selectedMood == selectedMood,
              ["chill", "groove", "energy", "party"].contains(response.selectedMood) else { return self }
        var result = self
        result.selectedMood = response.selectedMood; result.moodRevision = response.moodRevision
        result.broadcast.session.selectedMood = response.selectedMood; result.broadcast.session.moodRevision = response.moodRevision
        return result
    }
}
