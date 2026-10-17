import Combine
import Foundation
import ImageIO
import DJConnectCore

/// Foreground-only, RAM-only grant owner. It never derives rights from a Moment,
/// private owner response, previous cache, app launch, or a Watch request.
@MainActor public final class PassiveSessionSurfaceModel: ObservableObject {
    public enum Phase: String { case idle, loading, ready, unavailable }
    public struct Services {
        public var available: () async throws -> Bool
        public var authorize: (String, DJConnectPassiveSurface, Bool) async throws -> DJConnectPassiveSurfaceResponse?
        public var read: (String, DJConnectPassiveSurface, String) async throws -> DJConnectPassiveSurfaceResponse
        public var image: (DJConnectPassiveSession.Artwork, DJConnectPassiveSurfaceResponse) async throws -> Data
        public init(available: @escaping () async throws -> Bool,
                    authorize: @escaping (String, DJConnectPassiveSurface, Bool) async throws -> DJConnectPassiveSurfaceResponse?,
                    read: @escaping (String, DJConnectPassiveSurface, String) async throws -> DJConnectPassiveSurfaceResponse,
                    image: @escaping (DJConnectPassiveSession.Artwork, DJConnectPassiveSurfaceResponse) async throws -> Data) {
            self.available = available; self.authorize = authorize; self.read = read; self.image = image
        }
    }
    @Published public private(set) var available = false
    @Published public private(set) var phases: [DJConnectPassiveSurface: Phase] = [:]
    @Published public private(set) var caches: [DJConnectPassiveSurface: DJConnectPassiveSurfaceCache] = [:]
    public var onChange: (() -> Void)?
    public private(set) var renderingRevision = UUID()
    private func notify() { renderingRevision = UUID(); onChange?() }
    private var owner: String?
    private var sessionID: String?
    private var active = false
    private var epoch = UUID()
    private struct Grant {
        let id: String
        let binding: String
        let generation: String
        init(_ response: DJConnectPassiveSurfaceResponse) {
            id = response.grant_id; binding = response.passive_session.binding_id; generation = response.passive_session.generation
        }
    }
    private var grants: [DJConnectPassiveSurface: Grant] = [:]
    private var tasks: [DJConnectPassiveSurface: Task<Void, Never>] = [:]
    private var versions: [DJConnectPassiveSurface: UUID] = [:]
    private var lastRead: [DJConnectPassiveSurface: Date] = [:]
    private var discovering = false
    private var expiryTask: Task<Void, Never>?
    private var invalidationTask: Task<Void, Never>?
    private var lastInvalidationSequence = -1
    private var automaticAttempts: Set<DJConnectPassiveSurface> = []
    public init() {}
    public func enabled(_ surface: DJConnectPassiveSurface) -> Bool { grants[surface] != nil }
    public func busy(_ surface: DJConnectPassiveSurface) -> Bool { tasks[surface] != nil }

