import DJConnectCore
import Darwin
import Foundation
@preconcurrency import Network

@MainActor
protocol DJConnectLocalDeviceServerDelegate: AnyObject {
    func localDeviceServerDidStart(localURL: String)
    func localDeviceServerDidStop(error: String?)
    func localDeviceServerPairingInfo() -> DJConnectLocalDeviceServer.PairingInfo
    func localDeviceServerPair(payload: DJConnectLocalDeviceServer.PairPayload) -> DJConnectLocalDeviceServer.JSON
    func localDeviceServerCommand(payload: DJConnectLocalDeviceServer.JSON) -> DJConnectLocalDeviceServer.JSON
    func localDeviceServerDJResponse(payload: DJConnectLocalDeviceServer.JSON) -> DJConnectLocalDeviceServer.JSON
}

final class DJConnectLocalDeviceServer: @unchecked Sendable {
    typealias JSON = [String: Any]

    struct PairingInfo: Sendable {
        var deviceID: String
        var deviceName: String
        var clientType: DJConnectClientType
        var firmware: String
        var appVersion: String?
        var platform: DJConnectPlatform
        var pairCode: String
        var localURL: String?
    }

    struct PairPayload: Sendable {
        var pairCode: String?
        var deviceToken: String?
        var haLocalURL: String?
        var haRemoteURL: String?
        var deviceLanguage: String?
        var assistPipelineID: String?
    }

    weak var delegate: DJConnectLocalDeviceServerDelegate?
    private let queue = DispatchQueue(label: "nl.pcvantol.djconnect.local-device-server")
    private var listener: NWListener?
    private var localURL: String?

