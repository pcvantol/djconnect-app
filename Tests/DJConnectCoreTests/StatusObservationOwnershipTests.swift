import Foundation
import Testing
@testable import DJConnectCore

/// MODEL continuity/cancellation controls; never an original source factory,
/// OS selection, enrolled key, signing permission or native delivery result.
@Suite @MainActor struct StatusObservationOwnershipTests {
    @Test(arguments: ["profile", "session", "source", "token", "registered_child", "local_resources"])
    func observedOwningLossIsTerminalEvenIfTheSameDataReturns(_ field: String) {
        let flags = Flags()
        let owner = StatusObservationOwnershipContinuity { !flags.lost.contains(field) }
        #expect(owner.isCurrent)
        flags.lost.insert(field)
        #expect(!owner.isCurrent)
        flags.lost.remove(field)
        #expect(!owner.isCurrent)
    }
    @Test func cancellingOneRefreshDoesNotManufactureOrRevokeOriginalOwnership() async {
        let flags = Flags()
        let owner = StatusObservationOwnershipContinuity { flags.lost.isEmpty }
        let gate = Gate()
        let worker = Task { @MainActor in
            await gate.wait()
            return (!Task.isCancelled, owner.isCurrent)
        }
        await gate.entered()
        worker.cancel(); gate.release()
        let outcome = await worker.value
        #expect(!outcome.0 && outcome.1) // No dispatch allowed; original ownership remains separate.
        flags.lost.insert("token")
        #expect(!owner.isCurrent)
    }
    @MainActor private final class Flags { var lost: Set<String> = [] }
    @MainActor private final class Gate {
        private var held: CheckedContinuation<Void, Never>?
        private var observer: CheckedContinuation<Void, Never>?
        func wait() async {
            await withCheckedContinuation { continuation in
                held = continuation; observer?.resume(); observer = nil
            }
        }
        func entered() async {
            if held != nil { return }
            await withCheckedContinuation { observer = $0 }
        }
        func release() { held?.resume(); held = nil }
    }
}
