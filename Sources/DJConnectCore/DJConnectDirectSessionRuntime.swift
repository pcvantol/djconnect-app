import Foundation
#if os(iOS) && !targetEnvironment(simulator)
import UIKit
@preconcurrency import WidgetKit
#endif

/// The app's one retained direct-read owner for one surface and Session.
/// The initializer captures an actual paired client; neither a restored DTO
/// nor a returned frame can construct its original receiving context.
/// This object does not grant native display, SDK, enrollment or clock rights.
@MainActor public final class DJConnectDirectSessionRuntime {
    public enum Phase: Equatable, Sendable { case idle, authorizing, active, suspended, closed, unknown }
    private let custody: DirectRichReadCustody
    private let captureHostWakeAttempt: (@MainActor @Sendable () -> (@MainActor @Sendable () -> Bool))?
    private var candidate: DirectRichReadCustody.Candidate?
    private var statusOrigin: DJConnectDirectStatusObservationOrigin?
    private var registeredTokenIsCurrent: (@MainActor @Sendable () -> Bool)?
    private var registeredReadRetired = false
    private var withdrawalTask: Task<Void, any Error>?
    private let withdrawalCancellation = CoreHostWakeProxyCancellation()

    public init(client: DJConnectClient, sessionID: String, surface: DJConnectPassiveSurface,
                lockedDisplay: Bool,
                pairedIsCurrent: @escaping @MainActor @Sendable () -> Bool,
                ownerIsCurrent: @escaping @MainActor @Sendable () -> Bool,
                captureAttempt: @escaping @MainActor @Sendable () -> (@MainActor @Sendable () -> Bool),
                captureHostWakeAttempt: (@MainActor @Sendable () -> (@MainActor @Sendable () -> Bool))? = nil) throws {
        self.captureHostWakeAttempt = captureHostWakeAttempt
        custody = try DirectRichReadCustody(client: client, sessionID: sessionID, surface: surface,
            lockedDisplay: lockedDisplay, pairedIsCurrent: pairedIsCurrent,
            ownerIsCurrent: ownerIsCurrent, captureAttempt: captureAttempt)
    }

    /// Internal synthetic DATA tests retain the existing injected transport's
    /// missing ReceivingContext. This cannot create a genuine parent or permit.
    init(testCustody: DirectRichReadCustody) { custody = testCustody; captureHostWakeAttempt = nil }
    deinit { withdrawalCancellation.cancelAll(); custody.cancelOwnedResources() }

    /// Synchronous negative resource hook for the actual AppModel's deinit.
    /// In-flight calls may still retain this object until cancellation unwinds.
    public nonisolated func cancelOwnedResources() { withdrawalCancellation.cancelAll(); custody.cancelOwnedResources() }

    public var phase: Phase {
        switch custody.state {
        case .idle: .idle
        case .authorizing: .authorizing
        case .active: .active
        case .suspended: .suspended
        case .closed: .closed
        case .unknown: .unknown
        }
    }

    public func begin() async throws {
        let received = try await custody.authorize()
        try Task.checkCancellation()
        guard received.isCurrent else { throw CancellationError() }
        candidate = received
    }

    /// Reads retain the same original operation, purpose and pre-await C0.
    /// This never replaces a failed/unknown authorization with a new UUID.
    public func read() async throws {
        let received = try await custody.read()
        try Task.checkCancellation()
        guard received.isCurrent else { throw CancellationError() }
        candidate = received
    }

