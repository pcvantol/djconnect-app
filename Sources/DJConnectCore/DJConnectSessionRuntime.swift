import Foundation

public struct DJConnectSessionStartRequest: Codable, Equatable, Sendable {
    public var mood: String

    public init(mood: String) {
        self.mood = mood
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

public struct DJConnectSessionFlowItem: Codable, Equatable, Sendable, Identifiable {
    public var itemID: String
    public var itemType: String
    public var position: String
    public var label: String

    public var id: String { itemID }

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case itemType = "item_type"
        case position, label
    }
}

public struct DJConnectSessionFlow: Codable, Equatable, Sendable {
    public var flowID: String
    public var planningHorizonMinutes: Int
    public var createdAt: String
    public var items: [DJConnectSessionFlowItem]

    enum CodingKeys: String, CodingKey {
        case flowID = "flow_id"
        case planningHorizonMinutes = "planning_horizon_minutes"
        case createdAt = "created_at"
        case items
    }
}

public struct DJConnectBroadcastState: Codable, Equatable, Sendable {
    public struct Session: Codable, Equatable, Sendable {
        public var sessionID: String
        public var runtimeState: String
        public var selectedMood: String

        enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
            case runtimeState = "runtime_state"
            case selectedMood = "selected_mood"
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

    public var session: Session
    public var planner: Planner
    public var sessionFlow: DJConnectSessionFlow

    enum CodingKeys: String, CodingKey {
        case session, planner
        case sessionFlow = "session_flow"
    }
}

public struct DJConnectSessionRuntime: Codable, Equatable, Sendable, Identifiable {
    public var sessionID: String
    public var room: String
    public var selectedMood: String
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
        case musicBackend = "music_backend"
        case runtimeState = "runtime_state"
        case startedAt = "started_at"
        case planner, broadcast
    }
}

public struct DJConnectPlannerRuntime: Codable, Equatable, Sendable {
    public var planningHorizonMinutes: Int
    public var currentDirection: String

    enum CodingKeys: String, CodingKey {
        case planningHorizonMinutes = "planning_horizon_minutes"
        case currentDirection = "current_direction"
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

        enum CodingKeys: String, CodingKey {
            case session, planner
            case sessionFlow = "session_flow"
        }
    }

    public var eventType: String
    public var sessionID: String
    public var payload: Payload

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case sessionID = "session_id"
        case payload
    }
}

public extension DJConnectSessionRuntime {
    func applying(broadcastState: DJConnectBroadcastState) -> DJConnectSessionRuntime {
        var runtime = self
        runtime.runtimeState = broadcastState.session.runtimeState
        runtime.selectedMood = broadcastState.session.selectedMood
        runtime.planner = DJConnectPlannerRuntime(
            planningHorizonMinutes: broadcastState.planner.planningHorizonMinutes,
            currentDirection: broadcastState.planner.currentDirection
        )
        runtime.broadcast = broadcastState
        return runtime
    }

    func applying(broadcastEvent: DJConnectSessionBroadcastEvent) -> DJConnectSessionRuntime {
        var state = broadcast
        if let session = broadcastEvent.payload.session { state.session = session }
        if let planner = broadcastEvent.payload.planner { state.planner = planner }
        if let sessionFlow = broadcastEvent.payload.sessionFlow { state.sessionFlow = sessionFlow }
        return applying(broadcastState: state)
    }
}
