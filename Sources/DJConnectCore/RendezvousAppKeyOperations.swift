import Foundation

/// Process-wide sequencing for the complete App Attest sign → submit operation.
/// The caller must revalidate its owner context and original deadlines after
/// acquiring the slot, and resolve retries/outcome uncertainty inside its operation.
/// This component neither authorizes an action nor generates or persists keys.
public actor RendezvousAppKeyOperations {
    public static let shared = RendezvousAppKeyOperations()
    // Shared by initial generation and every legacy journal creation entry point.
    static let installationAdmissionSlot = "rendezvous-initial-generation-v1"
    @TaskLocal static var initialEnrollmentLease:RendezvousInitialEnrollmentLease?
    @TaskLocal private static var installationTransitionLease: RendezvousInstallationTransitionLease?

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }
    private struct Slot {
        var owner: UUID
        var waiters: [Waiter] = []
    }
    private var slots: [String: Slot] = [:]

    private let onInstallationTransitionAcquired: (@Sendable () -> Void)?
    // The callback is an internal synchronous test barrier; production leaves it nil.
    init(onInstallationTransitionAcquired: (@Sendable () -> Void)? = nil) {
        self.onInstallationTransitionAcquired = onInstallationTransitionAcquired
    }

    public enum Failure: Error, Sendable {
        case emptyKeyIdentifier, invalidInitialEnrollmentLease, initialEnrollmentKeyBusy
        case invalidInstallationTransition, installationTransitionKeyBusy
    }

    public func perform<Value: Sendable>(
        keyIdentifier: String,
        operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        guard !keyIdentifier.isEmpty else { throw Failure.emptyKeyIdentifier }
        if let lease = Self.installationTransitionLease {
            try lease.beginBorrow(key: keyIdentifier, queue: ObjectIdentifier(self))
            defer { lease.endBorrow() }
            try Task.checkCancellation()
            let result = try await operation()
            try lease.validateOpen()
            return result
        }
        let id = UUID()
        if let lease = Self.initialEnrollmentLease,keyIdentifier != Self.installationAdmissionSlot {
            // Initial enrollment already owns the installation slot. Never wait
            // for a key owner that could itself be waiting to create a journal.
            try lease.withAccess(keyIdentifier:keyIdentifier) {
                guard slots[keyIdentifier] == nil else { throw Failure.initialEnrollmentKeyBusy }
                slots[keyIdentifier] = Slot(owner:id)
            }
        } else {
            try await acquire(key: keyIdentifier, id: id)
        }
        defer { release(key: keyIdentifier, id: id) }
        try Task.checkCancellation()
        // Keep ownership through every suspension, including cancellation cleanup
        // and the response to submission. Actor isolation alone is reentrant.
        return try await operation()
    }

    /// Local composition/migration only. Never wait for an affected key while
    /// holding installation admission: an old key owner may itself await it.
    /// No SDK/HTTP authority is supplied by this internal exclusion primitive.
    func performInstallationTransition<Value: Sendable>(
        affectedKeys: [String], operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        guard Self.installationTransitionLease == nil, Self.initialEnrollmentLease == nil,
              affectedKeys.count <= 2, Set(affectedKeys).count == affectedKeys.count,
              affectedKeys.allSatisfy({ !$0.isEmpty && $0 != Self.installationAdmissionSlot }) else {
            throw Failure.invalidInstallationTransition
        }
        let id = UUID(), keys = affectedKeys.sorted()
        try await acquire(key: Self.installationAdmissionSlot, id: id)
        defer { release(key: Self.installationAdmissionSlot, id: id) }
        try Task.checkCancellation()
        onInstallationTransitionAcquired?()
        // Actor isolation covers the entire test-and-reserve set, without await.
        guard keys.allSatisfy({ slots[$0] == nil }) else { throw Failure.installationTransitionKeyBusy }
        for key in keys { slots[key] = Slot(owner: id) }
        defer { for key in keys.reversed() { release(key: key, id: id) } }
        let lease = RendezvousInstallationTransitionLease(keys: Set(keys + [Self.installationAdmissionSlot]), queue: ObjectIdentifier(self))
        let result: Result<Value, any Error> = await Self.$installationTransitionLease.withValue(lease) {
            do {
                let value = try await operation()
                try Task.checkCancellation()
                try lease.validateQuiescent()
                return .success(value)
            } catch { return .failure(error) }
        }
        // An inherited borrower cannot outlive the logical exclusion. Close to
        // new work, then drain even an uncooperative borrower before releasing.
        await lease.closeWhenQuiescent()
        return try result.get()
    }

    private func acquire(key: String, id: UUID) async throws {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                if var slot = slots[key] {
                    slot.waiters.append(Waiter(id: id, continuation: continuation))
                    slots[key] = slot
                } else {
                    slots[key] = Slot(owner: id)
                    continuation.resume()
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(key: key, id: id) }
        }
    }

    private func cancelWaiter(key: String, id: UUID) {
        guard var slot = slots[key],
              let index = slot.waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = slot.waiters.remove(at: index)
        slots[key] = slot
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func release(key: String, id: UUID) {
        guard var slot = slots[key], slot.owner == id else { return }
        guard !slot.waiters.isEmpty else {
            slots.removeValue(forKey: key)
            return
        }
        let next = slot.waiters.removeFirst()
        slot.owner = next.id
        slots[key] = slot
        next.continuation.resume()
    }

    // Scheduling barrier for deterministic concurrency qualification; no key IDs
    // or assertion material are exposed through logging or product diagnostics.
    func waitingOperationCount(for key: String) -> Int {
        slots[key]?.waiters.count ?? 0
    }
}


