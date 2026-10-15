import Foundation
import CoreGraphics
import ImageIO

/// Immutable decoded pixels. No disk cache, provider URL or credential is retained.
public struct DJConnectSessionArtworkImage: @unchecked Sendable {
    public let image: CGImage
}

private final class SessionArtworkRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private actor SessionArtworkBudget {
    private var active = 0
    func acquire() throws {
        guard active < 2 else { throw DJConnectError.invalidResponse }
        active += 1
    }
    func release() { active -= 1 }
}

/// Separate credentialed owner transport: redirects, cookies and URLCache are
/// disabled. Bounded streaming precedes static-image validation and decoding.
final class DJConnectSessionArtworkTransport: Sendable {
    private static let budget = SessionArtworkBudget()
    private let session: URLSession
    static let maximumBytes = 2 * 1024 * 1024

    init(configuration: URLSessionConfiguration) {
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        session = URLSession(configuration: configuration, delegate: SessionArtworkRedirectGuard(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }

    func load(_ request: URLRequest, width: Int, height: Int) async throws -> DJConnectSessionArtworkImage {
        try await Self.budget.acquire()
        do {
            let result = try await download(request, width: width, height: height)
            await Self.budget.release()
            return result
        } catch {
            await Self.budget.release()
            throw error
        }
    }

    private func download(_ request: URLRequest, width: Int, height: Int) async throws -> DJConnectSessionArtworkImage {
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
        guard response.expectedContentLength <= Int64(Self.maximumBytes) else {
            throw DJConnectError.payloadTooLarge(limitBytes: Self.maximumBytes, actualBytes: nil)
        }
        let mime = response.mimeType?.lowercased()
        guard mime == "image/png" || mime == "image/jpeg" else { throw DJConnectError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < Self.maximumBytes else {
                throw DJConnectError.payloadTooLarge(limitBytes: Self.maximumBytes, actualBytes: data.count + 1)
            }
            data.append(byte)
        }
        try Task.checkCancellation()
        guard response.expectedContentLength < 0 || data.count == response.expectedContentLength else { throw DJConnectError.invalidResponse }
        return try Self.decode(data, mime: mime!, width: width, height: height)
    }

    static func decode(_ data: Data, mime: String, width: Int, height: Int) throws -> DJConnectSessionArtworkImage {
        guard data.count <= maximumBytes, width > 0, height > 0, width <= 4096, height <= 4096,
              width * height <= 16_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1,
              let type = CGImageSourceGetType(source) as String?,
              (mime == "image/png" && type == "public.png") || (mime == "image/jpeg" && type == "public.jpeg"),
              CGImageSourceGetStatus(source) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              properties[kCGImagePropertyPixelWidth] as? Int == width,
              properties[kCGImagePropertyPixelHeight] as? Int == height,
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { throw DJConnectError.invalidResponse }
        return .init(image: image)
    }
}
