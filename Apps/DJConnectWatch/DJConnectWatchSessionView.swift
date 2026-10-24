import DJConnectCore
import SwiftUI

/// The visible Watch Session belongs to its own paired backend identity. This
/// view has no AppGroup, history cache, passive grant or local intelligence.
struct DJConnectWatchSessionView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @ObservedObject var state: DJConnectWatchForegroundSession
    @ObservedObject var settings: ProfileDJSettingsModel
    @ObservedObject var speech: DJConnectWatchSessionSpeech
    @State private var showsFlow = false
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(text("ui.session.title"), systemImage: "opticaldisc")
                        .font(.headline)
                    Spacer(minLength: 2)
                    Button {
                        Task { await model.refreshForegroundSession(force: true) }
                    } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                    .accessibilityLabel(text("ui.refresh"))
                }
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
                        }
                        let current = session.broadcast.nativeCurrentMoment(at: now, spotifyAttributionAvailable: true)
                        if let current {
                            Label(text("watch.session.current"), systemImage: "sparkles").font(.caption.weight(.semibold))
                            momentCard(current)
                        }
                        else { Text(text("watch.session.waiting")).font(.callout) }
                        let flow = session.broadcast.nativeFlowMoments(at: now).filter { $0.id != current?.id }
                        if !flow.isEmpty {
                            Button { showsFlow.toggle() } label: {
                                HStack {
                                    Text(text("ui.session.flow"))
                                    Spacer(minLength: 2)
                                    Image(systemName: showsFlow ? "chevron.up" : "chevron.down")
                                }.font(.caption.weight(.semibold))
                            }
                            .accessibilityIdentifier("watch-session-flow-toggle")
                            if showsFlow { ForEach(flow) { moment in momentCard(moment) } }
                        }
                    } else {
                        Text(text("ui.session.idle")).font(.callout)
                        if let confirmation = model.settingsOperationConfirmation {
                            Label(confirmation, systemImage: "sparkles").font(.callout)
                        }
                    }
                    if !snapshot.settings.requiresSelection {
                        Button(role: snapshot.session == nil ? nil : .destructive) {
                            if snapshot.session == nil { Task { await model.changeForegroundSession() } }
                            else { endingSessionID = snapshot.session?.id; confirmsEnd = true }
                        } label: {
                            Label(text(snapshot.session == nil ? "ui.session.start" : "ui.session.end"),
                                  systemImage: snapshot.session == nil ? "play.fill" : "stop.fill")
                        }
                        .disabled(state.isChanging || state.isRefreshing || state.outcomeUnknown || settings.hasUncertainOperation)
                        .accessibilityIdentifier(snapshot.session == nil ? "watch-session-start" : "watch-session-end")
                    } else { Text(text("ui.dj_settings.review_choices")).font(.caption) }
                    if snapshot.settings.allowsSpeech(.local) {
                        NavigationLink {
                            DJConnectWatchSessionSpeechSettingsView()
                        } label: {
                            Label(text("watch.session.speech_settings"), systemImage: "speaker.wave.2")
                                .font(.footnote)
                        }
                        if !model.deviceSpeechPreferences.enabled {
                            Text(text("watch.session.enable_speech")).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        DJConnectWatchSharedDJSettingsView(settings: settings)
                    } label: {
                        Label(text("watch.session.settings"), systemImage: "slider.horizontal.3")
                            .font(.footnote)
                    }
                } else {
                    Text(text(model.canUseBackend ? (state.failureKey ?? (state.unavailable ? "watch.session.retry" : "watch.session.loading")) : "watch.session.connect_phone"))
                        .font(.callout)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(DJConnectMaterial(.regular), in: RoundedRectangle(cornerRadius: 16))
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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
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
            }.padding(8).foregroundStyle(.white)
        }
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

private struct DJConnectWatchSessionSpeechSettingsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    var body: some View {
        ScrollView {
            DeviceSpeechSettingsView(language: model.language, preferences: $model.deviceSpeechPreferences,
                previewAllowed: model.canPreviewDeviceSpeech, isSpeaking: model.deviceSpeechPreviewIsPlaying,
                preview: model.previewDeviceSpeech, stop: model.stopDeviceSpeechPreview)
                .padding(8)
        }
        .navigationTitle(DJConnectLocalization.localized(key: "watch.session.speech_settings", language: model.language))
    }
}
