import Foundation
import Combine
import DJConnectCore

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
        /// Shipping caller always supplies the independently negotiated observer.
        var observe: @MainActor (DJConnectPersonaReactionResult) async throws -> DJConnectPersonaReactionObservation = { _ in throw DJConnectHybridTransportError.unavailable }
        /// Device clock seam for deterministic expiry tests; shipping uses Date().
        var now: @MainActor () -> Date = { Date() }
    }
    @MainActor private final class Run {
        let services: Services
        var id: String?
        var reason: DJConnectPersonaReactionCancellation?
        var cancelSent = false
        var observation: DJConnectPersonaReactionObservation?
        var observationTask: Task<Void, Never>?
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
        let pendingDeadline = services.now().addingTimeInterval(30)
        monitor = Task { [weak self, weak current] in
            while let self, let current, self.run === current, !Task.isCancelled {
                let deadline = self.reaction?.deadline ?? pendingDeadline
                guard current.services.current(), deadline > current.services.now(), current.observation?.isValid != false else {
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
                guard let self, self.run === current, !Task.isCancelled else { return }
                guard services.current(), result.persona_reaction.deadline.map({ $0 > services.now() }) == true else {
                    // A completed but expired response is no longer a pending
                    // request. Close this original run so a deliberate new tap
                    // is possible; late callbacks retain its cancellation fence.
                    self.cancel(.dismissed); return
                }
                guard current.id == nil || current.id == result.persona_reaction.id else {
                    self.cancel(.dismissed); services.failure(); return
                }
                current.id = result.persona_reaction.id
                do {
                    let observation = try await services.observe(result)
                    guard self.run === current, !Task.isCancelled, services.current(), observation.isValid else {
                        await observation.close(); return
                    }
                    current.observation = observation
                    current.observationTask = Task { [weak self, weak current] in
                        for await _ in observation.withdrawals {
                            guard let self, let current, self.run === current else { return }
                            self.cancel(.dismissed); return
                        }
                    }
                }
                guard self.run === current, current.observation?.isValid != false, services.current(), !Task.isCancelled else { return }
                self.reaction = result.persona_reaction
                self.notice = services.notice
                services.admittedFeedback()
                if services.admitsSpeech(result.persona_reaction) {
                    let completed = try await services.play(result.persona_reaction) { [weak self, current] playing in
                        guard let self, self.run === current, services.current(),
                              self.reaction?.deadline.map({ $0 > services.now() }) == true else { return }
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
        current.observationTask?.cancel()
        if let observation = current.observation { Task { await observation.close() } }
        current.observation = nil
        task?.cancel(); task = nil; monitor?.cancel(); monitor = nil
        current.services.stop(reason)
        reaction = nil; preparing = false; speaking = false; notice = nil
        current.cancelOnServer()
    }
}
