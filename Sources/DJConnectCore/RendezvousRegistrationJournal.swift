import CryptoKit
import Foundation

/// Attestation/registration accounting only: no SDK, HTTP, key creation, endpoint selection or
/// active-key adoption. The caller must qualify the original app/key/nonce and
/// operation context before preparing, and again before sending returned bytes.
public actor RendezvousRegistrationJournal {
    public static let shared = RendezvousRegistrationJournal(storage: RendezvousRepairKeychainStorage(
        service: "dev.djconnect.rendezvous.enrollment", account: "prepared-registration-v1"
    ))
    public enum Phase: String, Codable, Sendable { case attestationPending, prepared, registrationUncertain, completed }
    public enum AttestationResult: Sendable {
        case received(Data), serverUnavailable, terminalFailure
    }
    public enum Failure: Error, Sendable { case invalidMaterial, invalidData, alreadyExists, missingState, wrongAttempt, unavailable }
    public struct Snapshot: Sendable {
        public let attemptIdentifier: UUID
        public let keyIdentifier: String
        public let deadlineMS: Int64
        public let phase: Phase
        public let callsStarted: Int
        public let reservation: UUID?
        public let attestationCallsStarted: Int
        public let attestationReservation: UUID?
    }
    public struct AttestationCall: Sendable {
        public let attemptIdentifier: UUID
        public let reservation: UUID
        public let keyIdentifier: String
        public let challengeIdentifier: String
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
    private static let maximumBytes = 98_304

    init(storage: any RendezvousRepairStorage) { self.storage = storage }

    /// The caller has already admitted this existing key and server challenge.
    /// Save their original binding before permitting any SDK invocation.
    public func beginAttestation(keyIdentifier: String, challengeIdentifier: String, nonce: Data,
                                 admittedAtMS: Int64, deadlineMS: Int64) async throws -> UUID {
        guard RendezvousAppKeyOperations.initialEnrollmentLease == nil else { throw Failure.unavailable }
        return try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:RendezvousAppKeyOperations.installationAdmissionSlot) {
            try await self.beginAttestationLocked(keyIdentifier:keyIdentifier,challengeIdentifier:challengeIdentifier,
                nonce:nonce,admittedAtMS:admittedAtMS,deadlineMS:deadlineMS)
        }
    }
    /// Only the initial adapter owns this one-shot exact attempt, before it
    /// invokes downstream enrollment. No descendant receives creation authority.
    func beginInitialAttestation(_ admission:RendezvousInitialRegistrationAdmission) throws -> UUID {
        try admission.consume { material in
            try refuseReplacement(at:material.admittedAtMS)
            let record = try RegistrationRecord(key:material.key,challenge:material.challenge.identifier,
                nonce:material.challenge.nonce,attestation:nil,startedAtMS:material.admittedAtMS,
                deadlineMS:material.challenge.expiresAtMS,identifier:material.identifier)
            try persist(record)
            return record.id
        }
    }
    private func beginAttestationLocked(keyIdentifier:String,challengeIdentifier:String,nonce:Data,
                                       admittedAtMS:Int64,deadlineMS:Int64) throws -> UUID {
        try refuseReplacement(at: admittedAtMS)
        let record = try RegistrationRecord(key: keyIdentifier, challenge: challengeIdentifier,
                                            nonce: nonce, attestation: nil,
                                            startedAtMS: admittedAtMS, deadlineMS: deadlineMS)
        try persist(record)
        return record.id
    }

    /// The returned hash is SHA256 of the original stored server nonce bytes.
    /// A restored in-flight reservation cannot authorize another SDK call.
    public func reserveAttestation(attemptIdentifier: UUID, at nowMS: Int64) throws -> AttestationCall {
        try mutate(attemptIdentifier, at: nowMS) { record in
            guard record.phase == .attestationPending, let hash = record.nonceHash, let challenge = record.challenge,
                  var sdk = record.attestationWindow else { throw Failure.unavailable }
            let reservation = try sdk.reserve(at: nowMS)
            record.attestationWindow = sdk
            return AttestationCall(attemptIdentifier: record.id, reservation: reservation,
                                   keyIdentifier: record.key, challengeIdentifier: challenge, deadlineMS: sdk.deadlineMS, clientDataHash: hash)
        }
    }

    /// Only serverUnavailable permits another same-key/hash SDK call. Receiving
    /// bounded proof saves the registration body once, within the original deadline.
    public func completeAttestation(attemptIdentifier: UUID, reservation: UUID,
                                    result: AttestationResult, at nowMS: Int64) throws {
        try mutate(attemptIdentifier, at: nowMS) { record in
            try record.completeAttestation(reservation, result: result, at: nowMS)
        }
    }

    /// Called after the original SDK attestation has been prepared. No prior
    /// attempt (including an uncertain/completed one) can be replaced here.
    public func prepare(keyIdentifier: String, challengeIdentifier: String, nonce: Data,
                        attestation: Data, admittedAtMS: Int64, deadlineMS: Int64) async throws -> UUID {
        guard RendezvousAppKeyOperations.initialEnrollmentLease == nil else { throw Failure.unavailable }
        return try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:RendezvousAppKeyOperations.installationAdmissionSlot) {
            try await self.prepareLocked(keyIdentifier:keyIdentifier,challengeIdentifier:challengeIdentifier,
                nonce:nonce,attestation:attestation,admittedAtMS:admittedAtMS,deadlineMS:deadlineMS)
        }
    }
    private func prepareLocked(keyIdentifier:String,challengeIdentifier:String,nonce:Data,attestation:Data,
                               admittedAtMS:Int64,deadlineMS:Int64) throws -> UUID {
        try refuseReplacement(at: admittedAtMS)
        let record = try RegistrationRecord(key: keyIdentifier, challenge: challengeIdentifier,
                                            nonce: nonce, attestation: attestation,
                                            startedAtMS: admittedAtMS, deadlineMS: deadlineMS)
        try persist(record)
        return record.id
    }

    private func refuseReplacement(at nowMS: Int64) throws {
        if var existing = try read() {
            try existing.observeAndExpire(at: nowMS)
            try persist(existing)
            throw Failure.alreadyExists
        }
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
    private let schemaVersion = 2
    // Required in v2: missing SDK accounting is only valid for an explicitly
    // imported, already prepared record (including a migrated v1 record).
    private enum Admission: String, Codable { case preparedImport, trackedAttestation }
    private let admission: Admission
    let id: UUID
    let key: String
    var phase: RendezvousRegistrationJournal.Phase = .prepared
    var window: RendezvousRetryWindow
    var attestationWindow: RendezvousRetryWindow?
    private var lastObservedMS: Int64
    fileprivate var challenge: String?
    private var nonce: Data?
    fileprivate var nonceHash: Data?
    fileprivate var request: Data?
    private var requestHash: Data?

    init(key: String, challenge: String, nonce: Data, attestation: Data?,
         startedAtMS: Int64, deadlineMS: Int64, identifier:UUID = UUID()) throws {
        guard Self.validKey(key), Self.decodeURL(challenge)?.count == 32, nonce.count == 32,
              attestation.map({ !$0.isEmpty && $0.count <= 32_768 }) ?? true,
              deadlineMS <= 9_007_199_254_740_991 else { throw RendezvousRegistrationJournal.Failure.invalidMaterial }
        id = identifier
        self.key = key
        self.challenge = challenge
        self.nonce = nonce
        nonceHash = Self.hash(nonce)
        admission = attestation == nil ? .trackedAttestation : .preparedImport
        if let attestation {
            request = try Self.body(key: key, challenge: challenge, attestation: Self.encodeURL(attestation))
            requestHash = Self.hash(request!)
        } else {
            phase = .attestationPending
            attestationWindow = try RendezvousRetryWindow(kind: .appleAttestation, startedAtMS: startedAtMS, deadlineMS: deadlineMS)
        }
        window = try RendezvousRetryWindow(kind: .registration, startedAtMS: startedAtMS, deadlineMS: deadlineMS)
        lastObservedMS = startedAtMS
    }

    var snapshot: RendezvousRegistrationJournal.Snapshot {
        .init(attemptIdentifier: id, keyIdentifier: key, deadlineMS: window.deadlineMS,
              phase: phase, callsStarted: window.callsStarted, reservation: window.reservation,
              attestationCallsStarted: attestationWindow?.callsStarted ?? 0,
              attestationReservation: attestationWindow?.reservation)
    }

    mutating func completeAttestation(_ reservation: UUID, result: RendezvousRegistrationJournal.AttestationResult,
                                      at nowMS: Int64) throws {
        guard phase == .attestationPending, var sdk = attestationWindow else {
            throw RendezvousRegistrationJournal.Failure.unavailable
        }
        let outcome: RendezvousRetryWindow.Outcome
        let proof: Data?
        var invalidProof = false
        switch result {
        case .received(let data):
            invalidProof = data.isEmpty || data.count > 32_768
            outcome = invalidProof ? .terminalFailure : .succeeded
            proof = invalidProof ? nil : data
        case .serverUnavailable: outcome = .appleServerUnavailable; proof = nil
        case .terminalFailure: outcome = .terminalFailure; proof = nil
        }
        try sdk.complete(reservation, outcome: outcome, at: nowMS)
        // Construct before changing phase/accounting, so a failed construction
        // never leaves a partially prepared record.
        if let proof, let challenge {
            let bytes = try Self.body(key: key, challenge: challenge, attestation: Self.encodeURL(proof))
            request = bytes
            requestHash = Self.hash(bytes)
            phase = .prepared
        } else if sdk.isClosed {
            finish(as: .registrationUncertain)
        }
        attestationWindow = sdk
        if invalidProof { throw RendezvousRegistrationJournal.Failure.invalidMaterial }
    }

    mutating func observeAndExpire(at nowMS: Int64) throws {
        guard nowMS >= lastObservedMS else { throw RendezvousRegistrationJournal.Failure.invalidData }
        lastObservedMS = nowMS
        if phase == .prepared || phase == .attestationPending,
           nowMS >= window.deadlineMS { finish(as: .registrationUncertain) }
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
        case schemaVersion, admission, id, key, phase, window, attestationWindow, lastObservedMS, challenge, nonce, nonceHash, request, requestHash
    }
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 || version == 2 else { throw RendezvousRegistrationJournal.Failure.invalidData }
        admission = version == 1 ? .preparedImport : try c.decode(Admission.self, forKey: .admission)
        attestationWindow = try c.decodeIfPresent(RendezvousRetryWindow.self, forKey: .attestationWindow)
        guard version != 1 || (!c.contains(.attestationWindow) && !c.contains(.admission)) else {
            throw RendezvousRegistrationJournal.Failure.invalidData
        }
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
              lastObservedMS >= window.observedAtMS else { throw RendezvousRegistrationJournal.Failure.invalidData }
        if admission == .trackedAttestation {
            guard let sdk = attestationWindow, sdk.kind == .appleAttestation,
                  sdk.startedAtMS == window.startedAtMS, sdk.deadlineMS == window.deadlineMS,
                  lastObservedMS >= sdk.observedAtMS else { throw RendezvousRegistrationJournal.Failure.invalidData }
            if phase == .attestationPending {
                guard !sdk.isClosed, window.callsStarted == 0, !window.isClosed else {
                    throw RendezvousRegistrationJournal.Failure.invalidData
                }
            } else if phase == .prepared || phase == .completed || window.callsStarted > 0 {
                guard sdk.isClosed, sdk.callsStarted > 0, sdk.reservation == nil else {
                    throw RendezvousRegistrationJournal.Failure.invalidData
                }
            }
        } else {
            guard attestationWindow == nil, phase != .attestationPending else { throw RendezvousRegistrationJournal.Failure.invalidData }
        }
        if phase == .prepared || phase == .attestationPending {
            guard !window.isClosed, lastObservedMS < window.deadlineMS,
                  let challenge, Self.decodeURL(challenge)?.count == 32,
                  let nonce, nonce.count == 32, nonceHash == Self.hash(nonce) else {
                throw RendezvousRegistrationJournal.Failure.invalidData
            }
            if phase == .attestationPending {
                guard request == nil, requestHash == nil else { throw RendezvousRegistrationJournal.Failure.invalidData }
            } else {
                guard let request, !request.isEmpty, request.count <= 65_536, requestHash == Self.hash(request),
                  let object = try JSONSerialization.jsonObject(with: request) as? [String: String],
                  Set(object.keys) == Set(["v", "key_id", "challenge_id", "attestation"]),
                  object["v"] == "djc-rendezvous/1", object["key_id"] == key,
                  object["challenge_id"] == challenge, let encoded = object["attestation"],
                  let attestation = Self.decodeURL(encoded), !attestation.isEmpty, attestation.count <= 32_768,
                  request == (try Self.body(key: key, challenge: challenge, attestation: encoded)) else {
                throw RendezvousRegistrationJournal.Failure.invalidData
                }
            }
        } else {
            guard challenge == nil, nonce == nil, nonceHash == nil, request == nil, requestHash == nil,
                  window.isClosed || attestationWindow?.isClosed == true || lastObservedMS >= window.deadlineMS else {
                throw RendezvousRegistrationJournal.Failure.invalidData
            }
            if phase == .completed {
                guard window.isClosed, window.callsStarted > 0, window.reservation == nil else { throw RendezvousRegistrationJournal.Failure.invalidData }
            }
        }
    }
}


