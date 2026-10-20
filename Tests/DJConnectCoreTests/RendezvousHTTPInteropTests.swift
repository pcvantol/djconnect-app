import Foundation
import Darwin
import Testing
@testable import DJConnectCore

private struct RendezvousHTTPPlan: Decodable {
    let api_locator:String
    let qr:String
}
private final class RendezvousHTTPRedirectGuard:NSObject,URLSessionTaskDelegate,Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,
                    newRequest request:URLRequest,completionHandler:@escaping @Sendable(URLRequest?)->Void) { completionHandler(nil) }
}
/// Test-only transport locator. The product's canonical request/body stays intact.
/// No verifier, policy, identity, response body or status is substituted.
private final class RendezvousHTTPWire:URLProtocol,@unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var locator:URL?
    static func bind(_ url:URL?) { lock.withLock { locator = url } }
    private var operation:Task<Void,Never>?
    override class func canInit(with request:URLRequest)->Bool { request.url?.host == "api.djconnect.dev" }
    override class func canonicalRequest(for request:URLRequest)->URLRequest { request }
    override func startLoading() {
        let original = request
        operation = Task { @Sendable [self,original] in
            var stage = 1
            do {
                guard original.url?.absoluteString == "https://api.djconnect.dev/v1/rendezvous/inspect",
                      original.httpMethod == "POST", let base = Self.lock.withLock({Self.locator}),
                      !(original.allHTTPHeaderFields ?? [:]).keys.contains(where:{
                          $0.lowercased() == "authorization" || $0.lowercased().hasPrefix("x-djconnect") || $0.lowercased() == "cookie"
                      }) else { throw URLError(.badServerResponse) }
                stage = 2
                var body = original.httpBody
                if body == nil, let stream = original.httpBodyStream {
                    stream.open(); defer { stream.close() }
                    var data = Data(); var buffer = [UInt8](repeating:0,count:512)
                    while stream.hasBytesAvailable {
                        let count = stream.read(&buffer,maxLength:buffer.count)
                        guard count >= 0, data.count + count <= 1024 else { throw URLError(.badServerResponse) }
                        if count == 0 { break }; data.append(contentsOf:buffer.prefix(count))
                    }
                    body = data
                }
                guard let body, !body.isEmpty, body.count <= 1024 else { throw URLError(.badServerResponse) }
                stage = 3
                let config = URLSessionConfiguration.ephemeral
                config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
                config.httpShouldSetCookies = false; config.timeoutIntervalForResource = 8
                let session = URLSession(configuration:config,delegate:RendezvousHTTPRedirectGuard(),delegateQueue:nil)
                defer { session.invalidateAndCancel() }
                let url = URL(string:"inspect",relativeTo:base)!.absoluteURL
                var forwarded = URLRequest(url:url); forwarded.httpMethod = "POST"; forwarded.httpBody = body
                forwarded.setValue("application/json",forHTTPHeaderField:"Content-Type")
                forwarded.setValue("identity",forHTTPHeaderField:"Accept-Encoding")
                forwarded.setValue(original.value(forHTTPHeaderField:"Accept"),forHTTPHeaderField:"Accept")
                stage = 4
                let (data,response) = try await session.data(for:forwarded)
                stage = 5
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse, http.url == url, data.count <= 4096,
                      let canonical = original.url else { throw URLError(.badServerResponse) }
                let keys = (try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
                print("Local inspect status=\(http.statusCode) bytes=\(data.count) keys=\(keys?.keys.sorted() ?? []) encodingPresent=\(http.value(forHTTPHeaderField:"Content-Encoding") != nil)")
                let headers = http.allHeaderFields.reduce(into:[String:String]()) { result,item in
                    if let name = item.key as? String { result[name] = String(describing:item.value) }
                }
                guard let relayed = HTTPURLResponse(url:canonical,statusCode:http.statusCode,httpVersion:nil,headerFields:headers) else { throw URLError(.badServerResponse) }
                self.client?.urlProtocol(self,didReceive:relayed,cacheStoragePolicy:.notAllowed)
                self.client?.urlProtocol(self,didLoad:data); self.client?.urlProtocolDidFinishLoading(self)
            } catch { self.client?.urlProtocol(self,didFailWithError:NSError(domain:"RendezvousHTTPQualificationStage",code:stage)) }
        }
    }
    override func stopLoading() { operation?.cancel() }
}

@Test(.enabled(if:ProcessInfo.processInfo.environment["DJCONNECT_RENDEZVOUS_HTTP_PLAN"] != nil, "Opt-in protected local HTTP fixture"))
func rendezvousHTTPNativeClientInterop() async throws {
    guard let path = ProcessInfo.processInfo.environment["DJCONNECT_RENDEZVOUS_HTTP_PLAN"] else { return }
    // This test cannot discover an endpoint, open a public service or use a token.
    let planURL = URL(fileURLWithPath:path).standardizedFileURL
    let directory = planURL.deletingLastPathComponent()
    let temporaryRoot = URL(fileURLWithPath:"/private/tmp",isDirectory:true).resolvingSymlinksInPath()
    guard directory.deletingLastPathComponent().resolvingSymlinksInPath() == temporaryRoot,
          directory.lastPathComponent.hasPrefix("djc-rendezvous-http-"),
          directory.lastPathComponent != "djc-rendezvous-http-",
          planURL.resolvingSymlinksInPath() == planURL else { throw NSError(domain:"RendezvousHTTPPlan",code:1) }
    for url in [directory,planURL] {
        let attributes = try FileManager.default.attributesOfItem(atPath:url.path)
        guard let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue, mode & 0o077 == 0,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else { throw NSError(domain:"RendezvousHTTPPlan",code:2) }
    }
    let data = try Data(contentsOf:planURL); guard data.count <= 4096 else { throw URLError(.badServerResponse) }
    let plan = try JSONDecoder().decode(RendezvousHTTPPlan.self,from:data)
    guard let locator = URL(string:plan.api_locator), let components = URLComponents(url:locator,resolvingAgainstBaseURL:false),
          components.scheme == "http", components.host == "127.0.0.1", components.port != nil,
          components.user == nil, components.password == nil, components.query == nil, components.fragment == nil,
          components.path.hasSuffix("/v1/rendezvous/") else { throw NSError(domain:"RendezvousHTTPPlan",code:3) }
    let qr = try DJConnectRendezvousQR.parse(plan.qr)
    RendezvousHTTPWire.bind(locator); defer { RendezvousHTTPWire.bind(nil) }
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [RendezvousHTTPWire.self]
    let service = DJConnectRendezvousService(configuration:config)
    let browser = try await service.inspect(qr)
    let matched = browser.thumbprint == qr.browserKeyThumbprint && browser.modulus.count == 256
    #expect(matched)
    // Synthetic trusted HA context: not a real paired installation/readback.
    let owner = try JSONDecoder().decode(DJConnectDisplayOwnerContext.self,from:Data(#"{"success":true,"contract_version":1,"display_entry_url":"https://ha.example.com/djconnect/vibecast/display","route_trust":"paired_owner_response","issuer_epoch":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}"#.utf8))
    let envelope = try DJConnectRendezvousDestination.encrypt(qr:qr,browserKey:browser,owner:owner)
    let output = try JSONSerialization.data(withJSONObject:["jwe":envelope.compact,"digest":envelope.digest])
    let outputURL = directory.appendingPathComponent("native-envelope.json")
    try output.write(to:outputURL,options:.withoutOverwriting)
    try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:outputURL.path)
}
