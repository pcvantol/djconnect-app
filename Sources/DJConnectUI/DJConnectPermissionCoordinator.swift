import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Speech)
import Speech
#endif
#if canImport(UserNotifications)
@preconcurrency import UserNotifications
#endif

struct DJConnectPermissionSnapshot: Equatable, Sendable {
    var microphone: DJConnectPermissionStatus
    var speech: DJConnectPermissionStatus
    var notifications: DJConnectPermissionStatus
    var localNetwork: DJConnectPermissionStatus
}

struct DJConnectPermissionCoordinator: Sendable {
    func currentSnapshot() async -> DJConnectPermissionSnapshot {
        let notifications = await currentNotificationPermissionStatus()
        return DJConnectPermissionSnapshot(
            microphone: currentMicrophonePermissionStatus(),
            speech: currentSpeechPermissionStatus(),
            notifications: notifications,
            localNetwork: .unknown
        )
    }

    func currentMicrophonePermissionStatus() -> DJConnectPermissionStatus {
        #if canImport(AVFoundation)
        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
        #else
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
        #endif
        #else
        return .unavailable
        #endif
    }

    func currentSpeechPermissionStatus() -> DJConnectPermissionStatus {
        #if canImport(Speech)
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
        #else
        return .unavailable
        #endif
    }

    func currentNotificationPermissionStatus() async -> DJConnectPermissionStatus {
        #if canImport(UserNotifications)
        guard !Self.isRunningUnderSwiftPMTests else {
            return .unavailable
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .notDetermined:
            return .unknown
        case .denied:
            return .denied
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    static func requestAction(
        microphone: DJConnectPermissionStatus,
        speech: DJConnectPermissionStatus,
        notifications: DJConnectPermissionStatus = .granted
    ) -> DJConnectPermissionRequestAction {
        if microphone == .granted, speech == .granted, notifications == .granted {
            return .alreadyGranted
        }
        if microphone == .denied
            || microphone == .restricted
            || speech == .denied
            || speech == .restricted
            || notifications == .denied
            || notifications == .restricted {
            return .openSystemSettings
        }
        return .requestSystemPrompt
    }

    private static var isRunningUnderSwiftPMTests: Bool {
        let processInfo = ProcessInfo.processInfo
        return Bundle.main.bundleURL.path.contains("/swift/pm")
            || processInfo.arguments.contains { $0.contains("swiftpm-testing-helper") || $0.contains(".xctest") }
            || processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
