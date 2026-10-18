import Foundation
import CryptoKit

// Qualification seam for the unfrozen API0.4 profile, not a product scanner/parser.
// No transport, persistence, credentials, App Attest key generation or implicit authority.
enum BindingFailure: Error { case rejected }

enum FlatValue: Equatable, Sendable {
    case string(String), integer(Int64)
}

/// The selected clientData schema is flat and contains strings/integers only.
/// Foundation decodes each string (including escapes); this bounded recognizer
/// rejects duplicate decoded keys before forming a dictionary. It is not a general JSON parser.
struct FlatObject {
    static func parse(_ data: Data) throws -> [String: FlatValue] {
        guard !data.isEmpty, data.count <= 2048, String(data: data, encoding: .utf8) != nil else {
            throw BindingFailure.rejected
        }
        let bytes = Array(data); var i = 0
        func whitespace() { while i < bytes.count && [9, 10, 13, 32].contains(bytes[i]) { i += 1 } }
        func take(_ byte: UInt8) throws {
            whitespace(); guard i < bytes.count, bytes[i] == byte else { throw BindingFailure.rejected }; i += 1
        }
        func string() throws -> String {
            whitespace(); let start = i
            guard i < bytes.count, bytes[i] == 34 else { throw BindingFailure.rejected }; i += 1
            while i < bytes.count {
                if bytes[i] == 92 { i += 2; continue }
                if bytes[i] == 34 {
                    i += 1
                    guard let value = try JSONSerialization.jsonObject(with: Data(bytes[start..<i]), options: [.fragmentsAllowed]) as? String else {
                        throw BindingFailure.rejected
                    }
                    return value
                }
                i += 1
            }
            throw BindingFailure.rejected
        }
        try take(123); whitespace(); var result: [String: FlatValue] = [:]
        if i < bytes.count, bytes[i] == 125 { i += 1 }
        else {
            while true {
                let key = try string()
                guard result[key] == nil else { throw BindingFailure.rejected }
                try take(58); whitespace()
                guard i < bytes.count else { throw BindingFailure.rejected }
                let value: FlatValue
                if bytes[i] == 34 { value = .string(try string()) }
                else {
                    let start = i
                    while i < bytes.count, bytes[i] >= 48, bytes[i] <= 57 { i += 1 }
                    let token = String(decoding: bytes[start..<i], as: UTF8.self)
                    guard !token.isEmpty, (token == "0" || !token.hasPrefix("0")),
                          let number = Int64(token), number <= 9_007_199_254_740_991 else { throw BindingFailure.rejected }
                    value = .integer(number)
                }
                result[key] = value; whitespace()
                guard i < bytes.count else { throw BindingFailure.rejected }
                if bytes[i] == 125 { i += 1; break }
                try take(44)
            }
        }
        whitespace(); guard i == bytes.count else { throw BindingFailure.rejected }
        return result
    }
}

struct LocalScope: Equatable, Sendable {
    let installation: String
    let pairingGeneration: UInt64
    let profileGeneration: UInt64
    let routeGeneration: UInt64
    let displayURL: String
    let issuerEpoch: String
}

struct ScanContext: Equatable, Sendable {
    let transaction: String
    let generation: Int64
    let browserThumbprint: String
    let deadlineMS: Int64
}

struct FlowTicket: Equatable, Sendable {
    let revision: UInt64
    let scope: LocalScope
    let scan: ScanContext
}

/// Every cancellation/background/pairing/Profile/route event must invalidate,
/// even if the user later returns to exactly the same values (ABA).
struct FlowFence: Sendable {
    private var revision: UInt64 = 0
    private var current: FlowTicket?
    private var exhausted = false
    mutating func invalidate() {
        current = nil
        guard revision < UInt64.max else { exhausted = true; return }
        revision += 1
    }
    mutating func begin(scope: LocalScope, scan: ScanContext) throws -> FlowTicket {
        invalidate(); guard !exhausted else { throw BindingFailure.rejected }
        let ticket = FlowTicket(revision: revision, scope: scope, scan: scan)
        current = ticket; return ticket
    }
    func check(_ ticket: FlowTicket, currentScope: LocalScope, nowMS: Int64) throws {
        guard !exhausted, current == ticket, ticket.scope == currentScope,
              nowMS >= 0, nowMS < ticket.scan.deadlineMS else { throw BindingFailure.rejected }
    }
}

