import Foundation
import DJConnectCore

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
        let dispatchCapture: DJConnectNativeSurfaceClockCapture
        fileprivate init(owner: SessionSurfaceNativeCustody) {
            self.owner = owner; ownerGeneration = owner.ownerGeneration; frameGeneration = owner.frameGeneration
            dispatchCapture = .capture() // Before the caller creates/awaits a task.
        }
        var isOwnerCurrent: Bool {
            guard !Task.isCancelled, let owner else { return false }
            return owner.ownerGeneration == ownerGeneration
        }
        var isCurrent: Bool { isOwnerCurrent && owner?.frameGeneration == frameGeneration }
        var canStart: Bool { isCurrent && owner?.foreground == true }
        func canPublish(at now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
            guard isCurrent, let owner, owner.scope != nil, let snapshot = owner.snapshot,
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
    private var ownerGeneration = UUID()
    private var frameGeneration = UUID()

    func bind(scope next: Scope?, presentationID: String?, snapshot: DJConnectSessionSurfaceSnapshot?, foreground: Bool = true) {
        if scope != next || self.presentationID != presentationID {
            ownerGeneration = UUID(); frameGeneration = UUID()
        } else if self.snapshot != snapshot || self.foreground != foreground { frameGeneration = UUID() }
        scope = next; self.presentationID = presentationID; self.snapshot = snapshot
        self.foreground = foreground
    }
    func capture() -> Ticket { Ticket(owner: self) }
    func withdraw() {
        ownerGeneration = UUID(); frameGeneration = UUID(); scope = nil; presentationID = nil; snapshot = nil; foreground = false
    }
}
