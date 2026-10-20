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

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }
    private struct Slot {
        var owner: UUID
        var waiters: [Waiter] = []
    }
    private var slots: [String: Slot] = [:]

    // Production callers use the one shared instance across scans and actions.
    init() {}

    public enum Failure: Error, Sendable {
        case emptyKeyIdentifier, invalidInitialEnrollmentLease, initialEnrollmentKeyBusy
    }

    public func perform<Value: Sendable>(
        keyIdentifier: String,
        operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        guard !keyIdentifier.isEmpty else { throw Failure.emptyKeyIdentifier }
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
