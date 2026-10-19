import SwiftUI
import Combine
import DJConnectCore

/// Coalesces only unsent UI gestures. It never cancels or replays a sent write.
@MainActor
final class ProfileDJChoiceScheduler {
    private(set) var hasPending = false
    var pendingChanged: ((Bool) -> Void)?
    private var task: Task<Void, Never>?
    private var context: String?
    private var patch = DJConnectProfileDJSettings.Patch()
    func schedule(_ next: DJConnectProfileDJSettings.Patch, context: String,
                  isCurrent: @escaping () -> Bool,
                  perform: @escaping (DJConnectProfileDJSettings.Patch) async -> Void) {
        task?.cancel()
        if self.context != context { patch = .init() }
        self.context = context
        if let value = next.mood { patch.mood = value }
        if let value = next.presence { patch.presence = value }
        if let value = next.persona { patch.persona = value }
        if !hasPending { hasPending = true; pendingChanged?(true) }
        task = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            let value = patch
            patch = .init(); task = nil; hasPending = false; pendingChanged?(false)
            guard isCurrent() else { return }
            await perform(value)
        }
    }
}

/// Only values rendered by the editor participate in invalidation. The owner
/// retains every fresh response (including its qualified clock) for mutations.
@MainActor
final class ProfileDJSettingsEditorState: ObservableObject {
    struct Value: Equatable {
        let response: DJConnectProfileDJSettingsResponse?
        let phase: ProfileDJSettingsModel.Phase
        let canEdit: Bool
        let hasUncertainOperation: Bool

        @MainActor init(_ model: ProfileDJSettingsModel) {
            response = model.response; phase = model.phase
            canEdit = model.canEdit; hasUncertainOperation = model.hasUncertainOperation
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            guard lhs.phase == rhs.phase, lhs.canEdit == rhs.canEdit,
                  lhs.hasUncertainOperation == rhs.hasUncertainOperation else { return false }
            switch (lhs.response, rhs.response) {
            case (nil, nil): return true
            case let (a?, b?):
                return a.success == b.success && a.contract_version == b.contract_version &&
                    a.binding == b.binding && a.scope == b.scope && a.snapshot == b.snapshot &&
                    a.allowed_values == b.allowed_values && a.writable_fields == b.writable_fields &&
                    a.voice_revision == b.voice_revision && a.voice_availability == b.voice_availability &&
                    a.announcement_output == b.announcement_output && a.migration == b.migration &&
                    a.cache_policy == b.cache_policy
            default: return false
            }
        }
    }

    @Published private(set) var value: Value
    private var observation: AnyCancellable?
    private var publicationScheduled = false

    init(_ model: ProfileDJSettingsModel) {
        value = Value(model)
        observation = model.objectWillChange.sink { [weak self, weak model] _ in
            guard let self, !self.publicationScheduled else { return }
            self.publicationScheduled = true
            // objectWillChange precedes assignment. Coalesce the owner's
            // synchronous transaction, then compare its completed view state.
            Task { @MainActor [weak self, weak model] in
                guard let self, let model else { return }
                self.publicationScheduled = false
                let next = Value(model)
                if self.value != next { self.value = next }
            }
        }
    }
}

