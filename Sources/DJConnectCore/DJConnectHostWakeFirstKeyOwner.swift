import Combine
import CryptoKit
import Foundation
#if os(iOS)
import UIKit
import DeviceCheck
#endif

/// App-start ownership for the host-wake first-key operation. This is separate
/// from QR/Rendezvous enrollment and the Session-scoped direct-read owner.
/// Ordinary builds have no selected installation/effect plan, hence no positive
/// operator action. Neither startup, DTO decoding nor an HA ID can select one.
@MainActor public final class DJConnectHostWakeFirstKeyOwner: ObservableObject {
    public enum State: Sendable { case closed, available, running, referenceRecorded, preparing, registered, unknown }
    @Published public private(set) var state: State = .closed
    private var attempt: HostWakeFirstKeyAttempt?
    private var task: Task<Void, Never>?
    private var prepareTasks: [String: Task<Void, any Error>] = [:]
    private var warmReference: WarmReference?
    private var proxies: [CoreHostWakeProxyCustody] = []
    private let selection: ReviewedSelection?

    // This private, immutable source selection intentionally has NO live value.
    // Adding the actual reviewed signed installation/effect plan is a separate
    // source review. It is not a runtime Codable/approved/hash-match admission.
    private struct ReviewedSelection {
        let bundleID: String
        let build: String
        let profileSHA256: String
        let apnsEnvironment: String // Separately reviewed signed APNs entitlement; NOT App Attest AAGUID/category.
        let surfaces: [DJConnectPassiveSurface]
    }
    private static let reviewedLaunchSelection: ReviewedSelection? = nil
    private struct WarmReference {
        let key: String
        let journal: HostWakeFirstKeyJournal
        let attempt: HostWakeFirstKeyAttempt
        let host: ActualHost
    }
    public init() {
        selection = Self.reviewedLaunchSelection
        // This construction is usable only after separate exact signed-install/
        // effect review selects a real launch. Matching metadata is not itself
        // effect authority. Startup never initializes storage or schedules SDK.
        guard let selection, let actual = try? ActualHost.capture(),
              actual.bundleID == selection.bundleID, actual.build == selection.build,
              actual.profileSHA256 == selection.profileSHA256,
              !selection.surfaces.isEmpty, selection.surfaces.count <= 2,
              Set(selection.surfaces).count == selection.surfaces.count,
              ["sandbox", "production"].contains(selection.apnsEnvironment),
              HostWakeFirstKeyJournal.namespaceIsAbsent(inExistingSupport: actual.support) else { return }
        state = .available // Still requires the actual separate local Button action.
    }
    deinit { task?.cancel(); for task in prepareTasks.values { task.cancel() } }
    public var showsOperatorAction: Bool { state == .available && selection != nil }
    /// Target DATA from the separately selected plan, never display/SDK consent.
    public var originalSurfaceData: DJConnectPassiveSurface? { selection?.surfaces.first }
    public var originalSurfacesData: [DJConnectPassiveSurface] { selection?.surfaces ?? [] }

