import XCTest
import CryptoKit
import DeviceCheck
import UIKit
import JOSESwift

@MainActor final class HostedQualification: XCTestCase {
    func testActualAppHostAndSoftwareJOSE() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.djconnect.ios")
        let key = try DestinationJOSE.key(), publicKey = try DestinationJOSE.publicJWK(key)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let object: [String: Any] = ["v": "djc-rendezvous/1", "transaction_id": UUID().uuidString.lowercased(),
            "generation": 1, "browser_key_thumbprint": try publicKey.thumbprint(algorithm: .SHA256),
            "expires_at": now + 120_000, "bootstrap_origin": "https://vibecast.tv",
            "display_entry_url": "https://ha.example.org/djconnect/vibecast/display", "issuer_epoch": base64url(Data(repeating: 2, count: 32))]
        let bytes = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        let envelope = try DestinationJOSE.encrypt(bytes, to: publicKey)
        XCTAssertEqual(try DestinationJOSE.decrypt(envelope, with: key, expected: bytes, nowMS: now), bytes)
        XCTAssertThrowsError(try DestinationJOSE.decrypt(envelope, with: key, expected: bytes, nowMS: now + 120_000))
        XCTAssertThrowsError(try DestinationJOSE.decrypt(envelope + ".AA", with: key, expected: bytes, nowMS: now))
    }

    /// Explicitly opt-in, once per retained diagnostic directory. Reuses the old
    /// development handle; never generates/attests an App Attest key or contacts API/HA.
    func testFreshBoundActionAssertionsUsingExistingHandle() async throws {
        guard ProcessInfo.processInfo.environment["DJC_CAPTURE_BOUND_ACTIONS"] == "1" else {
            throw XCTSkip("Explicit bounded action capture not enabled")
        }
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.djconnect.ios")
        let service = DCAppAttestService.shared
        guard service.isSupported else { throw XCTSkip("App Attest unavailable in actual app") }
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let original = support.appendingPathComponent("DJConnect/AppAttestQualification")
        let state = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: original.appendingPathComponent("state.json")))
        let keyID = try XCTUnwrap(state["active"])
        let root = support.appendingPathComponent("DJConnect/BoundActionQualification20261018")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        let marker = root.appendingPathComponent("attempted")
        guard !FileManager.default.fileExists(atPath: marker.path) else { throw XCTSkip("Capture already attempted; explicit recovery required") }
        try Data("attempted".utf8).write(to: marker, options: [.atomic, .completeFileProtection])
        func random() throws -> String {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw BindingFailure.rejected }
            return base64url(Data(bytes))
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let softwareKey = try DestinationJOSE.key(), publicKey = try DestinationJOSE.publicJWK(softwareKey)
        let scan = ScanContext(transaction: UUID().uuidString.lowercased(), generation: 1,
            browserThumbprint: try publicKey.thumbprint(algorithm: .SHA256), deadlineMS: now + 120_000)
        let plaintext: [String: Any] = ["v": "djc-rendezvous/1", "transaction_id": scan.transaction, "generation": scan.generation,
            "browser_key_thumbprint": scan.browserThumbprint, "expires_at": scan.deadlineMS, "bootstrap_origin": "https://vibecast.tv",
            "display_entry_url": "https://ha.example.org/djconnect/vibecast/display", "issuer_epoch": try random()]
        let envelope = try DestinationJOSE.encrypt(JSONSerialization.data(withJSONObject: plaintext), to: publicKey)
        let digest = base64url(Data(SHA256.hash(data: Data(envelope.utf8))))
        for action in [ClientDataExpectation.Action.submit, .deleteKey, .recoverKey] {
            let expectation = ClientDataExpectation(action: action, keyID: keyID, challengeID: try random(), challenge: try random(),
                deadlineMS: now + 90_000, scan: action == .submit ? scan : nil, envelopeDigest: action == .submit ? digest : nil)
            let fields = try expectation.fields().mapValues { value -> Any in
                switch value { case .string(let s): return s; case .integer(let i): return i }
            }
            let bytes = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys, .withoutEscapingSlashes])
            let validated = try expectation.validate(bytes, at: Int64(Date().timeIntervalSince1970 * 1000))
            try bytes.write(to: root.appendingPathComponent(action.rawValue + "-input.bin"), options: [.atomic, .completeFileProtection])
            let assertion: Data
            do { assertion = try await service.generateAssertion(keyID, clientDataHash: validated.hash) }
            catch { throw BindingFailure.rejected } // Never let SDK userInfo enter XCTest logs.
            try assertion.write(to: root.appendingPathComponent(action.rawValue + ".cbor"), options: [.atomic, .completeFileProtection])
        }
        let report: [String: Any] = ["bundle_id": Bundle.main.bundleIdentifier!, "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "os": UIDevice.current.systemVersion, "actions": ["submit", "delete-key", "recover-key"], "new_app_attest_keys": 0,
            "scope": "local synthetic action-shaped challenges; NOT API-issued, enrolled, live or HA owner authority"]
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]).write(to: root.appendingPathComponent("report.json"), options: [.atomic, .completeFileProtection])
    }
}
