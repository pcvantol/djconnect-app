import Foundation

// Core surface-push v1 consumer lifecycle. Registration is not enrollment.
// The owning service must supply a genuinely admitted original purpose.
public struct DJConnectSurfacePushCoordinate: Codable, Equatable, Sendable {
    public let registration_id: String
    public let generation: String
    public let revision: Int
    public var isValid: Bool { Self.identifier(registration_id) && Self.identifier(generation) && revision > 0 && Int64(revision) < 9_007_199_254_740_991 }
    static func identifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }
}

public struct DJConnectSurfacePushReceipt: Decodable, Sendable {
    public let registration_id: String
    public let generation: String
    public let revision: Int
    public let state: String
    public let expires_at_ms: Int64
    public let token_role: String
    public let platform: String
    public let cache_policy: String
    public var coordinate: DJConnectSurfacePushCoordinate {
        .init(registration_id: registration_id, generation: generation, revision: revision)
    }
}

public struct DJConnectSurfaceBackgroundRead: Decodable, Sendable {
    public let credential: String
    public let expires_at_ms: Int64
    public let registration_id: String
    public let scope: String
    public let cache_policy: String
    public func matches(_ receipt: DJConnectSurfacePushReceipt) -> Bool {
        credential.range(of: "^djcsurface_[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil &&
        expires_at_ms == receipt.expires_at_ms && registration_id == receipt.registration_id &&
        scope == "exact_original_surface_read_only" && cache_policy == "private,no-store"
    }
}

public struct DJConnectSurfacePushResponse: Decodable, Sendable {
    public struct Operation: Decodable, Sendable { public let phase: String }
    public let success: Bool
    public let replayed: Bool
    public let operation: Operation
    public let registration: DJConnectSurfacePushReceipt?
    public let background_read: DJConnectSurfaceBackgroundRead?
}

/// Owner, installation, Session, grant and token generation must be part of the
/// caller's original witness; an equal Profile name is never sufficient.
public struct DJConnectSurfacePushWitness: Equatable, Sendable {
    public let installation: String
    public let ownerEpoch: UUID
    public let session: String
    public let purposeGeneration: String
    public let targetInstance: String
    public let platform: String
    public let tokenRole: String
    public let tokenDigest: Data
    public let originalExpiryMS: Int64
    public let originalMonotonicDeadline: ContinuousClock.Instant
}

@MainActor
public final class DJConnectSurfacePushRegistration {
    public enum State: Equatable { case idle, registering, registered, outcomeUnknown, withdrawn }
    public struct Services {
        public let isCurrent: @MainActor (DJConnectSurfacePushWitness) -> Bool
        public let nowMS: @MainActor () -> Int64
        public let monotonicNow: @MainActor () -> ContinuousClock.Instant
        public let register: @MainActor (DJConnectSurfacePushWitness, DJConnectSurfacePushCoordinate?) async throws -> DJConnectSurfacePushResponse
        public let revoke: @MainActor (DJConnectSurfacePushWitness, DJConnectSurfacePushCoordinate) async throws -> DJConnectSurfacePushResponse
        // Must atomically publish or scrub only the separately scoped credential.
        // The ordinary paired bearer is never an argument to this operation.
        public let publishBackgroundRead: @MainActor (DJConnectSurfaceBackgroundRead?) -> Void
    }
    public private(set) var state: State = .idle
    public private(set) var coordinate: DJConnectSurfacePushCoordinate?
    private var witness: DJConnectSurfacePushWitness?
    private var epoch = UUID()
    private var busy = false
    private var acceptedExpiryMS: Int64?
    public init() {}

