import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum ProbeFailure: Error { case arguments, state, unexpectedAdmission, metadata, cleanup }

@main struct Probe {
    static func main() async {
        do { try await run() }
        catch { FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8)); exit(1) }
    }
    static func original() -> Data {
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        let challenge = url(Data(repeating: 8, count: 32)), nonce = url(Data(repeating: 9, count: 32))
        let bytes = Data(" {\n\"action\":\"recover-key\",\"v\":\"djc-rendezvous/1\",\"key_id\":\"\(key)\",\"challenge_id\":\"\(challenge)\",\"challenge\":\"\(nonce)\",\"expires_at\":120000,\"service_origin\":\"https://api.djconnect.dev\" }\n".utf8)
        return bytes + Data(repeating: 32, count: 2_048 - bytes.count)
    }
    static func run() async throws {
        let args = CommandLine.arguments, prefix = "dev.djconnect.qualification.recovery."
        guard args.count == 3, args[1].hasPrefix(prefix), UUID(uuidString: String(args[1].dropFirst(prefix.count))) != nil else { throw ProbeFailure.arguments }
        let service = args[1], action = args[2], account = "synthetic-recover-key-v1"
        let store = RendezvousRepairKeychainStorage(service: service, account: account)
        let journal = RendezvousRecoveryJournal(storage: store)
        switch action {
        case "begin":
            guard try store.read() == nil else { throw ProbeFailure.state }
            let id = try await journal.begin(keyIdentifier: Data(repeating: 7, count: 32).base64EncodedString(),
                challengeIdentifier: url(Data(repeating: 8, count: 32)), nonce: Data(repeating: 9, count: 32),
                clientData: original(), admittedAtMS: 0, deadlineMS: 120_000)
            let call = try await journal.reserveAssertion(attemptIdentifier: id, at: 0)
            guard call.clientDataHash == Data(SHA256.hash(data: original())) else { throw ProbeFailure.state }
            print("PASS: original maximum clientData saved before synthetic assertion call; SHA256=\(digest(original()))")
        case "restore":
            guard let state = try await journal.snapshot(at: 1), state.phase == .assertionPending,
                  let reservation = state.assertionReservation, state.assertionStarted else { throw ProbeFailure.state }
            do { _ = try await journal.reserveAssertion(attemptIdentifier: state.attemptIdentifier, at: 1); throw ProbeFailure.unexpectedAdmission }
            catch RendezvousRecoveryJournal.Failure.unavailable {}
            guard let raw = try store.read(), let object = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  object["clientData"] as? String == original().base64EncodedString(),
                  object["clientDataHash"] as? String == Data(SHA256.hash(data: original())).base64EncodedString() else { throw ProbeFailure.state }
            try await journal.completeAssertion(attemptIdentifier: state.attemptIdentifier, reservation: reservation,
                                                 result: .received(Data(repeating: 255, count: 4_096)), at: 1)
            let call = try await journal.reserveSubmission(attemptIdentifier: state.attemptIdentifier, at: 1)
            try await journal.completeSubmission(attemptIdentifier: state.attemptIdentifier, reservation: call.reservation, outcome: .responseLost, at: 100)
            print("PASS: occupied assertion restored; original bytes/hash matched; maximum synthetic assertion saved; request SHA256=\(digest(call.body))")
        case "retry":
            guard let state = try await journal.snapshot(at: 2_100), state.phase == .prepared,
                  state.callsStarted == 1, state.deadlineMS == 120_000 else { throw ProbeFailure.state }
            let call = try await journal.reserveSubmission(attemptIdentifier: state.attemptIdentifier, at: 2_100)
            let request = try JSONSerialization.jsonObject(with: call.body) as? [String: String]
            guard request?["client_data"] == url(original()) else { throw ProbeFailure.state }
            print("PASS: process-restored identical request bytes; request SHA256=\(digest(call.body))")
        case "expire", "verify-purge":
            let now: Int64 = action == "expire" ? 120_000 : 120_001
            guard let state = try await journal.snapshot(at: now), state.phase == .recoveryPaused,
                  state.callsStarted == 2, state.assertionStarted, state.deadlineMS == 120_000,
                  let raw = try store.read(), let object = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  ["challenge", "nonce", "clientData", "clientDataHash", "request", "requestHash"].allSatisfy({ object[$0] == nil }) else { throw ProbeFailure.state }
            do { _ = try await journal.reserveSubmission(attemptIdentifier: state.attemptIdentifier, at: now); throw ProbeFailure.unexpectedAdmission }
            catch RendezvousRecoveryJournal.Failure.unavailable {}
            print("PASS: expired material removed; original handle and consumed assertion/request budgets retained")
        case "metadata", "cleanup":
            let context = LAContext(); context.interactionNotAllowed = true
            var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: false, kSecUseDataProtectionKeychain as String: true,
                kSecUseAuthenticationContext as String: context]
            if action == "cleanup" {
                let status = SecItemDelete(query as CFDictionary)
                guard status == errSecSuccess || status == errSecItemNotFound, try store.read() == nil else { throw ProbeFailure.cleanup }
                print("PASS: exact synthetic item removed")
            } else {
                query[kSecReturnAttributes as String] = true
                var result: CFTypeRef?
                guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                      let attributes = result as? [String: Any],
                      attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
                      attributes[kSecAttrSynchronizable as String] as? Bool != true else { throw ProbeFailure.metadata }
                print("PASS: device-only/non-syncing Keychain attributes")
            }
        default: throw ProbeFailure.arguments
        }
    }
    static func url(_ bytes: Data) -> String {
        bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
}