/// Ephemeral key-bound ordering scope; it grants NO journal creation access.
/// It permits only non-waiting per-key acquisition and is never persisted/exported.
final class RendezvousInitialEnrollmentLease:@unchecked Sendable {
    private let lock = NSLock()
    private var open = true
    private let key:String
    private let qr:DJConnectRendezvousQR
    init(key:String,qr:DJConnectRendezvousQR) { self.key = key; self.qr = qr }
    func close() { lock.withLock { open = false } }
    func withAccess<Value>(keyIdentifier:String,operation:()throws->Value) throws -> Value {
        try lock.withLock {
            guard open,keyIdentifier == key,!Task.isCancelled,qr.isCurrent() else {
                throw RendezvousAppKeyOperations.Failure.invalidInitialEnrollmentLease
            }
            // No suspension between validation and durable creation. Closing an
            // inherited lease cannot race a late child's synchronous write.
            return try operation()
        }
    }
}

/// Inherited tasks may not borrow after closure or overlap an existing borrow.
/// The lease is exclusion only; it creates no key, budget, native or owner grant.
private final class RendezvousInstallationTransitionLease: @unchecked Sendable {
    private let lock = NSLock()
    private let keys: Set<String>
    private let queue: ObjectIdentifier
    private var open = true
    private var borrowed = false
    private var closedWaiter: CheckedContinuation<Void, Never>?
    init(keys: Set<String>, queue: ObjectIdentifier) { self.keys = keys; self.queue = queue }
    func beginBorrow(key: String, queue expectedQueue: ObjectIdentifier) throws {
        try lock.withLock {
            guard open, !borrowed, queue == expectedQueue, keys.contains(key) else {
                throw RendezvousAppKeyOperations.Failure.invalidInstallationTransition
            }
            borrowed = true
        }
    }
    func endBorrow() {
        let waiter = lock.withLock {
            borrowed = false
            let value = closedWaiter; closedWaiter = nil
            return value
        }
        waiter?.resume()
    }
    func validateOpen() throws {
        try lock.withLock {
            guard open else { throw RendezvousAppKeyOperations.Failure.invalidInstallationTransition }
        }
    }
    func validateQuiescent() throws {
        try lock.withLock {
            guard open, !borrowed else { throw RendezvousAppKeyOperations.Failure.invalidInstallationTransition }
        }
    }
    func closeWhenQuiescent() async {
        await withCheckedContinuation { continuation in
            let done = lock.withLock {
                open = false
                if borrowed { closedWaiter = continuation; return false }
                return true
            }
            if done { continuation.resume() }
        }
    }
}
