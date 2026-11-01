import Foundation

/// Independent local resource bound, captured BEFORE awaiting the challenge.
/// No server UTC/TTL is converted into a new local lifetime or SDK permission.
struct HostWakeNativeProofWindow: Sendable {
    let deadline = ContinuousClock.now.advanced(by: .seconds(30))
    var isCurrent: Bool { ContinuousClock.now < deadline }
}

@MainActor protocol HostWakeNativeProofSDK {
    var isSupported: Bool { get }
    func invoke(_ input: HostWakeNativeProofInputData, deadline: ContinuousClock.Instant,
        current: @escaping @MainActor @Sendable () -> Bool) async throws -> Data
}

/// Once-accounting engine shared with synthetic tests. Constructing this type
/// cannot obtain the private system SDK, genuine warm key or reviewed selection.
@MainActor final class HostWakeNativeProofAttempt {
    private let storage: HostWakeFirstKeyJournal
    private let sdk: any HostWakeNativeProofSDK
    private let window: HostWakeNativeProofWindow
    private let current: @MainActor @Sendable () -> Bool
    private let cancellation = HostWakeNativeProofCancellation()
    private var entered = false
    init(storage: HostWakeFirstKeyJournal, sdk: any HostWakeNativeProofSDK,
        window: HostWakeNativeProofWindow, current: @escaping @MainActor @Sendable () -> Bool) {
        self.storage = storage; self.sdk = sdk; self.window = window; self.current = current
    }
    func close() { cancellation.close(); storage.close() }
    var isCurrent: Bool {
        guard cancellation.isLive, window.isCurrent, current(),
              (try? storage.validateOriginal()) != nil else { close(); return false }
        return true
    }
    func perform(_ input: HostWakeNativeProofInputData) async throws -> Data {
        guard !entered else { throw HostWakeFirstKeyAttempt.Failure.closed }
        entered = true // Never refunded, even before an unavailable SDK.
        let cancellation = cancellation
        do {
            return try await withTaskCancellationHandler {
                try Task.checkCancellation()
                guard sdk.isSupported, isCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
                try storage.claimNativeProofBeforeSDK(input)
                try Task.checkCancellation()
                guard isCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
                let bytes = try await sdk.invoke(input, deadline: window.deadline, current: { [self] in isCurrent })
                try Task.checkCancellation()
                guard isCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
                _ = try input.proofData(bytes) // Bounds only; retain opaque SDK bytes unchanged.
                return bytes
            } onCancel: { cancellation.close() }
        } catch { close(); throw error }
    }
}

private final class HostWakeNativeProofCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var live = true
    var isLive: Bool { lock.withLock { live } }
    func close() { lock.withLock { live = false } }
}
