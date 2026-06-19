import Darwin
import Foundation
#if os(watchOS)
import Network
#endif

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
    private let queue = DispatchQueue(label: "dev.djconnect.local-device-api")
    private var listenSocket: Int32 = -1
    private var activeConnections: Set<Int32> = []
    #if os(watchOS)
    private var networkListener: NWListener?
    #else
    private var bonjourService: NetService?
    #endif
    private var port: UInt16?
    private var localURL: String?
    private var isBonjourAdvertisingEnabled: Bool

    public init(
        infoProvider: @escaping InfoProvider,
        tokenProvider: @escaping TokenProvider,
        pairHandler: @escaping PairHandler,
        commandHandler: @escaping CommandHandler,
        djResponseHandler: @escaping DJResponseHandler,
        forgetHandler: @escaping ForgetHandler,
        urlHandler: @escaping URLHandler,
        logHandler: @escaping LogHandler,
        preferredPort: UInt16? = nil,
        advertiseBonjour: Bool = true
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
        self.isBonjourAdvertisingEnabled = advertiseBonjour
    }

    public func start() {
        guard listenSocket < 0 else {
            return
        }

        #if os(watchOS)
        Task { await startNetworkListener() }
        return
        #else
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            Task { await logHandler("Local device API could not create socket: errno \(errno)") }
            return
        }

        var yes: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(preferredPort ?? 0).bigEndian
        address.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            let bindErrno = errno
            close(socketFD)
            Task { await logHandler("Local device API could not bind socket: errno \(bindErrno)") }
            return
        }

        guard listen(socketFD, SOMAXCONN) == 0 else {
            let listenErrno = errno
            close(socketFD)
            Task { await logHandler("Local device API could not listen on socket: errno \(listenErrno)") }
            return
        }

        guard let boundPort = Self.boundPort(for: socketFD) else {
            close(socketFD)
            Task { await logHandler("Local device API could not resolve bound port") }
            return
        }

        listenSocket = socketFD
        port = boundPort
        Task { await publishReadyURL() }
        queue.async { [weak self] in
            self?.acceptLoop(socketFD: socketFD)
        }
        #endif
    }

    public func stop() {
        #if os(watchOS)
        networkListener?.cancel()
        networkListener = nil
        listenSocket = -1
        port = nil
        localURL = nil
        Task { await urlHandler(nil) }
        return
        #else
        let socketFD = listenSocket
        listenSocket = -1
        port = nil
        stopBonjourService()
        for connection in activeConnections {
            shutdown(connection, SHUT_RDWR)
            close(connection)
        }
        activeConnections.removeAll()
        if socketFD >= 0 {
            shutdown(socketFD, SHUT_RDWR)
            close(socketFD)
        }
        localURL = nil
        Task { await urlHandler(nil) }
        #endif
    }

    public func setBonjourAdvertisingEnabled(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self, self.isBonjourAdvertisingEnabled != enabled else {
                return
            }
            self.isBonjourAdvertisingEnabled = enabled
            if enabled {
                Task { await self.publishReadyURL(logStart: false) }
            } else {
                self.stopBonjourService()
                Task { await self.logHandler("Local device API mDNS advertising disabled") }
            }
        }
    }

    private func publishReadyURL(logStart: Bool = true) async {
        guard let port else {
            return
        }
        let info = await infoProvider()
        let host = Self.localIPv4Address() ?? "\(info.identity.deviceID).local"
        let readyURL = "http://\(host):\(port)"
        localURL = readyURL
        if isBonjourAdvertisingEnabled {
            publishBonjourService(for: info)
        }
        await urlHandler(readyURL)
        if logStart {
            await logHandler("Local device API started at \(readyURL)")
        } else {
            await logHandler("Local device API mDNS advertising enabled")
        }
    }

    private func publishBonjourService(for info: DJConnectLocalDeviceAPIInfo) {
        guard let port else { return }
        let advertisedLocalURL = localURL ?? info.localURL ?? ""
        let txtRecord = Self.bonjourTXTRecord(for: info, localURL: advertisedLocalURL)
        #if os(watchOS)
        networkListener?.service = NWListener.Service(
            name: info.identity.deviceID,
            type: "_djconnect._tcp",
            txtRecord: NWTXTRecord(txtRecord.mapValues { String(decoding: $0, as: UTF8.self) })
        )
        #else
        stopBonjourService()
        let service = NetService(domain: "local.", type: "_djconnect._tcp.", name: info.identity.deviceID, port: Int32(port))
        service.setTXTRecord(NetService.data(fromTXTRecord: txtRecord))
        service.publish()
        bonjourService = service
        #endif
    }

    private static func bonjourTXTRecord(for info: DJConnectLocalDeviceAPIInfo, localURL: String) -> [String: Data] {
        [
            "name": info.identity.deviceName,
            "device_id": info.identity.deviceID,
            "version": info.identity.firmware,
            "app_version": info.identity.appVersion ?? info.identity.firmware,
            "paired": info.pairingStatus == .paired ? "true" : "false",
            "local_url": localURL,
            "pair_code": info.pairingToken,
            "api": "device",
            "path": "/api/device/info",
            "pairing_path": "/api/device/pairing-info",
            "pair_path": "/api/device/pair",
            "model": "apple-app",
            "platform": info.identity.platform.rawValue,
            "client_type": info.identity.clientType.rawValue
        ].mapValues { Data($0.utf8) }
    }

    private func stopBonjourService() {
        #if os(watchOS)
        networkListener?.service = nil
        #else
        bonjourService?.stop()
        bonjourService = nil
        #endif
    }

    #if os(watchOS)
    private func startNetworkListener() async {
        guard networkListener == nil else {
            return
        }
        do {
            let info = await infoProvider()
            let listenerPort = NWEndpoint.Port(rawValue: preferredPort ?? 0) ?? .any
            let listener = try NWListener(using: .tcp, on: listenerPort)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleNetworkConnection(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard let port = listener.port else {
                        Task { await self.logHandler("Local device API listener ready without a port") }
                        return
                    }
                    self.listenSocket = 0
                    self.port = UInt16(port.rawValue)
                    let host = Self.localIPv4Address() ?? "\(info.identity.deviceID).local"
                    let readyURL = "http://\(host):\(port.rawValue)"
                    self.localURL = readyURL
                    if self.isBonjourAdvertisingEnabled {
                        self.publishBonjourService(for: info)
                    }
                    Task {
                        await self.urlHandler(readyURL)
                        await self.logHandler("Local device API started at \(readyURL)")
                    }
                case let .failed(error):
                    Task { await self.logHandler("Local device API listener failed: \(error.localizedDescription)") }
                case .cancelled:
                    self.listenSocket = -1
                    self.port = nil
                    self.localURL = nil
                    Task { await self.urlHandler(nil) }
                default:
                    break
                }
            }
            networkListener = listener
            listener.start(queue: queue)
        } catch {
            await logHandler("Local device API could not start Network listener: \(error.localizedDescription)")
        }
    }

    private func handleNetworkConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveNetworkRequest(from: connection, buffer: Data())
    }

    private func receiveNetworkRequest(from connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var nextBuffer = buffer
            if let data, !data.isEmpty {
                nextBuffer.append(data)
                if let request = Self.parseRequest(nextBuffer) {
                    Task {
                        let response = await self.route(request, remote: "network-framework")
                        connection.send(content: response, completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    }
                    return
                }
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receiveNetworkRequest(from: connection, buffer: nextBuffer)
        }
    }
    #endif

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

    private static func boundPort(for socketFD: Int32) -> UInt16? {
        var address = sockaddr_in()
        var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(socketFD, sockaddrPointer, &addressLength)
            }
        }
        guard result == 0 else {
            return nil
        }
        return UInt16(bigEndian: address.sin_port)
    }

    private static func remoteDescription(_ storage: sockaddr_storage, length: socklen_t) -> String {
        var storage = storage
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var service = [CChar](repeating: 0, count: Int(NI_MAXSERV))
        let result = withUnsafePointer(to: &storage) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getnameinfo(
                    sockaddrPointer,
                    length,
                    &host,
                    socklen_t(host.count),
                    &service,
                    socklen_t(service.count),
                    NI_NUMERICHOST | NI_NUMERICSERV
                )
            }
        }
        guard result == 0 else {
            return "unknown"
        }
        let hostString = host.withUnsafeBufferPointer { buffer in
            String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        let serviceString = service.withUnsafeBufferPointer { buffer in
            String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return "\(hostString):\(serviceString)"
    }

    private func acceptLoop(socketFD: Int32) {
        while listenSocket == socketFD {
            var remoteAddress = sockaddr_storage()
            var remoteAddressLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let connection = withUnsafeMutablePointer(to: &remoteAddress) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    accept(socketFD, sockaddrPointer, &remoteAddressLength)
                }
            }

            guard connection >= 0 else {
                if listenSocket == socketFD {
                    let acceptErrno = errno
                    Task { await logHandler("Local device API accept failed: errno \(acceptErrno)") }
                }
                continue
            }

            activeConnections.insert(connection)
            let remote = Self.remoteDescription(remoteAddress, length: remoteAddressLength)
            Task { await logHandler("Local device API accepted connection remote=\(remote)") }
            handleAcceptedSocket(connection, remote: remote)
        }
    }

    private func handleAcceptedSocket(_ connection: Int32, remote: String) {
        var yes: Int32 = 1
        setsockopt(connection, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var buffer = Data()
        var scratch = [UInt8](repeating: 0, count: 16_384)

        while true {
            let count = recv(connection, &scratch, scratch.count, 0)
            if count > 0 {
                buffer.append(contentsOf: scratch.prefix(count))
                if let request = Self.parseRequest(buffer) {
                    Task {
                        let response = await self.route(request, remote: remote)
                        self.write(response, to: connection)
                        self.close(connection)
                    }
                    return
                }
                continue
            }

            if count == 0 {
                Task { await logHandler("Local device API connection closed before a complete HTTP request was received remote=\(remote)") }
            } else {
                let readErrno = errno
                Task { await logHandler("Local device API connection read failed remote=\(remote) errno=\(readErrno)") }
            }
            close(connection)
            return
        }
    }

    private func write(_ data: Data, to connection: Int32) {
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < data.count {
                let sent = send(connection, baseAddress.advanced(by: offset), data.count - offset, 0)
                guard sent > 0 else {
                    let writeErrno = errno
                    Task { await logHandler("Local device API connection write failed: errno \(writeErrno)") }
                    return
                }
                offset += sent
            }
        }
    }

    private func close(_ connection: Int32) {
        Darwin.close(connection)
        activeConnections.remove(connection)
    }

    private func route(_ request: HTTPRequest, remote: String) async -> Data {
        let path = normalizedPath(request.path)
        let host = request.headers["host"] ?? "missing"
        await logHandler("Local device API request remote=\(remote) method=\(request.method) path=\(path) host=\(host)")
        func loggedResponse<T: Encodable>(_ value: T, statusCode: Int = 200) async -> Data {
            await logHandler("Local device API response remote=\(remote) method=\(request.method) path=\(path) host=\(host) status=\(statusCode)")
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
            let statusCode = statusCode(for: responseValue, requestSummary: requestSummary)
            await logHandler("Local device API \(requestSummary) -> HTTP \(statusCode)")
            return response(responseValue, statusCode: statusCode)
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

    private func statusCode(for response: DJConnectLocalDeviceAPIResponse, requestSummary: String) -> Int {
        guard !response.success else {
            return 200
        }
        if requestSummary == "POST /api/device/pair" {
            return 500
        }
        return 200
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
