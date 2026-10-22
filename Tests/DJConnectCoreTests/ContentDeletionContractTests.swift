import Foundation
import Testing
import CryptoKit
@testable import DJConnectCore

private func contentExamples() throws -> [String: Any] {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/content-deletion-core-58561f97.json")
    let bytes = try Data(contentsOf: path)
    #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() ==
        "7c062c4a5b944f3abfb5a8d419a1c5403eeaa842636f83c78821c1b979b3159c")
    return try #require((JSONSerialization.jsonObject(with: bytes) as? [String: Any])?["examples"] as? [String: Any])
}
private func contentDecode<T: Decodable>(_ value: Any, as: T.Type = T.self) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
}

@Test(arguments: ["ok", "owner", "target", "expiry", "lifetime", "unit", "disposition", "playback"])
func contentDeletePreviewRequiresExactServerScope(_ mutation: String) throws {
    var object = try #require(contentExamples()["prepare_response"] as? [String: Any])
    let original: DJConnectContentDeleteScope = try contentDecode(object)
    let now = try #require(DJConnectHistoryEntry.date(original.created_at)).addingTimeInterval(1)
    switch mutation {
    case "owner": object["owner_profile_id"] = "other"
    case "target": var t = object["target"] as! [String: Any]; t["target_id"] = "other"; object["target"] = t
    case "expiry": object["expires_at"] = original.created_at
    case "lifetime": object["expires_at"] = ISO8601DateFormatter().string(from: now.addingTimeInterval(400))
    case "unit": var u = object["unit"] as! [String: Any]; u["session_id"] = "other"; object["unit"] = u
    case "disposition": object["affected_entries"] = [["session_id": "s", "entry_id": "e", "disposition": "guess"]]
    case "playback": object["music_playback_undone"] = true
    default: break
    }
    let scope: DJConnectContentDeleteScope = try contentDecode(object)
    #expect(scope.admits(target: original.target, owner: "profile-a", at: now) == (mutation == "ok"))
    #expect(!DJConnectContentDeleteTarget(kind: "moment", sessionID: "", targetID: "m").isValid)
    #expect(DJConnectContentDeleteTarget(kind: "message", sessionID: "", targetID: "server-id").isValid)
}

