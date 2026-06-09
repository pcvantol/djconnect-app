import Combine
import DJConnectCore
import Foundation
import OSLog

public enum DJConnectAppLogLevel: String, CaseIterable, Sendable {
    case debug
    case info
    case warning
    case error

    var priority: Int {
        switch self {
        case .debug:
            0
        case .info:
            1
        case .warning:
            2
        case .error:
            3
        }
    }

    static func parse(_ rawValue: String) -> DJConnectAppLogLevel {
        DJConnectAppLogLevel(rawValue: rawValue.lowercased()) ?? .info
    }
}

public struct DJConnectDiagnosticLogLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

@MainActor
public final class DJConnectAppModel: ObservableObject {
    @Published public var homeAssistantURL = "" {
        didSet { defaults.set(homeAssistantURL, forKey: homeAssistantURLKey) }
    }
    @Published public var pairingToken = ""
    @Published public var pairingStatus: DJConnectPairingStatus = .unpaired
    @Published public var isConnected = false
    @Published public var isPairing = false
    @Published public var backendAvailable = true
    @Published public var updateRequiredMessage: String?
    @Published public var pairingMessage: String?
    @Published public var playback: DJConnectPlayback?
    @Published public var queue: [String] = []
    @Published public var playlists: [String] = []
    @Published public var selectedOutput = "Not selected"
    @Published public var djResponseText = ""
    @Published public var logLevel = "info" {
        didSet {
            defaults.set(logLevel, forKey: logLevelKey)
            log(.info, "Log level changed to \(logLevel)")
        }
    }
    @Published public var language = "nl" {
        didSet { defaults.set(language, forKey: languageKey) }
    }
    @Published public var voiceEnabled = true
    @Published public var localResponseAudioEnabled = true
    @Published public private(set) var diagnosticLogLines: [DJConnectDiagnosticLogLine] = []
    @Published public private(set) var localDeviceURL: String?

    public let identity: DJConnectIdentity

    private let logger: Logger
    private let localDeviceServer = DJConnectLocalDeviceServer()
    private var pairingTask: Task<Void, Never>?
    private var scheduledPairingTask: Task<Void, Never>?
    private var volumeCommandTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let tokenStore: DJConnectTokenStore
    private let appVersion = "3.0.0"
    private let installIDKey = "DJConnectInstallID"
    private let homeAssistantURLKey = "DJConnectHomeAssistantURL"
    private let pairingTokenKey = "DJConnectPairingToken"
    private let languageKey = "DJConnectLanguage"
    private let logLevelKey = "DJConnectLogLevel"
    private let maxDiagnosticLogLines = 120

    public var volume: Double {
        get { Double(playback?.volumePercent ?? 0) }
        set {
            var updated = playback ?? DJConnectPlayback()
            updated.volumePercent = Int(newValue.rounded())
            playback = updated
        }
    }

    public var isPlaying: Bool {
        playback?.isPlaying ?? false
    }

