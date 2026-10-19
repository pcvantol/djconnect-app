import CryptoKit
import Foundation

/// Prepared registration only: no SDK, HTTP, key creation, endpoint selection or
/// active-key adoption. The caller must qualify the original app/key/nonce and
/// operation context before preparing, and again before sending returned bytes.
public actor RendezvousRegistrationJournal {
    public static let shared = RendezvousRegistrationJournal(storage: RendezvousRepairKeychainStorage(
        service: "dev.djconnect.rendezvous.enrollment", account: "prepared-registration-v1"
    ))
    public enum Phase: String, Codable, Sendable { case prepared, registrationUncertain, completed }
    public enum Failure: Error, Sendable { case invalidMaterial, invalidData, alreadyExists, missingState, wrongAttempt, unavailable }
    public struct Snapshot: Sendable {
        public let attemptIdentifier: UUID
        public let keyIdentifier: String
        public let deadlineMS: Int64
        public let phase: Phase
        public let callsStarted: Int
        public let reservation: UUID?
    }
    public struct Submission: Sendable {
        public let attemptIdentifier: UUID
        public let reservation: UUID
        public let keyIdentifier: String
        public let deadlineMS: Int64
        public let body: Data
    }
    private let storage: any RendezvousRepairStorage
    private static let maximumBytes = 98_304

    init(storage: any RendezvousRepairStorage) { self.storage = storage }

    /// Called after the original SDK attestation has been prepared. No prior
    /// attempt (including an uncertain/completed one) can be replaced here.
    public func prepare(keyIdentifier: String, challengeIdentifier: String, nonce: Data,
                        attestation: Data, admittedAtMS: Int64, deadlineMS: Int64) throws -> UUID {
        if var existing = try read() {
            try existing.observeAndExpire(at: admittedAtMS)
            try persist(existing)
            throw Failure.alreadyExists
        }
        let record = try RegistrationRecord(key: keyIdentifier, challenge: challengeIdentifier,
                                            nonce: nonce, attestation: attestation,
                                            startedAtMS: admittedAtMS, deadlineMS: deadlineMS)
        try persist(record)
        return record.id
    }

    /// Logical expiry is enforced before returning even this material-free view.
    /// An unavailable purge write stops the read; it never exposes expired bytes.
    public func snapshot(at nowMS: Int64) throws -> Snapshot? {
        guard var record = try read() else { return nil }
        try record.observeAndExpire(at: nowMS)
        try persist(record)
        return record.snapshot
    }

    /// A same-operation retry gets the original stored bytes, only after its
    /// consumed call/reservation is successfully persisted. No reconstructed body.
    public func reserveSubmission(attemptIdentifier: UUID, at nowMS: Int64) throws -> Submission {
        try mutate(attemptIdentifier, at: nowMS) { record in
            guard record.phase == .prepared, let body = record.request else { throw Failure.unavailable }
            let reservation = try record.window.reserve(at: nowMS)
            return Submission(attemptIdentifier: record.id, reservation: reservation,
                              keyIdentifier: record.key, deadlineMS: record.window.deadlineMS, body: body)
        }
    }

    /// Succeeded means only the caller-reported validated registration outcome;
    /// this journal does not validate a response or adopt/extend an active key.
    public func completeSubmission(attemptIdentifier: UUID, reservation: UUID,
                                   outcome: RendezvousRetryWindow.Outcome, at nowMS: Int64,
                                   retryNotBeforeMS: Int64? = nil) throws {
        try mutate(attemptIdentifier, at: nowMS) { record in
            guard record.phase == .prepared else { throw Failure.unavailable }
            try record.window.complete(reservation, outcome: outcome, at: nowMS, retryNotBeforeMS: retryNotBeforeMS)
            if record.window.isClosed {
                record.finish(as: outcome.isRegistrationSuccess ? .completed : .registrationUncertain)
            }
        }
    }

    private func mutate<Value>(_ id: UUID, at nowMS: Int64,
                               operation: (inout RegistrationRecord) throws -> Value) throws -> Value {
        guard var record = try read() else { throw Failure.missingState }
        guard record.id == id else { throw Failure.wrongAttempt }
        try record.observeAndExpire(at: nowMS)
        // Persist expiry/clock observations even when accounting refuses an
        // action. Keep the storage write outside Result: never retry an uncertain
        // storage write or return prepared bytes after a failed write.
        let result = Result { try operation(&record) }
        try persist(record)
        return try result.get()
    }

    private func read() throws -> RegistrationRecord? {
        guard let data = try storage.read() else { return nil }
        guard !data.isEmpty, data.count <= Self.maximumBytes else { throw Failure.invalidData }
        do { return try JSONDecoder().decode(RegistrationRecord.self, from: data) }
        catch { throw Failure.invalidData }
    }

    private func persist(_ record: RegistrationRecord) throws {
        let data = try JSONEncoder().encode(record)
        guard data.count <= Self.maximumBytes else { throw Failure.invalidData }
        try storage.write(data)
    }
}

private extension RendezvousRetryWindow.Outcome {
    var isRegistrationSuccess: Bool { if case .succeeded = self { return true }; return false }
}

private struct RegistrationRecord: Codable {
    private let schemaVersion = 1
    let id: UUID
    let key: String
    var phase: RendezvousRegistrationJournal.Phase = .prepared
    var window: RendezvousRetryWindow
    private var lastObservedMS: Int64
    private var challenge: String?
    private var nonce: Data?
    private var nonceHash: Data?
    fileprivate var request: Data?
    private var requestHash: Data?

