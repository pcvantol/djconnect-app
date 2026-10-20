import CryptoKit
import Foundation

/// Exact-byte recover-key accounting only. No SDK, HTTP, challenge allocation,
/// key generation, response verification or active-key adoption is performed.
/// Future callers must hold the complete per-key queue and separately admit the
/// existing key, trusted app/origin, explicit repair budget and current context.
public actor RendezvousRecoveryJournal {
    public static let shared = RendezvousRecoveryJournal(storage: RendezvousRepairKeychainStorage(
        service: "dev.djconnect.rendezvous.recovery", account: "recover-key-v1"
    ))
    public enum Failure: Error, Sendable { case invalidMaterial, invalidData, alreadyExists, missingState, wrongAttempt, unavailable }
    public enum Phase: String, Codable, Sendable { case assertionPending, prepared, recoveryPaused, completed }
    public enum AssertionResult: Sendable { case received(Data), failed }
    public struct Snapshot: Sendable {
        public let attemptIdentifier: UUID
        public let keyIdentifier: String
        public let deadlineMS: Int64
        public let phase: Phase
        public let assertionStarted: Bool
        public let assertionReservation: UUID?
        public let callsStarted: Int
        public let reservation: UUID?
    }
    public struct AssertionCall: Sendable {
        public let attemptIdentifier: UUID
        public let reservation: UUID
        public let keyIdentifier: String
        public let deadlineMS: Int64
        public let clientDataHash: Data
    }
    public struct Submission: Sendable {
        public let attemptIdentifier: UUID
        public let reservation: UUID
        public let keyIdentifier: String
        public let deadlineMS: Int64
        public let body: Data
    }
    private let storage: any RendezvousRepairStorage
    private static let maximumBytes = 24_576
    init(storage: any RendezvousRepairStorage) { self.storage = storage }

    /// clientData is the original decoded server byte string, never a rebuilt
    /// dictionary. All parsed fields must match this captured recovery context.
    public func begin(keyIdentifier: String, challengeIdentifier: String, nonce: Data, clientData: Data,
                      admittedAtMS: Int64, deadlineMS: Int64) async throws -> UUID {
        guard RendezvousAppKeyOperations.initialEnrollmentLease == nil else { throw Failure.unavailable }
        return try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:RendezvousAppKeyOperations.installationAdmissionSlot) {
            try await self.beginLocked(keyIdentifier:keyIdentifier,challengeIdentifier:challengeIdentifier,
                nonce:nonce,clientData:clientData,admittedAtMS:admittedAtMS,deadlineMS:deadlineMS)
        }
    }
    private func beginLocked(keyIdentifier:String,challengeIdentifier:String,nonce:Data,clientData:Data,
                              admittedAtMS:Int64,deadlineMS:Int64) throws -> UUID {
        if var existing = try read() {
            try existing.observe(at: admittedAtMS)
            try persist(existing)
            throw Failure.alreadyExists
        }
        let record = try RecoveryRecord(key: keyIdentifier, challenge: challengeIdentifier, nonce: nonce,
                                        clientData: clientData, startedAtMS: admittedAtMS, deadlineMS: deadlineMS)
        try persist(record)
        return record.id
    }

    public func snapshot(at nowMS: Int64) throws -> Snapshot? {
        guard var record = try read() else { return nil }
        try record.observe(at: nowMS)
        try persist(record)
        return record.snapshot
    }

    /// A consumed assertion reservation survives restart. No second assertion
    /// for this challenge is authorized, even after an interrupted SDK call.
    public func reserveAssertion(attemptIdentifier: UUID, at nowMS: Int64) throws -> AssertionCall {
        try mutate(attemptIdentifier, at: nowMS) { record in
            guard record.phase == .assertionPending, !record.assertionStarted,
                  let hash = record.clientDataHash else { throw Failure.unavailable }
            let reservation = UUID()
            record.assertionStarted = true
            record.assertionReservation = reservation
            return AssertionCall(attemptIdentifier: record.id, reservation: reservation,
                                 keyIdentifier: record.key, deadlineMS: record.window.deadlineMS, clientDataHash: hash)
        }
    }

    public func completeAssertion(attemptIdentifier: UUID, reservation: UUID,
                                  result: AssertionResult, at nowMS: Int64) throws {
        try mutate(attemptIdentifier, at: nowMS) { record in
            guard record.phase == .assertionPending, record.assertionReservation == reservation else { throw Failure.unavailable }
            switch result {
            case .received(let assertion) where !assertion.isEmpty && assertion.count <= 4_096:
                guard let original = record.clientData, let challenge = record.challenge else { throw Failure.invalidData }
                let body = try RecoveryRecord.body(key: record.key, challenge: challenge, clientData: original, assertion: assertion)
                record.request = body
                record.requestHash = RecoveryRecord.hash(body)
                record.assertionReservation = nil
                record.phase = .prepared
            case .received:
                record.assertionReservation = nil
                record.finish(as: .recoveryPaused)
                throw Failure.invalidMaterial
            case .failed:
                record.assertionReservation = nil
                record.finish(as: .recoveryPaused)
            }
        }
    }

    public func reserveSubmission(attemptIdentifier: UUID, at nowMS: Int64) throws -> Submission {
        try mutate(attemptIdentifier, at: nowMS) { record in
            guard record.phase == .prepared, let body = record.request else { throw Failure.unavailable }
            let reservation = try record.window.reserve(at: nowMS)
            return Submission(attemptIdentifier: record.id, reservation: reservation, keyIdentifier: record.key,
                              deadlineMS: record.window.deadlineMS, body: body)
        }
    }

    /// Only a lost response permits identical retries. Succeeded is the caller's
    /// validated receipt result; completed does not itself authorize key adoption.
    public func completeSubmission(attemptIdentifier: UUID, reservation: UUID,
                                   outcome: RendezvousRetryWindow.Outcome, at nowMS: Int64,
                                   retryNotBeforeMS: Int64? = nil) throws {
        try mutate(attemptIdentifier, at: nowMS) { record in
            guard record.phase == .prepared else { throw Failure.unavailable }
            try record.window.complete(reservation, outcome: outcome, at: nowMS, retryNotBeforeMS: retryNotBeforeMS)
            if record.window.isClosed {
                let succeeded: Bool = if case .succeeded = outcome { true } else { false }
                record.finish(as: succeeded ? .completed : .recoveryPaused)
            }
        }
    }

    private func mutate<Value>(_ id: UUID, at nowMS: Int64, operation: (inout RecoveryRecord) throws -> Value) throws -> Value {
        guard var record = try read() else { throw Failure.missingState }
        guard record.id == id else { throw Failure.wrongAttempt }
        try record.observe(at: nowMS)
        let result = Result { try operation(&record) }
        // Persist normalized expiry/clock even on refusal; never retry an
        // ambiguous storage write or release external-call bytes after failure.
        try persist(record)
        return try result.get()
    }
    private func read() throws -> RecoveryRecord? {
        guard let bytes = try storage.read() else { return nil }
        guard !bytes.isEmpty, bytes.count <= Self.maximumBytes else { throw Failure.invalidData }
        do { return try JSONDecoder().decode(RecoveryRecord.self, from: bytes) }
        catch { throw Failure.invalidData }
    }
    private func persist(_ record: RecoveryRecord) throws {
        let bytes = try JSONEncoder().encode(record)
        guard bytes.count <= Self.maximumBytes else { throw Failure.invalidData }
        try storage.write(bytes)
    }
}