    public init(
        playback: DJConnectPlayback? = nil,
        defaults: UserDefaults = .standard,
        tokenStore: DJConnectTokenStore? = nil
    ) {
        self.defaults = defaults
        let resolvedTokenStore = tokenStore ?? DJConnectKeychainTokenStore(service: Self.keychainService)
        self.tokenStore = resolvedTokenStore
        self.identity = Self.makeIdentity(defaults: defaults)
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "nl.pcvantol.djconnect",
            category: "DJConnectApp"
        )
        self.playback = playback
        self.homeAssistantURL = defaults.string(forKey: homeAssistantURLKey) ?? ""
        self.pairingToken = defaults.string(forKey: pairingTokenKey) ?? Self.generatePairingToken()
        self.language = defaults.string(forKey: languageKey) ?? "nl"
        self.logLevel = defaults.string(forKey: logLevelKey) ?? "info"
        defaults.set(pairingToken, forKey: pairingTokenKey)
        if let existingToken = try? resolvedTokenStore.loadToken(), !existingToken.isEmpty {
            pairingStatus = .paired
            isConnected = true
            log(.info, "App started with existing device token for \(identity.clientType.rawValue)")
        } else {
            log(.info, "App started without device token for \(identity.clientType.rawValue)")
        }
        localDeviceServer.delegate = self
        localDeviceServer.start(deviceID: identity.deviceID)
    }

    deinit {
        localDeviceServer.stop()
        scheduledPairingTask?.cancel()
        pairingTask?.cancel()
        volumeCommandTask?.cancel()
    }

    public func schedulePairingWait() {
        guard pairingStatus != .paired else {
            log(.debug, "Ignoring scheduled pairing because device is already paired")
            return
        }

        log(.debug, "Scheduling pairing retry after URL edit")
        scheduledPairingTask?.cancel()
        scheduledPairingTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else {
                return
            }
            self?.startPairingWait()
        }
    }

    public func startPairingWait() {
        guard pairingStatus != .paired else {
            log(.debug, "Ignoring pairing wait because device is already paired")
            return
        }

        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()

        guard let baseURL = Self.normalizedHomeAssistantURL(from: homeAssistantURL) else {
            log(.warning, "Pairing wait cannot start because the Home Assistant URL is invalid")
            pairingMessage = localized(
                english: "Enter your Home Assistant URL, for example 192.168.1.10:8123.",
                dutch: "Vul je Home Assistant URL in, bijvoorbeeld 192.168.1.10:8123."
            )
            pairingStatus = .unpaired
            isConnected = false
            isPairing = false
            return
        }

        let trimmedPairingToken = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let appPairingToken = trimmedPairingToken.isEmpty ? newPairingToken() : trimmedPairingToken

        log(.info, "Starting pairing wait against \(Self.redactedURL(baseURL))")
        pairingTask = Task { [weak self] in
            await self?.waitForHomeAssistantPairing(baseURL: baseURL, pairingToken: appPairingToken)
        }
    }

    public func stopPairingWait() {
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()
        pairingTask = nil
        if pairingStatus == .pairing {
            log(.info, "Pairing wait stopped")
            pairingStatus = .unpaired
            isPairing = false
            pairingMessage = localized(
                english: "Pairing wait stopped.",
                dutch: "Wachten op pairing gestopt."
            )
        }
    }

    private func waitForHomeAssistantPairing(baseURL: URL, pairingToken: String) async {
        isPairing = true
        pairingStatus = .pairing
        log(.info, "Polling Home Assistant pairing endpoint")
        pairingMessage = localized(
            english: "Waiting for Home Assistant to accept code \(pairingToken).",
            dutch: "Wachten tot Home Assistant code \(pairingToken) accepteert."
        )
        defer {
            if pairingStatus != .paired {
                isPairing = false
            }
        }

        while !Task.isCancelled && pairingStatus != .paired {
            let client = DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: tokenStore)
            do {
                _ = try await client.pair(DJConnectPairingPayload(
                    identity: identity,
                    pairingToken: pairingToken,
                    localURL: localDeviceURL
                ))
                log(.info, "Pairing accepted by Home Assistant")
                pairingStatus = .paired
                isConnected = true
                isPairing = false
                pairingMessage = localized(
                    english: "Paired with Home Assistant.",
                    dutch: "Gekoppeld met Home Assistant."
                )
                try await refreshStatus(client: client)
                return
            } catch let error as DJConnectError {
                logPairingError(error)
                if Self.isPairingCodeMismatch(error) {
                    applyPairingCodeMismatch()
                    return
                }
                applyPairingWait(error: error, pairingToken: pairingToken)
            } catch {
                log(.error, "Unexpected pairing error: \(error.localizedDescription)")
                isConnected = false
                pairingMessage = error.localizedDescription
            }

            try? await Task.sleep(for: .seconds(2))
        }
    }

    public func resetPairing() {
        log(.warning, "Resetting pairing and clearing local token")
        scheduledPairingTask?.cancel()
        scheduledPairingTask = nil
        pairingTask?.cancel()
        pairingTask = nil
        try? tokenStore.clearToken()
        defaults.removeObject(forKey: installIDKey)
        _ = newPairingToken()
        pairingStatus = .unpaired
        isConnected = false
        isPairing = false
        pairingMessage = localized(
            english: "Pairing reset.",
            dutch: "Pairing gereset."
        )
    }

    @discardableResult
    public func newPairingToken() -> String {
        let token = Self.generatePairingToken()
        pairingToken = token
        defaults.set(token, forKey: pairingTokenKey)
        log(.info, "Generated a new pairing code")
        return token
    }

    public func rotatePairingTokenAndWait() {
        guard pairingStatus != .paired else {
            return
        }
        _ = newPairingToken()
        startPairingWait()
    }

    public func refresh() {
        log(.debug, "Manual refresh requested")
        Task {
            do {
                try await refreshStatus(client: try makeClient())
            } catch let error as DJConnectError {
                log(.warning, "Refresh failed: \(Self.describe(error))")
                apply(error: error)
            } catch {
                log(.error, "Refresh failed unexpectedly: \(error.localizedDescription)")
                pairingMessage = error.localizedDescription
            }
        }
    }

    public func sendPlaybackCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil
    ) {
        guard updateRequiredMessage == nil else {
            log(.warning, "Command \(command) blocked because an app/integration update is required")
            return
        }
        log(.info, "Sending playback command: \(command)")
        Task {
            await performCommand(command, value: value, play: play)
        }
    }

    public func togglePlayback() {
        sendPlaybackCommand(isPlaying ? "pause" : "play")
    }

    public func commitVolumeChange() {
        volumeCommandTask?.cancel()
        let value = Int(volume.rounded())
        volumeCommandTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            await self?.performCommand("set_volume", value: .int(value))
        }
    }

    public func setShuffle(_ value: Bool) {
        sendPlaybackCommand("set_shuffle", value: .bool(value))
    }

    public func setRepeat(_ value: DJConnectRepeatState) {
        sendPlaybackCommand("set_repeat", value: .string(value.rawValue))
    }

    public func apply(playback: DJConnectPlayback?) {
        self.playback = playback
        selectedOutput = playback?.device?.name ?? selectedOutput
        backendAvailable = true
        updateRequiredMessage = nil
        if let playback {
            let playing = playback.isPlaying.map(String.init) ?? "unknown"
            let volume = playback.volumePercent.map(String.init) ?? "unknown"
            log(.debug, "Applied playback snapshot: playing=\(playing), volume=\(volume)")
        } else {
            log(.debug, "Applied empty playback snapshot")
        }
    }

    public func apply(error: DJConnectError) {
        log(.warning, "Applying app error state: \(Self.describe(error))")
        switch error {
        case let .backendUnavailable(message):
            backendAvailable = false
            djResponseText = message ?? localized(
                english: "Playback backend unavailable",
                dutch: "Playback-backend niet beschikbaar"
            )
        case let .versionMismatch(mismatch):
            updateRequiredMessage = mismatch.message ?? localized(
                english: "DJConnect update required",
                dutch: "DJConnect update vereist"
            )
        case let .authStale(_, message):
            pairingStatus = .stale
            isConnected = false
            pairingMessage = message ?? localized(
                english: "Pairing is stale. Open Home Assistant setup or reset pairing.",
                dutch: "Pairing is verlopen. Open Home Assistant setup of reset pairing."
            )
        case let .routeMissing(message):
            pairingStatus = .stale
            isConnected = false
            pairingMessage = message ?? localized(
                english: "DJConnect route missing in Home Assistant. Check the integration setup.",
                dutch: "DJConnect route ontbreekt in Home Assistant. Controleer de integratie."
            )
        case let .notConfigured(message):
            pairingStatus = .stale
            isConnected = false
            pairingMessage = message ?? localized(
                english: "DJConnect is not configured in Home Assistant.",
                dutch: "DJConnect is niet geconfigureerd in Home Assistant."
            )
        case .missingToken:
            pairingStatus = .stale
            isConnected = false
            pairingMessage = localized(
                english: "Missing DJConnect device token. Reset pairing to set up again.",
                dutch: "DJConnect device-token ontbreekt. Reset pairing om opnieuw te koppelen."
            )
        default:
            break
        }
    }

    private func applyPairingWait(error: DJConnectError, pairingToken: String) {
        isConnected = false

        switch error {
        case .pairingFailed:
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for Home Assistant to accept code \(pairingToken).",
                dutch: "Wachten tot Home Assistant code \(pairingToken) accepteert."
            )
        case let .network(message):
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for Home Assistant: \(message)",
                dutch: "Wachten op Home Assistant: \(message)"
            )
        case .routeMissing:
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for the DJConnect pairing route in Home Assistant.",
                dutch: "Wachten op de DJConnect pairing-route in Home Assistant."
            )
        case let .server(_, message):
            pairingStatus = .pairing
            pairingMessage = message ?? localized(
                english: "Waiting for Home Assistant to finish pairing.",
                dutch: "Wachten tot Home Assistant pairing afrondt."
            )
        case let .versionMismatch(mismatch):
            pairingStatus = .pairing
            updateRequiredMessage = mismatch.message ?? localized(
                english: "DJConnect update required",
                dutch: "DJConnect update vereist"
            )
        default:
            pairingStatus = .pairing
            pairingMessage = localized(
                english: "Waiting for Home Assistant to finish pairing.",
                dutch: "Wachten tot Home Assistant pairing afrondt."
            )
        }
    }

    private func applyPairingCodeMismatch() {
        pairingTask?.cancel()
        pairingTask = nil
        pairingStatus = .stale
        isConnected = false
        isPairing = false
        pairingMessage = localized(
            english: "Home Assistant rejected this pairing code. Tap New Code and enter the current app code in Home Assistant.",
            dutch: "Home Assistant weigert deze koppelcode. Tik op Nieuwe code en vul de actuele app-code in Home Assistant in."
        )
        log(.error, "Pairing stopped because Home Assistant rejected the current code")
    }

    private func refreshStatus(client: DJConnectClient) async throws {
        do {
            log(.debug, "Posting status to Home Assistant")
            let response = try await client.postStatus(
                DJConnectStatusPayload(
                    identity: identity,
                    haPairingStatus: .paired,
                    language: language,
                    logLevel: logLevel,
                    localAudioSupported: true,
                    voiceSupported: voiceEnabled,
                    localURL: localDeviceURL
                )
            )
            apply(playback: response.playback)
            backendAvailable = response.backendAvailable ?? backendAvailable
            log(.debug, "Status refresh succeeded")
        } catch let error as DJConnectError {
            log(.warning, "Status refresh failed: \(Self.describe(error))")
            apply(error: error)
            if case .backendUnavailable = error {
                pairingStatus = .paired
                isConnected = true
            } else {
                throw error
            }
        }
    }

    private func performCommand(
        _ command: String,
        value: DJConnectCommandValue? = nil,
        play: Bool? = nil
    ) async {
        guard updateRequiredMessage == nil else {
            log(.warning, "Command \(command) skipped because update is required")
            return
        }
        do {
            let client = try makeClient()
            log(.debug, "Posting command \(command) to Home Assistant")
            let response = try await client.sendCommand(
                DJConnectCommandPayload(
                    identity: identity,
                    command: command,
                    value: value,
                    play: play
                )
            )
            apply(playback: response.playback)
            backendAvailable = response.backendAvailable ?? backendAvailable
            log(.debug, "Command \(command) succeeded")
        } catch let error as DJConnectError {
            log(.warning, "Command \(command) failed: \(Self.describe(error))")
            apply(error: error)
        } catch {
            log(.error, "Command \(command) failed unexpectedly: \(error.localizedDescription)")
            pairingMessage = error.localizedDescription
        }
    }

    private func makeClient() throws -> DJConnectClient {
        guard let baseURL = Self.normalizedHomeAssistantURL(from: homeAssistantURL) else {
            log(.warning, "Cannot create Home Assistant client because URL is invalid")
            throw DJConnectError.network(message: localized(
                english: "Enter your Home Assistant URL, for example 192.168.1.10:8123.",
                dutch: "Vul je Home Assistant URL in, bijvoorbeeld 192.168.1.10:8123."
            ))
        }
        return DJConnectClient(baseURL: baseURL, identity: identity, tokenStore: tokenStore)
    }

    private func acceptLocalPairing(payload: DJConnectLocalDeviceServer.PairPayload) -> [String: Any] {
        let expectedPairCode = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let reportedPairCode = payload.pairCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard expectedPairCode.isEmpty || reportedPairCode.isEmpty || expectedPairCode == reportedPairCode else {
            log(.warning, "Local pair rejected because pair code did not match")
            return [
                "success": false,
                "error": "invalid_pair_code",
                "message": "Pair code does not match"
            ]
        }

        guard let deviceToken = payload.deviceToken?.trimmingCharacters(in: .whitespacesAndNewlines), !deviceToken.isEmpty else {
            pairingTask?.cancel()
            pairingTask = nil
            scheduledPairingTask?.cancel()
            scheduledPairingTask = nil
            pairingStatus = .paired
            isConnected = true
            isPairing = false
            pairingMessage = localized(
                english: "Paired locally with Home Assistant.",
                dutch: "Lokaal gekoppeld met Home Assistant."
            )
            log(.info, "Local device pairing accepted without device token")
            return [
                "success": true,
                "device_id": identity.deviceID,
                "device_name": identity.deviceName,
                "client_type": identity.clientType.rawValue,
                "ha_pairing_status": DJConnectPairingStatus.paired.rawValue,
                "firmware": identity.firmware,
                "app_version": identity.appVersion ?? identity.firmware,
                "platform": identity.platform.rawValue,
                "state": "online",
                "status": "online",
                "pair_code": expectedPairCode,
                "pairing_token": expectedPairCode,
                "local_url": localDeviceURL ?? ""
            ]
        }

        do {
            try tokenStore.saveToken(deviceToken)
            pairingTask?.cancel()
            pairingTask = nil
            pairingStatus = .paired
            isConnected = true
            isPairing = false
            pairingMessage = localized(
                english: "Paired with Home Assistant.",
                dutch: "Gekoppeld met Home Assistant."
            )
            if let deviceLanguage = payload.deviceLanguage, ["nl", "en"].contains(deviceLanguage) {
                language = deviceLanguage
            }
            log(.info, "Local device pairing accepted by Home Assistant")
            refresh()
            return [
                "success": true,
                "device_id": identity.deviceID,
                "client_type": identity.clientType.rawValue,
                "ha_pairing_status": DJConnectPairingStatus.paired.rawValue,
                "local_url": localDeviceURL ?? ""
            ]
        } catch {
            log(.error, "Failed to store local device token: \(error.localizedDescription)")
            return [
                "success": false,
                "error": "token_store_failed",
                "message": "Could not store device token"
            ]
        }
    }

    public func clearDiagnosticLog() {
        diagnosticLogLines.removeAll()
        log(.info, "Diagnostic log cleared")
    }

    public func localized(english: String, dutch: String) -> String {
        language == "nl" ? dutch : english
    }

    public static func normalizedHomeAssistantURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard
            let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else {
            return nil
        }

        return url
    }

    private func logPairingError(_ error: DJConnectError) {
        switch error {
        case .pairingFailed:
            log(.debug, "Pairing is still pending in Home Assistant")
        case .network:
            log(.warning, "Pairing network error: \(Self.describe(error))")
        case .routeMissing:
            log(.warning, "Pairing route is missing in Home Assistant")
        case .versionMismatch:
            log(.error, "Pairing blocked by version mismatch: \(Self.describe(error))")
        default:
            log(.warning, "Pairing poll failed: \(Self.describe(error))")
        }
    }

    private func log(_ level: DJConnectAppLogLevel, _ message: String) {
        let configuredLevel = DJConnectAppLogLevel.parse(logLevel)
        guard level.priority >= configuredLevel.priority else {
            return
        }

        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(level.rawValue.uppercased()) \(message)"
        diagnosticLogLines.append(DJConnectDiagnosticLogLine(text: line))
        if diagnosticLogLines.count > maxDiagnosticLogLines {
            diagnosticLogLines.removeFirst(diagnosticLogLines.count - maxDiagnosticLogLines)
        }
    }

    private static func describe(_ error: DJConnectError) -> String {
        switch error {
        case let .backendUnavailable(message):
            "backend unavailable\(message.map { ": \($0)" } ?? "")"
        case let .authStale(statusCode, message):
            "auth stale HTTP \(statusCode)\(message.map { ": \($0)" } ?? "")"
        case let .routeMissing(message):
            "route missing\(message.map { ": \($0)" } ?? "")"
        case let .versionMismatch(mismatch):
            "version mismatch HA \(mismatch.haMajorMinor ?? "?") app \(mismatch.firmwareMajorMinor ?? "?")"
        case let .notConfigured(message):
            "not configured\(message.map { ": \($0)" } ?? "")"
        case let .server(statusCode, message):
            "server HTTP \(statusCode)\(message.map { ": \($0)" } ?? "")"
        case let .network(message):
            "network: \(message)"
        case .invalidResponse:
            "invalid response"
        case let .invalidConfiguration(message):
            "invalid configuration: \(message)"
        case .missingToken:
            "missing device token"
        case let .pairingFailed(message):
            "pairing pending\(message.map { ": \($0)" } ?? "")"
        }
    }

    private static func isPairingCodeMismatch(_ error: DJConnectError) -> Bool {
        guard case let .authStale(statusCode, message) = error, statusCode == 401 else {
            return false
        }
        let normalized = (message ?? "").lowercased()
        return normalized.contains("pairing code") || normalized.contains("pair code") || normalized.contains("koppelcode")
    }

    private static func redactedURL(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let scheme = components?.scheme {
            components?.scheme = scheme.lowercased()
        }
        components?.user = nil
        components?.password = nil
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? "\(url.scheme ?? "http")://\(url.host ?? "unknown")"
    }

    private static var keychainService: String {
        Bundle.main.bundleIdentifier.map { "\($0).djconnect" } ?? "nl.pcvantol.djconnect.djconnect"
    }

    private static func makeIdentity(defaults: UserDefaults) -> DJConnectIdentity {
        let installIDKey = "DJConnectInstallID"
        let installID: String
        if let existing = defaults.string(forKey: installIDKey), !existing.isEmpty {
            installID = existing
        } else {
            installID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            defaults.set(installID, forKey: installIDKey)
        }

        #if os(macOS)
        return DJConnectIdentity(
            deviceID: "djconnect-macos-\(installID.prefix(12))",
            deviceName: "DJConnect Mac",
            clientType: .macos,
            firmware: "3.0.0",
            appVersion: "3.0.0",
            platform: .macos
        )
        #else
        return DJConnectIdentity(
            deviceID: "djconnect-ios-\(installID.prefix(12))",
            deviceName: "DJConnect iPhone",
            clientType: .ios,
            firmware: "3.0.0",
            appVersion: "3.0.0",
            platform: .ios
        )
        #endif
    }

    private static func generatePairingToken() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }
}

