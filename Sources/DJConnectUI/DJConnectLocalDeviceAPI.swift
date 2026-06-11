import DJConnectCore
import Darwin
import Foundation
import Network

public struct DJConnectLocalDeviceAPIInfo: Sendable {
    public var identity: DJConnectIdentity
    public var pairingToken: String
    public var pairingStatus: DJConnectPairingStatus
    public var localURL: String?

    public init(
        identity: DJConnectIdentity,
        pairingToken: String,
        pairingStatus: DJConnectPairingStatus,
        localURL: String? = nil
    ) {
        self.identity = identity
        self.pairingToken = pairingToken
        self.pairingStatus = pairingStatus
        self.localURL = localURL
    }
}

public struct DJConnectLocalPairRequest: Decodable, Sendable {
    public var pairCode: String?
    public var pairingCode: String?
    public var pairingToken: String?
    public var deviceID: String?
    public var clientType: DJConnectClientType?
    public var deviceToken: String?
    public var token: String?
    public var bearerToken: String?
    public var haLocalURL: String?
    public var haRemoteURL: String?
    public var deviceLanguage: String?
    public var language: String?
    public var assistPipelineID: String?

    public var resolvedPairCode: String? {
        pairCode ?? pairingCode ?? pairingToken
    }

    public var resolvedDeviceToken: String? {
        deviceToken ?? bearerToken ?? token
    }

    enum CodingKeys: String, CodingKey {
        case pairCode = "pair_code"
        case pairingCode = "pairing_code"
        case pairingToken = "pairing_token"
        case deviceID = "device_id"
        case clientType = "client_type"
        case deviceToken = "device_token"
        case token
        case bearerToken = "bearer_token"
        case haLocalURL = "ha_local_url"
        case haRemoteURL = "ha_remote_url"
        case deviceLanguage = "device_language"
        case language
        case assistPipelineID = "assist_pipeline_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pairCode = try Self.decodeStringIfPresent(from: container, forKey: .pairCode)
        pairingCode = try Self.decodeStringIfPresent(from: container, forKey: .pairingCode)
        pairingToken = try Self.decodeStringIfPresent(from: container, forKey: .pairingToken)
        deviceID = try Self.decodeStringIfPresent(from: container, forKey: .deviceID)
        if let rawClientType = try Self.decodeStringIfPresent(from: container, forKey: .clientType) {
            clientType = DJConnectClientType(rawValue: rawClientType.lowercased())
        }
        deviceToken = try Self.decodeStringIfPresent(from: container, forKey: .deviceToken)
        token = try Self.decodeStringIfPresent(from: container, forKey: .token)
        bearerToken = try Self.decodeStringIfPresent(from: container, forKey: .bearerToken)
        haLocalURL = try Self.decodeStringIfPresent(from: container, forKey: .haLocalURL)
        haRemoteURL = try Self.decodeStringIfPresent(from: container, forKey: .haRemoteURL)
        deviceLanguage = try Self.decodeStringIfPresent(from: container, forKey: .deviceLanguage)
        language = try Self.decodeStringIfPresent(from: container, forKey: .language)
        assistPipelineID = try Self.decodeStringIfPresent(from: container, forKey: .assistPipelineID)
    }

    private static func decodeStringIfPresent(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}

public struct DJConnectLocalCommandRequest: Decodable, Sendable {
    public var command: String?
    public var value: DJConnectCommandValue?
    public var play: Bool?
    public var language: String?
    public var logLevel: String?
    public var voiceEnabled: Bool?
    public var localResponseAudioEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case command
        case value
        case play
        case language
        case logLevel = "log_level"
        case voiceEnabled = "voice_enabled"
        case localResponseAudioEnabled = "local_response_audio_enabled"
    }
}

public struct DJConnectLocalDJResponseRequest: Decodable, Sendable {
    public var text: String?
    public var djText: String?
    public var audioURL: String?
    public var audioType: String?

    enum CodingKeys: String, CodingKey {
        case text
        case djText = "dj_text"
        case audioURL = "audio_url"
        case audioType = "audio_type"
    }
}

