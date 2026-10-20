import Foundation
import Combine
import DJConnectCore

/// Source readiness is separate from release activation. The delivered producer
/// can withdraw a lease after bytes were downloaded but exposes no consumer
/// revocation signal. A journal receipt cannot attest continuing speech rights.
/// See docs/feedback/APPLE_PERSONA_TOUCH_PRODUCER_GAPS_20261019.md.
enum PersonaReactionConsumerGate { static let isQualified = false }

/// One bounded foreground interaction, no queue, persistence, history or retries.
@MainActor final class PersonaReactionController: ObservableObject {
    struct Services {
        var request: @MainActor (@escaping @Sendable (String) -> Void) async throws -> DJConnectPersonaReactionResult
        var cancel: @MainActor (String, DJConnectPersonaReactionCancellation) async -> Void
        var current: @MainActor () -> Bool
        var admitsSpeech: @MainActor (DJConnectPersonaReaction) -> Bool
        var play: @MainActor (DJConnectPersonaReaction, @escaping @MainActor (Bool) -> Void) async throws -> Bool
        var stop: @MainActor (DJConnectPersonaReactionCancellation) -> Void
        var failure: @MainActor () -> Void
        var notice: String?
        /// Foreground presentation feedback, once per accepted current response.
        var admittedFeedback: @MainActor () -> Void = {}
    }
    @MainActor private final class Run {
        let services: Services
        var id: String?
        var reason: DJConnectPersonaReactionCancellation?
        var cancelSent = false
        init(_ services: Services) { self.services = services }
        func cancelOnServer() {
            guard !cancelSent, let id, let reason else { return }
            cancelSent = true
            Task { await services.cancel(id, reason) }
        }
    }
    @Published private(set) var reaction: DJConnectPersonaReaction?
    @Published private(set) var preparing = false
    @Published private(set) var speaking = false
    @Published private(set) var notice: String?
    private var run: Run?
    private var task: Task<Void, Never>?
    private var monitor: Task<Void, Never>?
    var isActive: Bool { run != nil }

    func start(_ services: Services) {
        guard run == nil, services.current() else { return }
        let current = Run(services); run = current
        preparing = true; speaking = false; notice = nil
        // A pending request is bounded too, even before a result supplies expiry.
        let pendingDeadline = Date().addingTimeInterval(30)
        monitor = Task { [weak self, weak current] in
            while let self, let current, self.run === current, !Task.isCancelled {
                let deadline = self.reaction?.deadline ?? pendingDeadline
                guard current.services.current(), deadline > Date() else {
                    self.cancel(.dismissed); return
                }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
        task = Task { [weak self] in
            do {
                let result = try await services.request { id in
                    Task { @MainActor in
                        current.id = id
                        // Dismissal can precede admission. It still cancels the
                        // original operation identity, never creates another tap.
                        current.cancelOnServer()
                    }
                }
                guard let self, self.run === current, !Task.isCancelled, services.current(),
                      result.persona_reaction.deadline.map({ $0 > Date() }) == true else { return }
                guard current.id == nil || current.id == result.persona_reaction.id else {
                    self.cancel(.dismissed); services.failure(); return
                }
                current.id = result.persona_reaction.id
                self.reaction = result.persona_reaction
                self.notice = services.notice
                services.admittedFeedback()
                if services.admitsSpeech(result.persona_reaction) {
                    let completed = try await services.play(result.persona_reaction) { [weak self, current] playing in
                        guard let self, self.run === current, services.current(),
                              self.reaction?.deadline.map({ $0 > Date() }) == true else { return }
                        self.speaking = playing
                        if playing { self.preparing = false }
                    }
                    guard self.run === current, !Task.isCancelled else { return }
                    self.preparing = false; self.speaking = false
                    if completed { self.cancel(.completed) }
                    else { services.stop(.speechConflict); self.notice = "ui.session.reaction.speech_unavailable" }
                } else {
                    self.preparing = false
                    if services.notice == nil { self.notice = "ui.session.reaction.speech_unavailable" }
                }
            } catch {
                guard let self, self.run === current, !Task.isCancelled else { return }
                if self.reaction != nil {
                    services.stop(.speechConflict); self.preparing = false; self.speaking = false
                    self.notice = "ui.session.reaction.speech_unavailable"
                } else {
                    self.cancel(.dismissed); services.failure()
                }
            }
        }
    }
    func cancel(_ reason: DJConnectPersonaReactionCancellation) {
        guard let current = run else { return }
        current.reason = reason
        run = nil // Fence callbacks before stopping their renderer.
        task?.cancel(); task = nil; monitor?.cancel(); monitor = nil
        current.services.stop(reason)
        reaction = nil; preparing = false; speaking = false; notice = nil
        current.cancelOnServer()
    }
}
