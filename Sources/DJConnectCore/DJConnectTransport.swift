import Foundation

public enum DJConnectHAConnectionMode: String, Codable, Equatable, Sendable {
    case local
    case remote
    case offline
}

public struct DJConnectTransportResolution: Equatable, Sendable {
    public var mode: DJConnectHAConnectionMode
    public var baseURL: URL?

    public init(mode: DJConnectHAConnectionMode, baseURL: URL?) {
        self.mode = mode
        self.baseURL = baseURL
    }
}

public final class DJConnectHATransportManager: Sendable {
    public let localURL: URL?
    public let remoteURL: URL?
    public let allowsRemoteFallback: Bool
    private let clientFactory: @Sendable (URL) -> DJConnectClient
    private let modeReporter: (@Sendable (DJConnectHAConnectionMode, URL?) -> Void)?

    public init(
        localURL: URL?,
        remoteURL: URL?,
        allowsRemoteFallback: Bool,
        clientFactory: @escaping @Sendable (URL) -> DJConnectClient,
        modeReporter: (@Sendable (DJConnectHAConnectionMode, URL?) -> Void)? = nil
    ) {
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.allowsRemoteFallback = allowsRemoteFallback
        self.clientFactory = clientFactory
        self.modeReporter = modeReporter
    }

    public var candidates: [DJConnectTransportResolution] {
        var values: [DJConnectTransportResolution] = []
        if let localURL {
            values.append(DJConnectTransportResolution(mode: .local, baseURL: localURL))
        }
        if allowsRemoteFallback, let remoteURL {
            values.append(DJConnectTransportResolution(mode: .remote, baseURL: remoteURL))
        }
        if values.isEmpty {
            values.append(DJConnectTransportResolution(mode: .offline, baseURL: nil))
        }
        return values
    }

    @MainActor
    public func perform<T: Sendable>(_ operation: (DJConnectClient) async throws -> T) async throws -> T {
        let candidates = candidates
        guard candidates.first?.mode != .offline else {
            modeReporter?(.offline, nil)
            throw DJConnectError.network(message: "Home Assistant unavailable")
        }

        var lastError: Error?
        for (index, candidate) in candidates.enumerated() {
            guard let baseURL = candidate.baseURL else {
                continue
            }
            do {
                let result = try await operation(clientFactory(baseURL))
                modeReporter?(candidate.mode, baseURL)
                return result
            } catch let error as DJConnectError {
                lastError = error
                let canRetry = index + 1 < candidates.count && Self.isRetryable(error)
                if !canRetry {
                    if candidate.mode == .remote || index + 1 >= candidates.count {
                        modeReporter?(.offline, nil)
                    }
                    throw error
                }
            } catch {
                lastError = error
                guard index + 1 < candidates.count else {
                    modeReporter?(.offline, nil)
                    throw error
                }
            }
        }

        modeReporter?(.offline, nil)
        throw lastError ?? DJConnectError.network(message: "Home Assistant unavailable")
    }

    public static func isRetryable(_ error: DJConnectError) -> Bool {
        switch error {
        case .network, .invalidResponse:
            true
        default:
            false
        }
    }
}