public struct DJConnectLocalDeviceAPIResponse: Encodable, Sendable {
    public var success: Bool
    public var error: String?
    public var message: String?
    public var data: [String: String]?
    public var deviceID: String?
    public var clientType: String?
    public var paired: Bool?

    public init(
        success: Bool,
        error: String? = nil,
        message: String? = nil,
        data: [String: String]? = nil,
        deviceID: String? = nil,
        clientType: String? = nil,
        paired: Bool? = nil
    ) {
        self.success = success
        self.error = error
        self.message = message
        self.data = data
        self.deviceID = deviceID
        self.clientType = clientType
        self.paired = paired
    }

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case message
        case data
        case deviceID = "device_id"
        case clientType = "client_type"
        case paired
    }
}

public struct DJConnectLocalDeviceInfoResponse: Encodable, Sendable {
    public var deviceID: String
    public var deviceName: String
    public var clientType: String
    public var firmware: String
    public var appVersion: String
    public var platform: String
    public var paired: Bool
    public var localURL: String
    public var pairCode: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case clientType = "client_type"
        case firmware
        case appVersion = "app_version"
        case platform
        case paired
        case localURL = "local_url"
        case pairCode = "pair_code"
    }
}

public final class DJConnectLocalDeviceAPI: @unchecked Sendable {
    public typealias InfoProvider = @Sendable () async -> DJConnectLocalDeviceAPIInfo
    public typealias TokenProvider = @Sendable () async -> String?
    public typealias PairHandler = @Sendable (DJConnectLocalPairRequest) async -> DJConnectLocalDeviceAPIResponse
    public typealias CommandHandler = @Sendable (DJConnectLocalCommandRequest) async -> DJConnectLocalDeviceAPIResponse
    public typealias DJResponseHandler = @Sendable (DJConnectLocalDJResponseRequest) async -> DJConnectLocalDeviceAPIResponse
    public typealias ForgetHandler = @Sendable () async -> DJConnectLocalDeviceAPIResponse
    public typealias URLHandler = @Sendable (String?) async -> Void
    public typealias LogHandler = @Sendable (String) async -> Void