private struct RecoveryRecord: Codable {
    private let schemaVersion = 1
    let id: UUID
    let key: String
    var phase: RendezvousRecoveryJournal.Phase = .assertionPending
    var window: RendezvousRetryWindow
    var assertionStarted = false
    var assertionReservation: UUID?
    private var lastObservedMS: Int64
    var challenge: String?
    private var nonce: Data?
    var clientData: Data?
    var clientDataHash: Data?
    var request: Data?
    var requestHash: Data?

    init(key: String, challenge: String, nonce: Data, clientData: Data, startedAtMS: Int64, deadlineMS: Int64) throws {
        try Self.validate(key: key, challenge: challenge, nonce: nonce, clientData: clientData, deadlineMS: deadlineMS)
        id = UUID()
        self.key = key; self.challenge = challenge; self.nonce = nonce
        self.clientData = clientData; clientDataHash = Self.hash(clientData)
        window = try RendezvousRetryWindow(kind: .recovery, startedAtMS: startedAtMS, deadlineMS: deadlineMS)
        lastObservedMS = startedAtMS
    }
    var snapshot: RendezvousRecoveryJournal.Snapshot {
        .init(attemptIdentifier: id, keyIdentifier: key, deadlineMS: window.deadlineMS, phase: phase,
              assertionStarted: assertionStarted, assertionReservation: assertionReservation,
              callsStarted: window.callsStarted, reservation: window.reservation)
    }
    mutating func observe(at nowMS: Int64) throws {
        guard nowMS >= lastObservedMS else { throw RendezvousRecoveryJournal.Failure.invalidData }
        lastObservedMS = nowMS
        if phase == .assertionPending || phase == .prepared,
           nowMS >= window.deadlineMS { finish(as: .recoveryPaused) }
    }
    mutating func finish(as phase: RendezvousRecoveryJournal.Phase) {
        self.phase = phase
        challenge = nil; nonce = nil; clientData = nil; clientDataHash = nil; request = nil; requestHash = nil
    }
    static func hash(_ bytes: Data) -> Data { Data(SHA256.hash(data: bytes)) }
    static func encodeURL(_ bytes: Data) -> String {
        bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private static func decodeURL(_ value: String) -> Data? {
        guard !value.isEmpty, value.utf8.count <= 5_462,
              value.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { return nil }
        let base = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let bytes = Data(base64Encoded: base + String(repeating: "=", count: (4 - base.count % 4) % 4)), encodeURL(bytes) == value else { return nil }
        return bytes
    }
    private static func validKey(_ key: String) -> Bool {
        guard key.utf8.count == 44, let bytes = Data(base64Encoded: key), bytes.count == 32 else { return false }
        return bytes.base64EncodedString() == key
    }
    private static func validate(key: String, challenge: String, nonce: Data, clientData: Data, deadlineMS: Int64) throws {
        guard validKey(key), decodeURL(challenge)?.count == 32, nonce.count == 32,
              deadlineMS >= 0, deadlineMS <= 9_007_199_254_740_991,
              try RecoveryFlatObject.parse(clientData) == [
                "v": .string("djc-rendezvous/1"), "action": .string("recover-key"),
                "service_origin": .string("https://api.djconnect.dev"), "key_id": .string(key),
                "challenge_id": .string(challenge), "challenge": .string(encodeURL(nonce)), "expires_at": .integer(deadlineMS)
              ] else { throw RendezvousRecoveryJournal.Failure.invalidMaterial }
    }
    static func body(key: String, challenge: String, clientData: Data, assertion: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "key_id": key,
            "challenge_id": challenge, "client_data": encodeURL(clientData), "assertion": encodeURL(assertion)],
            options: [.sortedKeys, .withoutEscapingSlashes])
    }
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, key, phase, window, assertionStarted, assertionReservation, lastObservedMS, challenge, nonce, clientData, clientDataHash, request, requestHash
    }
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(Int.self, forKey: .schemaVersion) == 1 else { throw RendezvousRecoveryJournal.Failure.invalidData }
        id = try c.decode(UUID.self, forKey: .id); key = try c.decode(String.self, forKey: .key)
        phase = try c.decode(RendezvousRecoveryJournal.Phase.self, forKey: .phase)
        window = try c.decode(RendezvousRetryWindow.self, forKey: .window)
        assertionStarted = try c.decode(Bool.self, forKey: .assertionStarted)
        assertionReservation = try c.decodeIfPresent(UUID.self, forKey: .assertionReservation)
        lastObservedMS = try c.decode(Int64.self, forKey: .lastObservedMS)
        challenge = try c.decodeIfPresent(String.self, forKey: .challenge)
        nonce = try c.decodeIfPresent(Data.self, forKey: .nonce)
        clientData = try c.decodeIfPresent(Data.self, forKey: .clientData)
        clientDataHash = try c.decodeIfPresent(Data.self, forKey: .clientDataHash)
        request = try c.decodeIfPresent(Data.self, forKey: .request)
        requestHash = try c.decodeIfPresent(Data.self, forKey: .requestHash)
        guard Self.validKey(key), window.kind == .recovery, window.deadlineMS <= 9_007_199_254_740_991,
              lastObservedMS >= window.observedAtMS,
              assertionStarted || assertionReservation == nil else { throw RendezvousRecoveryJournal.Failure.invalidData }
        if phase == .assertionPending || phase == .prepared {
            guard !window.isClosed, lastObservedMS < window.deadlineMS,
                  let challenge, let nonce, let clientData, clientDataHash == Self.hash(clientData) else { throw RendezvousRecoveryJournal.Failure.invalidData }
            try Self.validate(key: key, challenge: challenge, nonce: nonce, clientData: clientData, deadlineMS: window.deadlineMS)
            if phase == .assertionPending {
                guard assertionStarted == (assertionReservation != nil), window.callsStarted == 0,
                      request == nil, requestHash == nil else { throw RendezvousRecoveryJournal.Failure.invalidData }
            } else {
                guard assertionStarted, assertionReservation == nil,
                      let request, request.count <= 16_384, requestHash == Self.hash(request),
                      let object = try JSONSerialization.jsonObject(with: request) as? [String: String],
                      Set(object.keys) == Set(["v", "key_id", "challenge_id", "client_data", "assertion"]),
                      object["v"] == "djc-rendezvous/1", object["key_id"] == key, object["challenge_id"] == challenge,
                      object["client_data"] == Self.encodeURL(clientData), let encoded = object["assertion"],
                      let assertion = Self.decodeURL(encoded), !assertion.isEmpty, assertion.count <= 4_096,
                      request == (try Self.body(key: key, challenge: challenge, clientData: clientData, assertion: assertion)) else { throw RendezvousRecoveryJournal.Failure.invalidData }
            }
        } else {
            guard challenge == nil, nonce == nil, clientData == nil, clientDataHash == nil, request == nil, requestHash == nil,
                  assertionStarted || window.callsStarted == 0,
                  assertionReservation == nil || window.callsStarted == 0 else { throw RendezvousRecoveryJournal.Failure.invalidData }
            if phase == .completed {
                guard assertionStarted, assertionReservation == nil, window.isClosed, window.callsStarted > 0 else { throw RendezvousRecoveryJournal.Failure.invalidData }
            } else if lastObservedMS < window.deadlineMS, !window.isClosed {
                // A pre-expiry pause without a transport outcome can only be a
                // completed failed assertion, never a new unused admission.
                guard assertionStarted, assertionReservation == nil, window.callsStarted == 0 else { throw RendezvousRecoveryJournal.Failure.invalidData }
            }
        }
    }
}
private enum RecoveryFlatValue: Equatable, Sendable {
    case string(String), integer(Int64)
}

