import Foundation
import Testing
@testable import DJConnectCore

private final class RendezvousOwnerWire: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var calls = 0
    nonisolated(unsafe) private static var qualified = false
    static func reset(qualified:Bool = false) { lock.withLock { calls = 0; Self.qualified = qualified } }
    static var count: Int { lock.withLock { calls } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "127.0.0.1" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.withLock { Self.calls += 1 }
        let body: String
        if request.url!.path.hasSuffix("/transport/context") {
            if Self.lock.withLock({ Self.qualified }) {
                body = #"{"success":true,"contract_version":1,"ha_install_id":"fixture-install","requires_authenticated_tls":false,"operation_lifetime_ms":300000,"operation_epoch":"fixture","server_time_ms":1000,"transport_security":{"policy_version":1,"deployment_qualification_required":true,"external":"authenticated_tls","local_plaintext":"qualified_direct_only","peer_policy":"enabled_interface_subnet_or_loopback","internal_origin_required":true,"forwarded_plaintext":"forbidden","mode":"qualified_direct_http"}}"#
            } else { body = #"{"success":true,"contract_version":1,"ha_install_id":"fixture-install"}"# }
        } else {
            body = #"{"success":true,"contract_version":1,"display_entry_url":"https://ha.example.com/djconnect/vibecast/display","route_trust":"paired_owner_response","issuer_epoch":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}"#
        }
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@MainActor private final class RendezvousOwnerAuthority { var current = true }

@MainActor @Test func rendezvousOwnerRejectsLegacyPlaintextBeforeOwnerRequest() async throws {
    RendezvousOwnerWire.reset()
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [RendezvousOwnerWire.self]
    let session = URLSession(configuration:config); defer { session.invalidateAndCancel() }
    let client = DJConnectClient(baseURL:URL(string:"http://127.0.0.1:18766")!,
        identity:DJConnectIdentity(deviceID:"djconnect-ios-ABCDEF123456",deviceName:"Fixture",clientType:.ios,firmware:"4.0.0",platform:.ios),
        tokenStore:DJConnectInMemoryTokenStore(token:"synthetic-fixture-only"),session:session)
    var rejected = false
    do { _ = try await client.displayOwnerContext(expectedInstallationID:"fixture-install",pairedLocalOrigin:URL(string:"http://127.0.0.1:18766"),isCurrent:{ true }) }
    catch { rejected = true }
    #expect(rejected)
    #expect(RendezvousOwnerWire.count == 1)
    RendezvousOwnerWire.reset(qualified:true)
    let accepted = try await client.displayOwnerContext(expectedInstallationID:"fixture-install",pairedLocalOrigin:URL(string:"http://127.0.0.1:18766"),isCurrent:{ true })
    #expect(accepted.isAdmissible)
    #expect(RendezvousOwnerWire.count == 2)
    RendezvousOwnerWire.reset(qualified:true)
    do { _ = try await client.displayOwnerContext(expectedInstallationID:"fixture-install",pairedLocalOrigin:nil,isCurrent:{ true }); Issue.record("Missing selected local origin was admitted") }
    catch {}
    #expect(RendezvousOwnerWire.count == 0)
    let authority = RendezvousOwnerAuthority()
    do {
        _ = try await client.displayOwnerContext(expectedInstallationID:"fixture-install",pairedLocalOrigin:URL(string:"http://127.0.0.1:18766"),isCurrent:{
            let captured = authority.current; authority.current = false; return captured
        })
        Issue.record("Owner invalidated before dispatch was admitted")
    } catch {}
    #expect(RendezvousOwnerWire.count == 0)
}
