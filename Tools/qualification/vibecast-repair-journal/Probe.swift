import Foundation
import Security
import LocalAuthentication

enum ProbeFailure: Error { case invalidArguments, invalidState, unexpectedAdmission, keychainMetadata, cleanupFailed }

@main struct Probe {
    static func main() async {
        do { try await run() } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8)); exit(1)
        }
    }
    static func run() async throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { throw ProbeFailure.invalidArguments }
        let service = args[1], action = args[2]
        guard service.hasPrefix("dev.djconnect.qualification.repair."),
              UUID(uuidString: String(service.dropFirst("dev.djconnect.qualification.repair.".count))) != nil
        else { throw ProbeFailure.invalidArguments }
        let storage = RendezvousRepairKeychainStorage(service: service, account: "synthetic-v1")
        let journal = RendezvousRepairJournal(storage: storage)
        switch action {
        case "write":
            let initial = try storage.read()
            guard initial == nil else { throw ProbeFailure.invalidState }
            _ = try await journal.beginPause(keyIdentifier: "synthetic-not-an-app-attest-key", at: 0)
            _ = try await journal.reserveExplicitRecovery(keyIdentifier: "synthetic-not-an-app-attest-key", at: 60_000)
            print("PASS: synthetic reservation persisted")
        case "restore":
            guard let state = try await journal.snapshot() else { throw ProbeFailure.invalidState }
            guard state.attemptsStarted == 1 && state.reservation != nil && state.pausedAtMS == 0 else { throw ProbeFailure.invalidState }
            do { _ = try await journal.reserveExplicitRecovery(keyIdentifier: state.keyIdentifier, at: 120_000); throw ProbeFailure.unexpectedAdmission }
            catch is RendezvousRepairWindow.Failure {}
            try await journal.complete(keyIdentifier: state.keyIdentifier, reservation: state.reservation!, outcome: .paused, at: 120_001)
            _ = try await journal.reserveExplicitRecovery(keyIdentifier: state.keyIdentifier, at: 120_001)
            print("PASS: second process restored in-flight fence and original budget")
        case "exhaust":
            guard let state = try await journal.snapshot() else { throw ProbeFailure.invalidState }
            guard state.attemptsStarted == 2 && state.reservation != nil && state.pausedAtMS == 0 else { throw ProbeFailure.invalidState }
            try await journal.complete(keyIdentifier: state.keyIdentifier, reservation: state.reservation!, outcome: .paused, at: 120_002)
            do { _ = try await journal.reserveExplicitRecovery(keyIdentifier: state.keyIdentifier, at: 180_000); throw ProbeFailure.unexpectedAdmission }
            catch is RendezvousRepairWindow.Failure {}
            print("PASS: third process preserved exhausted budget")
        case "metadata", "cleanup":
            let authentication = LAContext(); authentication.interactionNotAllowed = true
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecAttrAccount as String: "synthetic-v1",
                kSecAttrSynchronizable as String: false, kSecUseDataProtectionKeychain as String: true,
                kSecUseAuthenticationContext as String: authentication]
            if action == "cleanup" {
                let status = SecItemDelete(query as CFDictionary)
                guard status == errSecSuccess || status == errSecItemNotFound else { throw ProbeFailure.cleanupFailed }
                let remaining = try storage.read()
                guard remaining == nil else { throw ProbeFailure.cleanupFailed }
                print("PASS: only synthetic qualification item removed")
            } else {
                var request = query; request[kSecReturnAttributes as String] = true
                var result: CFTypeRef?
                guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess else { throw ProbeFailure.keychainMetadata }
                guard let attributes = result as? [String: Any] else { throw ProbeFailure.keychainMetadata }
                guard attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String else { throw ProbeFailure.keychainMetadata }
                guard attributes[kSecAttrSynchronizable as String] as? Bool != true else { throw ProbeFailure.keychainMetadata }
                print("PASS: actual Keychain metadata is WhenUnlockedThisDeviceOnly, non-synchronizable")
            }
        default: throw ProbeFailure.invalidArguments
        }
    }
}