/// The selected clientData schema is flat and contains strings/integers only.
/// Foundation decodes each string (including escapes); this bounded recognizer
/// rejects duplicate decoded keys before forming a dictionary. It is not a general JSON parser.
private struct RecoveryFlatObject {
    static func parse(_ data: Data) throws -> [String: RecoveryFlatValue] {
        guard !data.isEmpty, data.count <= 2048, String(data: data, encoding: .utf8) != nil else {
            throw RendezvousRecoveryJournal.Failure.invalidMaterial
        }
        let bytes = Array(data); var i = 0
        func whitespace() { while i < bytes.count && [9, 10, 13, 32].contains(bytes[i]) { i += 1 } }
        func take(_ byte: UInt8) throws {
            whitespace(); guard i < bytes.count, bytes[i] == byte else { throw RendezvousRecoveryJournal.Failure.invalidMaterial }; i += 1
        }
        func string() throws -> String {
            whitespace(); let start = i
            guard i < bytes.count, bytes[i] == 34 else { throw RendezvousRecoveryJournal.Failure.invalidMaterial }; i += 1
            while i < bytes.count {
                if bytes[i] == 92 { i += 2; continue }
                if bytes[i] == 34 {
                    i += 1
                    // Foundation's parse error can contain input fragments.
                    // Expose only the fixed typed rejection to public callers.
                    guard let value = (try? JSONSerialization.jsonObject(with: Data(bytes[start..<i]), options: [.fragmentsAllowed])) as? String else {
                        throw RendezvousRecoveryJournal.Failure.invalidMaterial
                    }
                    return value
                }
                i += 1
            }
            throw RendezvousRecoveryJournal.Failure.invalidMaterial
        }
        try take(123); whitespace(); var result: [String: RecoveryFlatValue] = [:]
        if i < bytes.count, bytes[i] == 125 { i += 1 }
        else {
            while true {
                let key = try string()
                guard result[key] == nil else { throw RendezvousRecoveryJournal.Failure.invalidMaterial }
                try take(58); whitespace()
                guard i < bytes.count else { throw RendezvousRecoveryJournal.Failure.invalidMaterial }
                let value: RecoveryFlatValue
                if bytes[i] == 34 { value = .string(try string()) }
                else {
                    let start = i
                    while i < bytes.count, bytes[i] >= 48, bytes[i] <= 57 { i += 1 }
                    let token = String(decoding: bytes[start..<i], as: UTF8.self)
                    guard !token.isEmpty, (token == "0" || !token.hasPrefix("0")),
                          let number = Int64(token), number <= 9_007_199_254_740_991 else { throw RendezvousRecoveryJournal.Failure.invalidMaterial }
                    value = .integer(number)
                }
                result[key] = value; whitespace()
                guard i < bytes.count else { throw RendezvousRecoveryJournal.Failure.invalidMaterial }
                if bytes[i] == 125 { i += 1; break }
                try take(44)
            }
        }
        whitespace(); guard i == bytes.count else { throw RendezvousRecoveryJournal.Failure.invalidMaterial }
        return result
    }
}