    private let infoProvider: InfoProvider
    private let tokenProvider: TokenProvider
    private let pairHandler: PairHandler
    private let commandHandler: CommandHandler
    private let djResponseHandler: DJResponseHandler
    private let forgetHandler: ForgetHandler
    private let urlHandler: URLHandler
    private let logHandler: LogHandler
    private let preferredPort: UInt16?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "nl.pcvantol.djconnect.local-device-api")
    private var listener: NWListener?
    private var localURL: String?

    public init(
        infoProvider: @escaping InfoProvider,
        tokenProvider: @escaping TokenProvider,
        pairHandler: @escaping PairHandler,
        commandHandler: @escaping CommandHandler,
        djResponseHandler: @escaping DJResponseHandler,
        forgetHandler: @escaping ForgetHandler,
        urlHandler: @escaping URLHandler,
        logHandler: @escaping LogHandler,
        preferredPort: UInt16? = nil
    ) {
        self.infoProvider = infoProvider
        self.tokenProvider = tokenProvider
        self.pairHandler = pairHandler
        self.commandHandler = commandHandler
        self.djResponseHandler = djResponseHandler
        self.forgetHandler = forgetHandler
        self.urlHandler = urlHandler
        self.logHandler = logHandler
        self.preferredPort = preferredPort
    }

    public func start() {
        guard listener == nil else {
            return
        }

        do {
            let listener: NWListener
            if let preferredPort, let port = NWEndpoint.Port(rawValue: preferredPort) {
                listener = try NWListener(using: .tcp, on: port)
            } else {
                listener = try NWListener(using: .tcp, on: .any)
            }
            listener.service = NWListener.Service(
                name: nil,
                type: "_djconnect._tcp",
                txtRecord: NWTXTRecord(["api": "device"])
            )
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    Task { await self.publishReadyURL() }
                case let .failed(error):
                    Task { await self.logHandler("Local device API failed: \(error.localizedDescription)") }
                    self.stop()
                case .cancelled:
                    Task { await self.urlHandler(nil) }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            Task { await logHandler("Local device API could not start: \(error.localizedDescription)") }
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        localURL = nil
        Task { await urlHandler(nil) }
    }

    private func publishReadyURL() async {
        guard let listener, let port = listener.port else {
            return
        }
        let info = await infoProvider()
        let host = Self.localIPv4Address() ?? "\(info.identity.deviceID).local"
        localURL = "http://\(host):\(port.rawValue)"
        listener.service = NWListener.Service(
            name: info.identity.deviceID,
            type: "_djconnect._tcp",
            txtRecord: NWTXTRecord([
                "name": info.identity.deviceName,
                "device_id": info.identity.deviceID,
                "version": info.identity.firmware,
                "paired": info.pairingStatus == .paired ? "true" : "false",
                "api": "device",
                "model": "apple-app",
                "client_type": info.identity.clientType.rawValue
            ])
        )
        await urlHandler(localURL)
        await logHandler("Local device API started at \(localURL ?? "unknown")")
    }

    private static func localIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var fallback: String?
        var interface = firstInterface
        while true {
            defer {
                if let next = interface.pointee.ifa_next {
                    interface = next
                }
            }

            let flags = Int32(interface.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp, !isLoopback, let address = interface.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else {
                if interface.pointee.ifa_next == nil { break }
                continue
            }

            let name = String(cString: interface.pointee.ifa_name)
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else {
                if interface.pointee.ifa_next == nil { break }
                continue
            }

            let ipAddress = hostname.withUnsafeBufferPointer { buffer in
                let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                return String(decoding: bytes, as: UTF8.self)
            }
            if name == "en0" || name == "en1" {
                return ipAddress
            }
            fallback = fallback ?? ipAddress

            if interface.pointee.ifa_next == nil {
                break
            }
        }
        return fallback
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, data: Data())
    }

    private func receive(on connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] chunk, _, isComplete, error in
            guard let self else { return }
            if let error {
                Task { await self.logHandler("Local device API connection failed: \(error.localizedDescription)") }
                connection.cancel()
                return
            }

            var buffer = data
            if let chunk {
                buffer.append(chunk)
            }

            if let request = Self.parseRequest(buffer) {
                Task {
                    let response = await self.route(request)
                    connection.send(content: response, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
                return
            }

            if isComplete {
                connection.cancel()
                return
            }

            self.receive(on: connection, data: buffer)
        }
    }

    private func route(_ request: HTTPRequest) async -> Data {
        let path = normalizedPath(request.path)
        await logHandler("Local device API \(request.method) \(path)")
        func loggedResponse<T: Encodable>(_ value: T, statusCode: Int = 200) async -> Data {
            await logHandler("Local device API \(request.method) \(path) -> HTTP \(statusCode)")
            return response(value, statusCode: statusCode)
        }
        switch (request.method, path) {
        case ("GET", "/api/device/info"):
            return await loggedResponse(await infoPayload(includePairingCode: false))
        case ("GET", "/api/device/pairing-info"):
            return await loggedResponse(await infoPayload(includePairingCode: true))
        case ("POST", "/api/device/pair"):
            return await decodeAndRespond(request.body, as: DJConnectLocalPairRequest.self, requestSummary: "\(request.method) \(path)", handler: pairHandler)
        case ("POST", "/api/device/command"):
            guard await isAuthorized(request) else {
                return await loggedResponse(DJConnectLocalDeviceAPIResponse(success: false, error: "unauthorized", message: "Missing or invalid bearer token."), statusCode: 401)
            }
            return await decodeAndRespond(request.body, as: DJConnectLocalCommandRequest.self, requestSummary: "\(request.method) \(path)", handler: commandHandler)
        case ("POST", "/api/device/dj_response"):
            guard await isAuthorized(request) else {
                return await loggedResponse(DJConnectLocalDeviceAPIResponse(success: false, error: "unauthorized", message: "Missing or invalid bearer token."), statusCode: 401)
            }
            return await decodeAndRespond(request.body, as: DJConnectLocalDJResponseRequest.self, requestSummary: "\(request.method) \(path)", handler: djResponseHandler)
        case ("POST", "/api/device/forget"):
            guard await isAuthorized(request) else {
                return await loggedResponse(DJConnectLocalDeviceAPIResponse(success: false, error: "unauthorized", message: "Missing or invalid bearer token."), statusCode: 401)
            }
            return await loggedResponse(await forgetHandler())
        default:
            return await loggedResponse(DJConnectLocalDeviceAPIResponse(success: false, error: "not_found", message: "Unsupported local DJConnect endpoint."), statusCode: 404)
        }
    }

    private func decodeAndRespond<T: Decodable>(
        _ body: Data,
        as type: T.Type,
        requestSummary: String,
        handler: (T) async -> DJConnectLocalDeviceAPIResponse
    ) async -> Data {
        do {
            let value = try decoder.decode(type, from: body)
            let responseValue = await handler(value)
            await logHandler("Local device API \(requestSummary) -> HTTP 200")
            return response(responseValue)
        } catch {
            let typeName = String(describing: type)
            await logHandler("Local device API rejected invalid JSON for \(typeName): \(error.localizedDescription)")
            await logHandler("Local device API \(requestSummary) -> HTTP 400")
            return response(DJConnectLocalDeviceAPIResponse(success: false, error: "bad_request", message: "Invalid JSON body."), statusCode: 400)
        }
    }

    private func normalizedPath(_ path: String) -> String {
        guard path.count > 1, path.hasSuffix("/") else {
            return path
        }
        return String(path.dropLast())
    }

    private func isAuthorized(_ request: HTTPRequest) async -> Bool {
        guard let expected = await tokenProvider(), !expected.isEmpty else {
            return false
        }
        guard let header = request.headers["authorization"] else {
            return false
        }
        return header == "Bearer \(expected)"
    }

    private func infoPayload(includePairingCode: Bool) async -> DJConnectLocalDeviceInfoResponse {
        let info = await infoProvider()
        return DJConnectLocalDeviceInfoResponse(
            deviceID: info.identity.deviceID,
            deviceName: info.identity.deviceName,
            clientType: info.identity.clientType.rawValue,
            firmware: info.identity.firmware,
            appVersion: info.identity.appVersion ?? info.identity.firmware,
            platform: info.identity.platform.rawValue,
            paired: info.pairingStatus == .paired,
            localURL: localURL ?? info.localURL ?? "",
            pairCode: includePairingCode ? info.pairingToken : nil
        )
    }

    private func response<T: Encodable>(_ value: T, statusCode: Int = 200) -> Data {
        let body = (try? encoder.encode(value)) ?? Data(#"{"success":false,"error":"encoding_failed"}"#.utf8)
        let reason = statusCode == 200 ? "OK" : "Error"
        var headers = "HTTP/1.1 \(statusCode) \(reason)\r\n"
        headers += "Content-Type: application/json\r\n"
        headers += "Content-Length: \(body.count)\r\n"
        headers += "Connection: close\r\n\r\n"
        return Data(headers.utf8) + body
    }

    private struct HTTPRequest: Sendable {
        var method: String
        var path: String
        var headers: [String: String]
        var body: Data
    }

    private static func parseRequest(_ data: Data) -> HTTPRequest? {
        guard let separator = data.firstRange(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }
        let headerData = data[..<separator.lowerBound]
        let bodyStart = separator.upperBound
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            return nil
        }
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else {
            return nil
        }
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else {
            return nil
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else {
                continue
            }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            headers[name] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard data.count >= bodyStart + contentLength else {
            return nil
        }
        let body = Data(data[bodyStart..<(bodyStart + contentLength)])
        let path = requestParts[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        return HTTPRequest(method: String(requestParts[0]), path: path, headers: headers, body: body)
    }
}

private extension Data {
    static func + (lhs: Data, rhs: Data) -> Data {
        var data = lhs
        data.append(rhs)
        return data
    }
}
