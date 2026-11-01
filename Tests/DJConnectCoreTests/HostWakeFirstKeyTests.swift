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