public extension DJConnectAppModel {
    static var preview: DJConnectAppModel {
        DJConnectAppModel(
            playback: DJConnectPlayback(
                hasPlayback: true,
                isPlaying: true,
                trackName: "Late Night Connection",
                artistName: "DJConnect",
                progressMS: 72_000,
                durationMS: 184_000,
                volumePercent: 35,
                shuffle: false,
                repeatState: .off,
                device: DJConnectPlaybackDevice(
                    name: "Living Room",
                    type: "Speaker",
                    active: true,
                    supportsVolume: true,
                    volumePercent: 35
                )
            )
        )
    }
}

extension DJConnectAppModel: DJConnectLocalDeviceServerDelegate {
    func localDeviceServerDidStart(localURL: String) {
        localDeviceURL = localURL
        log(.info, "Local device API started at \(localURL)")
    }

    func localDeviceServerDidStop(error: String?) {
        if let error {
            log(.error, "Local device API stopped: \(error)")
        } else {
            log(.info, "Local device API stopped")
        }
        localDeviceURL = nil
    }

    func localDeviceServerPairingInfo() -> DJConnectLocalDeviceServer.PairingInfo {
        log(.info, "Local device API pairing info requested")
        return DJConnectLocalDeviceServer.PairingInfo(
            deviceID: identity.deviceID,
            deviceName: identity.deviceName,
            clientType: identity.clientType,
            firmware: identity.firmware,
            appVersion: identity.appVersion,
            platform: identity.platform,
            pairCode: pairingToken,
            localURL: localDeviceURL
        )
    }

