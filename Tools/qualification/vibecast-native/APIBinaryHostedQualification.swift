import XCTest
import DeviceCheck
import UIKit
import CryptoKit

@MainActor private final class BinaryCaptureFence { var valid = true }

/// Separate API-issued binary intake. Never included in the ordinary project.
/// A receipt string in the private descriptor is NOT proof of API approval:
/// the operator must verify the exact agreed profile before explicitly arming.
@MainActor final class APIBinaryHostedQualification: XCTestCase {
    func testAPIProvidedBinaryInput() async throws {
        guard ProcessInfo.processInfo.environment["DJC_API_BINARY_CAPTURE"] == "1" else {
            throw XCTSkip("Joint API binary capture is not armed")
        }
        do { try await capture() }
        catch { XCTFail("Binary API qualification stopped; inspect private state, no automatic retry") }
    }
    private func capture() async throws {
        guard Bundle.main.bundleIdentifier == "dev.djconnect.ios",
              Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String == "40380",
              !ProcessInfo.processInfo.isiOSAppOnMac, DCAppAttestService.shared.isSupported else { throw BindingFailure.rejected }
        let fm = FileManager.default
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let parent = support.appendingPathComponent("DJConnect/APIBinaryQualification40380", isDirectory: true)
        guard let stage = ProcessInfo.processInfo.environment["DJC_API_BINARY_STAGE"],
              ["register", "action"].contains(stage) else { throw BindingFailure.rejected }
        let root = parent.appendingPathComponent(stage, isDirectory: true)
        func read(_ name: String, maximum: Int) throws -> Data {
            let url = root.appendingPathComponent(name)
            let attributes = try fm.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber, size.intValue > 0, size.intValue <= maximum else { throw BindingFailure.rejected }
            let bytes = try Data(contentsOf: url)
            guard !bytes.isEmpty, bytes.count <= maximum else { throw BindingFailure.rejected }
            return bytes
        }
        let admissionBytes = try read("admission.json", maximum: 2_048)
        let admission = try FlatObject.parse(admissionBytes)
        guard Set(admission.keys) == Set(["v", "team_id", "bundle_id", "build", "environment", "api_review_receipt"]),
              admission["v"] == .string("djc-api-binary-qualification/1"),
              admission["team_id"] == .string("ZEML4LPXH4"), admission["bundle_id"] == .string("dev.djconnect.ios"),
              admission["build"] == .string("40380"), admission["environment"] == .string("development"),
              case .string(let receipt)? = admission["api_review_receipt"],
              receipt.range(of: "^https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-[0-9]+$", options: .regularExpression) != nil else { throw BindingFailure.rejected }
        let contextBytes = try read("request-context.json", maximum: 2_048)
        let context = try FlatObject.parse(contextBytes)
        func string(_ key: String) throws -> String {
            guard case .string(let value)? = context[key] else { throw BindingFailure.rejected }; return value
        }
        func integer(_ key: String) throws -> Int64 {
            guard case .integer(let value)? = context[key] else { throw BindingFailure.rejected }; return value
        }
        let action = try string("action"), key = try string("key_id"), requested = try integer("requested_at")
        let response = try read("challenge-response.json", maximum: 4_096)
        let now: () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1_000) }
        guard (stage == "register") == (action == "register") else { throw BindingFailure.rejected }
        let common = Set(["action", "key_id", "challenge_id", "challenge", "expires_at", "requested_at"])
        let input: BinarySDKInput
        if action == "register" {
            guard Set(context.keys) == common else { throw BindingFailure.rejected }
            let parsed = try FlatObject.parse(response, maximumBytes: 4_096)
            for field in ["challenge_id", "challenge", "expires_at"] {
                guard parsed[field] == context[field] else { throw BindingFailure.rejected }
            }
            input = try .registration(response: response, keyID: key, requestedAtMS: requested, nowMS: now())
        } else {
            guard let selected = ClientDataExpectation.Action(rawValue: action) else { throw BindingFailure.rejected }
            let extra = Set(["transaction_id", "generation", "browser_key_thumbprint", "envelope_digest", "transaction_expires_at"])
            guard Set(context.keys) == (selected == .submit ? common.union(extra) : common) else { throw BindingFailure.rejected }
            let scan: ScanContext? = selected == .submit ? try .init(transaction: string("transaction_id"), generation: integer("generation"),
                browserThumbprint: string("browser_key_thumbprint"), deadlineMS: integer("transaction_expires_at")) : nil
            let expectation = try ClientDataExpectation(action: selected, keyID: key, challengeID: string("challenge_id"),
                challenge: string("challenge"), deadlineMS: integer("expires_at"), scan: scan,
                envelopeDigest: selected == .submit ? string("envelope_digest") : nil)
            input = try .action(response: response, expectation: expectation, requestedAtMS: requested, nowMS: now())
        }
        // No pre-existing attestation/assertion from any historical diagnostic is
        // read here. The admitted setup must supply this exact existing key handle.
        let fence = BinaryCaptureFence()
        let observers = [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { fence.valid = false }
            }
        }
        defer { observers.forEach(NotificationCenter.default.removeObserver) }
        let proof = try await BinarySDKIntake.shared.perform(input, keyID: { key }, now: now, current: {
            fence.valid && UIApplication.shared.applicationState == .active &&
            (try? read("admission.json", maximum: 2_048)) == admissionBytes &&
            (try? read("request-context.json", maximum: 2_048)) == contextBytes &&
            (try? read("challenge-response.json", maximum: 4_096)) == response
        }, persist: { original, hash in
            // An interrupted or uncertain operation is never automatically rerun.
            guard !fm.fileExists(atPath: root.appendingPathComponent("attempted").path) else { throw BindingFailure.rejected }
            try original.write(to: root.appendingPathComponent("sdk-input.bin"), options: [.atomic, .completeFileProtection])
            try hash.write(to: root.appendingPathComponent("sdk-hash.bin"), options: [.atomic, .completeFileProtection])
            try Data([1]).write(to: root.appendingPathComponent("attempted"), options: [.withoutOverwriting, .completeFileProtection])
        }, sdk: { key, hash in
            // Callback continuations deliberately await the actual SDK callback;
            // cancellation does not free the qualification slot prematurely.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
                let completion: @Sendable (Data?, (any Error)?) -> Void = { data, error in
                    guard error == nil, let data else { continuation.resume(throwing: BindingFailure.rejected); return }
                    continuation.resume(returning: data)
                }
                switch input.kind {
                case .registration: DCAppAttestService.shared.attestKey(key, clientDataHash: hash, completionHandler: completion)
                case .assertion: DCAppAttestService.shared.generateAssertion(key, clientDataHash: hash, completionHandler: completion)
                }
            }
        })
        // Proof remains private; no attachments, hashes, key IDs or SDK userInfo
        // are printed. This file is not a successful API registration receipt.
        try proof.write(to: root.appendingPathComponent("proof.cbor"), options: [.atomic, .completeFileProtection])
    }
}
