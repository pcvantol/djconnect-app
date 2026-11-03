import DJConnectCore
import SwiftUI

/// The visible Watch Session belongs to its own paired backend identity. This
/// view has no AppGroup, history cache, passive grant or local intelligence.
struct DJConnectWatchSessionView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @ObservedObject var state: DJConnectWatchForegroundSession
    @ObservedObject var settings: ProfileDJSettingsModel
    @ObservedObject var speech: DJConnectWatchSessionSpeech
    @State private var confirmsEnd = false
    @State private var endingSessionID: String?

    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }

    var body: some View {
        TimelineView(.explicit(([Date()] + state.displayDeadlines).sorted())) { _ in
            // Timeline context.date can predate an asynchronous snapshot receipt.
            // It only schedules invalidation; current wall/monotonic clocks own
            // freshness and the producer's unchanged Moment deadlines.
            let now = Date()
            List {
                if state.isChanging { ProgressView().accessibilityIdentifier("watch-session-changing") }
                if state.outcomeUnknown {
                    Text(text("watch.session.check_outcome")).font(.caption)
                    Button(text("ui.refresh")) { Task { await model.refreshForegroundSession(force: true) } }
                    Button(text("ui.dj_settings.use_current")) { Task { await model.acceptCurrentForegroundSession() } }
                }
                if let snapshot = state.current(at: now) {
                    if let session = snapshot.session {
                        if let started = DJConnectHistoryEntry.date(session.startedAt) {
                            Text(text("ui.session.started_at") + " " + started.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: model.language))))
                                .font(.caption2).foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        }
                        NavigationLink {
                            DJConnectWatchCompanionMoodView(state: state, settings: settings)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(text("ui.dj_settings.mood"), systemImage: "waveform")
                                Text(text("ui.session.mood." + session.selectedMood))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        NavigationLink {
                            DJConnectWatchSessionPresenceView(state: state, settings: settings,
                                sessionID: session.id, binding: snapshot.settings.binding)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(text("ui.session.presence.title"), systemImage: "mic.fill")
                                Text(text(session.selectedPresence?.localizationKey ?? "ui.session.presence.unavailable"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        NavigationLink {
                            DJConnectWatchSharedDJSettingsView(settings: settings)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(text("ui.dj_settings.persona"), systemImage: "person.crop.circle")
                                if let persona = session.selectedPersona {
                                    Text(text("ui.session.persona." + persona.rawValue))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        let current = session.broadcast.nativeCurrentMoment(at: now, spotifyAttributionAvailable: true)
                        if let current {
                            Label(text("watch.session.current"), systemImage: "sparkles").font(.caption.weight(.semibold))
                            momentCard(current)
                        }
                    } else {
                        Text(text("ui.session.idle")).font(.callout)
                        if let confirmation = model.settingsOperationConfirmation {
                            Label(confirmation, systemImage: "sparkles").font(.callout)
                        }
                    }
                    if snapshot.settings.allowsSpeech(.local) {
                        if !model.deviceSpeechPreferences.enabled {
                            Text(text("watch.session.enable_speech")).font(.caption2).foregroundStyle(.secondary)
                        }
                        NavigationLink {
                            DJConnectWatchSessionSpeechSettingsView()
                        } label: {
                            Label(text("watch.session.speech_settings"), systemImage: "speaker.wave.2")
                                .font(.footnote)
                        }
                    }
                    if let session = snapshot.session, !snapshot.settings.requiresSelection {
                        Button(role: .destructive) {
                            endingSessionID = session.id; confirmsEnd = true
                        } label: {
                            Label(text("ui.session.end"), systemImage: "stop.fill")
                        }
                        .disabled(state.isChanging || state.isRefreshing || state.outcomeUnknown || settings.hasUncertainOperation)
                        .accessibilityIdentifier("watch-session-end")
                    }
                } else {
                    Text(text(model.canUseBackend ? (state.failureKey ?? (state.unavailable ? "watch.session.retry" : "watch.session.loading")) : "watch.session.connect_phone"))
                        .font(.callout)
                }
            }
            .listStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityIdentifier("watch-current-session")
        }
        .confirmationDialog(text("ui.session.end.confirm"), isPresented: $confirmsEnd) {
            Button(text("ui.session.end.action"), role: .destructive) { Task { await model.changeForegroundSession(expectedSessionID: endingSessionID) } }
            Button(text("ui.cancel"), role: .cancel) { }
        }
        .task { await model.refreshForegroundSession() }
        .onDisappear { speech.stop() }
    }

    private func momentCard(_ moment: DJConnectMoment) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                if let timestamp = DJConnectHistoryEntry.date(moment.createdAt) {
                    Text(timestamp.formatted(.dateTime.hour().minute().locale(Locale(identifier: model.language))))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 2)
            }
            // Complete producer copy, never a local summary or future plan label.
            Text(moment.content).font(.callout).fixedSize(horizontal: false, vertical: true)
            if moment.sourceAttribution?["provider"] == "Spotify",
               let source = moment.nativeSourceURLs.first(where: { $0.host == "open.spotify.com" }) {
                Link(destination: source) {
                    Image("SpotifyAttribution").resizable().scaledToFit().frame(width: 72, height: 24)
                        .accessibilityLabel("Spotify")
                }
            }
            ForEach(moment.nativeSourceURLs.filter { $0.host != "open.spotify.com" }, id: \.absoluteString) { source in
                Link(source.host ?? text("ui.session.flow"), destination: source).font(.caption2)
            }
            if model.canPlaySessionMoment(moment) {
                let selected = speech.momentID == moment.id
                let active = selected && (speech.state == .preparing || speech.state == .playing)
                Button {
                    if active { speech.stop() } else { model.playSessionMoment(moment) }
                } label: {
                    HStack {
                        if selected && speech.state == .preparing { ProgressView().frame(width: 20) }
                        else { Image(systemName: active ? "stop.fill" : "play.fill").frame(width: 20) }
                        Text(text(active ? "watch.session.stop_speech" : "watch.session.listen"))
                    }.frame(maxWidth: .infinity, minHeight: 36)
                }
                .accessibilityIdentifier("watch-session-speech-" + moment.id)
                if selected && speech.state == .unavailable {
                    Text(text("watch.session.speech_unavailable")).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DJConnectWatchSharedDJSettingsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @ObservedObject var settings: ProfileDJSettingsModel
    @State private var draft = DJConnectProfileDJSettings.Patch()
    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }
    private func label(_ field: String, _ value: String) -> String {
        let prefix = ["persona", "mood", "presence"].contains(field) ? "ui.session." : "ui.dj_settings."
        return text(prefix + field + "." + value)
    }
    private func choose(_ patch: DJConnectProfileDJSettings.Patch) {
        if settings.response?.requiresSelection == true {
            if let x = patch.persona { draft.persona = x }
            if let x = patch.mood { draft.mood = x }
            if let x = patch.presence { draft.presence = x }
            if let x = patch.voice { draft.voice = x }
            if let x = patch.gender { draft.gender = x }
            if let x = patch.announcement_output { draft.announcement_output = x }
        } else { Task { await model.changeSharedDJSettings(patch) } }
    }
    var body: some View {
        List {
            if settings.active, let r = settings.response {
                let e = r.snapshot.effective
                let review = r.requiresSelection
                if review { Text(text("ui.dj_settings.review_choices")).font(.caption) }
                choices("persona", r.allowed_values.persona, selected: (review ? draft.persona ?? e.persona : e.persona).rawValue) {
                    choose(.init(persona: DJConnectSessionPersonaValue(rawValue: $0)))
                }
                choices("mood", r.allowed_values.mood, selected: review ? draft.mood ?? e.mood : e.mood) { choose(.init(mood: $0)) }
                choices("presence", r.allowed_values.presence.filter { raw in DJConnectSessionPresenceValue.selectableChoices.contains { $0.rawValue == raw } }, selected: (review ? draft.presence ?? e.presence : e.presence).rawValue) {
                    choose(.init(presence: DJConnectSessionPresenceValue(rawValue: $0)))
                }
                let output = review ? draft.announcement_output ?? e.announcement_output : e.announcement_output
                choices("output", r.allowed_values.announcement_output, selected: output.rawValue) { choose(.init(output: DJAnnouncementOutput(rawValue: $0))) }
                if output != .textOnly {
                    let voice = review ? draft.voice ?? e.voice : e.voice
                    let gender = review ? draft.gender ?? e.gender : e.gender
                    Picker(text("ui.dj_settings.voice"), selection: Binding(get: { voiceTag(voice) }, set: { tag in
                        if tag == "default" { choose(.init(voice: .init())) }
                        else if let item = r.allowed_values.voice.voices.first(where: {
                            voiceTag(.init(kind: .providerVoice, providerID: r.allowed_values.voice.provider_id, voiceID: $0.voice_id)) == tag
                        }) { choose(.init(voice: .init(kind: .providerVoice, providerID: r.allowed_values.voice.provider_id, voiceID: item.voice_id))) }
                    })) {
                        Text(text("ui.dj_settings.provider_default")).tag("default")
                        ForEach(r.allowed_values.voice.voices.filter { gender == .default || $0.gender == gender.rawValue }, id: \.voice_id) { item in
                            Text(item.name).tag(voiceTag(.init(kind: .providerVoice, providerID: r.allowed_values.voice.provider_id, voiceID: item.voice_id)))
                        }
                        if voice.kind == .providerVoice && (voice.provider_id != r.allowed_values.voice.provider_id ||
                            !r.allowed_values.voice.voices.contains(where: { $0.voice_id == voice.voice_id && (gender == .default || $0.gender == gender.rawValue) })) {
                            Text(text("ui.dj_settings.selection_unavailable")).tag(voiceTag(voice)).disabled(true)
                        }
                    }
                    if r.allowed_values.gender.contains("male") || r.allowed_values.gender.contains("female") {
                        choices("gender", r.allowed_values.gender, selected: gender.rawValue) { raw in
                            // A provider-default voice can resolve the chosen gender.
                            choose(.init(voice: .init(), gender: DJConnectVoicePreference(rawValue: raw)))
                        }
                    }
                } else {
                    Text(text("ui.dj_settings.voice_preserved_text_only")).font(.caption).foregroundStyle(.white)
                }
                if review {
                    Button(text("ui.dj_settings.confirm_six")) {
                        Task { await model.changeSharedDJSettings(.init(persona: draft.persona ?? e.persona,
                            voice: draft.voice ?? e.voice, gender: draft.gender ?? e.gender,
                            mood: draft.mood ?? e.mood, presence: draft.presence ?? e.presence,
                            output: draft.announcement_output ?? e.announcement_output)) }
                    }
                }
            } else { Text(text("ui.dj_settings.unavailable")) }
            if [.conflict, .uncertain, .unavailable].contains(settings.phase) {
                Text(text("ui.dj_settings." + settings.phase.rawValue)).font(.caption)
            }
            if let confirmation = model.settingsOperationConfirmation {
                Label(confirmation, systemImage: "sparkles").font(.callout)
            }
            if settings.hasUncertainOperation {
                Button(text("ui.dj_settings.check_outcome")) { Task { await model.reconcileSharedDJSettings() } }
                Button(text("ui.dj_settings.use_current")) { Task { await settings.useCurrentSettings(model.sharedSettingsServices) } }
            }
        }
        .listStyle(.plain)
        .buttonStyle(.automatic)
        .pickerStyle(.navigationLink)
        .watchStandardBackground()
        .navigationTitle(text("watch.session.settings"))
        .onChange(of: settings.response?.binding) { draft = .init() }
        .onChange(of: settings.response?.requiresSelection) { draft = .init() }
        .task { await model.refreshForegroundSession(force: true) }
    }
    private func voiceTag(_ voice: DJConnectProfileDJSettings.Voice) -> String {
        voice.kind == .providerDefault ? "default" : "voice/\((voice.provider_id ?? "").utf8.count):\(voice.provider_id ?? "")/\(voice.voice_id ?? "")"
    }
    private func choices(_ field: String, _ values: [String], selected: String, change: @escaping (String) -> Void) -> some View {
        Picker(text("ui.dj_settings." + field), selection: Binding(get: { selected }, set: change)) {
            if !values.contains(selected) { Text(label(field, selected)).tag(selected).disabled(true) }
            ForEach(values, id: \.self) { value in
                Text(label(field, value)).tag(value)
                    .disabled(field == "output" && settings.response?.announcement_output.outputs.first(where: { $0.value == value })?.available != true)
            }
        }
    }
}

private struct DJConnectWatchSessionPresenceView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @ObservedObject var state: DJConnectWatchForegroundSession
    @ObservedObject var settings: ProfileDJSettingsModel
    let sessionID: String
    let binding: String

    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: model.language)
    }

    private var current: DJConnectProfileDJSettingsResponse? {
        guard let snapshot = state.current(), snapshot.session?.id == sessionID,
              snapshot.settings.binding == binding, let response = settings.response,
              response.binding == binding, !response.requiresSelection else { return nil }
        return response
    }

    var body: some View {
        List {
            if let current {
                let selected = current.snapshot.effective.presence
                ForEach(DJConnectSessionPresenceValue.selectableChoices, id: \.self) { choice in
                    Button {
                        Task {
                            guard let latest = self.current, settings.canEdit,
                                  latest.allowed_values.presence.contains(choice.rawValue),
                                  latest.snapshot.effective.presence != choice else { return }
                            await model.changeSharedDJSettings(.init(presence: choice))
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icon(for: choice))
                                .foregroundStyle(.purple)
                                .frame(width: 22)
                                .accessibilityHidden(true)
                            Text(text(choice.localizationKey))
                            Spacer()
                            if choice == selected { Image(systemName: "checkmark").accessibilityHidden(true) }
                        }
                        .contentShape(Rectangle())
                    }
                    .disabled(!settings.canEdit || !current.allowed_values.presence.contains(choice.rawValue))
                    .accessibilityAddTraits(choice == selected ? .isSelected : [])
                }
                if [.conflict, .uncertain, .unavailable].contains(settings.phase) {
                    Text(text("ui.dj_settings." + settings.phase.rawValue)).font(.caption)
                }
            } else {
                Text(text("ui.session.presence.unavailable")).foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .buttonStyle(.plain)
        .watchStandardBackground()
        .navigationTitle(text("ui.session.presence.title"))
    }

    private func icon(for choice: DJConnectSessionPresenceValue) -> String {
        switch choice {
        case .musicOnly: "music.note"
        case .occasional: "bubble.left"
        case .balanced: "bubble.left.and.bubble.right"
        case .talkative, .presenter: "mic.fill"
        }
    }
}

struct DJConnectWatchSessionSpeechSettingsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    var body: some View {
        ScrollView {
            DeviceSpeechSettingsView(language: model.language, preferences: $model.deviceSpeechPreferences,
                previewAllowed: model.canPreviewDeviceSpeech, isSpeaking: model.deviceSpeechPreviewIsPlaying,
                preview: model.previewDeviceSpeech, stop: model.stopDeviceSpeechPreview)
                .padding(8)
        }
        .watchStandardBackground()
        .navigationTitle(DJConnectLocalization.localized(key: "watch.session.speech_settings", language: model.language))
    }
}