    public func bind(owner nextOwner: String?, sessionID nextSession: String?, foreground: Bool) {
        let changed = owner != nextOwner || sessionID != nextSession
        if changed || active != foreground {
            epoch = UUID(); discovering = false
            if foreground { lastRead = [:] }
            tasks.values.forEach { $0.cancel() }; tasks = [:]
            invalidationTask?.cancel(); invalidationTask = nil
        }
        owner = nextOwner; sessionID = nextSession
        active = foreground && owner != nil && sessionID != nil
        if changed {
            automaticAttempts = []
            available = false; grants = [:]; caches = [:]; versions = [:]; lastRead = [:]; phases = [:]; lastInvalidationSequence = -1
            expiryTask?.cancel(); notify()
        }
    }
    /// OS configuration and a freshly confirmed active Session replace the old
    /// extra pop-out. One authorization attempt per owner/Session/OS choice;
    /// uncertain writes and server revocation never become a retry loop.
    public func reconcileAutomatic(surfaces: Set<DJConnectPassiveSurface>, services: Services) async {
        guard active else { return }
        let captured = epoch
        if !available { await discover(services) }
        guard active, captured == epoch, available else { return }
        for surface in DJConnectPassiveSurface.allCases {
            guard active, captured == epoch else { return }
            if !surfaces.contains(surface) {
                automaticAttempts.remove(surface)
                if enabled(surface) || busy(surface) {
                    tasks[surface]?.cancel(); tasks[surface] = nil
                    versions[surface] = UUID()
                    await setEnabled(false, surface: surface, services: services)
                }
            } else if !enabled(surface), !busy(surface), !automaticAttempts.contains(surface) {
                automaticAttempts.insert(surface)
                await setEnabled(true, surface: surface, services: services)
            }
        }
    }
    public func suspend() {
        guard active || !tasks.isEmpty || discovering else { return }
        active = false; epoch = UUID(); discovering = false
        tasks.values.forEach { $0.cancel() }; tasks = [:]
        invalidationTask?.cancel(); invalidationTask = nil
        // Already permitted OS snapshots keep only their original short deadlines.
    }
    /// History suspension is separate from passive consent. On foreground,
    /// withdraw rendered bytes until the original grant is authoritatively read.
    public func pauseForRevalidation() {
        let changed = active || !caches.isEmpty
        suspend()
        caches = [:]; expiryTask?.cancel()
        if changed { notify() }
    }
    public func discover(_ services: Services) async {
        guard active, !discovering else { return }
        let captured = epoch; discovering = true
        defer { if captured == epoch { discovering = false } }
        do {
            let supported = try await services.available()
            guard captured == epoch, active else { return }
            available = supported
            if !supported { grants = [:]; caches = [:]; notify() }
        } catch { if captured == epoch { available = false } }
    }
    /// Performs one requested state change. Callers fence automatic attempts;
    /// uncertain writes are never replayed here.
    public func setEnabled(_ enabled: Bool, surface: DJConnectPassiveSurface, services: Services) async {
        guard active, (!enabled || available), !busy(surface), let sessionID else { return }
        let captured = epoch, version = UUID(); versions[surface] = version
        // Local revocation is immediate even when the server is unreachable.
        if !enabled { grants[surface] = nil; caches[surface] = nil; notify() }
        phases[surface] = .loading
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if versions[surface] == version { tasks[surface] = nil } }
            do {
                let result = try await services.authorize(sessionID, surface, enabled)
                guard current(captured, version, surface), !Task.isCancelled else { return }
                if enabled {
                    guard let result, result.validates(sessionID: sessionID, surface: surface),
                          result.passive_session.cache_policy.locked_display else { throw DJConnectError.invalidResponse }
                    grants[surface] = Grant(result)
                    try await accept(result, surface: surface, captured: captured, version: version, services: services)
                } else { phases[surface] = .idle }
            } catch {
                guard current(captured, version, surface) else { return }
                grants[surface] = nil; caches[surface] = nil; phases[surface] = .unavailable; notify()
            }
        }
        tasks[surface] = task
        await task.value
    }
    /// The owner Broadcast hint grants no content. Coalesce it into pure reads,
    /// at most one batch per two seconds; never authorize or publish from a hint.
    public func invalidate(sequence: Int, services: Services) {
        guard active, !grants.isEmpty, sequence > lastInvalidationSequence else { return }
        lastInvalidationSequence = sequence
        guard invalidationTask == nil else { return }
        let captured = epoch
        let delay = max(0.25, 2 - Date().timeIntervalSince(lastRead.values.max() ?? .distantPast))
        invalidationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, captured == epoch, active else { return }
            invalidationTask = nil; refresh(services, force: true)
        }
    }
    /// Called by the existing foreground coordinator, not a new polling loop.
    public func refresh(_ services: Services, force: Bool = false) {
        guard active, let sessionID else { return }
        for (surface, grant) in grants {
            guard !busy(surface), force || lastRead[surface].map({ Date().timeIntervalSince($0) >= 15 }) != false else { continue }
            let captured = epoch, version = versions[surface] ?? UUID(); versions[surface] = version
            lastRead[surface] = Date()
            tasks[surface] = Task { @MainActor [weak self] in
                guard let self else { return }
                defer { if versions[surface] == version { tasks[surface] = nil } }
                do {
                    let result = try await services.read(sessionID, surface, grant.id)
                    guard current(captured, version, surface), !Task.isCancelled else { return }
                    guard result.passive_session.binding_id == grant.binding,
                          result.passive_session.generation == grant.generation else { throw DJConnectError.invalidResponse }
                    try await accept(result, surface: surface, captured: captured, version: version, services: services)
                } catch {
                    guard current(captured, version, surface) else { return }
                    if Self.withdraws(error) {
                        grants[surface] = nil; caches[surface] = nil; phases[surface] = .unavailable; notify()
                    }
                    // A network failure is not a fresh observation. Original
                    // cache/field/uptime deadlines still expire independently.
                }
            }
        }
    }
    private func current(_ captured: UUID, _ version: UUID, _ surface: DJConnectPassiveSurface) -> Bool {
        active && epoch == captured && versions[surface] == version
    }
    private static func withdraws(_ error: Error) -> Bool {
        guard let e = error as? DJConnectError else { return !(error is URLError) && !(error is CancellationError) }
        if e.invalidatesSessionAuthority { return true }
        switch e {
        case .invalidResponse, .routeMissing, .decodingFailed: return true
        case .server(let status, _): return status < 500
        default: return false
        }
    }
    private func accept(_ result: DJConnectPassiveSurfaceResponse, surface: DJConnectPassiveSurface,
                        captured: UUID, version: UUID, services: Services) async throws {
        let p = result.passive_session, now = Date()
        guard p.isValid, p.surface == surface, p.session_id == sessionID,
              let asOf = DJConnectHistoryEntry.date(p.as_of), abs(asOf.timeIntervalSince(now)) <= 30 else { throw DJConnectError.invalidResponse }
        if let previous = caches[surface]?.projection {
            guard p.binding_id == previous.binding_id, p.generation == previous.generation,
                  p.delivery_sequence >= previous.delivery_sequence,
                  asOf >= (DJConnectHistoryEntry.date(previous.as_of) ?? .distantFuture) else { return }
        }
        guard p.isCurrent(at: now) else { caches[surface] = nil; phases[surface] = .ready; notify(); return }
        let previous = caches[surface]
        // Publish text/metadata first; optional image IO cannot block the whole surface.
        caches[surface] = try DJConnectPassiveSurfaceCache(projection: p.removingExpiredFields(at: now), at: now)
        phases[surface] = .ready; notify(); scheduleExpiry()
        var pixels: [String: Data] = [:]
        for a in p.artwork where p.currentArtwork(slot: a.slot, at: Date()) != nil {
            if previous?.projection.currentArtwork(slot: a.slot, at: Date()) == a, let existing = previous?.pixels[a.slot] {
                pixels[a.slot] = existing
            } else {
                do {
                    let data = try await services.image(a, result)
                    guard current(captured, version, surface), !Task.isCancelled else { return }
                    guard Self.validPixels(data) else { continue }
                    pixels[a.slot] = data
                } catch {
                    if (error as? DJConnectError)?.invalidatesSessionAuthority == true { throw error }
                    // Missing/expired/unavailable cover never borrows another slot.
                }
            }
        }
        guard current(captured, version, surface), !Task.isCancelled, p.isCurrent(at: Date()) else { return }
        let valid = pixels.filter { p.currentArtwork(slot: $0.key, at: Date()) != nil }
        caches[surface] = try DJConnectPassiveSurfaceCache(projection: p.removingExpiredFields(at: Date()), pixels: valid)
        notify(); scheduleExpiry()
    }
    private static func validPixels(_ data: Data) -> Bool {
        guard data.count <= DJConnectPassiveSurfaceCache.maximumImageBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1, CGImageSourceGetType(source) as String? == "public.png",
              CGImageSourceGetStatus(source) == .statusComplete,
              let values = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = values[kCGImagePropertyPixelWidth] as? Int, let height = values[kCGImagePropertyPixelHeight] as? Int else { return false }
        return width > 0 && height > 0 && width <= 512 && height <= 512
    }
    private func scheduleExpiry() {
        expiryTask?.cancel()
        let now = Date()
        guard let deadline = caches.values.flatMap({ $0.projection.deadlines }).filter({ $0 > now }).min() else { return }
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            guard let self, !Task.isCancelled else { return }
            let now = Date()
            caches = caches.compactMapValues { $0.isCurrent(at: now) ? $0.removingExpiredFields(at: now) : nil }
            notify(); scheduleExpiry()
        }
    }
}
