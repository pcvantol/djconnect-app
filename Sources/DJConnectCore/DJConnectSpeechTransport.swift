import Foundation

private final class SpeechRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
private actor SpeechTransferBudget {
    private var active = 0
    func acquire() throws { guard active < 2 else { throw DJConnectError.invalidResponse }; active += 1 }
    func release() { active -= 1 }
}
/// Private paired POST resources; no legacy URL fallback, persistence or logs.
final class DJConnectSpeechTransport: Sendable {
    private let session: URLSession
    private static let budget = SpeechTransferBudget()
    init(configuration: URLSessionConfiguration) {
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false; configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 22; configuration.timeoutIntervalForResource = 22
        session = URLSession(configuration: configuration, delegate: SpeechRedirectGuard(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    func data(for request: URLRequest, audio: Bool = false) async throws -> Data {
        try await Self.budget.acquire()
        do {
            let data = try await read(request, audio: audio)
            await Self.budget.release(); return data
        } catch { await Self.budget.release(); throw error }
    }
    private func read(_ request: URLRequest, audio: Bool) async throws -> Data {
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse, response.url == request.url else { throw DJConnectError.invalidResponse }
        switch response.statusCode {
        case 200: break
        case 401: throw DJConnectError.authStale(statusCode: 401, message: nil)
        case 403: throw DJConnectError.profile(code: .profileAccessDenied, statusCode: 403, message: nil)
        case 404, 410: throw DJConnectError.routeMissing(message: nil)
        default: throw DJConnectError.server(statusCode: response.statusCode, message: nil)
        }
        let maximum = audio ? 2 * 1024 * 1024 : 64 * 1024
        guard response.expectedContentLength <= Int64(maximum) else {
            throw DJConnectError.payloadTooLarge(limitBytes: maximum, actualBytes: nil)
        }
        let mimes = audio ? ["audio/wav", "audio/x-wav", "audio/wave"] : ["application/json"]
        guard let mime = response.mimeType?.lowercased(), mimes.contains(mime) else { throw DJConnectError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < maximum else { throw DJConnectError.payloadTooLarge(limitBytes: maximum, actualBytes: data.count + 1) }
            data.append(byte)
        }
        guard response.expectedContentLength < 0 || data.count == response.expectedContentLength else { throw DJConnectError.invalidResponse }
        try Task.checkCancellation()
        if audio { try Self.validateWAV(data) }
        return data
    }
    static func validateWAV(_ data: Data) throws {
        // Bound and validate the actual RIFF PCM structure, not merely a suffix.
        func le(_ offset: Int, _ count: Int) -> Int { (0..<count).reduce(0) { $0 | (Int(data[offset + $1]) << ($1 * 8)) } }
        guard data.count >= 44, data.count <= 2 * 1024 * 1024,
              data.prefix(4) == Data("RIFF".utf8), data[8..<12] == Data("WAVE".utf8),
              le(4, 4) + 8 == data.count else { throw DJConnectError.invalidResponse }
        var cursor = 12, format = false, hasAudio = false, alignment = 0
        while cursor + 8 <= data.count {
            let size = le(cursor + 4, 4), start = cursor + 8
            guard size <= data.count - start else { throw DJConnectError.invalidResponse }
            let kind = data[cursor..<cursor + 4]
            if kind == Data("fmt ".utf8) {
                guard !format, size >= 16 else { throw DJConnectError.invalidResponse }
                let channels = le(start + 2, 2), rate = le(start + 4, 4), bits = le(start + 14, 2)
                alignment = le(start + 12, 2)
                guard le(start, 2) == 1, (1...2).contains(channels), (8000...96000).contains(rate),
                      [8, 16, 24, 32].contains(bits), alignment == channels * bits / 8,
                      le(start + 8, 4) == rate * alignment else { throw DJConnectError.invalidResponse }
                format = true
            } else if kind == Data("data".utf8) {
                guard format, !hasAudio, size > 0, size % alignment == 0 else { throw DJConnectError.invalidResponse }
                hasAudio = true
            }
            cursor = start + size + size % 2
        }
        guard format, hasAudio, cursor == data.count else { throw DJConnectError.invalidResponse }
    }
}
