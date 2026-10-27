import Foundation

/// Bounded interactive replies only. A background transition or lost companion
/// cannot leave a continuation hanging or replay an effectful operation.
@MainActor public final class DJConnectWatchProxyRequests {
    private struct Pending {
        let continuation: CheckedContinuation<DJConnectWatchProxyResponse, Never>
        let timeout: Task<Void, Never>
    }
    private var pending: [String: Pending] = [:]
    private let timeout: Duration
    public init(timeout: Duration = .seconds(20)) { self.timeout = timeout }
    public var count: Int { pending.count }

    public func request(timeout override: Duration? = nil, send: (String) -> Void) async -> DJConnectWatchProxyResponse {
        guard pending.count < 8, !Task.isCancelled else {
            return .init(success: false, error: "outcome_unknown")
        }
        let id = UUID().uuidString
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let duration = min(override ?? timeout, .seconds(300))
                let task = Task { [weak self] in
                    try? await Task.sleep(for: duration)
                    guard !Task.isCancelled else { return }
                    self?.complete(id: id, response: .init(success: false, error: "outcome_unknown"))
                }
                pending[id] = Pending(continuation: continuation, timeout: task)
                send(id)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.complete(id: id, response: .init(success: false, error: "outcome_unknown"))
            }
        }
    }

    public func receive(id: String, data: Data?) {
        guard pending[id] != nil else { return }
        guard let data, data.count <= 60_000,
              let response = try? JSONDecoder().decode(DJConnectWatchProxyResponse.self, from: data) else {
            complete(id: id, response: .init(success: false, error: "invalid_response")); return
        }
        complete(id: id, response: response)
    }
    public func complete(id: String, response: DJConnectWatchProxyResponse) {
        guard let value = pending.removeValue(forKey: id) else { return }
        value.timeout.cancel(); value.continuation.resume(returning: response)
    }
    public func cancelAll() {
        for id in Array(pending.keys) {
            complete(id: id, response: .init(success: false, error: "outcome_unknown"))
        }
    }
}
