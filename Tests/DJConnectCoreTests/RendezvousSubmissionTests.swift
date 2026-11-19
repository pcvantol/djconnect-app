import CryptoKit
import Foundation
import Testing
@testable import DJConnectCore

func submissionNow() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
func submissionB64(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
struct SubmissionFixture {
    let now = submissionNow()
    let context = Data(repeating: 9, count: 32)
    let key = Data(repeating: 7, count: 32).base64EncodedString()
    let qr: DJConnectRendezvousQR
    let envelope: DJConnectRendezvousDestination.Envelope
    let challenge: DJConnectRendezvousSubmitChallenge
    let original: Data
    let response: Data
    init(transaction: String = "00000000-0000-4000-8000-000000000001") throws {
        let expiry = now + 90000, token = String(repeating: "A", count: 43)
        let operation = submissionB64(Data(SHA256.hash(data: Data(transaction.utf8))))
        let qrBytes = try JSONSerialization.data(withJSONObject: ["type":"djc-rendezvous-qr", "v":"djc-rendezvous/1",
            "service_origin":DJConnectRendezvousQR.serviceOrigin, "transaction_id":transaction,
            "generation":1, "expires_at":expiry, "browser_key_thumbprint":token, "qr_capability":token])
        qr = try DJConnectRendezvousQR.parse(String(decoding:qrBytes,as:UTF8.self))
        let compact = "synthetic.envelope.only.for.accounting"
        envelope = .init(compact:compact,digest:submissionB64(Data(SHA256.hash(data:Data(compact.utf8)))))
        let fields = try JSONSerialization.data(withJSONObject: ["v":"djc-rendezvous/1", "action":"submit",
            "service_origin":DJConnectRendezvousQR.serviceOrigin, "transaction_id":qr.transactionID,
            "generation":1, "browser_key_thumbprint":token, "expires_at":expiry, "key_id":key,
            "challenge_id":operation, "challenge":token, "envelope_digest":envelope.digest],options:[.sortedKeys])
        original = Data((" \n"+String(decoding:fields,as:UTF8.self)+"\t").utf8)
        response = try JSONSerialization.data(withJSONObject:["v":"djc-rendezvous/1", "challenge_id":operation,
            "challenge":token, "expires_at":expiry, "client_data":submissionB64(original)])
        challenge = try .parse(response,qr:qr,keyID:key,envelopeDigest:envelope.digest,
                               requestedAtMS:now,requestedUptime:ProcessInfo.processInfo.systemUptime)
    }
    func begin(_ journal: RendezvousSubmissionJournal) async throws -> UUID {
        try await journal.begin(keyIdentifier:key,qr:qr,challenge:challenge,envelope:envelope,
                                appContext:context,at:submissionNow())
    }
}
final class SubmissionStore: RendezvousRepairStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var count = 0
    var failAt: Int?
    var commitBeforeFailure = false
    func read() throws -> Data? { lock.withLock { data } }
    func write(_ value: Data) throws {
        try lock.withLock {
            count += 1
            if count == failAt {
                if commitBeforeFailure { data = value }
                throw URLError(.cannotWriteToFile)
            }
            data = value
        }
    }
}