    /// Only the actual foreground enrollment owner can transfer an ACKed child
    /// before suspension. Original read/asset, local resource and field bounds
    /// remain unchanged; SDK/effect work can then close independently.
    func retainRegisteredHostWakeRead(child: CoreHostWakeProxyCustody,
        parent: DirectRichReadCustody.OriginalPurposeContext) throws {
        guard let captureHostWakeAttempt, !registeredReadRetired else { throw CancellationError() }
        let originalTokenIsCurrent = captureHostWakeAttempt()
        guard originalTokenIsCurrent() else { throw CancellationError() }
        try custody.retainRegisteredRead(from: child, parent: parent)
        registeredTokenIsCurrent = originalTokenIsCurrent
    }
    public var hasRegisteredHostWakeRead: Bool {
        guard let registeredTokenIsCurrent else { return false }
        guard !registeredReadRetired, registeredTokenIsCurrent(), custody.hasRegisteredRead else {
            registeredReadRetired = true; return false
        }
        return true
    }
    /// An OS hint may read only an already transferred warm original. It never
    /// begins authorization, adopts status history or recreates a cold owner.
    public func readRegisteredHostWake() async throws {
        guard hasRegisteredHostWakeRead, let captureHostWakeAttempt else { throw CancellationError() }
        let received = try await custody.readRegistered(captureAttempt: captureHostWakeAttempt)
        try Task.checkCancellation()
        guard received.isCurrent, hasRegisteredHostWakeRead else { throw CancellationError() }
        candidate = received
    }

    /// Genuine source side only. The native side still requires its actual OS
    /// widget configuration/cache choice or warm Activity request result.
    public func captureStatusObservationOrigin() -> DJConnectDirectStatusObservationOrigin? {
        if let statusOrigin { return statusOrigin.isCurrent ? statusOrigin : nil }
        guard hasRegisteredHostWakeRead, let parent = custody.originalPurposeContext,
              parent.isActive, candidate?.nativeQualificationInputs?.isCurrent == true else { return nil }
        let origin = DJConnectDirectStatusObservationOrigin(runtime: self, parent: parent)
        statusOrigin = origin
        return origin
    }
    public func retainsStatusObservationOrigin(_ origin: DJConnectDirectStatusObservationOrigin) -> Bool {
        statusOrigin === origin && origin.isCurrent
    }
    fileprivate func retainsStatusParent(_ parent: DirectRichReadCustody.OriginalPurposeContext) -> Bool {
        hasRegisteredHostWakeRead && custody.retainsStatusParentForOwnership(parent)
    }
    fileprivate func currentStatusData(parent: DirectRichReadCustody.OriginalPurposeContext) -> DJConnectSessionPlaybackObservation? {
        guard !Task.isCancelled, retainsStatusParent(parent), let input = candidate?.nativeQualificationInputs,
              input.isCurrent, input.purposeID == parent.purposeID, input.operationID == parent.operationID,
              input.sessionID == parent.sessionID, input.surface == parent.surface, let frame = input.frame else { return nil }
        return try? DJConnectSessionPlaybackObservation(frame: frame)
    }

    public func suspend() { candidate = nil; custody.suspend() }
    public func retire() { candidate = nil; custody.retire() }

    public func withdraw() async throws {
        // Local invalidation precedes even the async call boundary.
        retire()
        try Task.checkCancellation()
        if let withdrawalTask {
            try await withdrawalTask.value
            try Task.checkCancellation()
            return // Join the original result, including failure/UNKNOWN.
        }
        guard custody.authorizationWasStarted else { return } // No remote scope was attempted.
        let custody = custody, id = UUID()
        let task = Task { @MainActor in
            var failure: (any Error)?
            do { try await custody.withdrawExistingPushChild() } catch { failure = error }
            // A child failure must not skip independent parent-display cleanup.
            do { _ = try await custody.withdraw() } catch { if failure == nil { failure = error } }
            if let failure { throw failure }
        }
        withdrawalTask = task // Claim once before the FIRST async call; never reset on lost reply.
        do { try withdrawalCancellation.install(id, positive: false, cancel: { task.cancel() }) }
        catch { task.cancel(); throw error }
        defer { withdrawalCancellation.finish(id) }
        try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        try Task.checkCancellation()
    }
    public func readManagementStatus() async throws { _ = try await custody.status() }

