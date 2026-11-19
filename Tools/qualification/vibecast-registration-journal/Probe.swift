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
    static func run() async throws {
        let args = CommandLine.arguments, prefix = "dev.djconnect.qualification.registration."
        guard args.count == 3, args[1].hasPrefix(prefix),
              UUID(uuidString: String(args[1].dropFirst(prefix.count))) != nil else { throw ProbeFailure.arguments }
        let service = args[1], action = args[2], account = "synthetic-registration-v1"
        let store = RendezvousRepairKeychainStorage(service: service, account: account)
        let journal = RendezvousRegistrationJournal(storage: store)
        func verifyPurged() throws {
            guard let bytes = try store.read(), let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  ["challenge", "nonce", "nonceHash", "request", "requestHash"].allSatisfy({ object[$0] == nil }) else { throw ProbeFailure.state }
        }
        switch action {
        case "sdk-begin":
            guard try store.read() == nil else { throw ProbeFailure.state }
            let challenge = Data(repeating: 8, count: 32).base64EncodedString().replacingOccurrences(of: "=", with: "")
            let id = try await journal.beginAttestation(keyIdentifier: Data(repeating: 7, count: 32).base64EncodedString(),
                challengeIdentifier: challenge, nonce: Data(repeating: 9, count: 32), admittedAtMS: 0, deadlineMS: 120_000)
            let call = try await journal.reserveAttestation(attemptIdentifier: id, at: 0)
            guard call.clientDataHash == Data(SHA256.hash(data: Data(repeating: 9, count: 32))) else { throw ProbeFailure.state }
            print("PASS: SDK reservation persisted before call; synthetic nonce SHA256=\(digest(Data(repeating: 9, count: 32)))")
        case "sdk-restore":
            guard let state = try await journal.snapshot(at: 100), state.phase == .attestationPending,
                  state.attestationCallsStarted == 1, state.callsStarted == 0,
                  let reservation = state.attestationReservation else { throw ProbeFailure.state }
            do { _ = try await journal.reserveAttestation(attemptIdentifier: state.attemptIdentifier, at: 100); throw ProbeFailure.unexpectedAdmission }
            catch RendezvousRetryWindow.Failure.inFlight {}
            // Synthetic SDK callback only; no DeviceCheck import or SDK invocation.
            try await journal.completeAttestation(attemptIdentifier: state.attemptIdentifier, reservation: reservation, result: .serverUnavailable, at: 100)
            print("PASS: process-restored in-flight SDK call refused; synthetic unavailable result accounted")
        case "sdk-proof":
            guard let state = try await journal.snapshot(at: 2_100), state.phase == .attestationPending,
                  state.attestationCallsStarted == 1, state.deadlineMS == 120_000 else { throw ProbeFailure.state }
            let call = try await journal.reserveAttestation(attemptIdentifier: state.attemptIdentifier, at: 2_100)
            guard call.clientDataHash == Data(SHA256.hash(data: Data(repeating: 9, count: 32))) else { throw ProbeFailure.state }
            try await journal.completeAttestation(attemptIdentifier: state.attemptIdentifier, reservation: call.reservation,
                                                  result: .received(Data(repeating: 255, count: 32_768)), at: 2_200)
            let submission = try await journal.reserveSubmission(attemptIdentifier: state.attemptIdentifier, at: 2_200)
            print("PASS: original SDK hash restored; synthetic proof persisted into prepared request; SHA256=\(digest(submission.body))")
        case "sdk-prepared-restore":
            guard let state = try await journal.snapshot(at: 2_300), state.phase == .prepared,
                  state.attestationCallsStarted == 2, state.callsStarted == 1,
                  let reservation = state.reservation, state.deadlineMS == 120_000 else { throw ProbeFailure.state }
            do { _ = try await journal.reserveAttestation(attemptIdentifier: state.attemptIdentifier, at: 2_300); throw ProbeFailure.unexpectedAdmission }
            catch RendezvousRegistrationJournal.Failure.unavailable {}
            try await journal.completeSubmission(attemptIdentifier: state.attemptIdentifier, reservation: reservation, outcome: .responseLost, at: 2_300)
            let submission = try await journal.reserveSubmission(attemptIdentifier: state.attemptIdentifier, at: 4_300)
            print("PASS: SDK-to-registration handoff survives process restart; original bytes SHA256=\(digest(submission.body))")
        case "sdk-expire", "sdk-verify-purge":
            let now: Int64 = action == "sdk-expire" ? 120_000 : 120_001
            guard let state = try await journal.snapshot(at: now), state.phase == .registrationUncertain,
                  state.attestationCallsStarted == 2, state.callsStarted == 2, state.deadlineMS == 120_000 else { throw ProbeFailure.state }
            try verifyPurged()
            do { _ = try await journal.reserveAttestation(attemptIdentifier: state.attemptIdentifier, at: now); throw ProbeFailure.unexpectedAdmission }
            catch RendezvousRegistrationJournal.Failure.unavailable {}
            print("PASS: expired SDK/registration material purged; both consumed budgets and original handle retained")
        case "prepare":
            guard try store.read() == nil else { throw ProbeFailure.state }
            let challenge = Data(repeating: 8, count: 32).base64EncodedString().replacingOccurrences(of: "=", with: "")
            let id = try await journal.prepare(keyIdentifier: Data(repeating: 7, count: 32).base64EncodedString(),
                challengeIdentifier: challenge, nonce: Data(repeating: 9, count: 32),
                attestation: Data(repeating: 255, count: 32_768), admittedAtMS: 0, deadlineMS: 120_000)
            let submission = try await journal.reserveSubmission(attemptIdentifier: id, at: 0)
            try await journal.completeSubmission(attemptIdentifier: id, reservation: submission.reservation, outcome: .responseLost, at: 100)
            print("PASS: maximum synthetic prepared body stored; SHA256=\(digest(submission.body))")
        case "restore":
            guard let state = try await journal.snapshot(at: 2_100), state.phase == .prepared,
                  state.callsStarted == 1, state.deadlineMS == 120_000 else { throw ProbeFailure.state }
            let submission = try await journal.reserveSubmission(attemptIdentifier: state.attemptIdentifier, at: 2_100)
            try await journal.completeSubmission(attemptIdentifier: state.attemptIdentifier, reservation: submission.reservation, outcome: .responseLost, at: 2_200)
            print("PASS: new process restored identical retry bytes; SHA256=\(digest(submission.body))")
        case "expire", "verify-purge":
            let now: Int64 = action == "expire" ? 120_000 : 120_001
            guard let state = try await journal.snapshot(at: now), state.phase == .registrationUncertain,
                  state.callsStarted == 2, state.deadlineMS == 120_000 else { throw ProbeFailure.state }
            try verifyPurged()
            do { _ = try await journal.reserveSubmission(attemptIdentifier: state.attemptIdentifier, at: now); throw ProbeFailure.unexpectedAdmission }
            catch RendezvousRegistrationJournal.Failure.unavailable {}
            print("PASS: expiry fence and persisted proof/nonce removal; original handle retained")
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
                print("PASS: device-only, non-synchronizable Keychain metadata")
            }
        default: throw ProbeFailure.arguments
        }
    }
    static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