/// The adapter retains this capability; it is never passed to a callback/task.
/// Its only use consumes one exact key/challenge/nonce/deadline/attempt tuple.
final class RendezvousInitialRegistrationAdmission:@unchecked Sendable {
    struct Material:Sendable {
        let identifier:UUID
        let key:String
        let challenge:DJConnectRendezvousEnrollmentChallenge
        let admittedAtMS:Int64
    }
    private let lock = NSLock()
    private var consumed = false
    private let material:Material
    private let qr:DJConnectRendezvousQR
    init(key:String,challenge:DJConnectRendezvousEnrollmentChallenge,qr:DJConnectRendezvousQR,at nowMS:Int64) {
        material = .init(identifier:UUID(),key:key,challenge:challenge,admittedAtMS:nowMS); self.qr = qr
    }
    func consume<Value>(operation:(Material)throws->Value) throws -> Value {
        try lock.withLock {
            guard !consumed,!Task.isCancelled,qr.isCurrent(),material.challenge.isCurrent(),
                  DJConnectRendezvousSubmitChallenge.canonicalKeyID(material.key) else {
                throw RendezvousRegistrationJournal.Failure.unavailable
            }
            consumed = true // Failed/uncertain persistence never grants a replay.
            return try operation(material)
        }
    }
}