    // Deliberately module-internal. The native owner must join the genuine
    // original clock/enrollment suppliers before using these original inputs.
    // There is no public frame/DTO -> parent or native permission conversion.
    var nativeQualificationInputs: DirectRichReadCustody.Candidate.NativeInputs? { candidate?.nativeQualificationInputs }
    var firstKeySurfaceData: String { custody.firstKeySurfaceData }
    var firstKeyPairSourceIsCurrent: Bool { custody.firstKeyPairSourceIsCurrent }
    var originalPurposeContext: DirectRichReadCustody.OriginalPurposeContext? { custody.originalPurposeContext }
}

/// Non-Codable, warm original source ownership. No public constructor and no
/// native SDK/cache factory from a decoded observation. Private rich fields
/// remain inaccessible through this attenuated source port.
@MainActor public final class DJConnectDirectStatusObservationOrigin {
    private weak var runtime: DJConnectDirectSessionRuntime?
    private let parent: DirectRichReadCustody.OriginalPurposeContext
    private let continuity: StatusObservationOwnershipContinuity
    private var widgetWasSelected = false
    private var widgetRetired = false
    fileprivate init(runtime: DJConnectDirectSessionRuntime, parent: DirectRichReadCustody.OriginalPurposeContext) {
        self.runtime = runtime; self.parent = parent
        continuity = StatusObservationOwnershipContinuity { [weak runtime] in runtime?.retainsStatusParent(parent) == true }
    }
    public var surfaceData: String { parent.surface }
    public func matchesSessionData(_ sessionID: String) -> Bool { isCurrent && parent.sessionID == sessionID }
    public var isCurrent: Bool {
        continuity.isCurrent
    }
    public var currentObservationData: DJConnectSessionPlaybackObservation? {
        isCurrent ? runtime?.currentStatusData(parent: parent) : nil
    }
    public var currentSnapshotData: DJConnectSessionSurfaceSnapshot? {
        currentObservationData.map { .init(playbackObservation: $0) }
    }
    /// Actual OS configuration is observed here, never supplied as caller DATA.
    /// Initial adoption is foreground-only; background work can only carry the
    /// same already selected configuration and original registered read owner.
    @discardableResult public func adoptConfiguredWidgetObservation() async throws -> Bool {
        try await updateConfiguredWidgetObservation(allowInitialAdoption: true)
    }
    @discardableResult public func publishConfiguredWidgetObservation() async throws -> Bool {
        guard widgetWasSelected, !widgetRetired else { return false }
        return try await updateConfiguredWidgetObservation(allowInitialAdoption: false)
    }
    public func withdrawOriginalRead() async { try? await runtime?.withdraw() }
    private func updateConfiguredWidgetObservation(allowInitialAdoption: Bool) async throws -> Bool {
        try Task.checkCancellation()
        #if os(iOS) && !targetEnvironment(simulator)
        guard surfaceData == "widget", isCurrent, !widgetRetired,
              !DJConnectLocalization.isQualificationProcess,
              Bundle.main.bundleIdentifier == "dev.djconnect.ios" else { throw CancellationError() }
        let firstSelection = !widgetWasSelected
        if firstSelection {
            guard allowInitialAdoption, parent.isActive, UIApplication.shared.applicationState == .active,
                  UIApplication.shared.isProtectedDataAvailable else { throw CancellationError() }
        }
        let kinds = try await Self.configuredWidgetKinds()
        try Task.checkCancellation()
        guard isCurrent, !widgetRetired else { throw CancellationError() }
        guard kinds.contains(DJConnectSessionSurfaceSnapshot.widgetKind) else {
            // No initial configuration means no OS-side ownership was made.
            // Removal AFTER actual selection is terminal, including ABA.
            if widgetWasSelected { widgetRetired = true; await withdrawOriginalRead() }
            return false
        }
        if firstSelection {
            guard parent.isActive, UIApplication.shared.applicationState == .active,
                  UIApplication.shared.isProtectedDataAvailable else { throw CancellationError() }
            widgetWasSelected = true
        }
        guard let snapshot = currentSnapshotData,
              let shared = UserDefaults(suiteName: DJConnectLocalization.appGroupIdentifier) else { throw CancellationError() }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let bytes = try encoder.encode(snapshot)
        guard isCurrent, currentSnapshotData == snapshot else { throw CancellationError() }
        // Negative latch precedes storage: interrupted work cannot expose old
        // private caches or a session-derived palette as a fallback.
        DJConnectSessionSurfaceSnapshot.suppressPrivateCacheFallback(in: shared)
        try DJConnectPassiveSurfaceCache.replace(nil, surface: .widget, in: shared)
        try DJConnectPassiveSurfaceCache.replace(nil, surface: .liveActivity, in: shared)
        shared.removeObject(forKey: DJConnectWidgetPaletteSnapshot.storageKey)
        guard isCurrent, currentSnapshotData == snapshot else { throw CancellationError() }
        let changed = shared.data(forKey: DJConnectSessionSurfaceSnapshot.storageKey) != bytes
        if changed { shared.set(bytes, forKey: DJConnectSessionSurfaceSnapshot.storageKey) }
        guard isCurrent else { throw CancellationError() }
        if changed || firstSelection { WidgetCenter.shared.reloadTimelines(ofKind: DJConnectSessionSurfaceSnapshot.widgetKind) }
        return changed || firstSelection
        #else
        throw CancellationError()
        #endif
    }
    #if os(iOS) && !targetEnvironment(simulator)
    private static func configuredWidgetKinds() async throws -> Set<String> {
        let reply = StatusWidgetConfigurationReply()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                reply.start(continuation)
                guard !Task.isCancelled else { reply.fail(); return }
                WidgetCenter.shared.getCurrentConfigurations { result in
                    // Framework objects stay on their original callback; only
                    // bounded, non-authoritative kind DATA crosses to the owner.
                    let kinds: Set<String>?
                    if case .success(let values) = result {
                        kinds = Set(values.filter { $0.kind == DJConnectSessionSurfaceSnapshot.widgetKind }.map(\.kind))
                    } else { kinds = nil }
                    Task { @MainActor in reply.finish(kinds) }
                }
            }
        } onCancel: { Task { @MainActor in reply.fail() } }
    }
    #endif
}

