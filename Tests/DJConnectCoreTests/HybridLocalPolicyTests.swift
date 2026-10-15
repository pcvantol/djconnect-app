import Foundation
import Testing
@testable import DJConnectCore

private func localContext() -> [String: DJConnectJSONValue] {
    ["requires_authenticated_tls": .bool(false), "transport_security": .object([
        "policy_version": .int(1), "deployment_qualification_required": .bool(true),
        "external": .string("authenticated_tls"), "local_plaintext": .string("qualified_direct_only"),
        "peer_policy": .string("enabled_interface_subnet_or_loopback"), "internal_origin_required": .bool(true),
        "forwarded_plaintext": .string("forbidden"), "mode": .string("qualified_direct_http")])]
}
@Test func localPolicyAcceptsOnlyCompleteQualifiedPolicyAtPairedLocalOrigin() {
    let url = URL(string: "http://192.168.1.134:8123")!
    #expect(DJConnectHybridLocalPolicy.acceptsContext(localContext(), origin: url, pairedLocalOrigin: url))
    #expect(!DJConnectHybridLocalPolicy.acceptsContext(localContext(), origin: url, pairedLocalOrigin: nil))
    #expect(!DJConnectHybridLocalPolicy.acceptsContext(localContext(), origin: url, pairedLocalOrigin: URL(string: "http://192.168.1.135:8123")))
    #expect(!DJConnectHybridLocalPolicy.acceptsContext(localContext(), origin: url, pairedLocalOrigin: URL(string: "http://192.168.1.134:8124")))
    let policy = localContext()["transport_security"]!.hybridObject!
    for key in policy.keys {
        var missing = policy; missing.removeValue(forKey: key)
        #expect(!DJConnectHybridLocalPolicy.acceptsContext(["requires_authenticated_tls": .bool(false), "transport_security": .object(missing)], origin: url, pairedLocalOrigin: url))
    }
}
@Test func localPolicyRejectsExternalDowngradeAndDeceptivePrivateHosts() {
    for raw in ["http://remote.example", "http://192.168.evil.example", "http://10.evil.example", "http://172.16.1.999", "http://8.8.8.8", "http://user:secret@ha.local", "http://ha.local?token=x", "http://ha.local/path", "http://ha.local#fragment"] {
        let url = URL(string: raw)!
        #expect(!DJConnectHybridLocalPolicy.isLocalCandidate(url))
        #expect(!DJConnectHybridLocalPolicy.acceptsContext(localContext(), origin: url, pairedLocalOrigin: url))
    }
    let tls = URL(string: "https://remote.example")!
    #expect(!DJConnectHybridLocalPolicy.acceptsContext(localContext(), origin: tls, pairedLocalOrigin: nil))
    #expect(DJConnectHybridLocalPolicy.acceptsContext(["requires_authenticated_tls": .bool(true)], origin: tls, pairedLocalOrigin: nil))
}
@Test func localPolicyClassifiesIPv6AndPrivateIPv4WithoutGrantingAuthority() {
    for raw in ["http://10.1.2.3", "http://172.16.1.2", "http://192.168.1.2", "http://ha.local", "http://[fd00::1]", "http://[::1]", "http://[fe80::1]"] {
        let url = URL(string: raw)!
        #expect(DJConnectHybridLocalPolicy.isLocalCandidate(url))
        #expect(!DJConnectHybridLocalPolicy.acceptsContext(["requires_authenticated_tls": .bool(false)], origin: url, pairedLocalOrigin: url))
    }
}
@Test func localPolicyReadsExactPublishedCandidateContextsWithoutTreatingCapabilityAsAdmission() throws {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/hybrid_local_candidate_6a0c339.json")
    let fixture = try JSONDecoder().decode([String: DJConnectJSONValue].self, from: Data(contentsOf: path))
    let local = URL(string: "http://127.0.0.1:8123")!
    let tls = URL(string: "https://remote.example")!
    #expect(DJConnectHybridLocalPolicy.acceptsContext(try #require(fixture["local_context"]?.hybridObject), origin: local, pairedLocalOrigin: local))
    #expect(DJConnectHybridLocalPolicy.acceptsContext(try #require(fixture["tls_context"]?.hybridObject), origin: tls, pairedLocalOrigin: nil))
    #expect(!DJConnectHybridLocalPolicy.acceptsContext(try #require(fixture["capability"]?.hybridObject), origin: local, pairedLocalOrigin: local))
}