@Suite(.serialized) struct RendezvousSubmissionTests {
    @Test func originalBytesAreSignedOnceAndPreparedBodySurvivesRestore() async throws {
        let fixture = try SubmissionFixture(), store = SubmissionStore()
        let journal = RendezvousSubmissionJournal(storage:store)
        let id = try await fixture.begin(journal)
        let call = try await journal.reserveAssertion(id,appContext:fixture.context,at:submissionNow())
        #expect(call.clientDataHash == Data(SHA256.hash(data:fixture.original)))
        await #expect(throws:(any Error).self) {
            try await RendezvousSubmissionJournal(storage:store).reserveAssertion(id,appContext:fixture.context,at:submissionNow())
        }
        try await journal.completeAssertion(id,reservation:call.reservation,proof:Data([1,2,3]),appContext:fixture.context,at:submissionNow())
        let restored = RendezvousSubmissionJournal(storage:store)
        let request = try await restored.reserveSubmission(id,appContext:fixture.context,at:submissionNow())
        let body = try #require(JSONSerialization.jsonObject(with:request.body) as? [String:Any])
        #expect(body["client_data"] as? String == submissionB64(fixture.original))
        #expect(body["destination_envelope"] as? String == fixture.envelope.compact)
        #expect(Set(body.keys) == ["v","transaction_id","generation","qr_capability","key_id","challenge_id","client_data","assertion","destination_envelope"])
        await #expect(throws:(any Error).self) {
            try await restored.reserveSubmission(id,appContext:fixture.context,at:submissionNow())
        }
        try await restored.completeSubmission(id,reservation:request.reservation,accepted:true,appContext:fixture.context,at:submissionNow())
        let stored = try store.read()
        let saved = try #require(stored)
        #expect(!String(decoding:saved,as:UTF8.self).contains("synthetic.envelope"))
        #expect(try await restored.snapshot(at:submissionNow())?.phase == .accepted)
    }

    @Test(arguments:[false,true]) func uncertainReservationWriteCannotAuthorizeSigning(committed:Bool) async throws {
        let fixture = try SubmissionFixture(), store = SubmissionStore()
        let journal = RendezvousSubmissionJournal(storage:store)
        let id = try await fixture.begin(journal)
        store.failAt = 2; store.commitBeforeFailure = committed
        await #expect(throws:(any Error).self) {
            try await journal.reserveAssertion(id,appContext:fixture.context,at:submissionNow())
        }
        store.failAt = nil
        let phase = try await RendezvousSubmissionJournal(storage:store).snapshot(at:submissionNow())?.phase
        #expect(phase == (committed ? .signing : .readyToSign))
        // The failed call returned no SDK material in either case. A committed
        // reservation also blocks a second call after restart.
        if committed {
            await #expect(throws:(any Error).self) {
                try await journal.reserveAssertion(id,appContext:fixture.context,at:submissionNow())
            }
        }
    }

    @Test func unknownWorkBlocksFreshScanUntilOriginalDeadlineAndRejectsClockRollback() async throws {
        let fixture = try SubmissionFixture(), journal = RendezvousSubmissionJournal(storage:SubmissionStore())
        let id = try await fixture.begin(journal)
        let call = try await journal.reserveAssertion(id,appContext:fixture.context,at:submissionNow())
        await #expect(throws:(any Error).self) {
            try await journal.completeAssertion(id,reservation:call.reservation,proof:nil,appContext:fixture.context,at:submissionNow())
        }
        await #expect(throws:(any Error).self) { try await fixture.begin(journal) }
        #expect(try await journal.snapshot(at:fixture.challenge.expiresAtMS)?.phase == .expired)
        await #expect(throws:(any Error).self) { try await journal.snapshot(at:fixture.now) }
    }

    @Test(arguments:[0,4097]) func invalidProofNeverProducesSubmission(size:Int) async throws {
        let fixture = try SubmissionFixture(), journal = RendezvousSubmissionJournal(storage:SubmissionStore())
        let id = try await fixture.begin(journal)
        let call = try await journal.reserveAssertion(id,appContext:fixture.context,at:submissionNow())
        await #expect(throws:(any Error).self) {
            try await journal.completeAssertion(id,reservation:call.reservation,proof:Data(repeating:1,count:size),appContext:fixture.context,at:submissionNow())
        }
        await #expect(throws:(any Error).self) {
            try await journal.reserveSubmission(id,appContext:fixture.context,at:submissionNow())
        }
    }

    @Test func changedPolicyContextCannotUseOrReplaceAnExistingRecord() async throws {
        let fixture = try SubmissionFixture(), journal = RendezvousSubmissionJournal(storage:SubmissionStore())
        let id = try await fixture.begin(journal)
        await #expect(throws:(any Error).self) {
            try await journal.reserveAssertion(id,appContext:Data(repeating:8,count:32),at:submissionNow())
        }
        await #expect(throws:(any Error).self) {
            try await journal.begin(keyIdentifier:fixture.key,qr:fixture.qr,challenge:fixture.challenge,
                                    envelope:fixture.envelope,appContext:Data(repeating:8,count:32),at:submissionNow())
        }
    }
}
