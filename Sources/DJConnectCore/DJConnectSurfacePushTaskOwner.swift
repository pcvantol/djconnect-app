import Foundation

/// Process-local task custody. Native tokens/paired status are candidates, not
/// consent or a qualified original-purpose/clock witness. The public initializer
/// has NO admission factory, so acquisition remains closed in production.
@MainActor public final class DJConnectSurfacePushTaskOwner {
    public enum Role: String, Sendable { case widget, liveActivityUpdate = "live_activity_update" }
    public enum Phase: Equatable { case idle, admissionUnavailable, profileUnavailable, preparing, registering, registered, uncertain, withdrawn }
    public struct Scope: Equatable, Sendable {
        public let installation: String
        public let binding: String
        public let sessionID: String
        public let origin: URL
        public let deviceID: String
        public let clientType: String
        public init?(installation: String, binding: String, sessionID: String, origin: URL, deviceID: String, clientType: String) {
            guard !installation.isEmpty, installation.utf8.count <= 2048,
                  !binding.isEmpty, binding.utf8.count <= 2048,
                  DJConnectSurfacePushCoordinate.identifier(sessionID), DJConnectSurfacePushCoordinate.identifier(deviceID),
                  ["ios", "macos"].contains(clientType),
                  let c = URLComponents(url: origin, resolvingAgainstBaseURL: false),
                  ["http", "https"].contains(c.scheme), c.host?.isEmpty == false,
                  c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
                  c.path.isEmpty || c.path == "/" else { return nil }
            self.installation = installation; self.binding = binding
            self.sessionID = sessionID; self.origin = origin; self.deviceID = deviceID; self.clientType = clientType
        }
    }
    public struct Candidate: Equatable, Sendable {
        public let role: Role
        public let token: Data
        public let platform: String
        public let osVersion: String
        public let environment: String?
        public let target: [String: String]
        public init?(role: Role, token: Data, platform: String, osVersion: String,
                     environment: String?, target: [String: String]) {
            let fields: Set<String> = role == .widget
                ? ["instance_id", "app_bundle_id", "extension_bundle_id", "widget_kind"]
                : ["instance_id", "app_bundle_id", "activity_id", "attributes_type"]
            guard (16...2048).contains(token.count), ["ios", "ipados", "macos"].contains(platform),
                  environment.map({ ["sandbox", "production"].contains($0) }) ?? true, Set(target.keys) == fields,
                  target.values.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 200 }) else { return nil }
            self.role = role; self.token = token; self.platform = platform
            self.osVersion = osVersion; self.environment = environment; self.target = target
        }
    }

    // Internal MODEL seam only: no UI/runtime factory, persisted flag, wire rho
    // or public constructor can make one. A genuine factory still requires the
    // independently qualified OS clock/domain + original first-purpose flow.
    final class Admission {
        private var valid = true
        func withdraw() { valid = false }
        func isCurrent() -> Bool {
            guard valid, current() else { valid = false; return false }
            return true
        }
        let consent: [String: Bool]
        let current: () -> Bool
        let bounds: (DJConnectSurfacePushV3Data.Context, ContinuousClock.Instant) -> (purpose: ContinuousClock.Instant, submit: ContinuousClock.Instant)?
        init(modelConsent: [String: Bool], current: @escaping () -> Bool,
             modelBounds: @escaping (DJConnectSurfacePushV3Data.Context, ContinuousClock.Instant) -> (purpose: ContinuousClock.Instant, submit: ContinuousClock.Instant)?) {
            consent = modelConsent; self.current = current; bounds = modelBounds
        }
    }
    private struct Pin {
        let epoch: UUID
        let expiry: Int64
        let deadline: ContinuousClock.Instant
    }
    private struct Registered {
        let candidate: Candidate
        let admission: Admission
        let pin: Pin
        let coordinate: DJConnectSurfacePushCoordinate
        let read: DJConnectSurfaceBackgroundRead
        let client: DJConnectClient
    }
    public private(set) var phase: Phase = .idle
    public private(set) var coordinate: DJConnectSurfacePushCoordinate?
    public private(set) var uncertainOperationID: String?
    public var hasReadCustody: Bool {
        guard phase == .registered, let registered else { return false }
        guard registered.admission.isCurrent(), ContinuousClock.now < registered.pin.deadline else {
            withdrawLocally(); return false // Observed loss is terminal; no A→B→A revival.
        }
        return true
    }
    public var hasOwnedTask: Bool { task != nil || readTask != nil || statusTask != nil }
    public var observationGeneration: UUID { epoch }
    private let role: Role
    private let provider: ((Scope, Candidate) -> Admission?)?
    private var scope: Scope?
    private var candidate: Candidate?
    private var epoch = UUID()
    private var task: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var readTask: Task<DJConnectSurfacePushReadResponse?, Error>?
    private var statusTask: Task<DJConnectSurfacePushStatus?, Error>?
    private var readGeneration = UUID()
    private var statusGeneration = UUID()
    private var admissionInUse: Admission?
    private var attemptedCandidate: Candidate?
    private var registered: Registered?
    private var pins: [String: Pin] = [:] // Retained minima, including withdrawn/ABA contexts.

    public init(role: Role) { self.role = role; provider = nil }
    init(role: Role, modelProvider: @escaping (Scope, Candidate) -> Admission?) {
        self.role = role; provider = modelProvider
    }
    public func bind(_ next: Scope?) {
        guard next != scope else { return }
        withdrawLocally(); scope = next; candidate = nil
        attemptedCandidate = nil
        if next != nil { phase = .idle }
    }
    /// No await precedes local withdrawal. Old completions cannot refill read
    /// custody, including same-visible-owner A→B→A and cancelled HTTP replies.
    public func withdrawLocally() {
        epoch = UUID(); registered = nil; coordinate = nil
        admissionInUse?.withdraw(); admissionInUse = nil
        expiryTask?.cancel(); expiryTask = nil
        cancelReads()
        let old = task; task = nil; old?.cancel()
        candidate = nil; phase = .withdrawn
        // Pins are never evicted to create a new first-purpose assumption.
    }
    public func observe(_ next: Candidate?) {
        guard next != candidate else { return }
        if task != nil || phase == .uncertain {
            cancelReads()
            registered = nil; admissionInUse?.withdraw()
            expiryTask?.cancel(); expiryTask = nil
            task?.cancel(); task = nil; epoch = UUID()
            candidate = next; phase = .uncertain
            return // Never replace a possibly sent write with another UUID.
        }
        expiryTask?.cancel(); expiryTask = nil
        cancelReads()
        registered = nil // Rotation scrubs local reads before preparation awaits.
        candidate = next
        if next == nil { withdrawLocally() }
    }
    public func nativeActivityEnded(_ activityID: String) {
        guard role == .liveActivityUpdate, candidate?.target["activity_id"] == activityID else { return }
        withdrawLocally()
    }
    /// Explicitly selected operation; repeated calls on the same observed token
    /// never retry an uncertain result or an already owned task.
    public func register(using client: DJConnectClient, observationGeneration: UUID) {
        guard !Task.isCancelled, observationGeneration == epoch, task == nil, phase != .uncertain, let scope, let candidate,
              candidate.role == role, candidate != attemptedCandidate, client.baseURL == scope.origin,
              client.identity.deviceID == scope.deviceID, client.identity.clientType.rawValue == scope.clientType else { return }
        guard role == .widget else { phase = .profileUnavailable; return }
        guard let admission = provider?(scope, candidate), admission.isCurrent() else {
            phase = .admissionUnavailable; return
        }
        if let registered, registered.candidate == candidate { return }
        let started = ContinuousClock.now // Original C0, before ANY await/child scheduling.
        let operation = DJConnectOperationIdentity.uuidV7(milliseconds: Int(Date().timeIntervalSince1970 * 1000))
        guard let environment = candidate.environment, let request = DJConnectSurfacePushRequest(identity: client.identity, sessionID: scope.sessionID,
            operationID: operation, platform: candidate.platform, osVersion: candidate.osVersion,
            target: candidate.target, token: candidate.token, environment: environment,
            consent: admission.consent, expected: coordinate) else { phase = .admissionUnavailable; return }
        let captured = epoch, expected = coordinate
        attemptedCandidate = candidate; admissionInUse = admission
        phase = .preparing
        task = Task { [weak self] in
            guard let self else { return }
            defer { if epoch == captured { task = nil } }
            let current: @MainActor @Sendable () -> Bool = {
                !Task.isCancelled && self.epoch == captured && self.scope == scope && self.candidate == candidate && admission.isCurrent()
            }
            do {
                guard current(), ContinuousClock.now < started.advanced(by: .seconds(30)) else { throw CancellationError() }
                let contextBytes = try JSONSerialization.data(withJSONObject: ["contract_version": 3,
                    "device_id": request.deviceID, "client_type": request.clientType,
                    "session_id": scope.sessionID, "operation_id": operation])
                uncertainOperationID = operation
                let raw = try await client.nativeSurfacePushV3POST("context", bytes: contextBytes, isCurrent: current)
                let context = try DJConnectSurfacePushV3Data.decodeContext(raw, matchingOperation: operation)
                guard current(), let mapped = admission.bounds(context, started),
                      mapped.submit <= mapped.purpose,
                      mapped.submit <= started.advanced(by: .milliseconds(context.contextRemainingAtOriginalStartMS)),
                      mapped.purpose <= started.advanced(by: .milliseconds(context.purposeRemainingAtOriginalStartMS)) else { throw CancellationError() }
                let previous = pins[context.purposeReference]
                guard previous.map({ $0.epoch == captured && $0.expiry == context.purposeExpiryMS }) ?? (pins.count < 128) else { throw CancellationError() }
                let deadline = min(previous?.deadline ?? mapped.purpose, mapped.purpose)
                let pin = Pin(epoch: captured, expiry: context.purposeExpiryMS, deadline: deadline)
                pins[context.purposeReference] = pin
                guard current(), ContinuousClock.now < min(mapped.submit, deadline) else { throw CancellationError() }
                guard var body = try JSONSerialization.jsonObject(with: request.bytes) as? [String: Any] else { throw DJConnectError.invalidResponse }
                body["contract_version"] = 3; body["context_handle"] = context.contextHandle
                let bytes = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
                phase = .registering; uncertainOperationID = operation
                let reply = try await client.nativeSurfacePushV3POST("register", bytes: bytes, isCurrent: {
                    current() && ContinuousClock.now < min(mapped.submit, deadline)
                })
                guard current(), ContinuousClock.now < min(mapped.submit, deadline) else { throw CancellationError() }
                guard case .confirmed(let confirmed) = try DJConnectSurfacePushV3Data.decodeRegistration(reply, matchingContext: context),
                      confirmed.receipt.platform == candidate.platform else { throw DJConnectError.invalidResponse }
                let value = try JSONDecoder().decode(DJConnectSurfacePushResponse.self, from: reply)
                guard let receipt = value.registration, let read = value.background_read,
                      expected == nil || (receipt.coordinate.registration_id == expected?.registration_id &&
                        receipt.coordinate.generation == expected?.generation &&
                        expected!.revision < Int.max && receipt.coordinate.revision == expected!.revision + 1) else { throw DJConnectError.invalidResponse }
                guard current() else { throw CancellationError() }
                registered = Registered(candidate: candidate, admission: admission, pin: pin,
                    coordinate: receipt.coordinate, read: read, client: client)
                coordinate = receipt.coordinate; uncertainOperationID = nil; phase = .registered
                expiryTask = Task { [weak self] in
                    do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
                    guard let self, self.epoch == captured else { return }
                    self.withdrawLocally()
                }
            } catch {
                guard epoch == captured else { return }
                registered = nil
                // A failed context can also lose first-purpose history; don't
                // create a new original UUID from another polling callback.
                phase = uncertainOperationID != nil ? .uncertain : .withdrawn
            }
        }
    }
    private func cancelReads() {
        readGeneration = UUID(); statusGeneration = UUID()
        readTask?.cancel(); readTask = nil; statusTask?.cancel(); statusTask = nil
    }
    /// Status is metadata only: it never reconstructs credentials or admission.
    public func status() async throws -> DJConnectSurfacePushStatus? {
        guard !Task.isCancelled, statusTask == nil, hasReadCustody, let scope, let value = registered else { return nil }
        let captured = epoch, operation = UUID(); statusGeneration = operation
        let pending = Task<DJConnectSurfacePushStatus?, Error> {
            try await value.client.surfacePushStatus(sessionID: scope.sessionID,
                registrationID: value.coordinate.registration_id, isCurrent: {
                    self.epoch == captured && self.scope == scope && self.hasReadCustody && self.candidate == value.candidate
                })
        }
        statusTask = pending
        defer { if statusGeneration == operation { statusTask = nil } }
        let result = try await withTaskCancellationHandler { try await pending.value } onCancel: { pending.cancel() }
        guard !Task.isCancelled, epoch == captured, statusGeneration == operation,
              scope == self.scope, hasReadCustody, candidate == value.candidate else { return nil }
        return result
    }
    /// This original scoped read never publishes a native cache or mints a
    /// field/extension lifetime. Cold B and display rights are separate gates.
    public func read() async throws -> DJConnectSurfacePushReadResponse? {
        guard !Task.isCancelled, readTask == nil, hasReadCustody, let scope, let value = registered else { return nil }
        let captured = epoch, operation = UUID(); readGeneration = operation
        let pending = Task<DJConnectSurfacePushReadResponse?, Error> {
            let transport = try value.client.nativeSurfaceBackgroundTransport()
            let result = try await transport.read(value.read, isCurrent: {
                self.epoch == captured && self.scope == scope && self.hasReadCustody && self.candidate == value.candidate
            })
            guard self.epoch == captured, self.hasReadCustody,
                  result.success, result.contract_version == 1,
                  result.registration.coordinate == value.coordinate,
                  result.registration.expires_at_ms == value.pin.expiry,
                  result.registration.state == "registered", result.registration.token_role == self.role.rawValue,
                  result.registration.platform == value.candidate.platform,
                  result.registration.cache_policy == "private,no-store",
                  result.cache_policy == "private,no-store", result.passive_session.hasValidFields else { return nil }
            return result
        }
        readTask = pending
        defer { if readGeneration == operation { readTask = nil } }
        let result = try await withTaskCancellationHandler { try await pending.value } onCancel: { pending.cancel() }
        guard !Task.isCancelled, epoch == captured, readGeneration == operation,
              scope == self.scope, hasReadCustody, candidate == value.candidate else { return nil }
        return result
    }
    /// Revoke claims local withdrawal synchronously; remote completion grants nothing.
    public func revoke() {
        // Copy NO read credential or native token into the revocation task.
        let proof = registered.map { (current: $0.admission.current, deadline: $0.pin.deadline,
                                       coordinate: $0.coordinate, client: $0.client) }
        let originalScope = scope
        withdrawLocally()
        guard !Task.isCancelled, let proof, let originalScope, proof.current(),
              ContinuousClock.now < proof.deadline else { return }
        let captured = epoch
        task = Task { [weak self] in
            guard let self else { return }
            defer { if epoch == captured { task = nil } }
            _ = try? await proof.client.revokeSurfacePush(sessionID: originalScope.sessionID,
                operationID: DJConnectOperationIdentity.uuidV7(milliseconds: Int(Date().timeIntervalSince1970 * 1000)),
                expected: proof.coordinate, isCurrent: {
                    !Task.isCancelled && self.epoch == captured && self.scope == originalScope &&
                    proof.current() && ContinuousClock.now < proof.deadline
                })
        }
    }
}
