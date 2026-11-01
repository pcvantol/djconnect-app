import Foundation

/// The app's one retained direct-read owner for one surface and Session.
/// The initializer captures an actual paired client; neither a restored DTO
/// nor a returned frame can construct its original receiving context.
/// This object does not grant native display, SDK, enrollment or clock rights.
@MainActor public final class DJConnectDirectSessionRuntime {
    public enum Phase: Equatable, Sendable { case idle, authorizing, active, suspended, closed, unknown }
    private let custody: DirectRichReadCustody
    private let captureHostWakeAttempt: (@MainActor @Sendable () -> (@MainActor @Sendable () -> Bool))?
    private var candidate: DirectRichReadCustody.Candidate?
    private var withdrawalTask: Task<Void, any Error>?
    private let withdrawalCancellation = CoreHostWakeProxyCancellation()

    public init(client: DJConnectClient, sessionID: String, surface: DJConnectPassiveSurface,
                lockedDisplay: Bool,
                pairedIsCurrent: @escaping @MainActor @Sendable () -> Bool,
                ownerIsCurrent: @escaping @MainActor @Sendable () -> Bool,
                captureAttempt: @escaping @MainActor @Sendable () -> (@MainActor @Sendable () -> Bool),
                captureHostWakeAttempt: (@MainActor @Sendable () -> (@MainActor @Sendable () -> Bool))? = nil) throws {
        self.captureHostWakeAttempt = captureHostWakeAttempt
        custody = try DirectRichReadCustody(client: client, sessionID: sessionID, surface: surface,
            lockedDisplay: lockedDisplay, pairedIsCurrent: pairedIsCurrent,
            ownerIsCurrent: ownerIsCurrent, captureAttempt: captureAttempt)
    }

    /// Internal synthetic DATA tests retain the existing injected transport's
    /// missing ReceivingContext. This cannot create a genuine parent or permit.
    init(testCustody: DirectRichReadCustody) { custody = testCustody; captureHostWakeAttempt = nil }
    deinit { withdrawalCancellation.cancelAll(); custody.cancelOwnedResources() }

    /// Synchronous negative resource hook for the actual AppModel's deinit.
    /// In-flight calls may still retain this object until cancellation unwinds.
    public nonisolated func cancelOwnedResources() { withdrawalCancellation.cancelAll(); custody.cancelOwnedResources() }

    public var phase: Phase {
        switch custody.state {
        case .idle: .idle
        case .authorizing: .authorizing
        case .active: .active
        case .suspended: .suspended
        case .closed: .closed
        case .unknown: .unknown
        }
    }

    public func begin() async throws {
        let received = try await custody.authorize()
        try Task.checkCancellation()
        guard received.isCurrent else { throw CancellationError() }
        candidate = received
    }

    /// Reads retain the same original operation, purpose and pre-await C0.
    /// This never replaces a failed/unknown authorization with a new UUID.
    public func read() async throws {
        let received = try await custody.read()
        try Task.checkCancellation()
        guard received.isCurrent else { throw CancellationError() }
        candidate = received
    }

    /// Only the actual foreground enrollment owner can transfer an ACKed child
    /// before suspension. Original read/asset, local resource and field bounds
    /// remain unchanged; SDK/effect work can then close independently.
    func retainRegisteredHostWakeRead(child: CoreHostWakeProxyCustody,
        parent: DirectRichReadCustody.OriginalPurposeContext) throws {
        guard captureHostWakeAttempt != nil else { throw CancellationError() }
        try custody.retainRegisteredRead(from: child, parent: parent)
    }
    public var hasRegisteredHostWakeRead: Bool { custody.hasRegisteredRead }
    /// An OS hint may read only an already transferred warm original. It never
    /// begins authorization, adopts status history or recreates a cold owner.
    public func readRegisteredHostWake() async throws {
        guard let captureHostWakeAttempt else { throw CancellationError() }
        let received = try await custody.readRegistered(captureAttempt: captureHostWakeAttempt)
        try Task.checkCancellation()
        guard received.isCurrent else { throw CancellationError() }
        candidate = received
    }

    public func suspend() { candidate = nil; custody.suspend() }
    public func retire() { candidate = nil; custody.retire() }

    public func withdraw() async throws {
        // Local invalidation precedes even the async call boundary.
        retire()
        try Task.checkCancellation()
        if let withdrawalTask {
            try await withdrawalTask.value
            try Task.checkCancellation()
            return // Join the original result, including failure/UNKNOWN.
        }
        guard custody.authorizationWasStarted else { return } // No remote scope was attempted.
        let custody = custody, id = UUID()
        let task = Task { @MainActor in
            var failure: (any Error)?
            do { try await custody.withdrawExistingPushChild() } catch { failure = error }
            // A child failure must not skip independent parent-display cleanup.
            do { _ = try await custody.withdraw() } catch { if failure == nil { failure = error } }
            if let failure { throw failure }
        }
        withdrawalTask = task // Claim once before the FIRST async call; never reset on lost reply.
        do { try withdrawalCancellation.install(id, positive: false, cancel: { task.cancel() }) }
        catch { task.cancel(); throw error }
        defer { withdrawalCancellation.finish(id) }
        try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        try Task.checkCancellation()
    }
    public func readManagementStatus() async throws { _ = try await custody.status() }

    // Deliberately module-internal. The native owner must join the genuine
    // original clock/enrollment suppliers before using these original inputs.
    // There is no public frame/DTO -> parent or native permission conversion.
    var nativeQualificationInputs: DirectRichReadCustody.Candidate.NativeInputs? { candidate?.nativeQualificationInputs }
    var originalPurposeContext: DirectRichReadCustody.OriginalPurposeContext? { custody.originalPurposeContext }
}
