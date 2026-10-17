import XCTest
import DeviceCheck
import CryptoKit
import UIKit

/// Hosted diagnostic, deliberately independent of unfrozen rendezvous endpoints.
/// Raw proofs remain in the app's protected container, never in test attachments/logs.
@MainActor
final class AppAttestQualification: XCTestCase {
    func testAppBoundDevelopmentCapture() async throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.djconnect.ios")
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true).appendingPathComponent("DJConnect/AppAttestQualification", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        let service = DCAppAttestService.shared
        var report: [String: Any] = ["app_bundle_id": Bundle.main.bundleIdentifier!,
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "os": UIDevice.current.systemVersion, "is_supported": service.isSupported,
            "scope": "app-hosted development diagnostic; no rendezvous/server admission"]
        func saveReport() throws {
            try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
                .write(to: root.appendingPathComponent("report.json"), options: [.atomic, .completeFileProtection])
        }
        try saveReport()
        guard service.isSupported else { throw XCTSkip("App Attest unavailable in actual app process") }
        let input = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "challenges", withExtension: "json"))
        let challenges = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: input))
        func bytes(_ action: String) throws -> Data {
            try XCTUnwrap(challenges[action]).data(using: .utf8)!
        }
        func digest(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }
        let stateURL = root.appendingPathComponent("state.json")
        var state: [String: String] = [:]
        if FileManager.default.fileExists(atPath: stateURL.path) {
            state = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: stateURL))
        }
        func saveState() throws {
            try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic, .completeFileProtection])
        }
        // At most one active and one replacement handle. Never regenerate on retry.
        for slot in ["active", "replacement"] {
            do {
                let key: String
                let reusedHandle = state[slot] != nil
                if let existing = state[slot] { key = existing }
                else {
                    key = try await service.generateKey()
                    state[slot] = key
                    try saveState()
                }
                let attestationURL = root.appendingPathComponent("\(slot)-attestation.cbor")
                if !FileManager.default.fileExists(atPath: attestationURL.path) {
                    // Persist exact hash input before the Apple call; retries keep the same bytes.
                    let challengeURL = root.appendingPathComponent("\(slot)-attestation-input.bin")
                    if !FileManager.default.fileExists(atPath: challengeURL.path) {
                        try bytes("\(slot)-attest").write(to: challengeURL, options: [.atomic, .completeFileProtection])
                    }
                    guard state["\(slot)_attestation_started"] == nil else {
                        throw NSError(domain: "DJConnect.AppAttestQualification", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Prior attestation outcome unknown; explicit recovery required"])
                    }
                    let hash = digest(try Data(contentsOf: challengeURL))
                    state["\(slot)_attestation_started"] = "true"
                    try saveState()
                    let attestation = try await service.attestKey(key, clientDataHash: hash)
                    try attestation.write(to: attestationURL, options: [.atomic, .completeFileProtection])
                }
                report["\(slot)_attestation_captured"] = true
                let priorCount = FileManager.default.fileExists(atPath: root.appendingPathComponent("\(slot)-assert-2.cbor").path) ? "2" : "0"
                let completed = Int(state["\(slot)_assertion_count"] ?? priorCount) ?? 0
                guard completed <= 2 else {
                    throw NSError(domain: "DJConnect.AppAttestQualification", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Bounded capture already complete"])
                }
                for index in (completed + 1)...(completed + 2) {
                    let inputData = try bytes("\(slot)-assert-\(index)")
                    let assertion = try await service.generateAssertion(key, clientDataHash: digest(inputData))
                    try inputData.write(to: root.appendingPathComponent("\(slot)-assert-\(index)-input.bin"), options: [.atomic, .completeFileProtection])
                    try assertion.write(to: root.appendingPathComponent("\(slot)-assert-\(index).cbor"), options: [.atomic, .completeFileProtection])
                    state["\(slot)_assertion_count"] = String(index)
                    try saveState()
                }
                report["\(slot)_handle_reused"] = reusedHandle
                report["\(slot)_assertions_captured"] = completed + 2
                try saveReport()
            } catch {
                let ns = error as NSError
                report["failed_stage"] = slot
                report["error_domain"] = ns.domain
                report["error_code"] = ns.code
                try saveReport()
                XCTFail("App Attest diagnostic stopped: \(slot), \(ns.domain), code \(ns.code); no automatic key replacement")
                return
            }
        }
        do {
            _ = try await service.generateAssertion(Data(repeating: 0, count: 32).base64EncodedString(), clientDataHash: digest(try bytes("invalid-key")))
            report["unknown_key_rejected"] = false
            XCTFail("Unknown App Attest key unexpectedly accepted")
        } catch {
            let ns = error as NSError
            report["unknown_key_rejected"] = true
            report["unknown_key_error_domain"] = ns.domain
            report["unknown_key_error_code"] = ns.code
        }
        report["server_verification"] = "NOT_RUN_API_LANE_OWNS"
        report["hardware_erasure"] = "NOT_CLAIMED"
        try saveReport()
    }
}
