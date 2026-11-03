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

/// Identity allocated once when the Watch starts recording.
public struct DJConnectWatchVoiceOperation {
    public let sequence: Int
    public let id: String

    public init(sequence: Int) {
        self.sequence = sequence
        self.id = "\(sequence):\(UUID().uuidString)"
    }

    public func header(for payload: DJConnectWatchProxyVoicePayload) throws -> Data {
        var metadata = payload
        metadata.wavData = Data()
        metadata.clientMessageID = id
        return try JSONEncoder().encode(metadata)
    }
}

/// One bounded foreground recording over the existing companion connection.
/// Individual WC messages contain raw bytes, not nested base64 WAV envelopes.
/// No backend request is produced before the complete ordered original stream.
@MainActor public final class DJConnectWatchVoiceAssembly {
    public static let chunkBytes = 16_000
    public static let maximumBytes = 200_000
    private struct Buffer {
        let owner: String, id: String, header: Data, total: Int, began: TimeInterval
        let sequence: Int
        var next = 0
        var bytes = Data()
    }
    private var buffer: Buffer?
    private var owner: String?
    // The sender assigns a persistent increasing sequence to each transfer.
    private var highestStartedSequence = 0
    public init() {}
    public func bind(owner value: String?) {
        guard value != owner else { return }
        owner = value; buffer = nil; highestStartedSequence = 0
    }
    public func receive(id: String, sequence: Int, header: Data, index: Int, total: Int, bytes: Data,
                        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws -> DJConnectWatchProxyVoicePayload? {
        guard let owner, !id.isEmpty, id.utf8.count <= 64, header.count < 4_000,
              (1...16).contains(total), (0..<total).contains(index), !bytes.isEmpty,
              bytes.count <= Self.chunkBytes, uptime.isFinite else { throw DJConnectError.invalidResponse }
        if index == 0 {
            // The operation ID fixes the sequence for the lifetime of the transfer.
            // A replay cannot move the high-water mark by changing its envelope.
            let prefix = "\(sequence):"
            guard sequence > highestStartedSequence, id.hasPrefix(prefix), id.utf8.count > prefix.utf8.count,
                  buffer == nil || uptime - buffer!.began >= 20 else { throw DJConnectError.invalidResponse }
            let metadata = try JSONDecoder().decode(DJConnectWatchProxyVoicePayload.self, from: header)
            guard metadata.wavData.isEmpty, metadata.clientMessageID == id, metadata.conversationContext != nil else { throw DJConnectError.invalidResponse }
            highestStartedSequence = sequence
            buffer = Buffer(owner: owner, id: id, header: header, total: total, began: uptime, sequence: sequence)
        }
        guard var value = buffer, value.owner == owner, value.id == id, value.sequence == sequence, value.header == header,
              value.total == total, value.next == index, uptime >= value.began, uptime - value.began < 20,
              value.bytes.count + bytes.count <= Self.maximumBytes else { throw DJConnectError.invalidResponse }
        value.bytes.append(bytes); value.next += 1
        if value.next < value.total { buffer = value; return nil }
        buffer = nil // Spend before decode/validation/await: never repeat an effect.
        try DJConnectSpeechTransport.validateWAV(value.bytes)
        var result = try JSONDecoder().decode(DJConnectWatchProxyVoicePayload.self, from: value.header)
        result.wavData = value.bytes
        return result
    }
}
