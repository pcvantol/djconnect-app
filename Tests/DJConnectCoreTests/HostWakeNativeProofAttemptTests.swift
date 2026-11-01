import Foundation
import Darwin
import CryptoKit
import Testing
@testable import DJConnectCore

/// Real filesystem/once/cancellation checks with an explicitly synthetic SDK.
/// These cases do not exercise App Attest or qualify a signed installation.
@Suite @MainActor struct HostWakeNativeProofAttemptTests {
    private struct Vector: Decodable {
        let original: DirectRichWireJSON
        let canonical_transcript_utf8: String
        let client_data_sha256: String
        let native_token_b64: String
    }
    private func input(kind: String = "app_attest_attestation", operationID: String? = nil) throws -> HostWakeNativeProofInputData {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ProofAttemptFixtureAnchor.self)
        #endif
        let url = try #require(bundle.url(forResource: "host-wake-native-sdk-input-api-03323cd", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "host-wake-native-sdk-input-api-03323cd", withExtension: "json"))
        let v = try JSONDecoder().decode(Vector.self, from: Data(contentsOf: url))
        var original = v.original, transcript = Data(v.canonical_transcript_utf8.utf8), hash = v.client_data_sha256
        if let operationID {
            var fields = try #require(original.object); fields["operation_id"] = .string(operationID)
            original = .object(fields)
            var root = try #require(DirectRichWireJSON.parse(transcript, maximumBytes: 8192).object)
            root["original"] = original; transcript = try DirectRichWireJSON.object(root).canonicalData()
            hash = SHA256.hash(data: HostWakeNativeTranscriptData.domain + transcript).map { String(format: "%02x", $0) }.joined()
        }
        return try .init(preparedOriginal: original.canonicalData(), preparedKind: kind,
            challengeTranscript: transcript, challengeKind: kind,
            advertisedHash: hash, suppliedSDKKeyIdentifier: #require(original.object?["native_key_id_b64"]?.string),
            originalToken: #require(Data(base64Encoded: v.native_token_b64)))
    }
    private func support() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("native-proof-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }
    private func journal(_ root: URL, key: String) async throws -> HostWakeFirstKeyJournal {
        try await Task.detached(priority: .utility) {
            let store = try HostWakeFirstKeyJournal(freshInExistingSupport: root, artifact: String(repeating: "a", count: 64))
            try store.claimBeforeSDK(); try store.recordOriginalCallback(key)
            return store
        }.value
    }
    private func record(_ root: URL) throws -> URL {
        root.appendingPathComponent("DJConnectHostWakeFirstKey-v1/native-proof-" + (try input()).operationID + ".json")
    }
    @Test(arguments: ["app_attest_attestation", "app_attest_assertion"])
    func durableOriginalClaimPrecedesSDKAndOpaqueBytesStayExact(_ kind: String) async throws {
        let value = try input(kind: kind), root = try support()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await journal(root, key: value.keyIdentifier), sdk = ModelSDK()
        sdk.onEntry = {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: record(root))) as? [String: String]
            #expect(json?["kind"] == kind)
            #expect(json?["keyIdentifier"] == value.keyIdentifier)
            #expect(json?["clientDataSHA256"] == value.clientDataHash.map { String(format: "%02x", $0) }.joined())
            try store.validateOriginal()
        }
        let attempt = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        #expect(try await attempt.perform(value) == sdk.bytes)
        #expect(sdk.kinds == [kind])
        #expect(throws: (any Error).self) { try store.claimNativeProofBeforeSDK(value) }
        do { _ = try await attempt.perform(value); Issue.record("same native proof retried") } catch {}
        let second = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        do { _ = try await second.perform(value); Issue.record("new engine refunded durable claim") } catch {}
        #expect(sdk.kinds == [kind])
    }
    @Test func unknownSDKCannotRetryOrSwitchProofKind() async throws {
        let value = try input(), root = try support()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await journal(root, key: value.keyIdentifier), sdk = ModelSDK(); sdk.lost = true
        let attempt = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        do { _ = try await attempt.perform(value); Issue.record("unknown accepted") } catch {}
        sdk.lost = false
        let second = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        do { _ = try await second.perform(input(kind: "app_attest_assertion")); Issue.record("kind switch recovered unknown") } catch {}
        #expect(sdk.kinds.count == 1)
        #expect(FileManager.default.fileExists(atPath: (try record(root)).path))
        #expect(!HostWakeFirstKeyJournal.namespaceIsAbsent(inExistingSupport: root))
    }
    @Test func distinctChildClaimsDoNotReuseProofOrPermitAnotherAttestation() async throws {
        let value = try input(), root = try support()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await journal(root, key: value.keyIdentifier), sdk = ModelSDK()
        let first = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        _ = try await first.perform(value)
        let next = try input(kind: "app_attest_assertion", operationID: UUID().uuidString.lowercased())
        let second = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        _ = try await second.perform(next)
        #expect(sdk.kinds == ["app_attest_attestation", "app_attest_assertion"])
        #expect(value.operationID != next.operationID && value.clientDataHash != next.clientDataHash)
        #expect(throws: (any Error).self) { try store.claimNativeProofBeforeSDK(input(operationID: UUID().uuidString.lowercased())) }
        #expect(throws: (any Error).self) { try store.claimNativeProofBeforeSDK(next) }
        try store.validateOriginal()
    }
    @Test func anotherChildCannotRepeatTheFirstKeyAttestation() async throws {
        let value = try input(), root = try support()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await journal(root, key: value.keyIdentifier)
        try store.claimNativeProofBeforeSDK(value)
        #expect(throws: (any Error).self) { try store.claimNativeProofBeforeSDK(input(operationID: UUID().uuidString.lowercased())) }
        try store.validateOriginal()
    }
    @Test func observedOwnerLossAtCallbackIsTerminalEvenAfterABA() async throws {
        let value = try input(), root = try support()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await journal(root, key: value.keyIdentifier), sdk = ModelSDK(), flag = CurrentFlag()
        sdk.onEntry = { flag.value = false }
        let attempt = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { flag.value })
        do { _ = try await attempt.perform(value); Issue.record("lost owner proof accepted") } catch {}
        flag.value = true
        #expect(!attempt.isCurrent)
        do { _ = try await attempt.perform(value); Issue.record("ABA reopened proof") } catch {}
        #expect(sdk.kinds.count == 1)
    }
    @Test func cancelledUncooperativeSDKCannotSubmitLateProof() async throws {
        let value = try input(), root = try support()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await journal(root, key: value.keyIdentifier), sdk = ModelSDK(); sdk.hold = true
        let attempt = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        let task = Task { () -> Bool in
            do { _ = try await attempt.perform(value); return true } catch { return false }
        }
        await sdk.waitForEntry()
        task.cancel(); sdk.release()
        #expect(await task.value == false)
        #expect(!attempt.isCurrent)
        #expect(sdk.kinds.count == 1)
        #expect(FileManager.default.fileExists(atPath: (try record(root)).path))
    }
    @Test(arguments: [false, true]) func replacementOfProofRecordClosesCallback(_ fifo: Bool) async throws {
        let value = try input(), root = try support()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await journal(root, key: value.keyIdentifier), sdk = ModelSDK()
        sdk.onEntry = {
            let url = try record(root), bytes = try Data(contentsOf: url)
            try FileManager.default.removeItem(at: url)
            if fifo { #expect(mkfifo(url.path, 0o600) == 0) }
            else { try bytes.write(to: url) }
        }
        let attempt = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        do { _ = try await attempt.perform(value); Issue.record("replacement restored proof custody") } catch {}
        #expect(sdk.kinds.count == 1)
        #expect(!attempt.isCurrent)
    }
    @Test func differentKeyOrMissingReferenceNeverReachesSDK() async throws {
        let value = try input(), root = try support()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await journal(root, key: Data(repeating: 37, count: 32).base64EncodedString()), sdk = ModelSDK()
        let attempt = HostWakeNativeProofAttempt(storage: store, sdk: sdk, window: .init(), current: { true })
        do { _ = try await attempt.perform(value); Issue.record("different key accepted") } catch {}
        #expect(sdk.kinds.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: (try record(root)).path))
    }
    @MainActor private final class CurrentFlag { var value = true }
    @MainActor private final class ModelSDK: HostWakeNativeProofSDK {
        struct Loss: Error {}
        var isSupported = true, lost = false, hold = false
        let bytes = Data([0, 255, 128, 3, 0])
        var kinds: [String] = []
        var onEntry: (() throws -> Void)?
        private var held: CheckedContinuation<Void, Never>?
        private var entry: CheckedContinuation<Void, Never>?
        func waitForEntry() async {
            if !kinds.isEmpty { return }
            await withCheckedContinuation { entry = $0 }
        }
        func release() { held?.resume(); held = nil }
        func invoke(_ input: HostWakeNativeProofInputData, deadline: ContinuousClock.Instant,
            current: @escaping @MainActor @Sendable () -> Bool) async throws -> Data {
            kinds.append(input.kind.rawValue); try onEntry?()
            if hold {
                await withCheckedContinuation { continuation in
                    held = continuation; entry?.resume(); entry = nil
                }
            }
            if lost { throw Loss() }
            return bytes // Deliberately ignores current/cancellation to exercise caller fencing.
        }
    }
}
private final class ProofAttemptFixtureAnchor: NSObject {}
