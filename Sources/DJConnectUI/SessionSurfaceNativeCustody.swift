import Foundation
import DJConnectCore

/// Bounded live-handle ownership only, not an operation journal or replay ledger.
@MainActor protocol SessionSurfaceRetirableHandle: AnyObject {
    var isRetired: Bool { get }
    func retire()
}
@MainActor final class SessionSurfaceNativeHandleRegistry<Handle: SessionSurfaceRetirableHandle> {
    private var entries: [String: Handle] = [:]
    private let capacity = 128
    var count: Int { entries.count }
    var hasCapacity: Bool { count < capacity }
    var values: [Handle] { Array(entries.values) }
    subscript(id: String) -> Handle? { entries[id] }
    @discardableResult func insert(_ handle: Handle, id: String) -> Bool {
        guard hasCapacity, !handle.isRetired, entries[id] == nil else { return false }
        entries[id] = handle
        return true
    }
    @discardableResult func retire(_ handle: Handle, id: String) -> Bool {
        handle.retire() // Outstanding references close before the capacity is released.
        guard entries[id] === handle else { return false }
        entries.removeValue(forKey: id)
        return true
    }
}

/// Actual AppModel-local generation custody. Tickets are created by this live
/// object, never decoded/restored from a cache or constructed from a wire UUID.
/// These are necessary dispatch guards, not original rich-start permission.
@MainActor final class SessionSurfaceNativeCustody {
    struct Scope: Equatable {
        let installation: String?
        let binding: String
        let session: String
        let settingsGeneration: String?
        let settingsRevision: Int
    }
    @MainActor final class Ticket {
        private weak var owner: SessionSurfaceNativeCustody?
        private let ownerGeneration: UUID
        private let frameGeneration: UUID
        let dispatchCapture: DJConnectNativeSurfaceClockCapture?
        fileprivate init(owner: SessionSurfaceNativeCustody) {
            self.owner = owner; ownerGeneration = owner.ownerGeneration; frameGeneration = owner.frameGeneration
            dispatchCapture = owner.foreground && !owner.awaitingForegroundConfirmation && owner.scope != nil
                ? .capture() : nil // No new positive capture from background/negative work.
        }
        var isOwnerCurrent: Bool {
            guard !Task.isCancelled, let owner else { return false }
            return owner.ownerGeneration == ownerGeneration
        }
        var isCurrent: Bool { isOwnerCurrent && owner?.frameGeneration == frameGeneration }
        var canStart: Bool { canStartStatus && owner?.privateFieldsSuppressed == false }
        // Necessary UI/native-root guard only. The status controller ALSO needs
        // the genuine original source and actual OS Activity/cache choice.
        var canStartStatus: Bool { isCurrent && owner?.foreground == true && owner?.awaitingForegroundConfirmation == false && dispatchCapture != nil }
        var privateFieldsSuppressed: Bool { owner?.privateFieldsSuppressed != false }
        func currentSnapshot(at now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DJConnectSessionSurfaceSnapshot? {
            canPublish(at: now, uptime: uptime) ? owner?.snapshot : nil
        }
        func canPublish(at now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
            guard isCurrent, let owner, !owner.privateFieldsSuppressed, owner.scope != nil, let snapshot = owner.snapshot,
                  snapshot.isCurrent(at: now) else { return false }
            if let rich = snapshot.rich {
                guard rich.isCurrent(at: now, uptime: uptime),
                      rich.contribution == nil || rich.currentContribution(at: now, uptime: uptime) != nil,
                      rich.nowPlaying == nil || rich.currentPlayback(at: now, uptime: uptime) != nil else { return false }
            }
            return isCurrent
        }
    }
    private var scope: Scope?
    private var presentationID: String?
    private var snapshot: DJConnectSessionSurfaceSnapshot?
    private var foreground = false
    private(set) var awaitingForegroundConfirmation = false
    private var ownerGeneration = UUID()
    private var frameGeneration = UUID()
    private var privateFieldsSuppressed = false

    /// Negative-only one-way attenuation. Invalidates queued private work while
    /// preserving the identity of already owned native handles for status/end.
    func suppressPrivateFields() {
        guard !privateFieldsSuppressed else { return }
        privateFieldsSuppressed = true; snapshot = nil; frameGeneration = UUID()
    }

    func bind(scope next: Scope?, presentationID: String?, snapshot: DJConnectSessionSurfaceSnapshot?, foreground: Bool = true,
              confirmedForeground: Bool = false) {
        if scope != next || self.presentationID != presentationID {
            ownerGeneration = UUID(); frameGeneration = UUID()
        } else if self.snapshot != snapshot || self.foreground != foreground { frameGeneration = UUID() }
        if scope != nil && next == nil { awaitingForegroundConfirmation = true }
        if confirmedForeground && foreground && next != nil {
            if awaitingForegroundConfirmation { frameGeneration = UUID() }
            awaitingForegroundConfirmation = false
        }
        scope = next; self.presentationID = presentationID
        self.snapshot = privateFieldsSuppressed ? nil : snapshot
        self.foreground = foreground
    }
    func capture() -> Ticket { Ticket(owner: self) }
    func retains(scope candidate: Scope, presentationID: String?) -> Bool {
        scope == candidate && self.presentationID == presentationID
    }
    func suspend() {
        if foreground { foreground = false; frameGeneration = UUID() }
        awaitingForegroundConfirmation = true
    }
    func withdraw() {
        ownerGeneration = UUID(); frameGeneration = UUID(); scope = nil; presentationID = nil; snapshot = nil; foreground = false
        awaitingForegroundConfirmation = true
    }
}