    /// The actual app's explicit local Button is the only production callsite.
    /// A future concrete selection must be reviewed before this can become live.
    public func operatorRequestsFirstKey() {
        guard state == .available, task == nil, let selection else { return }
        state = .running // Latch synchronously before task creation/reentrancy.
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let actual = try ActualHost.capture()
                guard actual.bundleID == selection.bundleID, actual.build == selection.build,
                      actual.profileSHA256 == selection.profileSHA256 else { throw HostWakeFirstKeyAttempt.Failure.closed }
                // The exact SIGNED artifact is bound by the external install/
                // effect review, not a self-referential digest compiled into it.
                // This measurement retains local continuity only, not admission.
                let storage = try HostWakeFirstKeyJournal(freshInExistingSupport: actual.support,
                    artifact: actual.executableSHA256)
                let attempt = HostWakeFirstKeyAttempt(storage: storage, sdk: SystemHostWakeFirstKeySDK(),
                    current: { actual.isStillCurrent })
                self.attempt = attempt
                let key = try await attempt.perform()
                self.warmReference = .init(key: key, journal: storage, attempt: attempt, host: actual)
                self.state = .referenceRecorded // Key-reference DATA, NOT enrolled.
            } catch { self.state = .unknown }
        }
    }
    /// Foreground loss is terminal for this original operator/task. Reactivation
    /// cannot select another plan, recreate initialization or retry an unknown SDK.
    public func closeOriginalOperation() {
        attempt?.close(); task?.cancel()
        for task in prepareTasks.values { task.cancel() }
        for proxy in proxies { proxy.retire() }
        warmReference = nil
        state = [.running, .preparing].contains(state) ? .unknown : .closed
    }

    /// The actual AppModel passes its retained genuine direct-read runtime and
    /// current in-memory OS token. No key-reference file or DTO is adopted here.
    /// Runs one original enrollment. Only an acknowledged pending server job
    /// may be polled; lost/unknown responses never restart the challenge/SDK.
    public func prepareOriginalHostWake(runtime: DJConnectDirectSessionRuntime, token: Data,
        tokenIsCurrent: @escaping @MainActor @Sendable () -> Bool) async throws {
        try Task.checkCancellation()
        guard [.referenceRecorded, .registered].contains(state), let reference = warmReference,
              let selection, ["sandbox", "production"].contains(selection.apnsEnvironment),
              reference.attempt.referenceIsCurrent, reference.host.isStillCurrent,
              tokenIsCurrent(), let parent = runtime.originalPurposeContext,
              selection.surfaces.contains(where: { $0.rawValue == parent.surface }),
              prepareTasks[parent.surface] == nil else {
            throw HostWakeFirstKeyAttempt.Failure.closed
        }
        state = .preparing // Once BEFORE child creation or any suspension.
        do {
            let child = try parent.proxyCustody()
            proxies.append(child)
            let intent = CoreHostWakeProxyCustody.NativeIntentData(token: token,
                hostBundleID: reference.host.bundleID, installationID: reference.journal.installationIdentifier,
                platform: reference.host.platform, environment: selection.apnsEnvironment, nativeKeyID: reference.key)
            let operation = Task { @MainActor [weak self] in
                guard let self, self.state == .preparing, reference.attempt.referenceIsCurrent,
                      reference.host.isStillCurrent, tokenIsCurrent(), parent.isActive else { throw CancellationError() }
                _ = try await child.prepare(intent)
                try Task.checkCancellation()
                guard self.state == .preparing, reference.attempt.referenceIsCurrent,
                      reference.host.isStillCurrent, tokenIsCurrent(), parent.isActive else { throw CancellationError() }
                // Capture BEFORE the first challenge await. This local 30s
                // resource bound is independent of the server's UTC deadline.
                let proofWindow = HostWakeNativeProofWindow()
                _ = try await child.challenge()
                let current: @MainActor @Sendable () -> Bool = { [weak self] in
                    self?.state == .preparing && reference.attempt.referenceIsCurrent &&
                        reference.host.isStillCurrent && tokenIsCurrent() && parent.isActive
                }
                guard current(), proofWindow.isCurrent else { throw CancellationError() }
                let input = try child.nativeProofInputData(suppliedSDKKeyIdentifier: reference.key)
                let proof = HostWakeNativeProofAttempt(storage: reference.journal, sdk: SystemHostWakeNativeProofSDK(),
                    window: proofWindow, current: current)
                // Hold the actual key's exclusion slot through SDK -> complete;
                // neither the slot nor a parsed input supplies native authority.
                _ = try await RendezvousAppKeyOperations.shared.performHostWakeProof(keyIdentifier: reference.key) {
                    let bytes = try await proof.perform(input)
                    guard await proof.isCurrent else { throw CancellationError() }
                    return try await child.complete(proof: bytes)
                }
                guard current() else { throw CancellationError() }
                for _ in 0..<12 where child.phase == .verifying {
                    try await Task.sleep(for: .milliseconds(350))
                    guard current() else { throw CancellationError() }
                    _ = try await child.nativeStatus()
                    guard current() else { throw CancellationError() }
                }
                guard current(), child.phase == .nativeVerified else { throw CancellationError() }
                _ = try await child.register()
                guard current() else { throw CancellationError() }
                for _ in 0..<12 where child.phase == .registerPending {
                    try await Task.sleep(for: .milliseconds(350))
                    guard current() else { throw CancellationError() }
                    _ = try await child.status()
                    guard current() else { throw CancellationError() }
                }
                guard current(), child.phase == .registered else { throw CancellationError() }
                try runtime.retainRegisteredHostWakeRead(child: child, parent: parent)
                self.state = .registered
            }
            prepareTasks[parent.surface] = operation
            try await withTaskCancellationHandler { try await operation.value } onCancel: { operation.cancel() }
            try Task.checkCancellation()
        } catch {
            for proxy in proxies { proxy.retire() }
            attempt?.close(); warmReference = nil; state = .unknown
            throw error // No fresh operation, UUID, key or automatic retry.
        }
    }

    private struct ActualHost {
        let bundleID: String
        let build: String
        let profileSHA256: String
        let executableSHA256: String
        let support: URL
        let platform: String
        @MainActor static func capture() throws -> Self {
            #if os(iOS) && !targetEnvironment(simulator)
            guard UIApplication.shared.applicationState == .active,
                  UIApplication.shared.isProtectedDataAvailable,
                  DCAppAttestService.shared.isSupported,
                  let bundleID = Bundle.main.bundleIdentifier,
                  let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                  let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
                  let executable = Bundle.main.executableURL,
                  let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw HostWakeFirstKeyAttempt.Failure.closed
            }
            return try .init(bundleID: bundleID, build: build,
                profileSHA256: digest(profile, maximum: 1_048_576),
                executableSHA256: digest(executable, maximum: 134_217_728), support: support,
                platform: UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios")
            #else
            throw HostWakeFirstKeyAttempt.Failure.closed
            #endif
        }
        @MainActor var isStillCurrent: Bool {
            guard let now = try? Self.capture() else { return false }
            return now.bundleID == bundleID && now.build == build &&
                now.profileSHA256 == profileSHA256 && now.executableSHA256 == executableSHA256 &&
                now.support == support && now.platform == platform
        }
        private static func digest(_ url: URL, maximum: Int) throws -> String {
            let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard info.isRegularFile == true, info.isSymbolicLink != true,
                  let size = info.fileSize, (1...maximum).contains(size) else { throw HostWakeFirstKeyAttempt.Failure.closed }
            let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
            guard bytes.count == size else { throw HostWakeFirstKeyAttempt.Failure.closed }
            return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        }
    }
}

