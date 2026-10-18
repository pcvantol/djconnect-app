import Combine
import Foundation

/// Revision metadata for an already admitted Watch card, never executable
/// segments, audio, credentials or a replacement for prepare3 authorization.
public struct DJConnectWatchSpeechSource: Codable, Equatable, Sendable {
    public let reference: DJConnectSpeechReference
    public let textRevision: String
    public let presentationRevision: String
    public let persona: String?
    public let personaRevision: Int?
    public let locale: String
    public let attribution: [DJConnectSessionSpeech.Attribution]?
    public let expiresAt: String
    public init?(_ original: DJConnectSessionSpeech, text: String, at now: Date = Date()) {
        guard original.admits(reference: original.reference, text: text, at: now),
              original.advertisesPreparationAttempt(.localOnDevice), original.processorQualificationRequired == true,
              let textRevision = original.textRevision, let presentationRevision = original.presentationRevision,
              let locale = original.locale, let expires = original.expiresAt else { return nil }
        reference = original.reference; self.textRevision = textRevision
        self.presentationRevision = presentationRevision; persona = original.persona
        personaRevision = original.personaRevision; self.locale = locale
        attribution = original.attribution; expiresAt = expires
    }
    public func matches(_ prepared: DJConnectSessionSpeech, at now: Date = Date()) -> Bool {
        guard let sourceDeadline = DJConnectHistoryEntry.date(expiresAt), sourceDeadline > now,
              let deadline = prepared.expiresAt.flatMap(DJConnectHistoryEntry.date), deadline <= sourceDeadline else { return false }
        return reference == prepared.reference && textRevision == prepared.textRevision &&
            presentationRevision == prepared.presentationRevision && persona == prepared.persona &&
            personaRevision == prepared.personaRevision && locale == prepared.locale && attribution == prepared.attribution
    }
}

/// Interactive Watch-owned intent, not a bearer or an iPhone speech grant.
/// The iPhone re-reads with the Watch identity and compares this visible source.
public struct DJConnectWatchMomentSpeechRequest: Codable, Sendable {
    public let settings: DJConnectProfileDJSettingsResponse
    public let moment: DJConnectMoment
    public let source: DJConnectWatchSpeechSource
    public var reference: DJConnectSpeechReference { .moment(sessionID: moment.sessionID, momentID: moment.id) }
    public init(settings: DJConnectProfileDJSettingsResponse, moment: DJConnectMoment, source: DJConnectWatchSpeechSource) {
        self.settings = settings; self.moment = moment; self.source = source
    }
    public func matches(_ snapshot: DJConnectWatchSessionSnapshot, at now: Date = Date()) -> Bool {
        guard snapshot.isValid, settings.allowsSpeech(.local), snapshot.settings.allowsSpeech(.local),
              settings.binding == snapshot.settings.binding, settings.speechFence == snapshot.settings.speechFence,
              settings.snapshot.effective == snapshot.settings.snapshot.effective,
              settings.voice_revision == snapshot.settings.voice_revision,
              !moment.content.isEmpty, moment.content.unicodeScalars.count <= 4000,
              source.reference == reference, snapshot.speechSources.contains(source),
              let expiry = DJConnectHistoryEntry.date(source.expiresAt), expiry > now,
              let session = snapshot.session, session.id == moment.sessionID else { return false }
        let current = session.broadcast.nativeCurrentMoment(at: now, spotifyAttributionAvailable: true)
        let flow = session.broadcast.nativeFlowMoments(at: now)
        return ([current].compactMap { $0 } + flow).contains { $0 == moment }
    }
}

/// A manual foreground replay of an admitted Watch card. It never queues old
/// contributions or turns a refresh/reconnect into an autoplay event.
@MainActor public final class DJConnectWatchSessionSpeech: ObservableObject {
    public enum State: Equatable { case idle, preparing, playing, unavailable }
    @Published public private(set) var state: State = .idle
    @Published public private(set) var momentID: String?
    private var task: Task<Void, Never>?
    private let stopOutput: () -> Void
    private lazy var coordinator = DJConnectAudioPlaybackCoordinator { [weak self] in self?.clear() }
    public init(stopOutput: @escaping () -> Void) { self.stopOutput = stopOutput }
    private func clear() {
        task?.cancel(); task = nil
        state = .idle; momentID = nil
        stopOutput()
    }
    public func stop() { coordinator.stop() }
    public func play(_ request: DJConnectWatchMomentSpeechRequest,
                     preferences: DJConnectDeviceSpeechPreferences,
                     prepare: @escaping @MainActor () async throws -> DJConnectSharedSpeechResult,
                     isCurrent: @escaping @MainActor () -> Bool,
                     start: @escaping @MainActor (DJConnectSessionSpeech, @escaping () -> Void) throws -> Bool) {
        stop()
        guard preferences.enabled, preferences.isValid, request.settings.allowsSpeech(.local), isCurrent(),
              let ticket = coordinator.begin(deadline: Date().addingTimeInterval(300)) else { return }
        state = .preparing; momentID = request.moment.id
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            @MainActor func current() -> Bool { !Task.isCancelled && isCurrent() && coordinator.isCurrent(ticket) }
            defer { coordinator.finish(ticket) }
            do {
                let response = try await prepare()
                guard current() else { return }
                let speech = response.session_speech
                guard response.success, request.source.matches(speech), DJConnectNativeSpeechAdmission.admits(speech, reference: request.reference,
                    text: request.moment.content, settings: request.settings),
                    let deadline = speech.playbackDeadline(), coordinator.shortenDeadline(deadline, for: ticket) else {
                    fail(ticket, id: request.moment.id); return
                }
                guard try start(speech, { [weak self] in self?.coordinator.finish(ticket) }) else {
                    fail(ticket, id: request.moment.id); return
                }
                // A synchronous finish cannot reclaim ownership of a stopped ticket.
                guard current() else { return }
                state = .playing
                while current() && DJConnectNativeSpeechAdmission.admits(speech, reference: request.reference,
                    text: request.moment.content, settings: request.settings) {
                    try await Task.sleep(for: .milliseconds(100))
                }
            } catch {
                if current() { fail(ticket, id: request.moment.id) }
            }
        }
    }
    private func fail(_ ticket: DJConnectAudioPlaybackCoordinator.Ticket, id: String) {
        guard coordinator.isCurrent(ticket) else { return }
        coordinator.finish(ticket)
        state = .unavailable; momentID = id
    }
}