struct ProfileDJSettingsEditor: View, Equatable {
    let model: DJConnectAppModel
    private let language: String
    private let isDemoMode: Bool
    @StateObject private var presentation: ProfileDJSettingsEditorState
    @State private var draft = DJConnectProfileDJSettings.Patch()
    @State private var contentHeight: CGFloat = 220
    init(model: DJConnectAppModel) {
        self.model = model; language = model.language; isDemoMode = model.isDemoMode
        _presentation = StateObject(wrappedValue: ProfileDJSettingsEditorState(model.profileDJSettings))
    }
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model === rhs.model && lhs.language == rhs.language && lhs.isDemoMode == rhs.isDemoMode
    }
    private var state: ProfileDJSettingsEditorState.Value { presentation.value }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.dj_settings." + key, language: language) }
    private func choice(_ key: String, _ value: String) -> String {
        switch key {
        case "persona": return DJConnectLocalization.localized(key: "ui.session.persona." + value, language: language)
        case "presence": return DJConnectLocalization.localized(key: "ui.session.presence." + value, language: language)
        case "mood": return DJConnectLocalization.localized(key: "ui.session.mood." + value, language: language)
        default: return text(key + "." + value)
        }
    }
    private func choose(_ patch: DJConnectProfileDJSettings.Patch) {
        if state.response?.requiresSelection == true {
            if let x = patch.persona { draft.persona = x }
            if let x = patch.voice { draft.voice = x }
            if let x = patch.gender { draft.gender = x }
            if let x = patch.mood { draft.mood = x }
            if let x = patch.presence { draft.presence = x }
            if let x = patch.announcement_output { draft.announcement_output = x }
        } else { Task { await model.changeProfileDJSettings(patch) } }
    }
    private func voiceTag(_ voice: DJConnectProfileDJSettings.Voice) -> String {
        voice.kind == .providerDefault ? "default" : "voice/\((voice.provider_id ?? "").utf8.count):\(voice.provider_id ?? "")/\(voice.voice_id ?? "")"
    }
    var body: some View {
        ScrollView { content }
        .frame(height: min(620, max(1, contentHeight)))
        .tint(.white)
        .accentColor(.white)
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen-profile-your-dj")
        .task { await model.refreshProfileDJSettings() }
        .onChange(of: state.response?.binding) { draft = .init() }
        .onChange(of: state.response?.requiresSelection) { draft = .init() }
    }
    private var selectedOutput: DJAnnouncementOutput? {
        guard let response = state.response else { return nil }
        return response.requiresSelection ? draft.announcement_output ?? response.snapshot.effective.announcement_output
            : response.snapshot.effective.announcement_output
    }
    private var content: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(text("title"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityAddTraits(.isHeader)
                DeviceAppleSpeechPreferencesSection(model: model)
                Divider()
                if let response = state.response {
                    if response.requiresSelection {
                        Text(text("review_choices")).fixedSize(horizontal: false, vertical: true)
                        // Migration still requires informed acceptance of all six values.
                        Text([choice("persona", response.snapshot.effective.persona.rawValue),
                              choice("mood", response.snapshot.effective.mood),
                              choice("presence", response.snapshot.effective.presence.rawValue)].joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    fields(response)
                    if response.requiresSelection {
                        Button(text("confirm_six")) {
                            let e = response.snapshot.effective
                            let patch = DJConnectProfileDJSettings.Patch(persona: draft.persona ?? e.persona,
                                voice: draft.voice ?? e.voice, gender: draft.gender ?? e.gender,
                                mood: draft.mood ?? e.mood, presence: draft.presence ?? e.presence,
                                output: draft.announcement_output ?? e.announcement_output)
                            Task { await model.changeProfileDJSettings(patch) }
                        }
                        .disabled(!state.canEdit)
                        .accessibilityIdentifier("dj-settings-confirm-six")
                    }
                    if !response.voice_availability.available && selectedOutput != .textOnly {
                        Text(text("voice_unavailable")).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    if selectedOutput == .textOnly {
                        Text(text("voice_preserved_text_only")).font(.caption).foregroundStyle(.white)
                    }
                    if !response.announcement_output.speaker_available &&
                        [.haSpeaker, .both].contains(response.snapshot.effective.announcement_output) {
                        Text(text("speaker_unavailable")).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if state.phase != .loading {
                    Text(text(isDemoMode ? "demo_unavailable" : "unavailable"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if [.loading, .saving].contains(state.phase) {
                    ProgressView(text(state.phase == .saving ? "saving" : "loading"))
                } else if [.uncertain, .unavailable].contains(state.phase) {
                    Text(text(state.phase.rawValue)).font(.callout).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("dj-settings-status")
                }
                if state.hasUncertainOperation {
                    Button(text("check_outcome")) { Task { await model.reconcileProfileDJSettingsChoice() } }
                    Button(text("use_current")) { Task { await model.profileDJSettings.useCurrentSettings(model.profileDJSettingsServices) } }
                }
                if selectedOutput != .textOnly {
                    Divider()
                    SessionVoiceAutoplayControl(model: model)
                        .tint(djConnectAccent)
                }
                Divider()
                DeviceSpeechPreferencesSection(model: model)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                let measured = ceil(height)
                if abs(contentHeight - measured) > 0.5 { contentHeight = measured }
            }
    }
    private func fields(_ response: DJConnectProfileDJSettingsResponse) -> some View {
        let e = response.snapshot.effective
        let review = response.requiresSelection
        let voice = review ? draft.voice ?? e.voice : e.voice
        let gender = review ? draft.gender ?? e.gender : e.gender
        let inventory = response.allowed_values.voice
        return VStack(alignment: .leading, spacing: 8) {
            outputField(response)
            if (review ? draft.announcement_output ?? e.announcement_output : e.announcement_output) != .textOnly {
            HAProviderVoiceVisibility(model: model) {
            Text(text("voice")).font(.subheadline.weight(.semibold))
            Picker(text("voice"), selection: Binding(get: { voiceTag(voice) }, set: { tag in
                if tag == "default" { choose(.init(voice: .init())) }
                else if let item = inventory.voices.first(where: {
                    voiceTag(.init(kind: .providerVoice, providerID: inventory.provider_id, voiceID: $0.voice_id)) == tag
                }) { choose(.init(voice: .init(kind: .providerVoice, providerID: inventory.provider_id, voiceID: item.voice_id))) }
            })) {
                Text(text("provider_default")).tag("default")
                ForEach(inventory.voices, id: \.voice_id) { item in
                    Text(item.name).tag(voiceTag(.init(kind: .providerVoice, providerID: inventory.provider_id, voiceID: item.voice_id)))
                        .disabled(gender != .default && item.gender != gender.rawValue)
                }
                if voice.kind == .providerVoice && (voice.provider_id != inventory.provider_id || !inventory.voices.contains(where: { $0.voice_id == voice.voice_id })) {
                    Text(text("selection_unavailable")).tag(voiceTag(voice)).disabled(true)
                }
            }
            .pickerStyle(.menu).frame(minHeight: 44).disabled(!state.canEdit)
            .labelsHidden()
            .accessibilityLabel(text("voice"))
            .accessibilityIdentifier("dj-settings-voice")
            if response.allowed_values.gender.contains("male") || response.allowed_values.gender.contains("female") {
                let genders = ["male", "female"].filter { response.allowed_values.gender.contains($0) }
                SessionGlassChoiceSelector(
                    steps: genders.enumerated().map { (text("gender." + $0.element), $0.offset) },
                    selectedIndex: genders.firstIndex(of: gender.rawValue) ?? -1,
                    language: language, glyphs: genders.map { $0 == "male" ? "figure.stand" : "figure.stand.dress" },
                    titleKey: "ui.dj_settings.gender", accessibilityLabelKey: "ui.dj_settings.gender",
                    optionIDs: genders.map { "dj-settings-gender-" + $0 },
                    selectionColor: .white
                ) { index in
                    guard genders.indices.contains(index), let value = DJConnectVoicePreference(rawValue: genders[index]) else { return }
                    // A gender preference requires a compatible voice. Retain a
                    // concrete voice only when its server metadata supports it.
                    if voice.kind == .providerVoice,
                       inventory.voices.first(where: { $0.voice_id == voice.voice_id })?.gender != value.rawValue {
                        choose(.init(voice: .init(), gender: value))
                    } else { choose(.init(gender: value)) }
                }
                .disabled(!state.canEdit)
            }
            }
            }
        }
    }
    private func outputField(_ response: DJConnectProfileDJSettingsResponse) -> some View {
        let e = response.snapshot.effective
        let review = response.requiresSelection
        return VStack(alignment: .leading, spacing: 8) {
            Text(text("output")).font(.subheadline.weight(.semibold))
            Picker(text("output"), selection: Binding(get: {
                (review ? draft.announcement_output ?? e.announcement_output : e.announcement_output).rawValue
            }, set: { choose(.init(output: DJAnnouncementOutput(rawValue: $0))) })) {
                ForEach(response.allowed_values.announcement_output, id: \.self) { value in
                    Text(choice("output", value)).tag(value)
                        .disabled(response.announcement_output.outputs.first(where: { $0.value == value })?.available != true)
                }
            }
            .pickerStyle(.menu).frame(minHeight: 44).disabled(!state.canEdit)
            .labelsHidden()
            .accessibilityLabel(text("output"))
            .accessibilityIdentifier("dj-settings-output")
        }
    }
}

/// Local presentation only: hiding HA controls never mutates the saved Profile voice.
private struct HAProviderVoiceVisibility<Content: View>: View {
    @ObservedObject var model: DJConnectAppModel
    @ViewBuilder let content: () -> Content
    var body: some View {
        if !model.deviceSpeechPreferences.enabled { content() }
    }
}

/// Device speech route choices lead the speech menu, ahead of HA and wake controls.
private struct DeviceAppleSpeechPreferencesSection: View {
    @ObservedObject var model: DJConnectAppModel
    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(text("ui.device_stt.enabled"), isOn: $model.deviceSTTEnabled)
                .accessibilityIdentifier("device-stt-enabled")
            Text(text("ui.device_stt.explanation"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DeviceSpeechSettingsView(language: model.language, preferences: $model.deviceSpeechPreferences,
                previewAllowed: model.canPreviewDeviceSpeech, isSpeaking: model.deviceSpeechPreviewIsPlaying,
                preview: model.previewDeviceSpeech, stop: model.stopDeviceSpeechPreview)
        }
        .toggleStyle(SwitchToggleStyle(tint: DJConnectGlassAppearance.toggleTint))
        .djConnectButtonStyle(DJConnectButtonStyle())
        .tint(.white)
        .accentColor(.white)
        .accessibilityIdentifier("speech-preferences-apple-section")
    }
}

/// Observe device preferences independently of the equatable Profile projection.
/// Local input/output choices remain usable without a server settings snapshot.
private struct DeviceSpeechPreferencesSection: View {
    @ObservedObject var model: DJConnectAppModel
    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text("ui.device_speech.title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            LabeledContent(speechPreferencesText(model, "ui.wakeword")) {
                if model.wakeWordEnabled {
                    Button {
                        model.setWakeWordEnabled(false)
                    } label: {
                        Text(speechPreferencesText(model, "ui.disable.voice.activation"))
                            .foregroundStyle(.white)
                            .foregroundColor(.white)
                    }
                    .foregroundStyle(.white)
                    .foregroundColor(.white)
                    .tint(.white)
                } else {
                    Button {
                        model.setWakeWordEnabled(true)
                    } label: {
                        Text(speechPreferencesText(model, "ui.enable.voice.activation.321a28"))
                            .foregroundStyle(.white)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .selected, selectionTint: .purple))
                }
            }
            wakeWordPhraseField(model)
            LabeledContent(speechPreferencesText(model, "ui.wakeword.status")) {
                Text(wakeWordStatusText(model))
                    .foregroundStyle(.secondary)
            }

        }
        .toggleStyle(SwitchToggleStyle(tint: DJConnectGlassAppearance.toggleTint))
        .djConnectButtonStyle(DJConnectButtonStyle())
        .tint(.white)
        .accentColor(.white)
        .accessibilityIdentifier("speech-preferences-device-section")
    }
}

/// Private contribution controls; no controls survive a text-only selection.
struct SharedDJSpeechActions: View {
    @ObservedObject var model: DJConnectAppModel
    let speech: DJConnectSessionSpeech?
    let acceptedText: String
    var retainedEntry: DJConnectHistoryEntry? = nil
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.dj_settings." + key, language: model.language) }
    private var reference: DJConnectSpeechReference? {
        if let entry = retainedEntry, model.retainedSpeechSourceIsCurrent(entry) {
            return .entry(sessionID: entry.sessionID, entryID: entry.id)
        }
        if let speech, speech.admits(reference: speech.reference, text: acceptedText) { return speech.reference }
        return nil
    }
    private func play(_ target: DJConnectSharedSpeechTarget) {
        if let entry = retainedEntry { model.replayRetainedEntrySpeech(entry) }
        else if let speech { model.replaySharedDJSpeech(speech, acceptedText: acceptedText, target: target) }
    }
    var body: some View {
        if model.profileDJSettings.effective?.announcement_output != .textOnly, let reference {
            HStack(alignment: .bottom, spacing: 8) {
                Spacer(minLength: 0)
                if model.sharedSpeechReference == reference,
                   let status = model.sharedSpeechDelivery["local"],
                   ["failed", "unavailable", "unknown"].contains(status) {
                    Text(text("delivery." + status)).font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                controls(reference)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    @ViewBuilder private func controls(_ reference: DJConnectSpeechReference) -> some View {
        let preparing = model.sharedSpeechReference == reference && model.sharedSpeechIsPreparing
        let ownsOutput = model.sharedSpeechReference == reference
        let active = ownsOutput && (model.sharedSpeechIsPlaying || preparing)
        let actionLabel = text(active ? "stop_local" : ownsOutput && model.sharedSpeechDelivery["local"] != nil ? "replay_local" : "listen_local")
        if case .moment = reference, model.canUseHASpeechOutput(.haSpeaker),
           model.profileDJSettings.effective?.announcement_output != .clientDevice {
            Menu {
                Button(text("target.ha_speaker")) { play(.haSpeaker) }
                    .disabled(model.profileDJSettings.response?.announcement_output.speaker_available != true)
                Button(text("target.both")) { play(.both) }
            } label: { Label(text("target.choose"), systemImage: "hifispeaker").frame(minHeight: 44) }
            .disabled(!model.sharedDJSpeechAllowed || preparing)
            .accessibilityIdentifier("shared-speech-target")
        }
        Button {
            if active { model.stopAskDJAudio() } else { play(.local) }
        } label: {
            ZStack {
                Circle().fill(.white.opacity(0.12))
                if preparing {
                    ProgressView().tint(.white).controlSize(.small)
                } else {
                    Image(systemName: active ? "stop.fill" : "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
            .overlay { Circle().stroke(.white.opacity(0.28), lineWidth: 1) }
            .contentShape(Circle())
        }
        .djConnectPlainButtonStyle()
        .disabled(!active && (!model.sharedDJSpeechAllowed || !model.canUseLocalDJSpeechOutput))
        .accessibilityLabel(actionLabel)
        .accessibilityValue(preparing ? text("delivery.preparing") : ownsOutput ? text("delivery." + (model.sharedSpeechDelivery["local"] ?? "ready")) : "")
        .accessibilityIdentifier(active ? "shared-speech-stop-local" : "shared-speech-listen-local")


    }
}

@MainActor
private func speechPreferencesText(_ model: DJConnectAppModel, _ key: String) -> String {
    DJConnectLocalization.localized(key: key, language: model.language)
}

@ViewBuilder
@MainActor
private func wakeWordPhraseField(_ model: DJConnectAppModel) -> some View {
    let phrase = Binding(
        get: { model.wakeWordPhrase },
        set: { model.wakeWordPhrase = $0 }
    )
    #if os(iOS)
    LabeledContent(speechPreferencesText(model, "ui.wake.word")) {
        TextField(speechPreferencesText(model, "ui.wake.word"), text: phrase)
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
    #else
    LabeledContent(speechPreferencesText(model, "ui.wake.word")) {
        TextField(speechPreferencesText(model, "ui.wake.word"), text: phrase)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 320)
    }
    #endif
}

@MainActor
private func wakeWordStatusText(_ model: DJConnectAppModel) -> String {
    switch model.wakeWordStatus {
    case .idle:
        if model.wakeWordEnabled {
            if model.pairingStatus != .paired || !model.isConnected {
                return speechPreferencesText(model, "ui.pair.home.assistant.first")
            }
            if !model.backendAvailable {
                return speechPreferencesText(model, "ui.playback.backend.unavailable")
            }
            if !model.voiceEnabled {
                return speechPreferencesText(model, "ui.voice.requests.unavailable")
            }
        }
        return speechPreferencesText(model, "ui.idle")
    case .listening:
        return speechPreferencesText(model, "ui.listening.for.wake.word")
    case .detected:
        return speechPreferencesText(model, "ui.wake.word.detected")
    case .unavailable:
        if model.isDemoMode {
            return speechPreferencesText(model, "ui.not.available.in.demo.mode")
        }
        return speechPreferencesText(model, "ui.not.available")
    }
}
