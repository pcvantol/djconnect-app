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

@MainActor @Test(.isolatedClientResources) func rendezvousOwnerRejectsLegacyPlaintextBeforeOwnerRequest() async throws {
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

private final class CredentialDispatchWire:URLProtocol,@unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var captured:[URLRequest] = []
    nonisolated(unsafe) private static var status = 200
    static func reset(status:Int = 200) { lock.withLock { captured = [];Self.status = status } }
    static var requests:[URLRequest] { lock.withLock { captured } }
    override class func canInit(with request:URLRequest)->Bool { true }
    override class func canonicalRequest(for request:URLRequest)->URLRequest { request }
    override func startLoading() {
        let status = Self.lock.withLock { Self.captured.append(request);return Self.status }
        let headers = status == 200 ? ["Content-Type":"application/json"] : ["Content-Type":"text/plain","Content-Length":"999999"]
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:headers)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:Data("{}".utf8));client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@Suite(.serialized) @MainActor struct CredentialedOwnerDispatchTests {
    private func request(_ path:String)->URLRequest {
        var request = URLRequest(url:URL(string:"http://127.0.0.1:18766/api/djconnect/v1/"+path)!)
        request.httpMethod = "POST";request.httpBody = Data("{}".utf8)
        request.setValue("Bearer synthetic-owner-token",forHTTPHeaderField:"Authorization")
        return request
    }
    @Test(.isolatedClientResources) func credentialedTaskStartsBeforeQueuedOwnerWithdrawal() async throws {
        for path in ["transport/context","display/owner/context"] {
            CredentialDispatchWire.reset()
            let config = URLSessionConfiguration.ephemeral;config.protocolClasses = [CredentialDispatchWire.self]
            var observed:URLSessionDataTask?,probe:Task<Void,Never>?
            var resumeIssued = false, probeEntered = false
            let authority = RendezvousOwnerAuthority()
            let transport = DJConnectSessionArtworkTransport(configuration:config,
                preparationTaskCreated:{observed = $0}, preparationTaskResumed:{ task in
                    #expect(task === observed && !probeEntered)
                    resumeIssued = true
                })
            _ = try await transport.prepare(request(path),isCurrent:{
                #expect(observed?.state == .suspended)
                probe = Task { @MainActor in
                    probeEntered = true
                    // Foundation may publish task.state later than resume().
                    // Observe the actual synchronous call boundary instead.
                    #expect(resumeIssued)
                    authority.current = false
                }
                return authority.current
            })
            await probe?.value
            #expect(observed?.state != .suspended)
            #expect(CredentialDispatchWire.requests.count == 1)
            #expect(CredentialDispatchWire.requests.first?.value(forHTTPHeaderField:"Authorization") == "Bearer synthetic-owner-token")
        }
    }
    @Test(.isolatedClientResources) func withdrawnOwnerNeverResumesCredentialedTask() async throws {
        for path in ["transport/context","display/owner/context"] {
            CredentialDispatchWire.reset()
            let config = URLSessionConfiguration.ephemeral;config.protocolClasses = [CredentialDispatchWire.self]
            let transport = DJConnectSessionArtworkTransport(configuration:config)
            await #expect(throws:(any Error).self) { _ = try await transport.prepare(request(path),isCurrent:{false}) }
            #expect(CredentialDispatchWire.requests.isEmpty)
        }
    }
    @Test(.isolatedClientResources) func denialPrecedesMalformedAndOversizedBodyMetadata() async throws {
        for status in [401,403] {
            CredentialDispatchWire.reset(status:status)
            let config = URLSessionConfiguration.ephemeral;config.protocolClasses = [CredentialDispatchWire.self]
            let transport = DJConnectSessionArtworkTransport(configuration:config)
            do {
                _ = try await transport.prepare(request("display/owner/context"),isCurrent:{true})
                Issue.record("Authorization denial accepted")
            } catch let error as DJConnectError {
                switch error {
                case .authStale(let code,_): #expect(status == 401 && code == 401)
                case .profile(_,let code,_): #expect(status == 403 && code == 403)
                default: Issue.record("Body metadata masked authorization denial")
                }
            }
            #expect(CredentialDispatchWire.requests.count == 1)
        }
    }
}