    func start(deviceID: String) {
        guard listener == nil else {
            return
        }

        do {
            let listener = try NWListener(using: .tcp, on: 0)
            listener.service = NWListener.Service(name: deviceID, type: "_djconnect._tcp")
            listener.stateUpdateHandler = { [weak self] state in
                self?.handle(state: state, deviceID: deviceID)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            Task { @MainActor [weak self] in
                self?.delegate?.localDeviceServerDidStop(error: error.localizedDescription)
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(state: NWListener.State, deviceID: String) {
        switch state {
        case .ready:
            guard let port = listener?.port?.rawValue else {
                return
            }
            let host = Self.primaryIPv4Address() ?? "\(deviceID).local"
            let url = "http://\(host):\(port)"
            localURL = url
            Task { @MainActor [weak self] in
                self?.delegate?.localDeviceServerDidStart(localURL: url)
            }
        case let .failed(error):
            Task { @MainActor [weak self] in
                self?.delegate?.localDeviceServerDidStop(error: error.localizedDescription)
            }
        case .cancelled:
            Task { @MainActor [weak self] in
                self?.delegate?.localDeviceServerDidStop(error: nil)
            }
        default:
            break
        }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection: connection, buffer: Data())
    }

    private func receive(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            if let error {
                self.send(response: self.response(status: 500, json: ["success": false, "error": error.localizedDescription]), on: connection)
                return
            }
            var updated = buffer
            if let data {
                updated.append(data)
            }
            if let request = Self.parseRequest(updated) {
                self.route(request: request, connection: connection)
            } else if isComplete {
                self.send(response: self.response(status: 400, json: ["success": false, "error": "invalid_request"]), on: connection)
            } else {
                self.receive(connection: connection, buffer: updated)
            }
        }
    }

    private func route(request: HTTPRequest, connection: NWConnection) {
        Task { @MainActor [weak self] in
            guard let self else {
                connection.cancel()
                return
            }

            let result: (Int, JSON)
            switch (request.method, request.path) {
            case ("GET", "/api/device/info"),
                 ("GET", "/api/device/status"),
                 ("GET", "/api/device/pairing-info"),
                 ("GET", "/api/device/pairing_info"),
                 ("GET", "/api/djconnect/device/info"),
                 ("GET", "/api/djconnect/device/status"),
                 ("GET", "/api/djconnect/device/pairing-info"),
                 ("GET", "/api/djconnect/device/pairing_info"):
                result = (200, self.pairingInfoJSON())
            case ("POST", "/api/device/pair"), ("POST", "/api/djconnect/device/pair"):
                result = (200, self.delegate?.localDeviceServerPair(payload: Self.pairPayload(from: request.json)) ?? ["success": false])
            case ("POST", "/api/device/status"), ("POST", "/api/djconnect/device/status"):
                result = (200, self.delegate?.localDeviceServerCommand(payload: ["command": "status"]) ?? ["success": false])
            case ("POST", "/api/device/command"), ("POST", "/api/djconnect/device/command"):
                result = (200, self.delegate?.localDeviceServerCommand(payload: request.json) ?? ["success": false])
            case ("POST", "/api/device/dj_response"), ("POST", "/api/djconnect/device/dj_response"):
                result = (200, self.delegate?.localDeviceServerDJResponse(payload: request.json) ?? ["success": false])
            case ("POST", "/api/device/reboot"), ("POST", "/api/device/forget"), ("POST", "/api/device/ota"):
                result = (200, ["success": true, "client_type": self.delegate?.localDeviceServerPairingInfo().clientType.rawValue ?? "ios"])
            default:
                result = (404, ["success": false, "error": "not_found"])
            }

            self.send(response: self.response(status: result.0, json: result.1), on: connection)
        }
    }

    @MainActor
    private func pairingInfoJSON() -> JSON {
        guard let info = delegate?.localDeviceServerPairingInfo() else {
            return ["success": false, "error": "not_ready"]
        }
        return [
            "success": true,
            "device_id": info.deviceID,
            "device_name": info.deviceName,
            "client_type": info.clientType.rawValue,
            "firmware": info.firmware,
            "app_version": info.appVersion ?? info.firmware,
            "platform": info.platform.rawValue,
            "state": "online",
            "status": "online",
            "ha_pairing_status": "pairing",
            "pair_code": info.pairCode,
            "pairing_token": info.pairCode,
            "pairing_code": info.pairCode,
            "code": info.pairCode,
            "local_url": info.localURL ?? localURL ?? ""
        ]
    }

    private func response(status: Int, json: JSON) -> Data {
        let body = (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()
        let reason = status == 200 ? "OK" : status == 404 ? "Not Found" : "Error"
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: application/json\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n\r\n"
        return Data(header.utf8) + body
    }

    private func send(response: Data, on connection: NWConnection) {
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func pairPayload(from json: JSON) -> PairPayload {
        PairPayload(
            pairCode: Self.firstString(json, keys: ["pair_code", "pairing_token", "pairing_code", "code", "pin"]),
            deviceToken: Self.firstString(json, keys: ["device_token", "token", "bearer_token", "access_token"]),
            haLocalURL: json["ha_local_url"] as? String,
            haRemoteURL: json["ha_remote_url"] as? String,
            deviceLanguage: (json["device_language"] as? String) ?? (json["language"] as? String),
            assistPipelineID: json["assist_pipeline_id"] as? String
        )
    }

    private static func firstString(_ json: JSON, keys: [String]) -> String? {
        for key in keys {
            if let value = json[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }

    private static func parseRequest(_ data: Data) -> HTTPRequest? {
        guard let text = String(data: data, encoding: .utf8), let headerRange = text.range(of: "\r\n\r\n") else {
            return nil
        }
        let header = String(text[..<headerRange.lowerBound])
        let lines = header.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return nil
        }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return nil
        }
        let bodyStart = text.distance(from: text.startIndex, to: headerRange.upperBound)
        let contentLength = lines
            .dropFirst()
            .compactMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, parts[0].lowercased() == "content-length" else {
                    return nil
                }
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
            .first ?? 0
        guard data.count >= bodyStart + contentLength else {
            return nil
        }
        let body = data.subdata(in: bodyStart..<(bodyStart + contentLength))
        let json = (try? JSONSerialization.jsonObject(with: body)) as? JSON ?? [:]
        return HTTPRequest(method: String(parts[0]), path: String(parts[1].split(separator: "?").first ?? ""), json: json)
    }

    private static func primaryIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var fallback: String?
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let interface = current.pointee
            guard
                interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
                (interface.ifa_flags & UInt32(IFF_LOOPBACK)) == 0
            else {
                continue
            }

            var address = interface.ifa_addr.pointee
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                &address,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else {
                continue
            }

            let bytes = host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            let value = String(decoding: bytes, as: UTF8.self)
            let name = String(cString: interface.ifa_name)
            if name == "en0" {
                return value
            }
            fallback = fallback ?? value
        }
        return fallback
    }
}

private struct HTTPRequest: @unchecked Sendable {
    var method: String
    var path: String
    var json: DJConnectLocalDeviceServer.JSON
}