@MainActor protocol HostWakeFirstKeySDK {
    var isSupported: Bool { get }
    /// Recheck the original owner synchronously at SDK entry and callback, not
    /// merely before waiting for the shared exclusion slot.
    func generate(deadline: ContinuousClock.Instant,
                  current: @escaping @MainActor @Sendable () -> Bool) async throws -> String
}

/// Shared engine for the actual private app owner above and explicitly synthetic
/// tests. Injected test SDK/currentness never construct that production owner,
/// choose its effect plan or obtain the private system SDK implementation.
@MainActor final class HostWakeFirstKeyAttempt {
    enum Failure: Error { case closed, unknown }
    private let storage: HostWakeFirstKeyJournal
    private let sdk: any HostWakeFirstKeySDK
    private let current: @MainActor @Sendable () -> Bool
    private let started = ContinuousClock.now
    private var entered = false
    private var closed = false
    private let cancellation = HostWakeFirstKeyCancellation()
    init(storage: HostWakeFirstKeyJournal, sdk: any HostWakeFirstKeySDK,
         current: @escaping @MainActor @Sendable () -> Bool) {
        self.storage = storage; self.sdk = sdk; self.current = current
    }
    func close() { cancellation.close(); closed = true; storage.close() }
    private var isCurrent: Bool {
        guard !closed, cancellation.isLive, current(),
              ContinuousClock.now < started.advanced(by: .seconds(120)),
              (try? storage.validateOriginal()) != nil else {
            close() // An OBSERVED loss is terminal, including a pre-prepare guard.
            return false
        }
        return true
    }
    var referenceIsCurrent: Bool { entered && isCurrent }
    func perform() async throws -> String {
        guard !entered else { throw Failure.closed }
        entered = true
        do {
            // Exclusion ONLY: the existing installation slot is explicitly used
            // by all initial-generation journal creators. No QR/admission/lease
            // is borrowed, and a caller already inside such a scope is rejected.
            let cancellation = cancellation
            return try await withTaskCancellationHandler {
                try await RendezvousAppKeyOperations.shared.performHostWakeFirstKey { [self] in
                    try await generateOnce()
                }
            } onCancel: { cancellation.close() }
        } catch { close(); throw Failure.unknown }
    }
    private func generateOnce() async throws -> String {
        try Task.checkCancellation()
        guard sdk.isSupported, isCurrent else { throw Failure.closed }
        try storage.claimBeforeSDK() // File AND directory durable before SDK scheduling.
        try Task.checkCancellation()
        guard isCurrent else { throw Failure.closed }
        let key = try await sdk.generate(deadline: started.advanced(by: .seconds(120)), current: { [self] in isCurrent })
        try Task.checkCancellation()
        guard isCurrent else { throw Failure.closed }
        try storage.recordOriginalCallback(key)
        try Task.checkCancellation()
        guard isCurrent else { throw Failure.closed }
        return key
    }
}

