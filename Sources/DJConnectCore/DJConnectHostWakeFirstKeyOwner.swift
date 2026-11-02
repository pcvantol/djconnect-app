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
    private var firstKeyPreparation: HostWakeFirstKeyPreparation<HostWakeFirstKeyRuntimeSource>?
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
        let parents: HostWakeFirstKeyPreparation<HostWakeFirstKeyRuntimeSource>
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
    /// An unbound request is negative only; it cannot initialize any effect.
    public func operatorRequestsFirstKey() { closeOriginalOperation() }

    public func operatorRequestsFirstKey(runtimes: [DJConnectDirectSessionRuntime]) {
        guard state == .available, task == nil, let selection else { return }
        state = .running // Latch and capture BEFORE any Task/authorize/queue await.
        let window = HostWakeFirstKeyWindow()
        let preparation: HostWakeFirstKeyPreparation<HostWakeFirstKeyRuntimeSource>
        let actual: ActualHost
        do {
            actual = try ActualHost.capture()
            guard actual.bundleID == selection.bundleID, actual.build == selection.build,
                  actual.profileSHA256 == selection.profileSHA256 else { throw HostWakeFirstKeyAttempt.Failure.closed }
            preparation = .init(sources: try runtimes.map { try HostWakeFirstKeyRuntimeSource(runtime: $0, hostIsCurrent: { actual.isStillCurrent }) },
                                expected: selection.surfaces, window: window)
        } catch { window.close(); state = .unknown; return }
        firstKeyPreparation = preparation
        task = Task { [weak self] in
            guard let self else { preparation.close(); return }
            do {
                let (key, storage, attempt) = try await preparation.generate(journal: {
                    // No await between final bound-parent/host checks and mkdir.
                    guard preparation.isCurrent, actual.isStillCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
                    return try HostWakeFirstKeyJournal(freshInExistingSupport: actual.support,
                        artifact: actual.executableSHA256)
                }, sdk: SystemHostWakeFirstKeySDK())
                guard preparation.isCurrent, actual.isStillCurrent else {
                    attempt.close(); throw HostWakeFirstKeyAttempt.Failure.closed
                }
                self.attempt = attempt
                self.warmReference = .init(key: key, journal: storage, attempt: attempt, host: actual, parents: preparation)
                self.state = .referenceRecorded // Original reference DATA, NOT enrollment.
            } catch { preparation.close(); self.attempt?.close(); self.warmReference = nil; self.state = .unknown }
        }
    }
    /// No new parent or authorization may be looked up after key generation.
    public func retainedOriginalRuntime(for surface: DJConnectPassiveSurface) -> DJConnectDirectSessionRuntime? {
        guard [.referenceRecorded, .registered].contains(state), let reference = warmReference,
              reference.parents.isCurrent, reference.attempt.referenceIsCurrent, reference.host.isStillCurrent else { return nil }
        return reference.parents.sources.first { $0.surface == surface }?.runtime
    }
    /// Foreground loss is terminal for this original operator/task. Reactivation
    /// cannot select another plan, recreate initialization or retry an unknown SDK.
    public func closeOriginalOperation() {
        firstKeyPreparation?.close(); attempt?.close(); task?.cancel()
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
              reference.parents.isCurrent,
              tokenIsCurrent(), let parent = runtime.originalPurposeContext,
              let captured = reference.parents.captured(runtime: runtime, parent: parent),
              selection.surfaces.contains(where: { $0.rawValue == parent.surface }),
              prepareTasks[parent.surface] == nil else {
            throw HostWakeFirstKeyAttempt.Failure.closed
        }
        state = .preparing // Once BEFORE child creation or any suspension.
        do {
            try reference.parents.beginEnrollment(captured)
            let child = try parent.proxyCustody()
            proxies.append(child)
            let intent = CoreHostWakeProxyCustody.NativeIntentData(token: token,
                hostBundleID: reference.host.bundleID, installationID: reference.journal.installationIdentifier,
                platform: reference.host.platform, environment: selection.apnsEnvironment, nativeKeyID: reference.key)
            let operation = Task { @MainActor [weak self] in
                guard let self, self.state == .preparing, reference.attempt.referenceIsCurrent,
                      reference.parents.isCurrent, reference.host.isStillCurrent, tokenIsCurrent(), parent.isActive else { throw CancellationError() }
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
                // Only the actual matching registered ACK can advance this local
                // order; an SDK callback or warm reference never advances it.
                try reference.parents.completeEnrollment(captured)
                self.state = .registered
            }
            prepareTasks[parent.surface] = operation
            try await withTaskCancellationHandler { try await operation.value } onCancel: { operation.cancel() }
            try Task.checkCancellation()
        } catch {
            for proxy in proxies { proxy.retire() }
            firstKeyPreparation?.close(); attempt?.close(); warmReference = nil; state = .unknown
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
    private let window: HostWakeFirstKeyWindow
    private var entered = false
    private var closed = false
    private let cancellation = HostWakeFirstKeyCancellation()
    init(storage: HostWakeFirstKeyJournal, sdk: any HostWakeFirstKeySDK,
         window: HostWakeFirstKeyWindow = .init(), current: @escaping @MainActor @Sendable () -> Bool) {
        self.storage = storage; self.sdk = sdk; self.window = window; self.current = current
    }
    func close() { cancellation.close(); closed = true; window.close(); storage.close() }
    private var isCurrent: Bool {
        guard !closed, cancellation.isLive, current(),
              window.isCurrent,
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
        let key = try await sdk.generate(deadline: window.deadline, current: { [self] in isCurrent })
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

// Shared negative sequencing engine. Synthetic tests cannot construct the private
// shipping source adapter, select an artifact or obtain SystemHostWakeFirstKeySDK.
@MainActor final class HostWakeFirstKeyWindow {
    let started: ContinuousClock.Instant
    let deadline: ContinuousClock.Instant
    private let now: () -> ContinuousClock.Instant
    private var closed = false
    init() {
        let start = ContinuousClock.now
        started = start; deadline = start.advanced(by: .seconds(120))
        now = { ContinuousClock.now }
    }
    /// Internal synthetic clock seam; never used by the production owner.
    init(testStarted: ContinuousClock.Instant, testNow: @escaping () -> ContinuousClock.Instant) {
        started = testStarted; deadline = testStarted.advanced(by: .seconds(120)); now = testNow
    }
    var isCurrent: Bool {
        let value = now()
        guard !closed, !Task.isCancelled, value >= started, value < deadline else { close(); return false }
        return true // Local resource bound ONLY, not source/SDK/clock admission.
    }
    func close() { closed = true }
}

@MainActor protocol HostWakeFirstKeySource: AnyObject {
    associatedtype Parent: AnyObject
    var surface: DJConnectPassiveSurface { get }
    var isCurrent: Bool { get }
    func authorizeOriginal() async throws -> Parent
    func retains(_ parent: Parent) -> Bool
    func sharesPairedOwner(_ first: Parent, _ other: Parent) -> Bool
}

@MainActor final class HostWakeFirstKeyPreparation<Source: HostWakeFirstKeySource> {
    let window: HostWakeFirstKeyWindow
    let sources: [Source]
    private(set) var parents: [Source.Parent] = []
    private let expected: [DJConnectPassiveSurface]
    private var entered = false
    private var closed = false
    private var keyReferencePublished = false
    private var nextEnrollment = 0
    private var pendingEnrollment: Source.Parent?
    init(sources: [Source], expected: [DJConnectPassiveSurface], window: HostWakeFirstKeyWindow) {
        self.sources = sources; self.expected = expected; self.window = window
    }
    private var partialIsCurrent: Bool {
        guard !closed, window.isCurrent, (1...2).contains(sources.count),
              sources.map(\.surface) == expected, Set(expected).count == expected.count,
              Set(sources.map(ObjectIdentifier.init)).count == sources.count,
              sources.allSatisfy({ $0.isCurrent }), parents.count <= sources.count,
              zip(sources, parents).allSatisfy({ $0.retains($1) }),
              Set(parents.map(ObjectIdentifier.init)).count == parents.count,
              parents.isEmpty || parents.allSatisfy({ sources[0].sharesPairedOwner(parents[0], $0) }) else { close(); return false }
        return true
    }
    var isCurrent: Bool { entered && partialIsCurrent && parents.count == sources.count }
    func close() { closed = true; window.close() }
    /// Local negative ordering only. No API policy, proofkind or ACK authority.
    func beginEnrollment(_ parent: Source.Parent) throws {
        guard isCurrent, keyReferencePublished, pendingEnrollment == nil,
              parents.indices.contains(nextEnrollment), parents[nextEnrollment] === parent else {
            throw HostWakeFirstKeyAttempt.Failure.closed
        }
        pendingEnrollment = parent
    }
    /// Shipping caller reaches this only after its verified registered child ACK.
    func completeEnrollment(_ parent: Source.Parent) throws {
        guard isCurrent, pendingEnrollment === parent,
              parents.indices.contains(nextEnrollment), parents[nextEnrollment] === parent else {
            close(); throw HostWakeFirstKeyAttempt.Failure.closed
        }
        pendingEnrollment = nil; nextEnrollment += 1
    }
    private func prepare() async throws {
        guard !entered else { throw HostWakeFirstKeyAttempt.Failure.closed }
        entered = true
        do {
            for source in sources {
                guard partialIsCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
                let parent = try await source.authorizeOriginal()
                parents.append(parent)
                guard partialIsCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
            }
            guard isCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
        } catch { close(); throw error }
    }
    func generate(journal: () throws -> HostWakeFirstKeyJournal, sdk: any HostWakeFirstKeySDK)
        async throws -> (String, HostWakeFirstKeyJournal, HostWakeFirstKeyAttempt) {
        try await prepare()
        guard isCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
        let storage: HostWakeFirstKeyJournal
        do { storage = try journal() } catch { close(); throw error }
        guard isCurrent else { storage.close(); close(); throw HostWakeFirstKeyAttempt.Failure.closed }
        let attempt = HostWakeFirstKeyAttempt(storage: storage, sdk: sdk, window: window, current: { self.isCurrent })
        do {
            let key = try await attempt.perform()
            guard isCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
            keyReferencePublished = true
            return (key, storage, attempt)
        } catch { attempt.close(); close(); throw error }
    }
}

/// Comparison DATA only; never constructs or replaces either genuine parent.
/// Production callers still retain and recheck the original runtime/context.
@MainActor struct HostWakeFirstKeyOwnerJoin {
    let continuity: DirectSessionOwnerContinuity
    let origin: URL
    let device: String
    let client: DJConnectClientType
    let session: String
    func sharesOriginalOwner(with other: Self) -> Bool {
        continuity.sharesOriginalOwner(with: other.continuity) &&
            origin == other.origin && device == other.device &&
            client == other.client && session == other.session
    }
}

/// Production adapter: only real runtime custody can supply its private Parent.
/// This carries negative continuity, never native/clock/effect admission.
@MainActor private final class HostWakeFirstKeyRuntimeSource: HostWakeFirstKeySource {
    final class Parent {
        let runtime: DJConnectDirectSessionRuntime
        let original: DirectRichReadCustody.OriginalPurposeContext
        let ownerJoin: HostWakeFirstKeyOwnerJoin
        init(runtime: DJConnectDirectSessionRuntime, original: DirectRichReadCustody.OriginalPurposeContext) {
            self.runtime = runtime; self.original = original
            ownerJoin = .init(continuity: runtime.firstKeyOwnerContinuity, origin: original.pairedOrigin,
                device: original.pairedIdentity.deviceID, client: original.pairedIdentity.clientType, session: original.sessionID)
        }
    }
    let runtime: DJConnectDirectSessionRuntime
    let surface: DJConnectPassiveSurface
    private let hostIsCurrent: @MainActor () -> Bool
    init(runtime: DJConnectDirectSessionRuntime, hostIsCurrent: @escaping @MainActor () -> Bool) throws {
        guard let surface = DJConnectPassiveSurface(rawValue: runtime.firstKeySurfaceData) else {
            throw HostWakeFirstKeyAttempt.Failure.closed
        }
        self.runtime = runtime; self.surface = surface; self.hostIsCurrent = hostIsCurrent
    }
    var isCurrent: Bool { runtime.firstKeyPairSourceIsCurrent && hostIsCurrent() }
    func authorizeOriginal() async throws -> Parent {
        guard isCurrent else { throw HostWakeFirstKeyAttempt.Failure.closed }
        if runtime.phase == .idle { try await runtime.begin() }
        guard isCurrent, runtime.phase == .active, let parent = runtime.originalPurposeContext,
              parent.isActive, parent.surface == surface.rawValue, parent.pairedIdentity.clientType == .ios else {
            throw HostWakeFirstKeyAttempt.Failure.closed
        }
        return Parent(runtime: runtime, original: parent)
    }
    func retains(_ parent: Parent) -> Bool {
        isCurrent && runtime === parent.runtime && runtime.originalPurposeContext === parent.original && parent.original.isActive
    }
    func sharesPairedOwner(_ first: Parent, _ other: Parent) -> Bool {
        // Negative consistency check on already genuine retained contexts only;
        // matching DATA cannot construct either source or confer admission.
        first.ownerJoin.sharesOriginalOwner(with: other.ownerJoin)
    }
}
private extension HostWakeFirstKeyPreparation where Source == HostWakeFirstKeyRuntimeSource {
    func captured(runtime: DJConnectDirectSessionRuntime, parent: DirectRichReadCustody.OriginalPurposeContext) -> HostWakeFirstKeyRuntimeSource.Parent? {
        guard isCurrent else { return nil }
        return zip(sources, parents).first { source, captured in
            source.runtime === runtime && captured.runtime === runtime && captured.original === parent
        }?.1
    }
}
