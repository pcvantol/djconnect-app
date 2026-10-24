import CryptoKit
import Foundation
#if os(iOS)
import UIKit
#endif

/// Shipping and ordinary fixed-QA builds have no selected admission. The only
/// exception is a separately generated, signed, exact-profile finite QA run.
/// A compile condition alone cannot satisfy the runtime tuple or durable budget.
@MainActor public enum RendezvousNativeAdmission {
    public enum Failure: Error, Sendable { case notAdmitted }
    private static let gate: RendezvousNativeRunGate? = {
        #if DJCONNECT_VIBECAST_FIXED_QA && DJCONNECT_VIBECAST_NATIVE_TEST_ADMISSION
        let policy = RendezvousSelectedNativeTestPolicy.value
        return try? RendezvousNativeRunGate(policy: policy, storage: RendezvousRepairKeychainStorage(
            service: "dev.djconnect.rendezvous.fixedqa.native-run", account: policy.identifier))
        #else
        return nil
        #endif
    }()
    public static var isAdmitted: Bool { eligible(newConnection: true) }
    public static var canContinueInFlight: Bool { eligible(newConnection: false) }
    static func require() throws {
        guard isAdmitted else { throw Failure.notAdmitted }
    }
    static func perform(_ action: RendezvousNativeEffect, _ effect: () throws -> Void) throws {
        guard let gate, let context = actualContext() else { throw Failure.notAdmitted }
        try gate.reserve(action, context: context, at: now(), uptime: ProcessInfo.processInfo.systemUptime)
        try effect()
    }
    private static func eligible(newConnection: Bool) -> Bool {
        guard let gate, let context = actualContext() else { return false }
        return gate.isEligible(context, at: now(), uptime: ProcessInfo.processInfo.systemUptime, newConnection: newConnection)
    }
    private static func actualContext() -> RendezvousNativeRunContext? {
        #if os(iOS) && !targetEnvironment(simulator)
        guard let bundle = Bundle.main.bundleIdentifier,
              let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let bytes = try? Data(contentsOf: profile), bytes.count <= 1_048_576 else { return nil }
        return .init(bundleID: bundle, build: build,
            provisioningProfileSHA256: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
            serviceOrigin: RendezvousBuildProfile.serviceOrigin, browserOrigin: RendezvousBuildProfile.browserOrigin,
            physicalIOSDevice: true, foreground: UIApplication.shared.applicationState == .active)
        #else
        return nil
        #endif
    }
    private static func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