private final class HostWakeFirstKeyCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var live = true
    var isLive: Bool { lock.withLock { live } }
    func close() { lock.withLock { live = false } }
}

@MainActor private final class SystemHostWakeFirstKeySDK: HostWakeFirstKeySDK {
    var isSupported: Bool {
        #if os(iOS) && !targetEnvironment(simulator)
        DCAppAttestService.shared.isSupported
        #else
        false
        #endif
    }
    func generate(deadline: ContinuousClock.Instant,
                  current: @escaping @MainActor @Sendable () -> Bool) async throws -> String {
        guard isSupported, current() else { throw HostWakeFirstKeyAttempt.Failure.closed }
        #if os(iOS) && !targetEnvironment(simulator)
        let reply = HostWakeFirstKeySDKReply(deadline: deadline, current: current)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                reply.start(continuation)
                guard !Task.isCancelled, current() else { reply.fail(); return }
                DCAppAttestService.shared.generateKey { key, error in
                    Task { @MainActor in reply.finish(key: error == nil ? key : nil) }
                }
            }
        } onCancel: { Task { @MainActor in reply.fail() } }
        #else
        throw HostWakeFirstKeyAttempt.Failure.closed
        #endif
    }
}

@MainActor private final class HostWakeFirstKeySDKReply {
    private let current: @MainActor @Sendable () -> Bool
    private let deadline: ContinuousClock.Instant
    private var continuation: CheckedContinuation<String, any Error>?
    private var finished = false
    private var timeout: Task<Void, Never>?
    init(deadline: ContinuousClock.Instant, current: @escaping @MainActor @Sendable () -> Bool) {
        self.deadline = deadline; self.current = current
    }
    func start(_ continuation: CheckedContinuation<String, any Error>) {
        guard !finished else { continuation.resume(throwing: HostWakeFirstKeyAttempt.Failure.unknown); return }
        self.continuation = continuation
        let deadline = deadline
        timeout = Task { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard !Task.isCancelled else { return }; self?.fail()
        }
    }
    func finish(key: String?) {
        guard !finished else { return }
        guard current(), let key, let bytes = Data(base64Encoded: key), bytes.count == 32,
              bytes.base64EncodedString() == key else { fail(); return }
        finished = true; timeout?.cancel(); timeout = nil
        continuation?.resume(returning: key); continuation = nil
    }
    func fail() {
        guard !finished else { return }; finished = true
        timeout?.cancel(); timeout = nil
        continuation?.resume(throwing: HostWakeFirstKeyAttempt.Failure.unknown); continuation = nil
    }
}