    init(key: String, challenge: String, nonce: Data, attestation: Data,
         startedAtMS: Int64, deadlineMS: Int64) throws {
        guard Self.validKey(key), Self.decodeURL(challenge)?.count == 32, nonce.count == 32,
              !attestation.isEmpty, attestation.count <= 32_768,
              deadlineMS <= 9_007_199_254_740_991 else { throw RendezvousRegistrationJournal.Failure.invalidMaterial }
        id = UUID()
        self.key = key
        self.challenge = challenge
        self.nonce = nonce
        nonceHash = Self.hash(nonce)
        request = try Self.body(key: key, challenge: challenge, attestation: Self.encodeURL(attestation))
        requestHash = Self.hash(request!)
        window = try RendezvousRetryWindow(kind: .registration, startedAtMS: startedAtMS, deadlineMS: deadlineMS)
        lastObservedMS = startedAtMS
    }

    var snapshot: RendezvousRegistrationJournal.Snapshot {
        .init(attemptIdentifier: id, keyIdentifier: key, deadlineMS: window.deadlineMS,
              phase: phase, callsStarted: window.callsStarted, reservation: window.reservation)
    }

    mutating func observeAndExpire(at nowMS: Int64) throws {
        guard nowMS >= lastObservedMS else { throw RendezvousRegistrationJournal.Failure.invalidData }
        lastObservedMS = nowMS
        if phase == .prepared, nowMS >= window.deadlineMS { finish(as: .registrationUncertain) }
    }

    mutating func finish(as phase: RendezvousRegistrationJournal.Phase) {
        self.phase = phase
        challenge = nil
        nonce = nil
        nonceHash = nil
        request = nil
        requestHash = nil
    }

    private static func hash(_ bytes: Data) -> Data { Data(SHA256.hash(data: bytes)) }
    private static func encodeURL(_ bytes: Data) -> String {
        bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private static func decodeURL(_ string: String) -> Data? {
        guard !string.isEmpty, string.utf8.count <= 43_691,
              string.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { return nil }
        let base = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: base + String(repeating: "=", count: (4 - base.count % 4) % 4)),
              encodeURL(data) == string else { return nil }
        return data
    }
    private static func validKey(_ key: String) -> Bool {
        guard key.utf8.count == 44, let data = Data(base64Encoded: key), data.count == 32 else { return false }
        return data.base64EncodedString() == key
    }
    private static func body(key: String, challenge: String, attestation: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["v": "djc-rendezvous/1", "key_id": key,
            "challenge_id": challenge, "attestation": attestation], options: [.sortedKeys, .withoutEscapingSlashes])
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, key, phase, window, lastObservedMS, challenge, nonce, nonceHash, request, requestHash
    }
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(Int.self, forKey: .schemaVersion) == 1 else { throw RendezvousRegistrationJournal.Failure.invalidData }
        id = try c.decode(UUID.self, forKey: .id)
        key = try c.decode(String.self, forKey: .key)
        phase = try c.decode(RendezvousRegistrationJournal.Phase.self, forKey: .phase)
        window = try c.decode(RendezvousRetryWindow.self, forKey: .window)
        lastObservedMS = try c.decode(Int64.self, forKey: .lastObservedMS)
        challenge = try c.decodeIfPresent(String.self, forKey: .challenge)
        nonce = try c.decodeIfPresent(Data.self, forKey: .nonce)
        nonceHash = try c.decodeIfPresent(Data.self, forKey: .nonceHash)
        request = try c.decodeIfPresent(Data.self, forKey: .request)
        requestHash = try c.decodeIfPresent(Data.self, forKey: .requestHash)
        guard Self.validKey(key), window.kind == .registration,
              window.deadlineMS <= 9_007_199_254_740_991,
              lastObservedMS >= window.startedAtMS else { throw RendezvousRegistrationJournal.Failure.invalidData }
        if phase == .prepared {
            guard !window.isClosed, lastObservedMS < window.deadlineMS,
                  let challenge, Self.decodeURL(challenge)?.count == 32,
                  let nonce, nonce.count == 32, nonceHash == Self.hash(nonce),
                  let request, !request.isEmpty, request.count <= 65_536, requestHash == Self.hash(request),
                  let object = try JSONSerialization.jsonObject(with: request) as? [String: String],
                  Set(object.keys) == Set(["v", "key_id", "challenge_id", "attestation"]),
                  object["v"] == "djc-rendezvous/1", object["key_id"] == key,
                  object["challenge_id"] == challenge, let encoded = object["attestation"],
                  let attestation = Self.decodeURL(encoded), !attestation.isEmpty, attestation.count <= 32_768,
                  request == (try Self.body(key: key, challenge: challenge, attestation: encoded)) else {
                throw RendezvousRegistrationJournal.Failure.invalidData
            }
        } else {
            guard challenge == nil, nonce == nil, nonceHash == nil, request == nil, requestHash == nil,
                  window.isClosed || lastObservedMS >= window.deadlineMS else { throw RendezvousRegistrationJournal.Failure.invalidData }
            if phase == .completed {
                guard window.isClosed, window.callsStarted > 0, window.reservation == nil else { throw RendezvousRegistrationJournal.Failure.invalidData }
            }
        }
    }
}
