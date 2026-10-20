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
    private let preparationSession: URLSession
    private let preparationTaskCreated:(@MainActor @Sendable (URLSessionDataTask)->Void)?
    static let maximumBytes = 2 * 1024 * 1024

    init(configuration: URLSessionConfiguration, preparationTaskCreated:(@MainActor @Sendable (URLSessionDataTask)->Void)? = nil) {
        self.preparationTaskCreated = preparationTaskCreated
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        session = URLSession(configuration: configuration, delegate: SessionArtworkRedirectGuard(), delegateQueue: nil)
        configuration.timeoutIntervalForRequest = 22
        configuration.timeoutIntervalForResource = 22
        preparationSession = URLSession(configuration: configuration, delegate: SessionArtworkRedirectGuard(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel(); preparationSession.invalidateAndCancel() }

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

    func prepare(_ request: URLRequest, isCurrent: (@MainActor @Sendable () -> Bool)? = nil) async throws -> Data {
        try await Self.budget.acquire()
        do {
            let (data, _) = try await responseData(request, using: preparationSession,
                maximumBytes: 64 * 1024, allowedMIMEs: ["application/json"],
                isCurrent:isCurrent,taskCreated:preparationTaskCreated)
            await Self.budget.release()
            return data
        } catch {
            await Self.budget.release()
            throw error
        }
    }

    /// Forecast v1 supplies no dimensions; inspect bounded static bytes before
    /// using the same strict type/dimension/thumbnail decoder as Session art.
    func loadForecast(_ request: URLRequest) async throws -> DJConnectSessionArtworkImage {
        try await Self.budget.acquire()
        do {
            let (data, mime) = try await responseData(request, using: session,
                maximumBytes: Self.maximumBytes, allowedMIMEs: ["image/png", "image/jpeg"])
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw DJConnectError.invalidResponse }
            let result = try Self.decode(data, mime: mime, width: width, height: height)
            await Self.budget.release()
            return result
        } catch { await Self.budget.release(); throw error }
    }

    private func download(_ request: URLRequest, width: Int, height: Int) async throws -> DJConnectSessionArtworkImage {
        let (data, mime) = try await responseData(request, using: session,
            maximumBytes: Self.maximumBytes, allowedMIMEs: ["image/png", "image/jpeg"])
        return try Self.decode(data, mime: mime, width: width, height: height)
    }

    private func responseData(_ request: URLRequest, using transport: URLSession,
                              maximumBytes: Int, allowedMIMEs: [String],
                              isCurrent:(@MainActor @Sendable ()->Bool)? = nil,
                              taskCreated:(@MainActor @Sendable (URLSessionDataTask)->Void)? = nil) async throws -> (Data, String) {
        let response = try await DJConnectBoundedHTTPTransport.send(request,using:transport,maximumBytes:maximumBytes,
            beforeDispatch:{
                // Budget and executor hops may outlive the credential owner.
                // This check and synchronous resume share one actor segment.
                if let isCurrent,!isCurrent() { throw CancellationError() }
            },taskCreated:taskCreated,validateResponse:{ response in
                switch response.statusCode {
                case 200: break
                case 401: throw DJConnectError.authStale(statusCode:401,message:nil)
                case 403: throw DJConnectError.profile(code:.profileAccessDenied,statusCode:403,message:nil)
                case 404,410: throw DJConnectError.routeMissing(message:nil)
                default: throw DJConnectError.server(statusCode:response.statusCode,message:nil)
                }
                guard let mime = response.mimeType?.lowercased(),allowedMIMEs.contains(mime) else { throw DJConnectError.invalidResponse }
                return mime
            })
        return (response.data,response.mime)
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
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary)
        else { throw DJConnectError.invalidResponse }
        return .init(image: image)
    }
}