/// Only the private reviewed warm owner above constructs this actual adapter.
/// Simulator and all non-iOS hosts are unsupported; no synthetic fallback.
@MainActor private final class SystemHostWakeNativeProofSDK: HostWakeNativeProofSDK {
    var isSupported: Bool {
        #if os(iOS) && !targetEnvironment(simulator)
        DCAppAttestService.shared.isSupported
        #else
        false
        #endif
    }
    func invoke(_ input: HostWakeNativeProofInputData, deadline: ContinuousClock.Instant,
        current: @escaping @MainActor @Sendable () -> Bool) async throws -> Data {
        guard isSupported, current(), ContinuousClock.now < deadline else { throw HostWakeFirstKeyAttempt.Failure.closed }
        #if os(iOS) && !targetEnvironment(simulator)
        let reply = HostWakeNativeProofSDKReply(deadline: deadline, current: current)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                reply.start(continuation)
                guard !Task.isCancelled, current(), ContinuousClock.now < deadline else { reply.fail(); return }
                let callback: @Sendable (Data?, (any Error)?) -> Void = { data, error in
                    Task { @MainActor in reply.finish(error == nil ? data : nil) }
                }
                // The kind came from the retained prepared/challenge pair. Key
                // existence, local defaults or a server DTO cannot choose it.
                switch input.kind.sdkOperation {
                case .attestKey:
                    DCAppAttestService.shared.attestKey(input.keyIdentifier, clientDataHash: input.clientDataHash,
                        completionHandler: callback)
                case .generateAssertion:
                    DCAppAttestService.shared.generateAssertion(input.keyIdentifier, clientDataHash: input.clientDataHash,
                        completionHandler: callback)
                }
            }
        } onCancel: { Task { @MainActor in reply.fail() } }
        #else
        throw HostWakeFirstKeyAttempt.Failure.closed
        #endif
    }
}

@MainActor private final class HostWakeNativeProofSDKReply {
    private let current: @MainActor @Sendable () -> Bool
    private let deadline: ContinuousClock.Instant
    private var continuation: CheckedContinuation<Data, any Error>?
    private var finished = false
    private var timeout: Task<Void, Never>?
    init(deadline: ContinuousClock.Instant, current: @escaping @MainActor @Sendable () -> Bool) {
        self.deadline = deadline; self.current = current
    }
    func start(_ continuation: CheckedContinuation<Data, any Error>) {
        guard !finished else { continuation.resume(throwing: HostWakeFirstKeyAttempt.Failure.unknown); return }
        self.continuation = continuation
        let deadline = deadline
        timeout = Task { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard !Task.isCancelled else { return }; self?.fail()
        }
    }
    func finish(_ bytes: Data?) {
        guard !finished else { return }
        guard current(), ContinuousClock.now < deadline, let bytes, (1...9216).contains(bytes.count) else { fail(); return }
        finished = true; timeout?.cancel(); timeout = nil
        continuation?.resume(returning: bytes); continuation = nil
    }
    func fail() {
        guard !finished else { return }; finished = true
        timeout?.cancel(); timeout = nil
        continuation?.resume(throwing: HostWakeFirstKeyAttempt.Failure.unknown); continuation = nil
    }
}
