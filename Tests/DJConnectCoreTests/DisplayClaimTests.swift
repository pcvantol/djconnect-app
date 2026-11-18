import Foundation
import Testing
@testable import DJConnectCore

private let bEpoch = String(repeating: "A", count: 43)
private let bStart = Date(timeIntervalSince1970: 1_800_000_000)
private func bResponse(_ changes: [String: Any] = [:]) throws -> Data {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var value: [String: Any] = ["success": true, "contract_version": 1,
        "claim_id": String(repeating: "B", count: 42) + "A",
        "browser_generation": String(repeating: "C", count: 42) + "A",
        "issuer_epoch": bEpoch, "expires_in": 119.5,
        "expires_at": formatter.string(from: bStart.addingTimeInterval(120))]
    changes.forEach { value[$0] = $1 }
    return try JSONSerialization.data(withJSONObject: value)
}
private func bClaim(_ changes: [String: Any] = [:]) throws -> DJConnectDisplayClaim {
    try .parse(bResponse(changes), code: "012345", expectedIssuerEpoch: bEpoch,
               requestedAt: bStart, requestedUptime: 100, now: bStart.addingTimeInterval(1), uptime: 101)
}

@Test func displayClaimOriginalWallAndMonotonicBounds() throws {
    let claim = try bClaim()
    #expect(claim.isCurrent(now: bStart.addingTimeInterval(119), uptime: 219))
    #expect(!claim.isCurrent(now: bStart.addingTimeInterval(120), uptime: 219))
    #expect(!claim.isCurrent(now: bStart.addingTimeInterval(2), uptime: 219.5))
    #expect(!claim.isCurrent(now: bStart, uptime: 102))
    #expect(!claim.isCurrent(now: bStart.addingTimeInterval(2), uptime: 99))
    #expect(!claim.isCurrent(now: bStart.addingTimeInterval(2), uptime: .infinity))
    #expect(!claim.isCurrent(now: Date(timeIntervalSince1970: .nan), uptime: 102))
}

@Test func displayClaimRejectsMalformedAuthorityAndLifetime() throws {
    for change: [String: Any] in [
        ["success": false], ["contract_version": 2], ["contract_version": true],
        ["claim_id": "unsafe"], ["browser_generation": ""], ["issuer_epoch": String(repeating: "D", count: 43)],
        ["expires_in": 0], ["expires_in": -1], ["expires_in": 121], ["expires_in": true],
        ["expires_at": "invalid"], ["expires_at": "2027-01-01T00:00:00.000Z"]
    ] {
        #expect(throws: (any Error).self) { try bClaim(change) }
    }
    for code in ["12345", "1234567", "１２３４５６", "12345\n"] {
        #expect(throws: (any Error).self) {
            try DJConnectDisplayClaim.parse(bResponse(), code: code, expectedIssuerEpoch: bEpoch,
                requestedAt: bStart, requestedUptime: 100, now: bStart, uptime: 100)
        }
    }
    #expect(throws: (any Error).self) {
        try DJConnectDisplayClaim.parse(bResponse(), code: "012345", expectedIssuerEpoch: bEpoch,
            requestedAt: bStart, requestedUptime: 100, now: bStart.addingTimeInterval(5), uptime: 220)
    }
}

@Test func displayClaimApprovalHasExactConsentAndOriginalBinding() throws {
    let claim = try bClaim()
    let identity = DJConnectIdentity(deviceID: "synthetic-ios", deviceName: "Synthetic", clientType: .ios, firmware: "test", platform: .ios)
    let bytes = try claim.approvalBody(identity: identity, sessionID: "session-original", currentIssuerEpoch: bEpoch,
        share: .createTwoHours, now: bStart.addingTimeInterval(2), uptime: 102)
    let body = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect(Set(body.keys) == ["contract_version", "identity", "session_id", "issuer_epoch", "claim_id", "browser_generation", "code", "share"])
    #expect(body["code"] as? String == "012345")
    #expect(body["claim_id"] as? String == claim.claimID)
    #expect(body["browser_generation"] as? String == claim.browserGeneration)
    let share = try #require(body["share"] as? [String: Any])
    #expect(Set(share.keys) == ["mode", "consent", "lifetime_seconds"])
    #expect(share["consent"] as? Bool == true)
    #expect(share["lifetime_seconds"] as? Int == 7200)
    let existing = try claim.approvalBody(identity: identity, sessionID: "session-original", currentIssuerEpoch: bEpoch,
        share: .existing(id: bEpoch, generation: 2), now: bStart.addingTimeInterval(2), uptime: 102)
    let existingBody = try #require(JSONSerialization.jsonObject(with: existing) as? [String: Any])
    let existingShare = try #require(existingBody["share"] as? [String: Any])
    #expect(Set(existingShare.keys) == ["mode", "share_id", "share_generation"])
    #expect(existingShare["share_generation"] as? Int == 2)
    for badShare: DJConnectDisplayClaim.Share in [.existing(id: "bad", generation: 1), .existing(id: bEpoch, generation: 0)] {
        #expect(throws: (any Error).self) {
            try claim.approvalBody(identity: identity, sessionID: "session-original", currentIssuerEpoch: bEpoch,
                share: badShare, now: bStart.addingTimeInterval(2), uptime: 102)
        }
    }
    for badSession in ["", " changed ", "session\n", String(repeating: "s", count: 129)] {
        #expect(throws: (any Error).self) {
            try claim.approvalBody(identity: identity, sessionID: badSession, currentIssuerEpoch: bEpoch,
                share: .createTwoHours, now: bStart.addingTimeInterval(2), uptime: 102)
        }
    }
    #expect(throws: (any Error).self) {
        try claim.approvalBody(identity: identity, sessionID: "session-original", currentIssuerEpoch: "changed",
            share: .createTwoHours, now: bStart.addingTimeInterval(2), uptime: 102)
    }
    #expect(throws: (any Error).self) {
        try claim.approvalBody(identity: identity, sessionID: "session-original", currentIssuerEpoch: bEpoch,
            share: .createTwoHours, now: bStart.addingTimeInterval(120), uptime: 220)
    }
}

// Core8b protected actual isolated-HA fixture; identifiers are its published
// nonfunctional replacements. This is parser evidence, not a new HA execution.
@Test func displayClaimAcceptsReleasedCoreResolveFixture() throws {
    let bytes = Data(#"{"success":true,"contract_version":1,"claim_id":"-QzCBTkjWnJGiCZRHxBAKELEi-x5WSgaDc6Kz2abltc","browser_generation":"W0OBrbMviGcawZZJm5NZVAYqYVkWZV0gjyZjnHQhUU4","issuer_epoch":"FYrt5jgIX3fcPYyWqII3Q4J56CCi6fmel5j9tvvd7bc","expires_in":119.99859120800102,"expires_at":"2026-10-16T22:48:43.631947+00:00"}"#.utf8)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let requested = try #require(formatter.date(from: "2026-10-16T22:46:43.634000+00:00"))
    let claim = try DJConnectDisplayClaim.parse(bytes, code: "000000",
        expectedIssuerEpoch: "FYrt5jgIX3fcPYyWqII3Q4J56CCi6fmel5j9tvvd7bc",
        requestedAt: requested, requestedUptime: 100, now: requested.addingTimeInterval(0.1), uptime: 100.1)
    #expect(claim.claimID == "-QzCBTkjWnJGiCZRHxBAKELEi-x5WSgaDc6Kz2abltc")
    #expect(!claim.isCurrent(now: requested.addingTimeInterval(120), uptime: 220))
}