    func localDeviceServerPair(payload: DJConnectLocalDeviceServer.PairPayload) -> DJConnectLocalDeviceServer.JSON {
        log(.info, "Local device API pair request received")
        return acceptLocalPairing(payload: payload)
    }

    func localDeviceServerCommand(payload: DJConnectLocalDeviceServer.JSON) -> DJConnectLocalDeviceServer.JSON {
        let command = payload["command"] as? String ?? "status"
        log(.info, "Local device API command received: \(command)")

        return [
            "success": true,
            "device_id": identity.deviceID,
            "client_type": identity.clientType.rawValue,
            "ha_pairing_status": pairingStatus.rawValue,
            "firmware": identity.firmware,
            "app_version": identity.appVersion ?? identity.firmware,
            "platform": identity.platform.rawValue,
            "local_url": localDeviceURL ?? "",
            "voice_supported": voiceEnabled,
            "local_audio_supported": localResponseAudioEnabled,
            "language": language,
            "log_level": logLevel
        ]
    }

    func localDeviceServerDJResponse(payload: DJConnectLocalDeviceServer.JSON) -> DJConnectLocalDeviceServer.JSON {
        let text = (payload["text"] as? String) ?? (payload["dj_text"] as? String) ?? ""
        if !text.isEmpty {
            djResponseText = text
        }
        log(.info, "Local device API DJ response received")
        return [
            "success": true,
            "device_id": identity.deviceID,
            "client_type": identity.clientType.rawValue
        ]
    }
}
