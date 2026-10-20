import Foundation

/// Shared fixed-request dispatch. No redirects, retries, endpoint selection or
/// credential construction. Callers retain their own authority/status policies.
enum DJConnectBoundedHTTPTransport {
    struct Response:Sendable { let data:Data; let mime:String }

    @MainActor static func send(_ request:URLRequest,using session:URLSession,maximumBytes:Int,
        beforeDispatch:@escaping @MainActor @Sendable () throws -> Void,
        isBodyCurrent:@escaping @Sendable ()->Bool = {true},
        taskCreated:(@MainActor @Sendable (URLSessionDataTask)->Void)? = nil,
        validateResponse:@escaping @Sendable (HTTPURLResponse)throws->String) async throws -> Response {
        try Task.checkCancellation()
        guard let url = request.url,maximumBytes > 0 else { throw DJConnectError.invalidResponse }
        let reply = BoundedHTTPReply(url:url,limit:maximumBytes,isCurrent:isBodyCurrent,validate:validateResponse)
        let task = session.dataTask(with:request)
        task.delegate = reply
        taskCreated?(task) // Internal observation, never supplied by public factories.
        defer { task.cancel() }
        return try await withTaskCancellationHandler(operation:{
            // Install cancellation BEFORE these checks/resume. Concurrent cancel
            // then cancels the suspended task; resuming it cannot release bytes.
            try Task.checkCancellation()
            try beforeDispatch()
            try Task.checkCancellation()
            guard isBodyCurrent() else { throw DJConnectError.invalidResponse }
            task.resume() // Synchronous, without yielding the authority actor.
            let response = try await reply.value()
            try Task.checkCancellation()
            guard isBodyCurrent() else { throw DJConnectError.invalidResponse }
            return response
        },onCancel:{task.cancel();reply.cancel()},isolation:MainActor.shared)
    }
}

private final class BoundedHTTPReply:NSObject,URLSessionDataDelegate,@unchecked Sendable {
    private let lock = NSLock()
    private let url:URL
    private let limit:Int
    private let isCurrent:@Sendable ()->Bool
    private let validate:@Sendable (HTTPURLResponse)throws->String
    private var expectedLength:Int64 = -1
    private var mime:String?
    private var body = Data()
    private var result:Result<DJConnectBoundedHTTPTransport.Response,any Error>?
    private var continuation:CheckedContinuation<DJConnectBoundedHTTPTransport.Response,any Error>?
    init(url:URL,limit:Int,isCurrent:@escaping @Sendable ()->Bool,
        validate:@escaping @Sendable (HTTPURLResponse)throws->String) {
        self.url = url;self.limit = limit;self.isCurrent = isCurrent;self.validate = validate
    }
    func value() async throws -> DJConnectBoundedHTTPTransport.Response {
        try await withCheckedThrowingContinuation { next in
            let ready = lock.withLock { ()->Result<DJConnectBoundedHTTPTransport.Response,any Error>? in
                if let result { return result };continuation = next;return nil
            }
            if let ready { next.resume(with:ready) }
        }
    }
    func cancel() { finish(.failure(CancellationError())) }
    private func finish(_ outcome:Result<DJConnectBoundedHTTPTransport.Response,any Error>) {
        let waiting = lock.withLock { ()->CheckedContinuation<DJConnectBoundedHTTPTransport.Response,any Error>? in
            guard result == nil else { return nil };result = outcome
            let waiting = continuation;continuation = nil;body = Data();return waiting
        }
        waiting?.resume(with:outcome)
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,
        newRequest request:URLRequest,completionHandler:@escaping @Sendable (URLRequest?)->Void) { completionHandler(nil) }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive response:URLResponse,
        completionHandler:@escaping @Sendable (URLSession.ResponseDisposition)->Void) {
        do {
            try lock.withLock {
                guard result == nil,mime == nil,isCurrent(),let http = response as? HTTPURLResponse,
                      http.url == url else { throw DJConnectError.invalidResponse }
                // Classify authorization/status before optional body metadata.
                let checkedMIME = try validate(http)
                guard http.expectedContentLength <= Int64(limit) else {
                    throw DJConnectError.payloadTooLarge(limitBytes:limit,actualBytes:nil)
                }
                mime = checkedMIME;expectedLength = http.expectedContentLength
            }
            completionHandler(.allow)
        } catch { finish(.failure(error));completionHandler(.cancel) }
    }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive data:Data) {
        let allowed = lock.withLock { ()->Bool in
            guard result == nil,mime != nil,isCurrent(),data.count <= limit-body.count else { return false }
            body.append(data);return true
        }
        if !allowed {
            finish(.failure(DJConnectError.payloadTooLarge(limitBytes:limit,actualBytes:nil)));dataTask.cancel()
        }
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,didCompleteWithError error:(any Error)?) {
        let outcome:Result<DJConnectBoundedHTTPTransport.Response,any Error> = lock.withLock {
            guard result == nil,error == nil,isCurrent(),let mime,
                  expectedLength < 0 || expectedLength == body.count else { return .failure(DJConnectError.invalidResponse) }
            return .success(.init(data:body,mime:mime))
        }
        finish(outcome)
    }
}