struct ClientDataExpectation: Sendable {
    enum Action: String, Sendable { case submit, deleteKey = "delete-key", recoverKey = "recover-key" }
    let action: Action
    let keyID: String
    let challengeID: String
    let challenge: String
    let deadlineMS: Int64
    let scan: ScanContext?
    let envelopeDigest: String?

    func fields() throws -> [String: FlatValue] {
        guard Self.standardKey(keyID), Self.opaque(challengeID), Self.opaque(challenge),
              deadlineMS >= 0, deadlineMS <= 9_007_199_254_740_991 else { throw BindingFailure.rejected }
        var values: [String: FlatValue] = ["v": .string("djc-rendezvous/1"), "action": .string(action.rawValue),
            "service_origin": .string("https://api.djconnect.dev"), "key_id": .string(keyID),
            "challenge_id": .string(challengeID), "challenge": .string(challenge), "expires_at": .integer(deadlineMS)]
        if action == .submit {
            guard let scan, let envelopeDigest, Self.opaque(envelopeDigest), Self.opaque(scan.browserThumbprint),
                  scan.transaction.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", options: .regularExpression) != nil,
                  (1...2_147_483_647).contains(scan.generation), deadlineMS <= scan.deadlineMS else { throw BindingFailure.rejected }
            values["transaction_id"] = .string(scan.transaction); values["generation"] = .integer(scan.generation)
            values["browser_key_thumbprint"] = .string(scan.browserThumbprint); values["envelope_digest"] = .string(envelopeDigest)
        } else if scan != nil || envelopeDigest != nil { throw BindingFailure.rejected }
        return values
    }

    /// Returns the ORIGINAL bytes and hash. Never signs a reserialized object.
    func validate(_ original: Data, at nowMS: Int64) throws -> (bytes: Data, hash: Data) {
        guard nowMS >= 0, nowMS < deadlineMS, try FlatObject.parse(original) == fields() else { throw BindingFailure.rejected }
        return (original, Data(SHA256.hash(data: original)))
    }
    func validateEncoded(_ encoded: String, at nowMS: Int64) throws -> (bytes: Data, hash: Data) {
        guard !encoded.isEmpty, encoded.utf8.count <= 2731,
              encoded.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw BindingFailure.rejected }
        let padded = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - encoded.utf8.count % 4) % 4)
        guard let original = Data(base64Encoded: padded), base64url(original) == encoded else { throw BindingFailure.rejected }
        return try validate(original, at: nowMS)
    }
    static func opaque(_ text: String) -> Bool {
        guard text.utf8.count == 43, text.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil,
              let bytes = Data(base64Encoded: text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "=") else { return false }
        return bytes.count == 32 && base64url(bytes) == text
    }
    static func standardKey(_ text: String) -> Bool {
        guard let bytes = Data(base64Encoded: text), bytes.count == 32 else { return false }
        return bytes.base64EncodedString() == text
    }
}

func base64url(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

/// Isolated submit orchestration seam: single-flight gate for assertions, with
/// fences around suspension and immediately before handing bytes to a caller.
@MainActor final class ActionBindingHarness {
    var fence = FlowFence()
    private var signing = false
    func sign(ticket: FlowTicket, expectation: ClientDataExpectation, original: Data,
              scope: () -> LocalScope, keyID: () -> String, now: () -> Int64,
              signer: (Data) async throws -> Data) async throws -> Data {
        guard !signing, expectation.action == .submit, expectation.scan == ticket.scan,
              expectation.keyID == keyID() else { throw BindingFailure.rejected }
        try fence.check(ticket, currentScope: scope(), nowMS: now())
        let validated = try expectation.validate(original, at: now())
        signing = true; defer { signing = false }
        let assertion = try await signer(validated.hash)
        guard expectation.keyID == keyID(), !assertion.isEmpty, assertion.count <= 4096 else { throw BindingFailure.rejected }
        try fence.check(ticket, currentScope: scope(), nowMS: now())
        _ = try expectation.validate(validated.bytes, at: now())
        return assertion
    }
}
