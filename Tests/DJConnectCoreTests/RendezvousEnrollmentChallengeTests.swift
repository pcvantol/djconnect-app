import Foundation
import Testing
@testable import DJConnectCore

@Test func rendezvousEnrollmentChallengeDoesNotRestartOriginalDeadline() throws {
    let token = String(repeating:"A",count:43)
    let object: [String:Any] = ["v":"djc-rendezvous/1","challenge_id":token,"challenge":token,"expires_at":121000]
    let data = try JSONSerialization.data(withJSONObject:object)
    let challenge = try DJConnectRendezvousEnrollmentChallenge.parse(data,requestedAtMS:1000,requestedUptime:10,nowMS:2000,uptime:11)
    #expect(challenge.nonce == Data(repeating:0,count:32))
    #expect(challenge.expiresAtMS == 121000)
    #expect(challenge.isCurrent(at:2001,uptime:11.1))
    #expect(!challenge.isCurrent(at:1999,uptime:11.1))
    #expect(!challenge.isCurrent(at:2001,uptime:130))
    #expect(!challenge.isCurrent(at:2001,uptime:9))
    #expect(throws:(any Error).self) {
        try DJConnectRendezvousEnrollmentChallenge.parse(data,requestedAtMS:1000,requestedUptime:10,nowMS:2000,uptime:130)
    }
    for mutation in ["121001", "9007199254740992", "true"] {
        let changed = Data(String(decoding:data,as:UTF8.self).replacingOccurrences(of:"121000",with:mutation).utf8)
        #expect(throws:(any Error).self) {
            try DJConnectRendezvousEnrollmentChallenge.parse(changed,requestedAtMS:1000,requestedUptime:10,nowMS:2000,uptime:11)
        }
    }
}
