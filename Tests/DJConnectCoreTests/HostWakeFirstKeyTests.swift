import Foundation
import Darwin
import Testing
@testable import DJConnectCore

/// Actual local filesystem/once semantics with a synthetic SDK. None of these
/// cases qualify App Attest, a signed device, operator authority or enrollment.
@Suite @MainActor struct HostWakeFirstKeyTests {
    private func support() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("host-wake-once-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }
    private func journal(_ root: URL) throws -> HostWakeFirstKeyJournal {
        try .init(freshInExistingSupport: root, artifact: String(repeating: "a", count: 64))
    }
    private func file(_ root: URL, _ name: String) -> URL {
        root.appendingPathComponent("DJConnectHostWakeFirstKey-v1").appendingPathComponent(name)
    }
    @Test func ordinaryStartupHasNoSelectedEffectOrAutomaticGeneration() {
        let owner = DJConnectHostWakeFirstKeyOwner()
        #expect(owner.state == .closed)
        #expect(!owner.showsOperatorAction)
        #expect(owner.originalSurfaceData == nil)
        owner.operatorRequestsFirstKey()
        #expect(owner.state == .closed)
        owner.closeOriginalOperation()
        owner.operatorRequestsFirstKey()
        #expect(owner.state == .closed)
    }
    @Test func sdkSeesDurableOriginalClaimAndCanonicalReferenceIsOnlyData() async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK()
        sdk.onEntry = { () throws in
            #expect(FileManager.default.fileExists(atPath: self.file(root, "sdk-start.json").path))
            let claim = try Data(contentsOf: self.file(root, "sdk-start.json"))
            let identity = try Data(contentsOf: self.file(root, "identity.json"))
            #expect(claim == identity)
        }
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
        let key = try await owner.perform()
        #expect(sdk.calls == 1)
        #expect(try Data(contentsOf: file(root, "key-reference")) == Data(key.utf8))
        do { _ = try await owner.perform(); Issue.record("second original SDK start") } catch {}
        #expect(sdk.calls == 1)
        // Cold/recreated runtime cannot turn existing DATA into a new reservation.
        do { _ = try journal(root); Issue.record("cold journal adopted") } catch {}
    }
    @Test func claimOrCallbackLossNeverRefundsTheStart() async throws {
        for malformed in [false, true] {
            let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
            let store = try journal(root), sdk = ModelSDK()
            sdk.result = malformed ? .success("not-an-sdk-key") : .failure(ModelSDK.Loss())
            let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
            do { _ = try await owner.perform(); Issue.record("unknown callback accepted") } catch {}
            do { _ = try await owner.perform(); Issue.record("unknown operation retried") } catch {}
            #expect(sdk.calls == 1)
            #expect(!FileManager.default.fileExists(atPath: file(root, "key-reference").path))
            #expect(FileManager.default.fileExists(atPath: file(root, "sdk-start.json").path))
            do { _ = try journal(root); Issue.record("fresh namespace after loss") } catch {}
        }
    }
    @Test func originalOwnerLossAtCallbackRejectsReferenceAndRetry() async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK(), flags = Flags()
        sdk.onEntry = { flags.current = false }
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { flags.current })
        do { _ = try await owner.perform(); Issue.record("lost owner callback accepted") } catch {}
        flags.current = true // ABA does not restore original custody.
        do { _ = try await owner.perform(); Issue.record("owner ABA retried") } catch {}
        #expect(sdk.calls == 1)
        #expect(!FileManager.default.fileExists(atPath: file(root, "key-reference").path))
    }
    @Test func cancelledOriginalTaskRejectsLateCallbackWithoutWritingReference() async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK()
        sdk.hold = true
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
        let task = Task { () -> Bool in do { _ = try await owner.perform(); return true } catch { return false } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while sdk.calls == 0 && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(sdk.calls == 1)
        task.cancel()
        sdk.release() // Deliberately uncooperative synthetic SDK; real caller still fences it.
        #expect(await task.value == false)
        #expect(!FileManager.default.fileExists(atPath: file(root, "key-reference").path))
        #expect(FileManager.default.fileExists(atPath: file(root, "sdk-start.json").path))
    }
    @Test func malformedOrMissingOriginalIdentityClosesBeforeSDK() async throws {
        for missing in [false, true] {
            let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
            let store = try journal(root), sdk = ModelSDK()
            if missing { try FileManager.default.removeItem(at: file(root, "identity.json")) }
            else { try Data("{}".utf8).write(to: file(root, "identity.json")) }
            let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
            do { _ = try await owner.perform(); Issue.record("missing/malformed identity accepted") } catch {}
            #expect(sdk.calls == 0)
            do { _ = try journal(root); Issue.record("damaged directory replaced") } catch {}
        }
    }
    @Test func renamedOriginalDirectoryOrSymlinkCannotBecomeFreshInstallation() throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root)
        let directory = file(root, "identity.json").deletingLastPathComponent()
        let moved = root.appendingPathComponent("old")
        try FileManager.default.moveItem(at: directory, to: moved)
        try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: moved)
        do { try store.claimBeforeSDK(); Issue.record("replaced directory kept custody") } catch {}
        do { _ = try journal(root); Issue.record("symlink genesis") } catch {}
    }
    @Test func unsupportedSDKCannotConsumeAStartOrCreateReference() async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK(); sdk.isSupported = false
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
        do { _ = try await owner.perform(); Issue.record("unsupported SDK executed") } catch {}
        #expect(sdk.calls == 0)
        #expect(!FileManager.default.fileExists(atPath: file(root, "sdk-start.json").path))
        // The initialization remains occupied; this same owner is terminal too.
        sdk.isSupported = true
        do { _ = try await owner.perform(); Issue.record("closed unsupported attempt retried") } catch {}
        #expect(sdk.calls == 0)
    }
    @Test func replacingOriginalIdentityWithEqualBytesDoesNotRestoreCustody() async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK()
        let path = file(root, "identity.json"), bytes = try Data(contentsOf: path)
        try FileManager.default.removeItem(at: path)
        try bytes.write(to: path)
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
        do { _ = try await owner.perform(); Issue.record("equal-byte replacement restored custody") } catch {}
        #expect(sdk.calls == 0)
    }
    @Test func replacedSDKClaimAtCallbackRejectsEvenEqualBytes() async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK()
        sdk.onEntry = { () throws in
            let path = self.file(root, "sdk-start.json"), bytes = try Data(contentsOf: path)
            try FileManager.default.removeItem(at: path)
            try bytes.write(to: path)
        }
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
        do { _ = try await owner.perform(); Issue.record("replaced claim accepted callback") } catch {}
        #expect(sdk.calls == 1)
        #expect(!FileManager.default.fileExists(atPath: file(root, "key-reference").path))
    }
    @Test func incompleteOldDirectoryIsOccupiedAndNeverReinitialized() throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        #expect(HostWakeFirstKeyJournal.namespaceIsAbsent(inExistingSupport: root))
        let directory = file(root, "identity.json").deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        #expect(!HostWakeFirstKeyJournal.namespaceIsAbsent(inExistingSupport: root))
        do { _ = try journal(root); Issue.record("partial old initialization treated as fresh") } catch {}
        #expect(!FileManager.default.fileExists(atPath: file(root, "identity.json").path))
    }
    @Test func observedWarmReferenceOwnerLossCannotReopenBeforeCorePrepare() async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK(), flags = Flags()
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { flags.current })
        _ = try await owner.perform()
        #expect(owner.referenceIsCurrent)
        flags.current = false
        #expect(!owner.referenceIsCurrent)
        flags.current = true
        #expect(!owner.referenceIsCurrent)
        #expect(sdk.calls == 1)
    }
    @Test func observedMissingWarmReferenceCannotReopenAfterFileReturns() async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK()
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
        _ = try await owner.perform()
        let path = file(root, "key-reference"), moved = root.appendingPathComponent("held-reference")
        try FileManager.default.moveItem(at: path, to: moved)
        #expect(!owner.referenceIsCurrent)
        try FileManager.default.moveItem(at: moved, to: path)
        #expect(!owner.referenceIsCurrent)
        #expect(sdk.calls == 1)
    }
    @Test(arguments: ["identity.json", "sdk-start.json", "key-reference"])
    func fifoReplacementIsRejectedBeforeBlockingTheOwner(_ name: String) async throws {
        let root = try support(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try journal(root), sdk = ModelSDK()
        let owner = HostWakeFirstKeyAttempt(storage: store, sdk: sdk, current: { true })
        _ = try await owner.perform()
        let path = file(root, name).path
        try FileManager.default.removeItem(atPath: path)
        #expect(mkfifo(path, 0o600) == 0)
        // A regressed blocking open is released by an independent watchdog.
        // It then fails the elapsed-time assertion instead of hanging the suite.
        let watchdog = Task.detached {
            try? await Task.sleep(for: .seconds(2))
            let fd = open(path, O_WRONLY | O_NONBLOCK | O_CLOEXEC)
            if fd >= 0 { Darwin.close(fd) }
        }
        let start = ContinuousClock.now
        let current = owner.referenceIsCurrent
        let elapsed = start.duration(to: .now)
        await watchdog.value // Join before deleting this case's private fixture.
        #expect(!current)
        #expect(elapsed < .seconds(1))
        #expect(sdk.calls == 1)
    }
}