    /// Never retries a write automatically. Unknown outcomes require explicit
    /// original-operation reconciliation by the owning caller, not fresh IDs.
    public func register(_ original: DJConnectSurfacePushWitness, services: Services) async {
        guard !Task.isCancelled, !busy, state != .outcomeUnknown, services.isCurrent(original),
              original.originalExpiryMS > services.nowMS(),
              services.monotonicNow() < original.originalMonotonicDeadline else { return }
        if state == .registered, witness == original { return }
        // A different owner/session/target cannot rotate the old registration.
        if let previous = witness, coordinate != nil {
            guard previous.installation == original.installation,
                  previous.ownerEpoch == original.ownerEpoch,
                  previous.session == original.session,
                  previous.purposeGeneration == original.purposeGeneration,
                  previous.targetInstance == original.targetInstance,
                  previous.platform == original.platform,
                  previous.tokenRole == original.tokenRole,
                  previous.originalExpiryMS == original.originalExpiryMS,
                  previous.originalMonotonicDeadline == original.originalMonotonicDeadline else { return }
        }
        busy = true
        let attempt = UUID(); epoch = attempt
        let expected = coordinate
        guard expected.map({ $0.isValid && $0.revision < Int.max && Int64($0.revision) < 9_007_199_254_740_990 }) ?? true else { busy = false; return }
        let expectedExpiry = acceptedExpiryMS
        witness = original; state = .registering
        services.publishBackgroundRead(nil) // Rotation invalidates local reads before suspension.
        defer { if epoch == attempt { busy = false } }
        do {
            guard !Task.isCancelled, epoch == attempt, services.isCurrent(original),
                  services.nowMS() < original.originalExpiryMS,
                  services.monotonicNow() < original.originalMonotonicDeadline else {
                state = .withdrawn; witness = nil; coordinate = nil; return
            }
            guard !Task.isCancelled else { state = .withdrawn; witness = nil; coordinate = nil; return }
            let response = try await services.register(original, expected)
            guard epoch == attempt else { return }
            guard !Task.isCancelled, services.isCurrent(original),
                  services.nowMS() < original.originalExpiryMS,
                  services.monotonicNow() < original.originalMonotonicDeadline else {
                state = .withdrawn; coordinate = nil; witness = nil; return
            }
            guard response.success, response.operation.phase == "confirmed",
                  let receipt = response.registration, receipt.coordinate.isValid,
                  receipt.state == "registered", receipt.token_role == original.tokenRole,
                  receipt.platform == original.platform, receipt.cache_policy == "private,no-store",
                  receipt.expires_at_ms == original.originalExpiryMS,
                  receipt.expires_at_ms > services.nowMS(),
                  expectedExpiry == nil || receipt.expires_at_ms == expectedExpiry,
                  expected == nil || (receipt.registration_id == expected?.registration_id &&
                    receipt.revision == expected!.revision + 1 && receipt.generation == expected?.generation),
                  response.background_read.map({ $0.matches(receipt) }) ?? (original.tokenRole != "widget")
            else { state = .outcomeUnknown; return }
            guard !Task.isCancelled, epoch == attempt else { state = .withdrawn; witness = nil; coordinate = nil; return }
            coordinate = receipt.coordinate; acceptedExpiryMS = receipt.expires_at_ms; state = .registered
            services.publishBackgroundRead(response.background_read)
        } catch {
            guard epoch == attempt else { return }
            state = services.isCurrent(original) ? .outcomeUnknown : .withdrawn
        }
    }

    /// Scrub synchronously before any revoke/network await; old ACKs cannot
    /// resurrect a locally withdrawn credential. No successor-owner write.
    public func withdraw(services: Services) async {
        let previous = witness, expected = coordinate
        epoch = UUID(); busy = false; coordinate = nil; witness = nil; acceptedExpiryMS = nil
        state = .withdrawn; services.publishBackgroundRead(nil)
        guard !Task.isCancelled, let previous, let expected, services.isCurrent(previous),
              services.nowMS() < previous.originalExpiryMS,
              services.monotonicNow() < previous.originalMonotonicDeadline else { return }
        guard !Task.isCancelled else { return }
        _ = try? await services.revoke(previous, expected)
        // Revoke ACK is evidence for caller, never registration/read authority.
    }
}
