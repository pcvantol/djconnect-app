import Foundation
import Darwin

/// Core source0f92b74e76ae055efdbf2b375d95c58e86328e27, PR1184.
/// Local source qualification is separate from installed deployment acceptance.
/// This validates a response, never grants permission to send credentials.
enum DJConnectHybridLocalPolicy {
    static func acceptsContext(_ body: HybridObject, origin: URL, pairedLocalOrigin: URL?) -> Bool {
        if origin.scheme?.lowercased() == "https" {
            guard DJConnectHybridTransport.trustedOrigin(origin), body["requires_authenticated_tls"] == .bool(true) else { return false }
            guard let policy = body["transport_security"]?.hybridObject else { return body["transport_security"] == nil }
            return policy["mode"] == .string("authenticated_tls")
        }
        guard let pairedLocalOrigin, isLocalCandidate(origin), isLocalCandidate(pairedLocalOrigin),
              sameOrigin(origin, pairedLocalOrigin), body["requires_authenticated_tls"] == .bool(false),
              let policy = body["transport_security"]?.hybridObject else { return false }
        let required: HybridObject = [
            "policy_version": .int(1), "deployment_qualification_required": .bool(true),
            "external": .string("authenticated_tls"), "local_plaintext": .string("qualified_direct_only"),
            "peer_policy": .string("enabled_interface_subnet_or_loopback"),
            "internal_origin_required": .bool(true), "forwarded_plaintext": .string("forbidden"),
            "mode": .string("qualified_direct_http")
        ]
        return required.allSatisfy { policy[$0.key] == $0.value }
    }

    static func isLocalCandidate(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false), c.scheme == "http",
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              c.path.isEmpty || c.path == "/", let rawHost = c.host else { return false }
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host.hasSuffix(".local") { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy({ (48...57).contains($0) }) }),
           parts.allSatisfy({ UInt8($0) != nil }) {
            let octets = parts.map { UInt8($0)! }
            return octets[0] == 10 || octets[0] == 127 || (octets[0] == 192 && octets[1] == 168)
                || (octets[0] == 172 && (16...31).contains(octets[1]))
        }
        var address = in6_addr()
        guard host.withCString({ inet_pton(AF_INET6, $0, &address) }) == 1 else { return false }
        let bytes = withUnsafeBytes(of: address) { Array($0) }
        return (bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1)
            || bytes[0] & 0xfe == 0xfc || (bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80)
    }

    private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && (lhs.port ?? 80) == (rhs.port ?? 80)
    }
}