@MainActor private final class Flags { var current = true }
@MainActor private final class ModelSDK: HostWakeFirstKeySDK {
    struct Loss: Error {}
    var isSupported = true
    var calls = 0
    var hold = false
    var onEntry: (() throws -> Void)?
    var result: Result<String, any Error> = .success(Data(repeating: 7, count: 32).base64EncodedString())
    private var continuation: CheckedContinuation<Void, Never>?
    func generate(deadline: ContinuousClock.Instant, current: @escaping @MainActor @Sendable () -> Bool) async throws -> String {
        #expect(ContinuousClock.now < deadline)
        #expect(current())
        calls += 1
        try onEntry?()
        if hold { await withCheckedContinuation { continuation = $0 } }
        return try result.get()
    }
    func release() { continuation?.resume(); continuation = nil }
}

/// Synthetic sequencing tests. These cannot mint a shipping ReceivingContext,
/// select a native effect, or invoke the private system SDK.
@Suite @MainActor struct HostWakeFirstKeyPairBindingTests {
    @Test(.isolatedClientResources, arguments: ["missing", "replacement", "aba", "pre-journal-loss", "queue-loss", "callback-loss", "expired-window", "elapsed-window", "two-surfaces", "two-surfaces-success", "post-key-replacement", "authorize-cancel", "callback-cancel", "duplicate", "wrong-order", "nil-selection"])
    func originalPairPrecedesEveryEffect(vector: String) async throws {
        if vector == "nil-selection" {
            let owner = DJConnectHostWakeFirstKeyOwner()
            owner.operatorRequestsFirstKey()
            #expect(owner.state == .closed && !owner.showsOperatorAction)
            return
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("first-key-pair-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let clock = PairClock(), a = PairSource(.widget), b = PairSource(.liveActivity), sdk = PairSDK()
        let window = HostWakeFirstKeyWindow(testStarted: clock.start, testNow: { clock.value })
        let sources = ["two-surfaces", "two-surfaces-success", "wrong-order"].contains(vector) ? [a, b] : vector == "duplicate" ? [a, a] : [a]
        let expected = vector == "wrong-order" ? [DJConnectPassiveSurface.liveActivity, .widget] : sources.map(\.surface)
        let preparation = HostWakeFirstKeyPreparation(sources: sources, expected: expected, window: window)
        var initializations = 0
        if vector == "missing" { a.retire() }
        if vector == "replacement" { a.onAuthorize = { a.parent = PairParent() } }
        if vector == "aba" { a.onAuthorize = { a.retire(); a.restoreVisibleFields() } }
        if vector == "pre-journal-loss" { a.onAuthorize = { a.retire() } }
        if vector == "expired-window" { a.onAuthorize = { clock.value = clock.start.advanced(by: .seconds(121)) } }
        if vector == "two-surfaces" { b.onAuthorize = { a.retire() } }
        if vector == "elapsed-window" { a.onAuthorize = { clock.value = clock.start.advanced(by: .seconds(30)) } }
        if ["callback-loss", "callback-cancel"].contains(vector) { sdk.hold = true }
        if vector == "authorize-cancel" { a.hold = true }
        let gate = PairQueueGate()
        let blocker: Task<Void, any Error>?
        if vector == "queue-loss" {
            blocker = Task { try await RendezvousAppKeyOperations.shared.performHostWakeFirstKey { await gate.hold() } }
            await gate.waitEntered()
        } else { blocker = nil }
        let operation = Task {
            try await preparation.generate(journal: {
                initializations += 1
                return try HostWakeFirstKeyJournal(freshInExistingSupport: root, artifact: String(repeating: "b", count: 64))
            }, sdk: sdk)
        }
        if ["callback-loss", "callback-cancel"].contains(vector) {
            await sdk.waitEntered()
            if vector == "callback-cancel" { operation.cancel() }
            else { a.retire(); a.restoreVisibleFields() }
            sdk.release()
        }
        if vector == "authorize-cancel" {
            await a.gate.waitEntered(); operation.cancel(); await a.gate.release()
        }
        if vector == "queue-loss" {
            // Journal construction occurs before queue acquisition. Wait for its
            // actual event, then revoke while the original exclusion slot is held.
            for _ in 0..<1000 where initializations == 0 { await Task.yield() }
            #expect(initializations == 1)
            a.retire(); await gate.release(); try await blocker?.value
        }
        var result: (String, HostWakeFirstKeyJournal, HostWakeFirstKeyAttempt)?
        do { result = try await operation.value } catch {}
        if ["missing", "replacement", "aba", "pre-journal-loss", "expired-window", "two-surfaces", "authorize-cancel", "duplicate", "wrong-order"].contains(vector) {
            #expect(initializations == 0, "No journal may exist before every original pair is retained: \(vector)")
            #expect(sdk.calls == 0)
            #expect(HostWakeFirstKeyJournal.namespaceIsAbsent(inExistingSupport: root))
        } else if ["elapsed-window", "two-surfaces-success"].contains(vector) {
            #expect(result != nil && initializations == 1 && sdk.calls == 1)
            #expect(preparation.parents.count == sources.count)
            result?.2.close()
        } else if vector == "post-key-replacement" {
            #expect(result != nil && initializations == 1 && sdk.calls == 1)
            let original = a.parent; a.parent = PairParent()
            #expect(!preparation.isCurrent)
            a.parent = original
            #expect(!preparation.isCurrent, "Equal/restored parent cannot revive an observed loss")
            result?.2.close()
        } else {
            #expect(result == nil)
            #expect(sdk.calls <= 1)
            if vector == "queue-loss" { #expect(sdk.calls == 0) }
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("DJConnectHostWakeFirstKey-v1/key-reference").path))
        }
        #expect(sdk.deadlines.allSatisfy { $0 == window.deadline }, "Authorization/queue time must not restart the original local ceiling")
    }
}
@MainActor private final class PairClock {
    let start = ContinuousClock.now
    lazy var value = start
}
@MainActor private final class PairParent {}
@MainActor private final class PairSource: HostWakeFirstKeySource {
    let surface: DJConnectPassiveSurface
    var parent = PairParent()
    private let originalParent: PairParent
    private var live = true
    var onAuthorize: (() -> Void)?
    var hold = false
    let gate = PairQueueGate()
    init(_ surface: DJConnectPassiveSurface) { self.surface = surface; originalParent = parent }
    var isCurrent: Bool { live }
    func authorizeOriginal() async throws -> PairParent {
        let original = originalParent
        if hold { await gate.hold() }
        await Task.yield(); onAuthorize?()
        return original
    }
    func retains(_ parent: PairParent) -> Bool { live && self.parent === parent }
    func retire() { live = false }
    func restoreVisibleFields() { /* A retired generation cannot be rearmed. */ }
}
@MainActor private final class PairSDK: HostWakeFirstKeySDK {
    let isSupported = true
    var calls = 0
    var deadlines: [ContinuousClock.Instant] = []
    var onEntry: (() -> Void)?
    var hold = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    func waitEntered() async {
        if calls > 0 { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }
    func generate(deadline: ContinuousClock.Instant, current: @escaping @MainActor @Sendable () -> Bool) async throws -> String {
        calls += 1; deadlines.append(deadline); onEntry?()
        for waiter in entryWaiters { waiter.resume() }; entryWaiters.removeAll()
        if hold { await withCheckedContinuation { continuation = $0 } }
        guard current() else { throw CancellationError() }
        return Data(repeating: 9, count: 32).base64EncodedString()
    }
    func release() { continuation?.resume(); continuation = nil }
}

private actor PairQueueGate {
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<Void, Never>?
    func hold() async {
        entered = true
        for waiter in waiters { waiter.resume() }; waiters.removeAll()
        await withCheckedContinuation { continuation = $0 }
    }
    func waitEntered() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() { continuation?.resume(); continuation = nil }
}

extension HostWakeFirstKeyPairBindingTests {
    @Test(.isolatedClientResources)
    func heldFirstRegistrationCannotPreissueSecondSurface() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("first-key-child-order-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = PairSource(.widget), b = PairSource(.liveActivity), sdk = PairSDK()
        sdk.hold = true
        let preparation = HostWakeFirstKeyPreparation(sources: [a, b], expected: [.widget, .liveActivity], window: .init())
        let operation = Task {
            try await preparation.generate(journal: {
                try HostWakeFirstKeyJournal(freshInExistingSupport: root, artifact: String(repeating: "c", count: 64))
            }, sdk: sdk)
        }
        await sdk.waitEntered()
        #expect(preparation.parents.count == 2)
        do { try preparation.beginEnrollment(preparation.parents[0]); Issue.record("child before original SDK reference") } catch {}
        sdk.release()
        let result = try await operation.value
        defer { result.2.close() }
        let first = preparation.parents[0], second = preparation.parents[1]
        var secondIssuerCalls = 0
        try preparation.beginEnrollment(first)
        // First registration is genuinely still pending at this sequencing seam.
        // No second child may be issued merely because a key reference exists.
        do { try preparation.beginEnrollment(second); secondIssuerCalls += 1 } catch {}
        #expect(secondIssuerCalls == 0)
        do { try preparation.beginEnrollment(first); Issue.record("pending child duplicated") } catch {}
        try preparation.completeEnrollment(first) // Simulated matching ACK, not native/API acceptance.
        try preparation.beginEnrollment(second); secondIssuerCalls += 1
        #expect(secondIssuerCalls == 1)
        try preparation.completeEnrollment(second)
        do { try preparation.beginEnrollment(second); Issue.record("registered original repeated") } catch {}
    }
}