#if os(iOS) && !targetEnvironment(simulator)
/// Read-only OS query resource bound. Late callbacks cannot adopt a widget or
/// publish; this timer never changes the original read/display/field bounds.
@MainActor private final class StatusWidgetConfigurationReply {
    private let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    private var continuation: CheckedContinuation<Set<String>, any Error>?
    private var finished = false
    private var timeout: Task<Void, Never>?
    func start(_ continuation: CheckedContinuation<Set<String>, any Error>) {
        guard !finished else { continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        let deadline = deadline
        timeout = Task { [weak self] in
            do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
            self?.fail()
        }
    }
    func finish(_ kinds: Set<String>?) {
        guard !finished else { return }
        guard ContinuousClock.now < deadline, let kinds else { fail(); return }
        finished = true; timeout?.cancel(); timeout = nil
        continuation?.resume(returning: kinds); continuation = nil
    }
    func fail() {
        guard !finished else { return }; finished = true
        timeout?.cancel(); timeout = nil
        continuation?.resume(throwing: CancellationError()); continuation = nil
    }
}
#endif

/// Negative lifetime bookkeeping only. Synthetic tests may exercise this book
/// but cannot obtain a genuine original source or native OS publisher from it.
@MainActor final class StatusObservationOwnershipContinuity {
    private let originalIsCurrent: @MainActor () -> Bool
    private var closed = false
    init(originalIsCurrent: @escaping @MainActor () -> Bool) { self.originalIsCurrent = originalIsCurrent }
    var isCurrent: Bool {
        guard !closed, originalIsCurrent() else { closed = true; return false }
        return true
    }
}
