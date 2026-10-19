import CryptoKit
import Foundation

/// Qualification-only binary boundary, not an endpoint/owner authorization.
/// Construct from the actual response plus independently captured request context.
struct BinarySDKInput: Sendable {
    enum Kind: Sendable { case registration, assertion }
    let kind: Kind
    let keyID: String
    let challengeID: String
    let action: String
    let deadlineMS: Int64
    let requestedAtMS: Int64
    let original: Data
    private let observedAtMS: Int64
    private let lifetimeStart: ContinuousClock.Instant
    var hash: Data { Data(SHA256.hash(data: original)) }
    private init(kind: Kind, keyID: String, challengeID: String, action: String, deadlineMS: Int64, requestedAtMS: Int64, original: Data, observedAtMS: Int64, lifetimeStart: ContinuousClock.Instant) {
        self.kind = kind; self.keyID = keyID; self.deadlineMS = deadlineMS
        self.challengeID = challengeID; self.action = action
        self.observedAtMS = observedAtMS; self.lifetimeStart = lifetimeStart
        self.requestedAtMS = requestedAtMS; self.original = original
    }

    static func registration(response: Data, keyID: String, requestedAtMS: Int64, nowMS: Int64) throws -> Self {
        let lifetimeStart = ContinuousClock.now
        let fields = try responseFields(response, hasClientData: false)
        guard ClientDataExpectation.standardKey(keyID),
              case .string(let nonce)? = fields["challenge"], ClientDataExpectation.opaque(nonce),
              case .string(let id)? = fields["challenge_id"],
              case .integer(let deadline)? = fields["expires_at"] else { throw BindingFailure.rejected }
        let decoded = try decodeURL(nonce, limit: 32)
        guard decoded.count == 32 else { throw BindingFailure.rejected }
        let input = Self(kind: .registration, keyID: keyID, challengeID: id, action: "register", deadlineMS: deadline, requestedAtMS: requestedAtMS, original: decoded, observedAtMS: nowMS, lifetimeStart: lifetimeStart)
        try input.check(keyID: keyID, nowMS: nowMS, current: true)
        return input
    }

    static func action(response: Data, expectation: ClientDataExpectation, requestedAtMS: Int64, nowMS: Int64) throws -> Self {
        let lifetimeStart = ContinuousClock.now
        let fields = try responseFields(response, hasClientData: true)
        guard fields["challenge_id"] == .string(expectation.challengeID),
              fields["challenge"] == .string(expectation.challenge),
              fields["expires_at"] == .integer(expectation.deadlineMS),
              case .string(let encoded)? = fields["client_data"] else { throw BindingFailure.rejected }
        let original = try decodeURL(encoded, limit: 2_048)
        // Closed decoded action/key/service/nonce/deadline/transaction binding.
        // Validation never reserializes the bytes sent to the SDK.
        _ = try expectation.validate(original, at: nowMS)
        let input = Self(kind: .assertion, keyID: expectation.keyID, challengeID: expectation.challengeID, action: expectation.action.rawValue, deadlineMS: expectation.deadlineMS,
                         requestedAtMS: requestedAtMS, original: original, observedAtMS: nowMS, lifetimeStart: lifetimeStart)
        try input.check(keyID: expectation.keyID, nowMS: nowMS, current: true)
        return input
    }

    func check(keyID: String, nowMS: Int64, current: Bool) throws {
        guard current, self.keyID == keyID, requestedAtMS >= 0, deadlineMS > requestedAtMS,
              deadlineMS <= 9_007_199_254_740_991, deadlineMS - requestedAtMS <= 120_000,
              nowMS >= requestedAtMS, nowMS >= observedAtMS, nowMS < deadlineMS else { throw BindingFailure.rejected }
        // Original remaining lifetime starts at input construction, never dispatch.
        guard ContinuousClock.now < lifetimeStart.advanced(by: .milliseconds(deadlineMS - observedAtMS)) else { throw BindingFailure.rejected }
    }

    private static func responseFields(_ bytes: Data, hasClientData: Bool) throws -> [String: FlatValue] {
        guard !bytes.isEmpty, bytes.count <= 4_096 else { throw BindingFailure.rejected }
        let fields = try FlatObject.parse(bytes, maximumBytes: 4_096)
        let keys = hasClientData ? ["v", "challenge_id", "challenge", "expires_at", "client_data"] : ["v", "challenge_id", "challenge", "expires_at"]
        guard Set(fields.keys) == Set(keys), fields["v"] == .string("djc-rendezvous/1"),
              case .string(let id)? = fields["challenge_id"], ClientDataExpectation.opaque(id),
              case .string(let nonce)? = fields["challenge"], ClientDataExpectation.opaque(nonce) else { throw BindingFailure.rejected }
        return fields
    }
    private static func decodeURL(_ encoded: String, limit: Int) throws -> Data {
        guard !encoded.isEmpty, encoded.utf8.count <= (limit * 4 + 2) / 3,
              encoded.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { throw BindingFailure.rejected }
        let padded = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - encoded.utf8.count % 4) % 4)
        guard let bytes = Data(base64Encoded: padded), bytes.count <= limit, base64url(bytes) == encoded else { throw BindingFailure.rejected }
        return bytes
    }
}

/// One qualification SDK call at a time, including cancellation until the actual
/// SDK completion. Persist must durably consume the attempt before SDK dispatch.
/// No retry, key generation, server request or automatic capture is implemented.
@MainActor final class BinarySDKIntake {
    static let shared = BinarySDKIntake()
    private var busy = false
    func perform(_ input: BinarySDKInput, keyID: () -> String, now: () -> Int64, current: () -> Bool,
                 persist: (Data, Data) throws -> Void,
                 sdk: (String, Data) async throws -> Data) async throws -> Data {
        do {
            guard !busy else { throw BindingFailure.rejected }
            try Task.checkCancellation()
            var lastObservedWall = now()
            try input.check(keyID: keyID(), nowMS: lastObservedWall, current: current())
            func recheck() throws {
                let observed = now()
                guard observed >= lastObservedWall else { throw BindingFailure.rejected }
                try input.check(keyID: keyID(), nowMS: observed, current: current())
                lastObservedWall = observed
            }
            busy = true; defer { busy = false }
            let original = input.original, hash = input.hash
            try persist(original, hash)
            try Task.checkCancellation()
            try recheck()
            let proof = try await sdk(input.keyID, hash)
            try Task.checkCancellation()
            try recheck()
            let maximum = switch input.kind { case .registration: 32_768; case .assertion: 4_096 }
            guard !proof.isEmpty, proof.count <= maximum else { throw BindingFailure.rejected }
            return proof
        } catch {
            // Includes SDK/OS/file/JSON errors: never publish userInfo/input fragments.
            throw BindingFailure.rejected
        }
    }
}