@Test(arguments: ["ok", "owner", "operation", "confirmation", "digest", "unit", "entries", "messages", "unit_kind", "playback", "state"])
func contentDeleteReceiptBindsOriginalConfirmationBodyAndCascade(_ mutation: String) throws {
    let examples = try contentExamples()
    let scope: DJConnectContentDeleteScope = try contentDecode(try #require(examples["prepare_response"]))
    let wireRequest = try #require(examples["delete_request"] as? [String: Any])
    let identity = DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios,
        firmware: "4.0.0", platform: .ios)
    let request = DJConnectContentDeleteRequest(identity: identity, confirmationID: scope.confirmation_id,
        operationID: try #require(wireRequest["operation_id"] as? String))
    var object = try #require(examples["delete_response"] as? [String: Any])
    switch mutation {
    case "owner": object["owner_profile_id"] = "other"
    case "operation": object["operation_id"] = DJConnectOperationIdentity.uuidV7(milliseconds: 1)
    case "confirmation": object["confirmation_id"] = "other"
    case "digest": object["request_digest"] = String(repeating: "0", count: 64)
    case "unit": var u = object["unit"] as! [String: Any]; u["target_id"] = "other"; object["unit"] = u
    case "entries": object["affected_entries"] = []
    case "messages": object["removed_message_ids"] = []
    case "unit_kind": var u = object["unit"] as! [String: Any]; u["kind"] = "moment"; object["unit"] = u
    case "playback": object["music_playback_undone"] = true
    case "state": object["state"] = "pending"
    default: break
    }
    let receipt: DJConnectContentDeleteReceipt = try contentDecode(object)
    #expect(receipt.admits(scope: scope, request: request, owner: "profile-a") == (mutation == "ok"))
}

@Test func contentDeleteCapabilityRequiresExactProducerVersion() throws {
    for flag in [false, true] {
        for version in [0, 1, 2] {
            let caps: DJConnectSessionHistoryCapabilities = try contentDecode([
                "capabilities": ["session_conversation_history": true, "session_content_delete": flag],
                "contract_versions": ["session_conversation_history": 1, "session_content_delete": version]])
            #expect(caps.contentDeletionAvailable == (flag && version == 1))
        }
    }
}

@Test(arguments: ["moment", "attempt"])
func contentDeleteUsesOriginalMomentAndAttemptScopes(_ kind: String) throws {
    let examples = try contentExamples()
    let scope: DJConnectContentDeleteScope = try contentDecode(try #require(examples[kind + "_prepare_response"]))
    let receipt: DJConnectContentDeleteReceipt = try contentDecode(try #require(examples[kind + "_response"]))
    let identity = DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios,
        firmware: "4.0.0", platform: .ios)
    let request = DJConnectContentDeleteRequest(identity: identity, confirmationID: scope.confirmation_id,
        operationID: receipt.operation_id)
    let now = try #require(DJConnectHistoryEntry.date(scope.created_at)).addingTimeInterval(1)
    #expect(scope.admits(target: scope.target, owner: "profile-a", at: now))
    #expect(receipt.admits(scope: scope, request: request, owner: "profile-a"))
    if kind == "attempt" { #expect(scope.target.session_id == "" && scope.target.kind == "request") }
}

@Test(arguments: ["completed", "pending", "unknown", "expired_unknown", "owner", "digest", "operation", "confirmation", "definitive"])
func contentDeleteStatusNeverSettlesUnboundOrUncertainResults(_ mutation: String) throws {
    let examples = try contentExamples()
    let scope: DJConnectContentDeleteScope = try contentDecode(try #require(examples["prepare_response"]))
    var object = try #require(examples["completed_status_response"] as? [String: Any])
    let identity = DJConnectIdentity(deviceID: "djconnect-ios-ABCDEF123456", deviceName: "Fixture", clientType: .ios,
        firmware: "4.0.0", platform: .ios)
    let request = DJConnectContentDeleteRequest(identity: identity, confirmationID: scope.confirmation_id,
        operationID: try #require(object["operation_id"] as? String))
    if ["pending", "unknown", "expired_unknown"].contains(mutation) {
        object["state"] = mutation; object["definitive"] = false; object.removeValue(forKey: "receipt")
    } else {
        switch mutation {
        case "owner": object["owner_profile_id"] = "other"
        case "digest": object["request_digest"] = "wrong"
        case "operation": object["operation_id"] = "other"
        case "confirmation": object["confirmation_id"] = "other"
        case "definitive": object["definitive"] = false
        default: break
        }
    }
    let status: DJConnectContentDeleteStatus = try contentDecode(object)
    #expect(status.admits(scope: scope, request: request, owner: "profile-a") ==
        ["completed", "pending", "unknown", "expired_unknown"].contains(mutation))
    if status.state != "completed" { #expect(status.receipt == nil && !status.definitive) }
}

#if os(macOS)
import AppKit
@testable import DJConnectUI

@Test @MainActor func revealedContributionDismissalExcludesTrashAndOtherWindows() throws {
    _ = NSApplication.shared
    let window = NSWindow(contentRect: .init(x: -3000, y: -3000, width: 400, height: 300),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let root = NSView(frame: .init(x: 0, y: 0, width: 400, height: 300))
    window.contentView = root
    let probe = ContentSwipeTapDismissal.TapProbe(frame: .init(x: 320, y: 120, width: 56, height: 56))
    var dismissals = 0
    probe.dismiss = { dismissals += 1 }
    root.addSubview(probe)
    window.orderBack(nil)
    defer { window.close() }
    func click(_ point: NSPoint, windowNumber: Int) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
            timestamp: 0, windowNumber: windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
    }
    probe.observe(try click(.init(x: 340, y: 140), windowNumber: window.windowNumber))
    #expect(dismissals == 0) // Actual trash bounds stay actionable.
    probe.observe(try click(.init(x: 100, y: 140), windowNumber: window.windowNumber))
    #expect(dismissals == 1) // Contribution and surrounding page dismiss.
    probe.observe(try click(.init(x: 100, y: 140), windowNumber: window.windowNumber + 1))
    #expect(dismissals == 1)
    #expect(probe.hitTest(.init(x: 20, y: 20)) == nil)
    probe.removeFromSuperview()
    probe.observe(try click(.init(x: 100, y: 140), windowNumber: window.windowNumber))
    #expect(dismissals == 1) // Unmounted rows cannot react to another screen.
}
#endif
