import CryptoKit
import Foundation

/// Install-local exact-byte accounting. A reservation is persisted before each
/// SDK/HTTP effect; restoring an interrupted effect never authorizes replay.
/// Callers also hold the complete per-key FIFO and their current owner fences.
public actor RendezvousSubmissionJournal {
    public static let shared = RendezvousSubmissionJournal(storage: RendezvousRepairKeychainStorage(
        service: RendezvousBuildProfile.storageNamespace + ".submit", account: "submission-v1"))
    public enum Failure: Error, Sendable { case invalidMaterial, invalidData, occupied, unavailable, staleClock }
    public enum Phase: String, Codable, Sendable {
        case readyToSign, signing, prepared, submitting, accepted, uncertain, expired
    }
    public struct Snapshot: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        public let identifier: UUID
        public let phase: Phase
        public let deadlineMS: Int64
        public var description: String { "RendezvousSubmission(redacted)" }
        public var debugDescription: String { description }
    }
    public struct AssertionCall: Sendable {
        public let reservation: UUID
        public let keyIdentifier: String
        public let clientDataHash: Data
        public let deadlineMS: Int64
    }
    public struct Submission: Sendable {
        public let reservation: UUID
        public let body: Data
    }
    private let storage: any RendezvousRepairStorage
    init(storage: any RendezvousRepairStorage) { self.storage = storage.claimingJournalOwner(UUID()) }

    /// Check before allocating a fresh server challenge. An interrupted operation
    /// must not spend more challenges simply because the user scans again.
    public func requireAvailable(appContext: Data, at nowMS: Int64) throws {
        guard appContext.count == 32, nowMS >= 0 else { throw Failure.invalidMaterial }
        guard var old = try read() else { return }
        guard old.context == appContext else { throw Failure.invalidMaterial }
        try old.observe(nowMS); try persist(old)
        guard old.phase == .accepted || old.phase == .expired else { throw Failure.occupied }
    }

    public func begin(keyIdentifier: String, qr: DJConnectRendezvousQR,
                      challenge: DJConnectRendezvousSubmitChallenge,
                      envelope: DJConnectRendezvousDestination.Envelope,
                      appContext: Data, at nowMS: Int64) throws -> UUID {
        guard RendezvousAppKeyOperations.initialEnrollmentLease == nil,
              nowMS >= 0, appContext.count == 32, qr.isCurrent(at: nowMS),
              challenge.isCurrent(at: nowMS) else { throw Failure.invalidMaterial }
        if var old = try read() {
            guard old.context == appContext else { throw Failure.invalidMaterial }
            try old.observe(nowMS)
            try persist(old)
            // Unknown/unfinished work blocks fresh signing until the ORIGINAL
            // deadline. A fresh scan does not reset the interrupted operation.
            guard old.phase == .accepted || old.phase == .expired else { throw Failure.occupied }
        }
        let record = try Record(key: keyIdentifier, qr: qr, challenge: challenge,
                                envelope: envelope, context: appContext, now: nowMS)
        try persist(record)
        return record.id
    }

    public func snapshot(at nowMS: Int64) throws -> Snapshot? {
        guard var record = try read() else { return nil }
        try record.observe(nowMS); try persist(record)
        return .init(identifier: record.id, phase: record.phase, deadlineMS: record.deadline)
    }

    public func reserveAssertion(_ id: UUID, appContext: Data, at nowMS: Int64) throws -> AssertionCall {
        try mutate(id, context: appContext, now: nowMS) { record in
            guard record.phase == .readyToSign, let bytes = record.clientData else { throw Failure.unavailable }
            let reservation = UUID()
            record.phase = .signing; record.reservation = reservation
            return .init(reservation: reservation, keyIdentifier: record.key,
                         clientDataHash: Data(SHA256.hash(data: bytes)), deadlineMS: record.deadline)
        }
    }

    public func completeAssertion(_ id: UUID, reservation: UUID, proof: Data?,
                                  appContext: Data, at nowMS: Int64) throws {
        try mutate(id, context: appContext, now: nowMS) { record in
            guard record.phase == .signing, record.reservation == reservation else { throw Failure.unavailable }
            guard let proof, !proof.isEmpty, proof.count <= 4096 else {
                record.finish(.uncertain)
                throw Failure.invalidMaterial
            }
            guard let clientData = record.clientData, let capability = record.capability,
                  let envelope = record.envelope else { throw Failure.invalidData }
            let body = try JSONSerialization.data(withJSONObject: [
                "v": "djc-rendezvous/1", "transaction_id": record.transaction,
                "generation": record.generation, "qr_capability": capability,
                "key_id": record.key, "challenge_id": record.challenge,
                "client_data": Self.encode(clientData), "assertion": Self.encode(proof),
                "destination_envelope": envelope], options: [.sortedKeys])
            guard body.count <= 32768 else { throw Failure.invalidMaterial }
            record.request = body; record.requestHash = Data(SHA256.hash(data: body))
            record.phase = .prepared; record.reservation = nil
        }
    }

    public func reserveSubmission(_ id: UUID, appContext: Data, at nowMS: Int64) throws -> Submission {
        try mutate(id, context: appContext, now: nowMS) { record in
            guard record.phase == .prepared, let body = record.request else { throw Failure.unavailable }
            let reservation = UUID()
            record.phase = .submitting; record.reservation = reservation
            return .init(reservation: reservation, body: body)
        }
    }

    /// accepted means only the independently validated historical API202. It
    /// never means browser consume, TV navigation or Home Assistant consent.
    public func completeSubmission(_ id: UUID, reservation: UUID, accepted: Bool,
                                   appContext: Data, at nowMS: Int64) throws {
        try mutate(id, context: appContext, now: nowMS) { record in
            guard record.phase == .submitting, record.reservation == reservation else { throw Failure.unavailable }
            record.finish(accepted ? .accepted : .uncertain)
        }
    }

    private func mutate<Value>(_ id: UUID, context: Data, now: Int64,
                               body: (inout Record) throws -> Value) throws -> Value {
        guard var record = try read(), record.id == id, record.context == context else { throw Failure.unavailable }
        try record.observe(now)
        let result = Result { try body(&record) }
        try persist(record)
        return try result.get()
    }
    private func read() throws -> Record? {
        guard let data = try storage.read() else { return nil }
        guard !data.isEmpty, data.count <= 65536 else { throw Failure.invalidData }
        do {
            let record = try JSONDecoder().decode(Record.self, from: data)
            try record.validate()
            return record
        } catch { throw Failure.invalidData }
    }
    private func persist(_ record: Record) throws {
        try record.validate()
        let data = try JSONEncoder().encode(record)
        guard data.count <= 65536 else { throw Failure.invalidData }
        try storage.write(data)
    }
    private static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private static func decode(_ text: String) -> Data? {
        guard let data = Data(base64Encoded: text.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/") + String(repeating: "=", count: (4-text.count%4)%4)),
              encode(data) == text else { return nil }
        return data
    }

    private struct Record: Codable {
        var version = 1
        var id = UUID()
        let context: Data
        let key: String
        let transaction: String
        let generation: Int64
        let thumbprint: String
        let challenge: String
        let started: Int64
        let deadline: Int64
        var observed: Int64
        var phase = Phase.readyToSign
        var reservation: UUID?
        var capability: String?
        var envelope: String?
        var clientData: Data?
        var request: Data?
        var requestHash: Data?

        init(key: String, qr: DJConnectRendezvousQR, challenge: DJConnectRendezvousSubmitChallenge,
             envelope: DJConnectRendezvousDestination.Envelope, context: Data, now: Int64) throws {
            self.context = context; self.key = key; transaction = qr.transactionID
            generation = qr.generation; thumbprint = qr.browserKeyThumbprint
            self.challenge = challenge.identifier; started = now; observed = now
            deadline = challenge.expiresAtMS; capability = qr.capability
            self.envelope = envelope.compact
            clientData = RendezvousSubmissionJournal.decode(challenge.originalClientData)
            guard deadline <= qr.expiresAtMS,
                  envelope.digest == RendezvousSubmissionJournal.encode(Data(SHA256.hash(data: Data(envelope.compact.utf8)))),
                  clientData.map({Data(SHA256.hash(data:$0))}) == challenge.clientDataHash else { throw Failure.invalidMaterial }
            try validate()
        }
        mutating func observe(_ now: Int64) throws {
            guard now >= observed else { throw Failure.staleClock }
            observed = now
            if now >= deadline { finish(.expired) }
        }
        mutating func finish(_ value: Phase) {
            phase = value; reservation = nil
            capability = nil; envelope = nil; clientData = nil; request = nil; requestHash = nil
        }
        func validate() throws {
            func require(_ valid: Bool) throws { if !valid { throw Failure.invalidData } }
            try require(version == 1 && context.count == 32 && started >= 0 && observed >= started &&
                deadline > started && deadline-started <= 120000 && deadline <= 9_007_199_254_740_991)
            try require(DJConnectRendezvousSubmitChallenge.canonicalKeyID(key) &&
                DJConnectRendezvousQR.canonicalToken(thumbprint) && DJConnectRendezvousQR.canonicalToken(challenge))
            try require((1...2_147_483_647).contains(generation) && transaction.range(of:
                #"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#,
                options: .regularExpression) != nil && transaction.utf8.count == 36)
            if [.accepted, .uncertain, .expired].contains(phase) {
                try require(reservation == nil && capability == nil && envelope == nil && clientData == nil && request == nil && requestHash == nil)
                if phase == .expired { try require(observed >= deadline) }
                else { try require(observed < deadline) }
                return
            }
            try require(observed < deadline)
            try require((phase == .signing || phase == .submitting) == (reservation != nil))
            guard let capability, let envelope, let clientData else { throw Failure.invalidData }
            try require(DJConnectRendezvousQR.canonicalToken(capability) && !envelope.isEmpty &&
                        envelope.utf8.count <= 8192 && envelope.utf8.allSatisfy({$0 < 128}) &&
                        !clientData.isEmpty && clientData.count <= 2048)
            let fields = try RendezvousFlatJSON.parse(clientData, maximumBytes: 2048)
            guard case let .string(nonce)? = fields["challenge"], DJConnectRendezvousQR.canonicalToken(nonce) else { throw Failure.invalidData }
            let digest = RendezvousSubmissionJournal.encode(Data(SHA256.hash(data: Data(envelope.utf8))))
            try require(fields == ["v":.string("djc-rendezvous/1"), "action":.string("submit"),
                "service_origin":.string(DJConnectRendezvousQR.serviceOrigin), "transaction_id":.string(transaction),
                "generation":.integer(generation), "browser_key_thumbprint":.string(thumbprint),
                "expires_at":.integer(deadline), "key_id":.string(key), "challenge_id":.string(challenge),
                "challenge":.string(nonce), "envelope_digest":.string(digest)])
            if phase == .prepared || phase == .submitting {
                guard let request, let requestHash else { throw Failure.invalidData }
                try require(request.count <= 32768 && Data(SHA256.hash(data:request)) == requestHash)
                let body = try RendezvousFlatJSON.parse(request, maximumBytes: 32768)
                guard case let .string(proof)? = body["assertion"], let bytes = RendezvousSubmissionJournal.decode(proof) else { throw Failure.invalidData }
                try require(!bytes.isEmpty && bytes.count <= 4096)
                try require(body == ["v":.string("djc-rendezvous/1"), "transaction_id":.string(transaction),
                    "generation":.integer(generation), "qr_capability":.string(capability), "key_id":.string(key),
                    "challenge_id":.string(challenge), "client_data":.string(RendezvousSubmissionJournal.encode(clientData)),
                    "assertion":.string(proof), "destination_envelope":.string(envelope)])
            } else { try require(request == nil && requestHash == nil) }
        }
    }
}
