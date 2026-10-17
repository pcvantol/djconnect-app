import Foundation

/// RAM-only orchestration for an explicit Listen action on an accepted contribution.
/// The UI owner must update context on authority/route/selection changes and set it
/// to nil on background or withdrawal. Reads, menu opening and reconnect never call Listen.
/// This path supports only the qualified HA processor; it never falls back to local TTS.
@MainActor
public final class DJConnectSpeechPlaybackRuntime {
    public struct Context: Equatable, Sendable {
        public let scope: DJConnectSpeechVoiceScope
        public let epoch: UUID
        public let selection: UUID
        public let preference: DJConnectVoicePreference
        public let voiceID: String?

        public init(scope: DJConnectSpeechVoiceScope, epoch: UUID, selection: UUID,
                    preference: DJConnectVoicePreference = .default, voiceID: String? = nil) {
            self.scope = scope; self.epoch = epoch; self.selection = selection
            self.preference = preference; self.voiceID = voiceID
        }
    }

    public enum State: Equatable, Sendable { case idle, preparing, downloading, playing, unavailable }

    /// Production adapters use DJConnectClient's bounded, authenticated, no-store
    /// routes. Output receives validated bytes, never a provider URL or file path.
    public struct Services {
        public let options: () async throws -> DJConnectSpeechVoiceOptions
        public let prepare: (DJConnectSessionSpeech, String, Context, DJConnectSpeechVoiceOptions) async throws -> DJConnectSessionSpeech
        public let audio: (DJConnectSessionSpeech, String) async throws -> Data
        public let play: (Data, @escaping @MainActor () -> Void) throws -> Void
        public let stop: () -> Void

        public init(client: DJConnectClient,
                    play: @escaping (Data, @escaping @MainActor () -> Void) throws -> Void,
                    stop: @escaping () -> Void) {
            options = { try await client.speechVoiceOptions() }
            prepare = { original, text, context, options in
                try await client.prepareSpeech(original, acceptedText: text, processor: .haConfigured,
                    preference: context.preference, voiceOptions: options, selectedVoiceID: context.voiceID)
            }
            audio = { try await client.speechAudio($0, acceptedText: $1) }
            self.play = play; self.stop = stop
        }

        // Internal dependency injection keeps modeled tests separate from native audio proof.
        init(options: @escaping () async throws -> DJConnectSpeechVoiceOptions,
             prepare: @escaping (DJConnectSessionSpeech, String, Context, DJConnectSpeechVoiceOptions) async throws -> DJConnectSessionSpeech,
             audio: @escaping (DJConnectSessionSpeech, String) async throws -> Data,
             play: @escaping (Data, @escaping @MainActor () -> Void) throws -> Void,
             stop: @escaping () -> Void) {
            self.options = options; self.prepare = prepare; self.audio = audio
            self.play = play; self.stop = stop
        }
    }

    public private(set) var state: State = .idle
    public private(set) var context: Context?
    public private(set) var retryAfter: Date?
    private let now: () -> Date
    private var task: Task<Void, Never>?
    private var stopOutput: (() -> Void)?
    private lazy var coordinator = DJConnectAudioPlaybackCoordinator(now: now) { [weak self] in
        guard let self else { return }
        self.task?.cancel(); self.task = nil
        let stop = self.stopOutput; self.stopOutput = nil
        self.state = .idle
        stop?()
    }

    public init(now: @escaping () -> Date = Date.init) { self.now = now }

    public func updateContext(_ value: Context?) {
        guard context != value else { return }
        stop()
        context = value
    }

    public func stop() { coordinator.stop() }

    /// One replacement slot, no queue and no retries. Claim ownership before
    /// scheduling work, so Stop before the task starts also suppresses preparation.
    @discardableResult
    public func listen(_ original: DJConnectSessionSpeech, reference: DJConnectSpeechReference,
                       acceptedText: String, services: Services) -> Bool {
        stop()
        guard let captured = context,
              retryAfter.map({ $0 <= now() }) ?? true,
              original.admits(reference: reference, text: acceptedText, at: now()),
              original.sessionID == nil || original.sessionID == captured.scope.sessionID,
              original.advertisesPreparationAttempt(.haConfigured),
              let deadline = original.expiresAt.flatMap(DJConnectHistoryEntry.date),
              let ticket = coordinator.begin(deadline: deadline) else { return false }
        stopOutput = services.stop
        state = .preparing
        task = Task { @MainActor [weak self] in
            guard let self, self.current(ticket, captured) else { return }
            do {
                let options = try await services.options()
                guard self.current(ticket, captured) else { return }
                guard options.isValid, options.preferenceContext?.isSupported == true,
                      options.supports(captured.preference),
                      captured.voiceID.map(options.supportsVoice) ?? true,
                      captured.preference == .default || options.admitsGender(captured.preference, voiceID: captured.voiceID)
                else { throw DJConnectError.invalidResponse }
                let prepared = try await services.prepare(original, acceptedText, captured, options)
                guard self.current(ticket, captured) else { return }
                guard prepared.admits(reference: reference, text: acceptedText, at: self.now()),
                      prepared.textRevision == original.textRevision,
                      prepared.sessionID == original.sessionID,
                      prepared.presentationRevision == original.presentationRevision,
                      prepared.persona == original.persona, prepared.personaRevision == original.personaRevision,
                      prepared.locale == original.locale, prepared.attribution == original.attribution,
                      prepared.audioState == "ready", prepared.effectiveVoice?.processor == .haConfigured,
                      prepared.audioReference?.isValid == true,
                      captured.voiceID == nil || prepared.effectiveVoice?.voiceID == captured.voiceID,
                      captured.preference == .default || prepared.effectiveVoice?.gender == captured.preference.rawValue,
                      let preparedDeadline = prepared.expiresAt.flatMap(DJConnectHistoryEntry.date),
                      self.coordinator.shortenDeadline(preparedDeadline, for: ticket)
                else { throw DJConnectError.invalidResponse }
                self.state = .downloading
                let bytes = try await services.audio(prepared, acceptedText)
                guard self.current(ticket, captured) else { return }
                guard !bytes.isEmpty, bytes.count <= 2 * 1024 * 1024,
                      prepared.admits(reference: reference, text: acceptedText, at: self.now())
                else { throw DJConnectError.invalidResponse }
                self.state = .playing
                try services.play(bytes) { [weak self] in self?.coordinator.finish(ticket) }
            } catch {
                guard self.current(ticket, captured) else { return }
                self.coordinator.finish(ticket)
                self.retryAfter = self.now().addingTimeInterval(60)
                self.state = .unavailable
            }
        }
        return true
    }

    private func current(_ ticket: DJConnectAudioPlaybackCoordinator.Ticket, _ captured: Context) -> Bool {
        !Task.isCancelled && context == captured && coordinator.isCurrent(ticket)
    }
}
