import DJConnectCore
import SwiftUI
import WatchKit

private let watchAccentBlue = Color(red: 0.16, green: 0.56, blue: 1.0)
private let watchAccentPurple = Color(red: 0.84, green: 0.18, blue: 1.0)
private let watchAccentGreen = Color(red: 0.20, green: 0.86, blue: 0.48)
private let watchDeepNavy = Color(red: 0.02, green: 0.03, blue: 0.09)

private func watchLocalized(_ language: String, _ english: String, _ dutch: String) -> String {
    DJConnectLocalization.localized(language: language, english: english, dutch: dutch)
}

private func watchLocalized(_ english: String, _ dutch: String) -> String {
    DJConnectLocalization.localized(locale: .current, english: english, dutch: dutch)
}

private func watchNonEmpty(_ value: String, fallback: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
}

private func watchAskDJTimestamp(_ date: Date, language: String, now: Date = Date()) -> String {
    let elapsed = max(0, now.timeIntervalSince(date))
    if elapsed < 3_600 {
        let minutes = max(1, Int(elapsed / 60))
        return watchLocalized(language, "\(minutes)m ago", "\(minutes) minuten geleden")
    }
    if Calendar.current.isDate(date, inSameDayAs: now) {
        return date.formatted(date: .omitted, time: .shortened)
    }
    let days = max(1, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 1)
    switch days {
    case 1:
        return watchLocalized(language, "Yesterday", "Gisteren")
    case 2...6:
        return watchLocalized(language, "\(days)d ago", "\(days) dagen geleden")
    case 7...13:
        return watchLocalized(language, "Last week", "Vorige week")
    case 14...30:
        let weeks = max(2, days / 7)
        return watchLocalized(language, "\(weeks)w ago", "\(weeks) weken geleden")
    case 31...61:
        return watchLocalized(language, "Last month", "Vorige maand")
    default:
        let months = max(2, days / 30)
        return watchLocalized(language, "\(months)mo ago", "\(months) maanden geleden")
    }
}

private func playWatchHaptic(_ haptic: WKHapticType, enabled: Bool) {
    guard enabled else {
        return
    }
    #if targetEnvironment(simulator)
    return
    #else
    WKInterfaceDevice.current().play(haptic)
    #endif
}

private extension Color {
    init?(watchHex: String) {
        var raw = watchHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") {
            raw.removeFirst()
        }
        guard raw.count == 6, let value = Int(raw, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xff) / 255.0,
            green: Double((value >> 8) & 0xff) / 255.0,
            blue: Double(value & 0xff) / 255.0
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct DJConnectWatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var moodCrownValue = 0.0
    @FocusState private var isMoodControlFocused: Bool

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("DJConnect")
                .navigationBarTitleDisplayMode(.inline)
        }
        .tint(watchAccentPurple)
        .sheet(isPresented: $model.isShowingMicrophonePermissionExplanation) {
            DJConnectWatchMicrophonePermissionView(kind: .pushToTalk)
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isShowingVoiceActivationPermissionExplanation) {
            DJConnectWatchMicrophonePermissionView(kind: .voiceActivation)
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isShowingWelcome) {
            DJConnectWatchWelcomeView()
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isShowingMusicDNAOptInPrompt) {
            DJConnectWatchMusicDNAOptInPromptView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { _, phase in
            model.handleAppForegroundChange(phase == .active)
        }
        .onAppear {
            model.handleAppForegroundChange(scenePhase == .active)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.connectionState {
        case .paired:
            if model.isShowingPairingSuccess {
                pairingSuccessView
            } else {
                pairedView
            }
        case .pairing:
            pairingView(message: watchLocalized(model.language, "Waiting for iPhone to pair this Watch with Home Assistant.", "Wachten tot iPhone deze Watch met Home Assistant koppelt."))
        case let .failed(message):
            pairingView(message: message)
        case .unpaired:
            pairingView(message: nil)
        }
    }

    private var canUsePlaybackControls: Bool {
        model.isDemoMode || model.canUseBackend
    }

    private var pairedView: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 12) {
                    mainHeader

                    nowPlaying

                    HStack(spacing: 12) {
                        commandButton("backward.fill", command: "previous", accessibilityLabel: watchLocalized(model.language, "Previous track", "Vorige track"))
                        commandButton(
                            model.playback?.isPlaying == true ? "pause.fill" : "play.fill",
                            command: model.playback?.isPlaying == true ? "pause" : "play",
                            accessibilityLabel: model.playback?.isPlaying == true
                                ? watchLocalized(model.language, "Pause", "Pauzeer")
                                : watchLocalized(model.language, "Play", "Speel af"),
                            isPrimary: true
                        )
                        commandButton("forward.fill", command: "next", accessibilityLabel: watchLocalized(model.language, "Next track", "Volgende track"))
                    }

                    volumeControl

                    Button {
                        Task { await model.saveCurrentTrack() }
                    } label: {
                        Label(
                            model.isSavingCurrentTrack
                                ? watchLocalized(model.language, "Saving...", "Opslaan...")
                                : watchLocalized(model.language, "Add to favorites", "Zet in favorieten"),
                            systemImage: model.isSavingCurrentTrack ? "hourglass" : "heart.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                    .disabled(!canUsePlaybackControls || model.isSavingCurrentTrack)

                    NavigationLink {
                        DJConnectWatchOutputsView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(watchAccentBlue.opacity(0.94))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(watchLocalized(model.language, "Output", "Uitvoer"))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.62))
                                Text(model.selectedOutput)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.46))
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(DJConnectWatchPanel(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DJConnectWatchQueueView()
                    } label: {
                        Label(watchLocalized(model.language, "Queue", "Wachtrij"), systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    askDJMoodControl

                    NavigationLink {
                        DJConnectWatchAskDJChatView()
                    } label: {
                        Label("Ask DJ", systemImage: "bubble.left.and.bubble.right")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchTrackInsightView()
                    } label: {
                        Label("Track Insight", systemImage: "waveform.path.ecg")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchMusicDNAView()
                    } label: {
                        Label("Music DNA", systemImage: "heart")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    Text(model.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)

                    if model.isDemoMode {
                        Button {
                            model.stopDemoMode()
                        } label: {
                            Label(watchLocalized(model.language, "Stop demo", "Stop demo"), systemImage: "xmark.circle")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                    }

                    if !model.responseImages.isEmpty {
                        AskDJWatchImageStack(images: model.responseImages)
                    }

                    NavigationLink {
                        DJConnectWatchPlaylistsView()
                    } label: {
                        Label(watchLocalized(model.language, "Playlists", "Afspeellijsten"), systemImage: "music.note.list")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchSettingsView()
                    } label: {
                        Label(watchLocalized(model.language, "Settings", "Instellingen"), systemImage: "gearshape")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchLogsView()
                    } label: {
                        Label("Logs", systemImage: "doc.text.magnifyingglass")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchAboutView()
                    } label: {
                        Label(watchLocalized(model.language, "About", "Over"), systemImage: "info.circle")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchLegalView()
                    } label: {
                        Label(watchLocalized(model.language, "Legal", "Juridisch"), systemImage: "doc.text")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchPrivacyView()
                    } label: {
                        Label("Privacy", systemImage: "hand.raised")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchFeedbackView()
                    } label: {
                        Label(watchLocalized(model.language, "Share feedback", "Feedback delen"), systemImage: "bubble.left.and.bubble.right")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .task {
            await model.refreshMainScreenStatusIfNeeded()
        }
        .onAppear {
            Task { await model.refreshMainScreenStatusIfNeeded() }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshStatusButton
            }
        }
    }

    private var mainHeader: some View {
        HStack {
            Text("DJConnect")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var refreshStatusButton: some View {
        Button {
            Task { await model.refreshStatus() }
        } label: {
            if model.isRefreshingStatus {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.82))
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .contentShape(Circle())
        .disabled(!model.canUseBackend || model.isRefreshingStatus)
        .accessibilityLabel(watchLocalized(model.language, "Refresh", "Ververs"))
    }

    private var pairingSuccessView: some View {
        ZStack {
            DJConnectWatchCanvas()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [watchAccentBlue, watchAccentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(watchLocalized(model.language, "Apple Watch paired", "Apple Watch gekoppeld"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(watchLocalized(model.language, "Apple Watch is paired with Home Assistant through your iPhone.", "Apple Watch is via je iPhone gekoppeld met Home Assistant."))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                Button {
                    model.dismissPairingSuccess()
                } label: {
                    Text(watchLocalized(model.language, "Continue", "Doorgaan"))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
            }
            .padding(.horizontal, 10)
        }
    }

    @ViewBuilder
    private var askDJMoodControl: some View {
        let content = VStack(spacing: 8) {
            HStack {
                Text("Mood")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(model.askDJMoodLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(watchAccentBlue.opacity(0.92))
            }

            HStack(spacing: 8) {
                ForEach(model.askDJMoodSteps.indices, id: \.self) { index in
                    let step = model.askDJMoodSteps[index]
                    let isSelected = index == model.askDJMoodStepIndex

                    Button {
                        setMoodStep(index)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isSelected ? watchAccentPurple.opacity(0.46) : Color.white.opacity(0.09))
                            Circle()
                                .stroke(isSelected ? watchAccentBlue.opacity(0.82) : Color.white.opacity(0.14), lineWidth: 1)
                            Image(systemName: moodIcon(for: index))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.68))
                        }
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(step.label)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .background(DJConnectWatchPanel(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(watchAccentPurple.opacity(0.18), lineWidth: 1)
        )
        .focusable(!model.isDemoMode)
        .focused($isMoodControlFocused)
        .onAppear {
            moodCrownValue = Double(model.askDJMoodStepIndex)
        }
        .onChange(of: model.askDJMoodStepIndex) {
            let nextValue = Double(model.askDJMoodStepIndex)
            guard moodCrownValue != nextValue else {
                return
            }
            moodCrownValue = nextValue
        }
        .onChange(of: moodCrownValue) {
            updateMoodFromCrown()
        }
        .accessibilityLabel("Mood")
        .accessibilityValue(model.askDJMoodLabel)

        content
            .digitalCrownRotation(
                $moodCrownValue,
                from: 0,
                through: 3,
                by: 1,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
    }

    private func updateMoodFromCrown() {
        let nextIndex = max(0, min(model.askDJMoodSteps.count - 1, Int(moodCrownValue.rounded())))
        guard nextIndex != model.askDJMoodStepIndex else {
            return
        }
        model.setAskDJMoodStep(nextIndex)
        moodCrownValue = Double(nextIndex)
        playWatchHaptic(.click, enabled: !model.isDemoMode)
    }

    private func setMoodStep(_ index: Int) {
        guard index != model.askDJMoodStepIndex else {
            isMoodControlFocused = false
            return
        }
        model.setAskDJMoodStep(index)
        moodCrownValue = Double(model.askDJMoodStepIndex)
        isMoodControlFocused = false
        playWatchHaptic(.click, enabled: !model.isDemoMode)
    }

    private func moodIcon(for index: Int) -> String {
        switch index {
        case 0:
            return "moon.zzz.fill"
        case 1:
            return "waveform"
        case 2:
            return "bolt.fill"
        default:
            return "sparkles"
        }
    }

    private var volumeControl: some View {
        let volumePercent = model.currentPlaybackVolumePercent
        return VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(watchAccentBlue.opacity(0.92))
                Slider(value: $model.volume, in: 0...1, step: 0.01) { editing in
                    if !editing {
                        model.commitVolume()
                    }
                }
                .tint(watchAccentPurple)
                .disabled(!canUsePlaybackControls || model.isRefreshingStatus || volumePercent == nil)
                Text(volumePercent.map { "\($0)%" } ?? "--")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(DJConnectWatchPanel(cornerRadius: 12))
        .accessibilityLabel(watchLocalized(model.language, "Volume", "Volume"))
        .accessibilityValue(volumePercent.map { "\($0)%" } ?? watchLocalized(model.language, "Unknown", "Onbekend"))
    }

    private var nowPlaying: some View {
        HStack(spacing: 9) {
            DJConnectWatchArtwork(
                url: model.playback?.albumImageURL,
                fallbackSystemImage: "music.note"
            )
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.playback?.trackName ?? watchLocalized(model.language, "No track", "Geen track"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text(model.playback?.artistName ?? "DJConnect")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if let volume = model.playback?.volumePercent {
                    Label("\(volume)%", systemImage: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundStyle(watchAccentBlue.opacity(0.92))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(DJConnectWatchPanel())
    }

    private struct DJConnectWatchTrackInsightView: View {
        @EnvironmentObject private var model: DJConnectWatchModel

        private var insight: TrackInsight {
            if let currentTrackInsight = model.currentTrackInsight {
                return currentTrackInsight
            }
            if model.isDemoMode, let demoInsight = DemoTrackInsightService.defaultTracks.first {
                return demoInsight
            }
            return TrackInsight(
                title: model.playback?.trackName ?? "Track Insight",
                artist: model.playback?.artistName ?? "DJConnect",
                artwork: model.playback?.albumImageURL,
                bpm: nil,
                key: nil,
                genre: nil,
                energy: nil,
                danceability: nil,
                intensity: nil,
                mood: nil,
                vibe: nil,
                texture: nil,
                summary: watchLocalized(model.language, "Ask DJ can fill Track Insight details for this track.", "Ask DJ kan Track Insight-details voor dit nummer vullen."),
                rawAnalysisText: "Watch Track Insight preview"
            )
        }

        var body: some View {
            ZStack {
                DJConnectWatchCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(insight.title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.72)
                                Text(insight.artist)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.68))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "waveform")
                                .foregroundStyle(watchAccentPurple)
                        }

                        DJConnectWatchTrackInsightVisualizer(
                            profile: TrackVibeProfile.make(for: insight),
                            isPlaying: model.playback?.isPlaying == true
                        )
                        .frame(height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        DJConnectWatchTrackInsightAnalysisCard(insight: insight, language: model.language)
                        DJConnectWatchTrackInsightMetricsGrid(insight: insight, language: model.language)

                        Label(
                            watchLocalized(model.language, "Rendered privately on your device", "Privé gerendered op je apparaat"),
                            systemImage: "lock.fill"
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.54))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(model.isDemoMode ? "Track Insight (Demo)" : "Track Insight")
        }
    }

    private struct DJConnectWatchTrackInsightAnalysisCard: View {
        let insight: TrackInsight
        let language: String

        var body: some View {
            VStack(alignment: .leading, spacing: 9) {
                Text("Track energy")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchNonEmpty(insight.summary, fallback: "-"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                let groups = DJConnectWatchTrackInsightGroups.make(for: insight, language: language)
                if !groups.isEmpty {
                    Divider().overlay(.white.opacity(0.14))
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.90))
                            ForEach(group.values, id: \.self) { value in
                                Text(value)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.64))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DJConnectWatchPanel(cornerRadius: 12))
        }
    }

    private struct DJConnectWatchTrackInsightMetricsGrid: View {
        let insight: TrackInsight
        let language: String

        private var columns: [GridItem] {
            [
                GridItem(.flexible(), spacing: 7, alignment: .top),
                GridItem(.flexible(), spacing: 7, alignment: .top)
            ]
        }

        var body: some View {
            LazyVGrid(columns: columns, spacing: 7) {
                DJConnectWatchTrackInsightMetric(title: "BPM", value: insight.bpm.map { String(Int($0.rounded())) })
                DJConnectWatchTrackInsightMetric(title: watchLocalized(language, "Key", "Toonsoort"), value: insight.key)
                DJConnectWatchTrackInsightMetric(title: watchLocalized(language, "Genre", "Genre"), value: insight.genre)
                DJConnectWatchTrackInsightMetric(title: watchLocalized(language, "Mood", "Mood"), value: insight.mood)
                DJConnectWatchTrackInsightMetric(title: watchLocalized(language, "Energy", "Energie"), value: percent(insight.energy))
                DJConnectWatchTrackInsightMetric(title: watchLocalized(language, "Dance", "Dans"), value: percent(insight.danceability))
                DJConnectWatchTrackInsightMetric(title: watchLocalized(language, "Intensity", "Intensiteit"), value: percent(insight.intensity))
                DJConnectWatchTrackInsightMetric(title: watchLocalized(language, "Vibe", "Vibe"), value: insight.vibe)
                DJConnectWatchTrackInsightMetric(title: watchLocalized(language, "Texture", "Textuur"), value: insight.texture)
            }
        }

        private func percent(_ value: Double?) -> String? {
            value.map { "\(Int(($0 * 100).rounded()))%" }
        }
    }

    private struct DJConnectWatchTrackInsightMetric: View {
        let title: String
        let value: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(value?.isEmpty == false ? value! : "-")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.70)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private struct DJConnectWatchTrackInsightStructuredGroup: Identifiable {
        let id: String
        let title: String
        let values: [String]
    }

    private struct DJConnectWatchTrackInsightGroups {
        static func make(for insight: TrackInsight, language: String) -> [DJConnectWatchTrackInsightStructuredGroup] {
            var groups = [
                DJConnectWatchTrackInsightStructuredGroup(id: "production", title: watchLocalized(language, "Production", "Productie"), values: insight.productionNotes),
                DJConnectWatchTrackInsightStructuredGroup(id: "instrumentation", title: watchLocalized(language, "Instrumentation", "Instrumentatie"), values: insight.instrumentation),
                DJConnectWatchTrackInsightStructuredGroup(id: "arrangement", title: watchLocalized(language, "Arrangement", "Arrangement"), values: insight.arrangementNotes),
                DJConnectWatchTrackInsightStructuredGroup(id: "listening", title: watchLocalized(language, "Listening cues", "Luisterpunten"), values: insight.listeningCues),
                DJConnectWatchTrackInsightStructuredGroup(
                    id: "similar",
                    title: watchLocalized(language, "Similar tracks", "Vergelijkbare tracks"),
                    values: insight.similarTracks.map { track in
                        if let reason = track.reason, !reason.isEmpty {
                            return "\(track.title) - \(track.artist): \(reason)"
                        }
                        return "\(track.title) - \(track.artist)"
                    }
                )
            ].filter { !$0.values.isEmpty }

            let backendSections = insight.sections.compactMap { section -> DJConnectWatchTrackInsightStructuredGroup? in
                let values = [section.value, section.summary]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard !values.isEmpty else {
                    return nil
                }
                return DJConnectWatchTrackInsightStructuredGroup(id: "section-\(section.id)", title: section.title, values: values)
            }
            groups.append(contentsOf: backendSections)

            if let musicDNASummary = insight.musicDNASummary, !musicDNASummary.isEmpty {
                groups.append(
                    DJConnectWatchTrackInsightStructuredGroup(
                        id: "music-dna",
                        title: musicDNATitle(insight.musicDNALabel, language: language),
                        values: [musicDNASummary]
                    )
                )
            }

            return groups
        }

        private static func musicDNATitle(_ label: TrackInsight.MusicDNALabel?, language: String) -> String {
            switch label {
            case .matchesMusicDNA:
                return watchLocalized(language, "Matches Music DNA", "Past bij Music DNA")
            case .expandsMusicDNA:
                return watchLocalized(language, "Expands Music DNA", "Verbreedt Music DNA")
            case .outsideMusicDNA:
                return watchLocalized(language, "Outside Music DNA", "Buiten Music DNA")
            case nil:
                return "Music DNA"
            }
        }
    }

    private struct DJConnectWatchTrackInsightVisualizer: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let profile: TrackVibeProfile
        let isPlaying: Bool

        private var shouldAnimate: Bool {
            !reduceMotion && isPlaying
        }

        var body: some View {
            TimelineView(.periodic(from: .now, by: shouldAnimate ? 0.12 : 60)) { timeline in
                let phase = shouldAnimate ? timeline.date.timeIntervalSinceReferenceDate : 0
                ZStack {
                    LinearGradient(
                        colors: [watchDeepNavy, watchAccentPurple.opacity(0.34), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    ZStack {
                        ForEach(0..<4, id: \.self) { ring in
                            let pulse = ringPulse(ring, phase: phase)
                            Circle()
                                .stroke(ringColor(ring).opacity(0.50 - Double(ring) * 0.07 + pulse * 0.12), lineWidth: 1.4)
                                .frame(width: 38 + CGFloat(ring) * 16 + CGFloat(pulse) * 7, height: 38 + CGFloat(ring) * 16 + CGFloat(pulse) * 7)
                                .rotationEffect(.degrees(phase * (shouldAnimate ? 8 + Double(ring) * 3 : 0)))
                        }
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<24, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1.1, style: .continuous)
                                .fill(Color(hue: 0.60 + Double(index) / 90, saturation: 0.85, brightness: 1.0).opacity(0.78))
                                .frame(width: 2.4, height: barHeight(index, phase: phase))
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 7)
                }
            }
        }

        private func ringColor(_ index: Int) -> Color {
            let colors = profile.palette.compactMap { Color(watchHex: $0) }
            return colors[safe: index] ?? watchAccentPurple
        }

        private func ringPulse(_ index: Int, phase: TimeInterval) -> Double {
            guard shouldAnimate else {
                return 0
            }
            return (sin(phase * 1.5 + Double(index) * 0.8) + 1) / 2
        }

        private func barHeight(_ index: Int, phase: TimeInterval) -> CGFloat {
            let spectrum = profile.spectrumProfile.isEmpty ? [0.5] : profile.spectrumProfile
            let base = spectrum[index % spectrum.count]
            let motion = shouldAnimate ? 0.72 + ((sin(phase * 2.4 + Double(index) * 0.55) + 1) / 2) * 0.48 : 1
            return CGFloat(base * motion) * 28 + 5
        }
    }

    private struct DJConnectWatchMusicDNAView: View {
        @EnvironmentObject private var model: DJConnectWatchModel

        var body: some View {
            ZStack {
                DJConnectWatchCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        header
                        content
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
            }
            .navigationTitle(model.isDemoMode ? "Music DNA (Demo)" : "Music DNA")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refreshMusicDNAProfile() }
                    } label: {
                        if model.isLoadingMusicDNA {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white.opacity(0.82))
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
                    .disabled(model.isLoadingMusicDNA || model.isUpdatingMusicDNA)
                    .accessibilityLabel(watchLocalized(model.language, "Refresh Music DNA", "Music DNA vernieuwen"))
                }
            }
            .task {
                await model.refreshMusicDNAProfile()
                await model.prepareMusicDNAConsentPromptIfNeeded()
            }
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: 7) {
                Label("Music DNA", systemImage: "heart")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchLocalized(
                    model.language,
                    "Server-side taste profile for Ask DJ context and recommendations.",
                    "Server-side smaakprofiel voor Ask DJ-context en aanbevelingen."
                ))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(DJConnectWatchPanel(cornerRadius: 12))
        }

        @ViewBuilder
        private var content: some View {
            if model.isLoadingMusicDNA, model.musicDNAProfileResponse == nil {
                watchPanel {
                    ProgressView()
                        .tint(.white)
                    Text(watchLocalized(model.language, "Loading Music DNA...", "Music DNA laden..."))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            } else if let response = model.musicDNAProfileResponse {
                if response.enabled {
                    if response.profile.isEmpty {
                        noProfilePanel
                    } else {
                        populatedProfile(response)
                    }
                } else {
                    disabledPanel
                }
            } else {
                unavailablePanel
            }

            if let message = model.musicDNAErrorMessage, !message.isEmpty {
                Text(message)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private var disabledPanel: some View {
            watchPanel {
                Label(watchLocalized(model.language, "Not enabled", "Niet geactiveerd"), systemImage: "lock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchLocalized(
                    model.language,
                    "Enable Music DNA to let Home Assistant build a private profile from future signals.",
                    "Activeer Music DNA om Home Assistant een prive profiel uit toekomstige signalen te laten opbouwen."
                ))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                Button {
                    model.showMusicDNAOptInPrompt()
                } label: {
                    Label(watchLocalized(model.language, "Enable", "Activeer"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
                .disabled(model.isUpdatingMusicDNA)
            }
        }

        private var noProfilePanel: some View {
            watchPanel {
                Label(watchLocalized(model.language, "No profile yet", "Nog geen profiel"), systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchLocalized(
                    model.language,
                    "Music DNA is on, but Home Assistant has not built data yet. This can happen after enabling or clearing.",
                    "Music DNA staat aan, maar Home Assistant heeft nog geen data opgebouwd. Dit kan na activeren of wissen."
                ))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
            }
        }

        private var unavailablePanel: some View {
            watchPanel {
                Label(watchLocalized(model.language, "Could not load", "Kon niet laden"), systemImage: "wifi.exclamationmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchLocalized(
                    model.language,
                    "This is a temporary backend or connection issue, not the same as Music DNA being turned off.",
                    "Dit is een tijdelijke backend- of verbindingsfout, niet hetzelfde als Music DNA uitschakelen."
                ))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                Button {
                    Task { await model.refreshMusicDNAProfile() }
                } label: {
                    Label(watchLocalized(model.language, "Try Again", "Opnieuw"), systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
                .disabled(model.isLoadingMusicDNA)
            }
        }

        private func populatedProfile(_ response: DJConnectMusicDNAProfileResponse) -> some View {
            let profile = response.profile
            return VStack(alignment: .leading, spacing: 8) {
                if let summary = profile.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                    watchPanel {
                        Label(watchLocalized(model.language, "Summary", "Samenvatting"), systemImage: "text.quote")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                        Text(summary)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LazyVStack(spacing: 8) {
                    metricPanel(title: watchLocalized(model.language, "Genres", "Genres"), value: names(profile.favoriteGenres), icon: "music.note.list")
                    metricPanel(title: watchLocalized(model.language, "Artists", "Artiesten"), value: names(profile.favoriteArtists), icon: "person.2")
                    metricPanel(title: watchLocalized(model.language, "Mood", "Mood"), value: mood(profile.mood), icon: "sparkles")
                    metricPanel(title: watchLocalized(model.language, "Recent", "Recent"), value: tracks(profile.recentTracks), icon: "clock.arrow.circlepath")
                    metricPanel(title: watchLocalized(model.language, "Signals", "Signalen"), value: signals(profile.recommendationSignals), icon: "slider.horizontal.3")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func metricPanel(title: String, value: String, icon: String) -> some View {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(watchAccentPurple)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(value)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(DJConnectWatchPanel(cornerRadius: 12))
        }

        private func watchPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 8, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(DJConnectWatchPanel(cornerRadius: 12))
        }

        private func names(_ values: [DJConnectMusicDNANameValue]) -> String {
            let value = values.map(\.name)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
                .joined(separator: ", ")
            return watchNonEmpty(value, fallback: watchLocalized(model.language, "Not enough signals", "Nog niet genoeg signalen"))
        }

        private func tracks(_ values: [DJConnectMusicDNATrack]) -> String {
            let value = values.compactMap { track in
                let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let artist = track.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if title.isEmpty { return artist.isEmpty ? nil : artist }
                return artist.isEmpty ? title : "\(title) - \(artist)"
            }
            .prefix(3)
            .joined(separator: ", ")
            return watchNonEmpty(value, fallback: watchLocalized(model.language, "Not enough signals", "Nog niet genoeg signalen"))
        }

        private func signals(_ values: [DJConnectMusicDNASignal]) -> String {
            let value = values.compactMap { $0.title ?? $0.name ?? $0.value }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
                .joined(separator: ", ")
            return watchNonEmpty(value, fallback: watchLocalized(model.language, "Not enough signals", "Nog niet genoeg signalen"))
        }

        private func mood(_ mood: DJConnectMusicDNAMood?) -> String {
            guard let mood else {
                return watchLocalized(model.language, "Not enough signals", "Nog niet genoeg signalen")
            }
            let zone = mood.zone?.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = mood.value.map { "\($0)%" }
            let summary = [zone, value]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " - ")
            return watchNonEmpty(summary, fallback: watchLocalized(model.language, "Not enough signals", "Nog niet genoeg signalen"))
        }
    }

    private func pairingView(message: String?) -> some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .center, spacing: 9) {
                        Image("LaunchIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(watchLocalized(model.language, "Pair DJConnect", "DJConnect koppelen"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(watchLocalized(model.language, "LAN pairing runs through your iPhone", "LAN-koppeling loopt via je iPhone"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Label(
                        watchLocalized(
                            model.language,
                            "Open DJConnect on your iPhone. The iPhone will show Apple Watch pairing with only the Apple Watch QR option. Keep iPhone, Watch and Home Assistant on the same local network.",
                            "Open DJConnect op je iPhone. De iPhone toont Apple Watch-koppeling met alleen de Apple Watch QR-optie. Houd iPhone, Watch en Home Assistant op hetzelfde lokale netwerk."
                        ),
                        systemImage: "network"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(9)
                    .background(DJConnectWatchPanel(cornerRadius: 12))

                    if let networkRequirementMessage = model.networkRequirementMessage {
                        Label(networkRequirementMessage, systemImage: "iphone")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.28))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(9)
                            .background(DJConnectWatchPanel(cornerRadius: 12))
                    }

                    pairingValueCard(
                        title: watchLocalized(model.language, "iPhone companion", "iPhone companion"),
                        value: model.companionPairingStatus,
                        systemImage: "iphone",
                        prominent: false
                    )

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.58))
                    }

                    Button {
                        model.startDemoMode()
                    } label: {
                        Label(watchLocalized(model.language, "Demo Mode", "Demo modus"), systemImage: "play.circle")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
    }

    private func pairingValueCard(
        title: String,
        value: String,
        systemImage: String,
        prominent: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                Text(value)
                    .font(prominent ? .title3.monospacedDigit().weight(.bold) : .caption2.monospaced())
                    .foregroundStyle(prominent ? .white : .white.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: systemImage)
                .font(.system(size: prominent ? 16 : 13, weight: .semibold))
                .foregroundStyle(watchAccentPurple.opacity(0.92))
        }
        .padding(9)
        .background(DJConnectWatchPanel(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func commandButton(
        _ icon: String,
        command: String,
        accessibilityLabel: String,
        isPrimary: Bool = false
    ) -> some View {
        Button {
            Task { await model.sendCommand(command) }
        } label: {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 24 : 19, weight: .semibold))
                .frame(width: isPrimary ? 54 : 44, height: isPrimary ? 54 : 44)
        }
        .buttonStyle(DJConnectWatchRoundButtonStyle())
        .disabled(!canUsePlaybackControls || model.isRefreshingStatus)
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
    }

}

private struct DJConnectWatchWelcomeView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(spacing: 11) {
                    Image("LaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)

                    Text(watchLocalized(model.language, "Welcome to DJConnect", "Welkom bij DJConnect"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(watchLocalized(model.language, "Configure DJConnect in Home Assistant, then pair this Watch.", "Configureer DJConnect in Home Assistant en koppel daarna deze Watch."))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(watchLocalized(model.language, "The music backend runs through Home Assistant.", "Muziekbackend loopt via Home Assistant."), systemImage: "music.note")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)

                    Button {
                        model.dismissWelcome()
                    } label: {
                        Text(watchLocalized(model.language, "Continue", "Doorgaan"))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
        }
    }
}

private struct DJConnectWatchMicrophonePermissionView: View {
    enum Kind {
        case pushToTalk
        case voiceActivation
    }

    @EnvironmentObject private var model: DJConnectWatchModel
    let kind: Kind

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            VStack(spacing: 10) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [watchAccentBlue, watchAccentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(watchLocalized(model.language, "Microphone", "Microfoon"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(bodyText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(secondaryText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.56))
                    .multilineTextAlignment(.center)

                Button {
                    switch kind {
                    case .pushToTalk:
                        model.continueAfterMicrophonePermissionExplanation()
                    case .voiceActivation:
                        model.continueAfterVoiceActivationPermissionExplanation()
                    }
                } label: {
                    Text(watchLocalized(model.language, "Continue", "Doorgaan"))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))

                Button {
                    switch kind {
                    case .pushToTalk:
                        model.cancelMicrophonePermissionExplanation()
                    case .voiceActivation:
                        model.cancelVoiceActivationPermissionExplanation()
                    }
                } label: {
                    Text(watchLocalized(model.language, "Not now", "Niet nu"))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
            }
            .padding(.horizontal, 8)
        }
    }

    private var bodyText: String {
        switch kind {
        case .pushToTalk:
            return watchLocalized(model.language, "DJConnect only uses the microphone when you start an Ask DJ voice request.", "DJConnect gebruikt de microfoon alleen wanneer je zelf een stemverzoek aan Ask DJ start.")
        case .voiceActivation:
            return watchLocalized(model.language, "Voice activation only listens for Hey DJ while the Watch app is visible and open.", "Stemactivatie luistert alleen naar Hey DJ zolang de Watch app zichtbaar en open is.")
        }
    }

    private var secondaryText: String {
        switch kind {
        case .pushToTalk:
            return watchLocalized(model.language, "Apple will ask for permission next.", "Hierna vraagt Apple om toestemming.")
        case .voiceActivation:
            return watchLocalized(model.language, "No wake word outside the app. Apple will ask for microphone and speech recognition permission next.", "Geen wake word buiten de app. Hierna vraagt Apple om microfoon- en spraakherkenningstoestemming.")
        }
    }
}

private struct DJConnectWatchAboutView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Image("LaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity)

                    Text("DJConnect")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)

                    Text(watchLocalized(model.language, "Music control with character.", "Muziekbediening met karakter."))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    DJConnectWatchSettingsSection(title: "App") {
                        aboutRow(watchLocalized(model.language, "Version", "Versie"), appVersion)
                        aboutRow(watchLocalized(model.language, "Device name", "Apparaatnaam"), model.identity.deviceName)
                        aboutRow("Website", "https://djconnect.dev")
                        aboutRow("Device ID", model.identity.deviceID)
                    }

                    DJConnectWatchSettingsSection(title: watchLocalized(model.language, "Connection", "Verbinding")) {
                        aboutRow("iPhone", model.companionPairingStatus)
                        aboutRow(watchLocalized(model.language, "Connection", "Connectie"), "\(watchLocalized(model.language, "through iPhone", "via iPhone")), \(connectionModeTitle(model.iPhoneConnectionMode))")
                        aboutRow(
                            "Backend",
                            backendTitle,
                            foregroundStyle: model.musicBackendSummary.musicBackendAvailable == false ? Color.red : Color.green
                        )
                        if let target = model.musicBackendSummary.musicTargetPlayer?.name ?? model.musicBackendSummary.musicTargetPlayer?.id {
                            aboutRow("Target", target)
                        }
                        if let error = model.musicBackendSummary.musicBackendError {
                            aboutRow(watchLocalized(model.language, "Backend error", "Backend fout"), error, foregroundStyle: .red)
                        }
                    }

                    DJConnectWatchSettingsSection(title: "Notices") {
                        aboutRow("Copyright", "2026 Peter van Tol")
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
            }
        }
        .navigationTitle(watchLocalized(model.language, "About", "Over"))
    }

    private var backendTitle: String {
        let name = model.musicBackendSummary.displayName
        if model.musicBackendSummary.musicBackendAvailable == false {
            return "\(name) \(watchLocalized(model.language, "unavailable", "niet beschikbaar"))"
        }
        if let revision = model.musicBackendSummary.musicBackendRevision {
            return "\(name) rev \(revision)"
        }
        return name
    }

    private func connectionModeTitle(_ mode: DJConnectHAConnectionMode) -> String {
        switch mode {
        case .local:
            return watchLocalized(model.language, "Local", "Lokaal")
        case .remote:
            return "Remote"
        case .offline:
            return "Offline"
        }
    }

    private func aboutRow(_ title: String, _ value: String, foregroundStyle: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(foregroundStyle)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

private struct DJConnectWatchLegalView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DJConnectWatchLegalSection(title: watchLocalized(model.language, "Legal", "Juridisch")) {
                        Text(watchLocalized(model.language, "DJConnect is not affiliated with, endorsed by, or sponsored by Spotify AB, Apple, or Home Assistant.", "DJConnect is niet gelieerd aan, goedgekeurd door of gesponsord door Spotify AB, Apple of Home Assistant."))
                        Text(watchLocalized(model.language, "Spotify is a trademark of Spotify AB. Home Assistant is a trademark of the Open Home Foundation.", "Spotify is een handelsmerk van Spotify AB. Home Assistant is een handelsmerk van de Open Home Foundation."))
                    }

                    DJConnectWatchLegalSection(title: "OSS") {
                        Text(watchLocalized(model.language, "DJConnect uses Apple platform frameworks and Swift Package Manager.", "DJConnect gebruikt Apple platform-frameworks en Swift Package Manager."))
                        Text(watchLocalized(model.language, "Third-party notices are documented in the repository when dependencies are added.", "Third-party notices worden in de repository gedocumenteerd wanneer dependencies worden toegevoegd."))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.76))
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalized(model.language, "Legal", "Juridisch"))
    }
}

private struct DJConnectWatchLegalSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 7) {
                content
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchPrivacyView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DJConnectWatchLegalSection(title: "Privacy") {
                        Text(watchLocalized(model.language, "DJConnect itself does not collect, sell, or process personal data in the app.", "DJConnect verzamelt, verkoopt of verwerkt zelf geen persoonsgegevens in de app."))
                        Text(watchLocalized(model.language, "Device tokens are stored locally in private app storage.", "Device-tokens worden lokaal in de private app-opslag bewaard."))
                        Text(watchLocalized(model.language, "Push notifications are only used for DJConnect notifications, such as Ask DJ responses. DJConnect stores an Apple push token locally and shares it with your own Home Assistant DJConnect integration so notifications can be delivered through Apple Push Notification service. Push tokens are not used for tracking, ads, or sale.", "Pushnotificaties worden alleen gebruikt voor DJConnect-meldingen, zoals Ask DJ-reacties. DJConnect bewaart hiervoor een Apple push-token lokaal en deelt dit met je eigen Home Assistant DJConnect-integratie zodat notificaties via Apple Push Notification service kunnen worden bezorgd. Push-tokens worden niet gebruikt voor tracking, advertenties of verkoop."))
                        Text(watchLocalized(model.language, "Diagnostics are only shared when you copy them yourself or open a GitHub issue.", "Diagnostiek wordt alleen gedeeld wanneer je die zelf kopieert of een GitHub issue opent."))
                        Text(watchLocalized(model.language, "Music, playback, and voice requests run through your own Home Assistant DJConnect integration.", "Muziek, playback en stemverzoeken lopen via je eigen Home Assistant DJConnect-integratie."))
                        Text(watchLocalized(model.language, "AI and Assist answers can be incorrect and depend on your own Home Assistant and Assist configuration.", "AI- en Assist-antwoorden kunnen onjuist zijn en hangen af van je eigen Home Assistant- en Assist-configuratie."))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.76))
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalized(model.language, "Privacy", "Privacy"))
    }
}

private struct DJConnectWatchFeedbackView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var model: DJConnectWatchModel

    private var feedbackURL: URL {
        var components = URLComponents(string: "https://github.com/pcvantol/djconnect/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "DJConnect watchOS feedback"),
            URLQueryItem(name: "body", value: """
            ## DJConnect watchOS feedback

            Please describe your feedback or feature request:


            ```text
            client_type: watchos
            ```
            """)
        ]
        return components?.url ?? URL(string: "https://github.com/pcvantol/djconnect/issues/new")!
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [watchAccentBlue, watchAccentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(watchLocalized(model.language, "Share feedback", "Feedback delen"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(watchLocalized(model.language, "Open a GitHub issue with app context. Nothing is uploaded automatically.", "Open een GitHub issue met app-context. Er wordt niets automatisch geüpload."))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        openURL(feedbackURL)
                    } label: {
                        Label(watchLocalized(model.language, "Open GitHub issue", "Open GitHub issue"), systemImage: "arrow.up.right.square")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(watchLocalized(model.language, "Does opening not work on the Watch?", "Werkt openen niet op de Watch?"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(watchLocalized(model.language, "Use this link on iPhone or Mac:", "Gebruik dan deze link op iPhone of Mac:"))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                        Text("github.com/pcvantol/djconnect/issues/new")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(watchAccentBlue.opacity(0.92))
                            .lineLimit(3)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(DJConnectWatchPanel(cornerRadius: 12))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
            }
        }
        .navigationTitle(watchLocalized(model.language, "Feedback", "Feedback"))
    }
}

private struct DJConnectWatchSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var isShowingResetPairingConfirmation = false
    @State private var isShowingMusicDNADisableConfirmation = false
    @State private var isShowingMusicDNAClearConfirmation = false

    private var selectedLogLevel: DJConnectWatchLogLevel {
        DJConnectWatchLogLevel(rawValue: model.watchLogLevel) ?? .info
    }

    private var musicDNAEnabled: Bool {
        model.musicDNAProfileResponse?.enabled == true
    }

    private var musicDNAStatusText: String {
        if model.isLoadingMusicDNA, model.musicDNAProfileResponse == nil {
            return watchLocalized(model.language, "Checking status...", "Status ophalen...")
        }
        if musicDNAEnabled {
            return watchLocalized(model.language, "Music DNA is enabled.", "Music DNA staat aan.")
        }
        if model.musicDNAProfileResponse?.enabled == false {
            return watchLocalized(model.language, "Music DNA is disabled.", "Music DNA staat uit.")
        }
        return watchLocalized(model.language, "Status not loaded yet.", "Status nog niet geladen.")
    }

    private var musicDNAHowItWorksText: String {
        if musicDNAEnabled {
            return watchLocalized(
                model.language,
                "Music DNA is enabled. Home Assistant can build a private profile from future listening signals.",
                "Music DNA staat aan. Home Assistant kan een prive profiel opbouwen uit toekomstige luistersignalen."
            )
        }
        if model.musicDNAProfileResponse?.enabled == false {
            return watchLocalized(
                model.language,
                "Music DNA is disabled. No profile is being built, and the learned profile has already been cleared.",
                "Music DNA staat uit. Er wordt geen profiel opgebouwd en het geleerde profiel is al gewist."
            )
        }
        return watchLocalized(
            model.language,
            "DJConnect is still checking the current Music DNA status.",
            "DJConnect haalt de huidige Music DNA-status nog op."
        )
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if model.isDemoMode {
                        DJConnectWatchSettingsSection(title: watchLocalized(model.language, "Mode", "Modus")) {
                            Text(watchLocalized(model.language, "Demo Mode active", "Demo modus actief"))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                            Button {
                                model.stopDemoMode()
                            } label: {
                                Label(watchLocalized(model.language, "Stop demo", "Stop demo"), systemImage: "xmark.circle")
                                    .font(.caption2.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                        }
                    }

                    if !model.isDemoMode {
                        DJConnectWatchSettingsSection(title: watchLocalized(model.language, "Pairing", "Koppeling")) {
                            Text(watchLocalized(model.language, "Reset Watch pairing and pair again through the iPhone companion.", "Reset de Watch-koppeling en koppel opnieuw via de iPhone companion."))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                            Button(role: .destructive) {
                                isShowingResetPairingConfirmation = true
                            } label: {
                                Label(watchLocalized(model.language, "Pair again", "Opnieuw koppelen"), systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption2.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                        }
                    }

                    DJConnectWatchSettingsSection(title: "Music DNA") {
                        HStack(spacing: 7) {
                            Image(systemName: musicDNAEnabled ? "checkmark.seal.fill" : "power")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(musicDNAEnabled ? watchAccentGreen : watchAccentPurple)
                            Text(musicDNAStatusText)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }

                        Text(musicDNAHowItWorksText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

                        if musicDNAEnabled {
                            Button(role: .destructive) {
                                isShowingMusicDNAClearConfirmation = true
                            } label: {
                                Label(watchLocalized(model.language, "Clear Music DNA", "Music DNA wissen"), systemImage: "trash")
                                    .font(.caption2.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                            .disabled(model.isLoadingMusicDNA || model.isUpdatingMusicDNA || (!model.canUseBackend && !model.isDemoMode))
                        }

                        Button {
                            if musicDNAEnabled {
                                isShowingMusicDNADisableConfirmation = true
                            } else {
                                model.showMusicDNAOptInPrompt()
                            }
                        } label: {
                            DJConnectWatchCenteredButtonLabel(
                                title: musicDNAEnabled
                                    ? watchLocalized(model.language, "Turn Off Music DNA", "Music DNA uitschakelen")
                                    : watchLocalized(model.language, "Turn On Music DNA", "Music DNA inschakelen"),
                                systemImage: musicDNAEnabled ? "power" : "sparkles"
                            )
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: musicDNAEnabled ? .secondary : .primary))
                        .disabled(model.isLoadingMusicDNA || model.isUpdatingMusicDNA || (!model.canUseBackend && !model.isDemoMode))
                    }

                    DJConnectWatchSettingsSection(title: watchLocalized(model.language, "Voice activation", "Stemactivatie")) {
                        Toggle(isOn: Binding(
                            get: { model.isVoiceActivationEnabled },
                            set: { model.setVoiceActivationEnabled($0) }
                        )) {
                            Label("Hey DJ", systemImage: "waveform")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .tint(watchAccentPurple)

                        HStack(spacing: 7) {
                            Image(systemName: voiceActivationIcon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(voiceActivationColor)
                            Text(model.voiceActivationStatusText)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }

                        Text(model.voiceActivationDetailText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(watchLocalized(model.language, "Stops automatically in the background or during sleep.", "Stop automatisch bij achtergrond of slapen."))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    DJConnectWatchSettingsSection(title: "Logs") {
                        VStack(spacing: 6) {
                            ForEach(DJConnectWatchLogLevel.allCases) { level in
                                Button {
                                    Task { @MainActor in
                                        model.setWatchLogLevel(level)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(selectedLogLevel == level ? "✓" : "")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(watchAccentPurple)
                                            .frame(width: 14, alignment: .center)
                                        Text(level.title(language: model.language))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 28)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalized(model.language, "Settings", "Instellingen"))
        .task {
            await model.refreshMusicDNAProfile()
        }
        .alert(watchLocalized(model.language, "Pair again?", "Opnieuw koppelen?"), isPresented: $isShowingResetPairingConfirmation) {
            Button(watchLocalized(model.language, "Cancel", "Annuleer"), role: .cancel) {}
            Button(watchLocalized(model.language, "Pair again", "Opnieuw koppelen"), role: .destructive) {
                model.resetPairing()
                dismiss()
            }
        } message: {
            Text(watchLocalized(model.language, "This clears local Watch pairing and opens the pairing screen again.", "Dit wist de lokale Watch-koppeling en opent het koppelscherm opnieuw."))
        }
        .alert(watchLocalized(model.language, "Turn Off Music DNA?", "Music DNA uitschakelen?"), isPresented: $isShowingMusicDNADisableConfirmation) {
            Button(watchLocalized(model.language, "Cancel", "Annuleer"), role: .cancel) {}
            Button(watchLocalized(model.language, "Turn Off", "Uitschakelen"), role: .destructive) {
                Task { await model.setMusicDNAEnabled(false) }
            }
        } message: {
            Text(watchLocalized(
                model.language,
                "This clears learned Music DNA on Home Assistant and stops future buildup until you turn it on again.",
                "Dit wist geleerde Music DNA op Home Assistant en stopt verdere opbouw totdat je het opnieuw inschakelt."
            ))
        }
        .alert(
            watchLocalized(model.language, "Clear Music DNA?", "Music DNA wissen?"),
            isPresented: $isShowingMusicDNAClearConfirmation
        ) {
            Button(watchLocalized(model.language, "Cancel", "Annuleer"), role: .cancel) {}
            Button(
                model.isDemoMode
                    ? watchLocalized(model.language, "Keep Demo Profile", "Demo-profiel behouden")
                    : watchLocalized(model.language, "Clear Music DNA", "Music DNA wissen"),
                role: model.isDemoMode ? nil : .destructive
            ) {
                Task { await model.clearMusicDNA() }
            }
        } message: {
            if model.isDemoMode {
                Text(watchLocalized(
                    model.language,
                    "In the real app this clears learned Music DNA on Home Assistant. Demo data stays visible.",
                    "In de echte app wist dit geleerde Music DNA op Home Assistant. Demo-data blijft zichtbaar."
                ))
            } else {
                Text(watchLocalized(
                    model.language,
                    "This clears learned Music DNA. If Music DNA stays enabled, Home Assistant starts learning again from empty.",
                    "Dit wist geleerde Music DNA. Als Music DNA aan blijft, begint Home Assistant opnieuw vanaf leeg."
                ))
            }
        }
    }

    private var voiceActivationIcon: String {
        switch model.voiceActivationStatus {
        case .listening:
            return "waveform.circle.fill"
        case .paused:
            return "pause.circle"
        case .microphoneRequired:
            return "mic.badge.xmark"
        case .unavailable:
            return "exclamationmark.triangle"
        }
    }

    private var voiceActivationColor: Color {
        switch model.voiceActivationStatus {
        case .listening:
            return .green
        case .paused:
            return .white.opacity(0.58)
        case .microphoneRequired, .unavailable:
            return Color(red: 1.0, green: 0.62, blue: 0.28)
        }
    }
}

private struct DJConnectWatchSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchCenteredButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16, height: 16, alignment: .center)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions[VerticalAlignment.center]
                }
            Text(title)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions[VerticalAlignment.center]
                }
        }
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .center)
    }
}

private struct DJConnectWatchLogsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var isShowingClearConfirmation = false

    var body: some View {
        ZStack(alignment: .bottom) {
            DJConnectWatchCanvas()
            VStack(spacing: 8) {
                if model.diagnosticLogLines.isEmpty {
                    Spacer(minLength: 22)
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [watchAccentBlue, watchAccentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(watchLocalized(model.language, "No logs", "Geen logs"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(watchLocalized(model.language, "New Watch actions appear here.", "Nieuwe acties op de Watch verschijnen hier."))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.66))
                            .multilineTextAlignment(.center)
                    }
                    .padding(10)
                    Spacer(minLength: 18)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 5) {
                                ForEach(Array(model.diagnosticLogLines.enumerated()), id: \.element.id) { index, line in
                                    HStack(alignment: .top, spacing: 5) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.42))
                                            .frame(width: 18, alignment: .trailing)
                                        Text(line.text)
                                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.76))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .id(line.id)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 34)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.top, 18)
                        .onAppear {
                            scrollToBottom(proxy)
                        }
                        .onChange(of: model.diagnosticLogLines.last?.id) {
                            scrollToBottom(proxy)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, model.diagnosticLogLines.isEmpty ? 34 : 0)

            Button(role: .destructive) {
                isShowingClearConfirmation = true
            } label: {
                Label(watchLocalized(model.language, "Clear logs", "Wis logs"), systemImage: "trash")
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
            .disabled(model.diagnosticLogLines.isEmpty)
            .padding(.horizontal, 4)
            .padding(.bottom, 0)
        }
        .navigationTitle("Logs")
        .alert(watchLocalized(model.language, "Clear logs?", "Logs wissen?"), isPresented: $isShowingClearConfirmation) {
            Button(watchLocalized(model.language, "Cancel", "Annuleer"), role: .cancel) {}
            Button(watchLocalized(model.language, "Clear logs", "Wis logs"), role: .destructive) {
                model.clearDiagnosticLog()
            }
        } message: {
            Text(watchLocalized(model.language, "This removes diagnostic logs on this Watch.", "Dit verwijdert de diagnostische logs op deze Watch."))
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = model.diagnosticLogLines.last?.id else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct DJConnectWatchOutputsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.isLoadingOutputs && model.availableOutputs.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 18)
                    } else if model.availableOutputs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "speaker.slash")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [watchAccentBlue, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(watchLocalized(model.language, "No output devices found.", "Geen uitvoerapparaten gevonden."))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)
                    } else {
                        ForEach(model.availableOutputs) { output in
                            Button {
                                Task { await model.selectOutput(output) }
                            } label: {
                                DJConnectWatchOutputRow(
                                    output: output,
                                    isLoading: model.loadingOutputID == output.id
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isLoadingOutputs || model.loadingOutputID != nil)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalized(model.language, "Output", "Uitvoer"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.loadOutputs() }
                } label: {
                    if model.isLoadingOutputs {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white.opacity(0.82))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
                .disabled(model.isLoadingOutputs)
                .accessibilityLabel(watchLocalized(model.language, "Refresh Output", "Uitvoer vernieuwen"))
            }
        }
        .task {
            await model.loadOutputs()
        }
    }
}

private struct DJConnectWatchOutputRow: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    let output: DJConnectOutputDevice
    let isLoading: Bool

    private var isActive: Bool {
        output.active == true
    }

    private var iconName: String {
        switch output.type?.lowercased() {
        case "computer", "tv":
            return "display"
        case "headphones":
            return "headphones"
        case "phone":
            return "iphone"
        default:
            return isActive ? "speaker.wave.2.fill" : "speaker.wave.2"
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? watchAccentBlue : .white.opacity(0.68))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isActive ? watchAccentBlue.opacity(0.18) : Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(output.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    if isActive {
                        Text(watchLocalized(model.language, "Active", "Actief"))
                    } else if let volume = output.volumePercent {
                        Text("\(volume)%")
                    } else {
                        Text(output.type ?? watchLocalized(model.language, "Output", "Uitvoer"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(isActive ? watchAccentBlue.opacity(0.92) : .white.opacity(0.56))
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(watchAccentPurple)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchPlaylistsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.isLoadingPlaylists && model.playlistItems.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 18)
                    } else if model.playlistItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [watchAccentBlue, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(watchLocalized(model.language, "No playlists found.", "Geen afspeellijsten gevonden."))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)
                    } else {
                        ForEach(model.playlistItems) { playlist in
                            Button {
                                Task { await model.startPlaylist(playlist) }
                            } label: {
                                DJConnectWatchPlaylistRow(
                                    playlist: playlist,
                                    isLoading: model.loadingPlaylistID == playlist.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalized(model.language, "Playlists", "Afspeellijsten"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.loadPlaylists() }
                } label: {
                    if model.isLoadingPlaylists {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white.opacity(0.82))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
                .disabled(model.isLoadingPlaylists)
                .accessibilityLabel(watchLocalized(model.language, "Refresh Playlists", "Afspeellijsten vernieuwen"))
            }
        }
        .task {
            await model.loadPlaylists()
        }
    }
}

private struct DJConnectWatchQueueView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.isLoadingQueue && model.queueItems.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 18)
                    } else if model.queueItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [watchAccentBlue, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(watchLocalized(model.language, "No queue found.", "Geen wachtrij gevonden."))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)
                    } else {
                        ForEach(Array(model.queueItems.enumerated()), id: \.offset) { index, item in
                            Button {
                                Task { await model.startQueueItem(item, at: index) }
                            } label: {
                                DJConnectWatchQueueRow(
                                    item: item,
                                    isLoading: model.loadingQueueItemIndex == index
                                )
                                .opacity(model.canStartQueueItem(item) ? 1 : 0.45)
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isLoadingQueue || model.loadingQueueItemIndex != nil || !model.canStartQueueItem(item))
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalized(model.language, "Queue", "Wachtrij"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.loadQueue() }
                } label: {
                    if model.isLoadingQueue {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white.opacity(0.82))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
                .disabled(model.isLoadingQueue)
                .accessibilityLabel(watchLocalized(model.language, "Refresh Queue", "Wachtrij vernieuwen"))
            }
        }
        .task {
            await model.loadQueue()
        }
    }
}

private struct DJConnectWatchQueueRow: View {
    let item: DJConnectQueueItem
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            DJConnectWatchArtwork(url: item.albumImageURL, fallbackSystemImage: "music.note")
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let artist = item.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [watchAccentPurple, watchAccentBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchPlaylistRow: View {
    let playlist: DJConnectPlaylist
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            DJConnectWatchArtwork(url: playlist.imageURL, fallbackSystemImage: "music.note.list")
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle = playlist.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [watchAccentPurple, watchAccentBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchArtwork: View {
    let url: URL?
    let fallbackSystemImage: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.10))

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var fallback: some View {
        Image(systemName: fallbackSystemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(watchAccentBlue.opacity(0.88))
    }
}

private struct DJConnectWatchAskDJChatView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var toast: String?
    @State private var didInitialScrollToLatest = false

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if model.isCheckingAskDJHistoryState {
                            ProgressView()
                                .tint(.white)
                                .padding(.vertical, 18)
                        } else if model.askDJMessages.isEmpty && model.transientAskDJMoodMessage == nil {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [watchAccentBlue, watchAccentPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(watchLocalized(model.language, "Ask something about the music or give your DJ a command.", "Vraag iets over de muziek of geef je DJ een opdracht."))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .multilineTextAlignment(.center)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(watchLocalized(model.language, "Why this track?", "Waarom dit nummer?"))
                                    Text(watchLocalized(model.language, "Surprise me with new music", "Verras me met nieuwe muziek"))
                                    Text(watchLocalized(model.language, "Give Track Insight", "Geef Track Insight"))
                                    Text(watchLocalized(model.language, "Play something for cooking", "Speel iets voor koken"))
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.84))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.white.opacity(0.09))
                                }
                                Text(watchLocalized(model.language, "Ask DJ can adjust music when you ask.", "Ask DJ kan muziek aanpassen als je daarom vraagt."))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.48))
                                    .multilineTextAlignment(.center)
                                if model.isRequestingAskDJIdleSuggestion {
                                    HStack(spacing: 5) {
                                        ProgressView()
                                            .controlSize(.mini)
                                            .tint(.white)
                                        Text(watchLocalized(model.language, "Finding something...", "Iets zoeken..."))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.58))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(model.askDJMessages) { message in
                                DJConnectWatchAskDJBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        if let transientMessage = model.transientAskDJMoodMessage {
                            DJConnectWatchAskDJBubble(message: transientMessage)
                                .id(transientMessage.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Button {
                            model.toggleRecording()
                        } label: {
                            Label(voiceButtonTitle, systemImage: voiceButtonIcon)
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: voiceButtonKind))
                        .disabled(!model.isDemoMode && !model.canUseBackend)

                        Button(role: .destructive) {
                            Task { await model.clearAskDJHistory() }
                        } label: {
                            Label(
                                model.isClearingAskDJHistory
                                    ? watchLocalized(model.language, "Clearing...", "Wissen...")
                                    : watchLocalized(model.language, "Clear chat", "Wis chat"),
                                systemImage: "trash"
                            )
                            .font(.footnote.weight(.semibold))
                            .symbolRenderingMode(.monochrome)
                            .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .destructive))
                        .disabled(model.askDJMessages.isEmpty || model.isClearingAskDJHistory)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .onChange(of: model.askDJScrollRequestID) {
                    scrollToLatest(proxy, animated: true)
                }
                .onChange(of: model.isCheckingAskDJHistoryState) { _, isChecking in
                    guard !isChecking else {
                        return
                    }
                    scrollToLatestOnce(proxy)
                }
                .onAppear {
                    didInitialScrollToLatest = false
                    scrollToLatestOnce(proxy)
                }
                .onDisappear {
                    didInitialScrollToLatest = false
                }
                .onChange(of: model.askDJMessages.last?.id) {
                    if !didInitialScrollToLatest {
                        scrollToLatestOnce(proxy)
                    }
                }
            }
            if let toast {
                VStack {
                    Spacer()
                    Label(toast, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [watchAccentBlue.opacity(0.96), watchAccentPurple.opacity(0.92)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Ask DJ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshStatus(confirmAskDJBeat: true) }
                } label: {
                    if model.isRefreshingStatus {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white.opacity(0.82))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
                .disabled(model.isRefreshingStatus || (!model.canUseBackend && !model.isDemoMode))
                .accessibilityLabel(watchLocalized(model.language, "Refresh Ask DJ", "Ask DJ vernieuwen"))
            }
        }
        .task {
            await model.prepareMusicDNAConsentPromptIfNeeded()
            await model.runAskDJHistorySyncLoop()
        }
        .onChange(of: model.askDJToast?.id) { _, _ in
            guard let text = model.askDJToast?.text else {
                return
            }
            showToast(text)
        }
    }

    private func scrollToLatestOnce(_ proxy: ScrollViewProxy) {
        guard !didInitialScrollToLatest else {
            return
        }
        didInitialScrollToLatest = true
        scrollToLatest(proxy, animated: false)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = model.transientAskDJMoodMessage?.id ?? model.askDJMessages.last?.id else {
            didInitialScrollToLatest = false
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            toast = text
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard toast == text else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                toast = nil
            }
        }
    }

    private var voiceButtonTitle: String {
        switch model.voiceState {
        case .idle:
            return "Ask DJ"
        case .recording:
            return "Stop"
        case .processing:
            return watchLocalized(model.language, "Working", "Bezig")
        case .failed:
            return watchLocalized(model.language, "Retry", "Opnieuw")
        }
    }

    private var voiceButtonIcon: String {
        switch model.voiceState {
        case .recording:
            return "stop.fill"
        case .processing:
            return "mic.fill"
        case .idle, .failed:
            return "mic.fill"
        }
    }

    private var voiceButtonKind: DJConnectWatchGradientButtonStyle.Kind {
        switch model.voiceState {
        case .recording:
            return .recording
        case .processing:
            return .primary
        case .idle, .failed:
            return .primary
        }
    }
}

private struct DJConnectWatchAskDJBubble: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    let message: DJConnectWatchAskDJMessage

    private var isUser: Bool {
        message.role == .user
    }

    private var isSystemMessage: Bool {
        !isUser && message.messageKind == .system
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: bubbleHorizontalInset)
            }
            bubbleContent
                .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
            if !isUser {
                Spacer(minLength: bubbleHorizontalInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: isSystemMessage ? 5 : 6) {
            if isSystemMessage {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text(message.origin == "spotify_playback_context"
                        ? watchLocalized(model.language, "DJ fact", "DJ feitje")
                        : watchLocalized(model.language, "DJ note", "DJ notitie"))
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
            }
            if !message.text.isEmpty {
                AskDJWatchRichText(text: message.text, compact: isSystemMessage)
            }
            if !isUser, !message.items.isEmpty {
                AskDJWatchItemList(items: message.items)
            }
            if !message.images.isEmpty {
                AskDJWatchImageStack(images: message.images)
            }
            if !message.links.isEmpty {
                AskDJWatchLinkStack(links: message.links)
            }
            if !isUser, !message.renderablePlaybackActions.isEmpty {
                AskDJWatchPlaybackActionStack(
                    actions: message.renderablePlaybackActions,
                    playingActionID: model.playingAskDJActionID,
                    playAction: { action in
                        Task { await model.playAskDJRecommendation(action) }
                    }
                )
            }
            if !isUser, message.audioURL != nil {
                audioButton
            }
            Text(watchAskDJTimestamp(message.createdAt, language: model.language))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, isSystemMessage ? 8 : 9)
        .padding(.vertical, isSystemMessage ? 7 : 8)
        .background {
            bubbleBackground
        }
    }

    private var audioButton: some View {
        Button {
            if model.isPlayingAskDJAudio(message.audioURL) {
                model.stopAskDJAudio()
            } else {
                model.replayAskDJAudio(message.audioURL)
            }
        } label: {
            HStack(spacing: 5) {
                if model.isLoadingAskDJAudio(message.audioURL) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                } else {
                    Image(systemName: model.isPlayingAskDJAudio(message.audioURL) ? "stop.fill" : "play.fill")
                }
                Text(model.isPlayingAskDJAudio(message.audioURL)
                    ? watchLocalized(model.language, "Stop audio", "Stop audio")
                    : watchLocalized(model.language, "Play audio", "Speel audio"))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
        }
        .buttonStyle(.plain)
        .disabled(model.isLoadingAskDJAudio(message.audioURL))
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.13))
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(watchAccentBlue)
        } else if isSystemMessage {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            watchAccentBlue.opacity(0.34),
                            watchAccentPurple.opacity(0.24),
                            .white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [watchAccentBlue, watchAccentPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var bubbleHorizontalInset: CGFloat {
        let width = WKInterfaceDevice.current().screenBounds.width
        if isSystemMessage {
            return max(14, min(26, width * 0.10))
        }
        return max(14, min(22, width * 0.08))
    }

    private var bubbleMaxWidth: CGFloat {
        let width = WKInterfaceDevice.current().screenBounds.width
        if isSystemMessage {
            return max(116, width - (bubbleHorizontalInset * 2) - 12)
        }
        return max(124, width - bubbleHorizontalInset - 10)
    }
}

private struct DJConnectWatchMusicDNAOptInPromptView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectWatchCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [watchAccentBlue, watchAccentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(watchLocalized(model.language, "Enable Music DNA?", "Music DNA activeren?"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        Text(watchLocalized(
                            model.language,
                            "With Music DNA, DJConnect can learn from your taste and listening behavior to give recommendations tailored to your listening profile.",
                            "Met Music DNA kan DJConnect leren van je smaak en luistergedrag om aanbevelingen te kunnen geven afgestemd op jouw luisterprofiel."
                        ))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                        if model.isDemoMode {
                            Text(watchLocalized(
                                model.language,
                                "Demo mode only unlocks fictional sample data on this watch. No backend call is made.",
                                "Demo modus zet alleen fictieve voorbeelddata op deze Watch aan. Er wordt geen backend-call gedaan."
                            ))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label(watchLocalized(model.language, "Explicit opt-in", "Expliciete opt-in"), systemImage: "checkmark.shield")
                            Label(watchLocalized(model.language, "Clear anytime", "Altijd te wissen"), systemImage: "trash")
                            Label(watchLocalized(model.language, "Can be turned off in Settings", "Uitzetten kan via Instellingen"), systemImage: "switch.2")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))

                        Button {
                            model.acceptMusicDNAOptInPrompt()
                        } label: {
                            Label(
                                model.isUpdatingMusicDNAConsent
                                    ? watchLocalized(model.language, "Enabling...", "Activeren...")
                                    : watchLocalized(model.language, "Enable", "Activeer"),
                                systemImage: "sparkles"
                            )
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
                        .disabled(model.isUpdatingMusicDNAConsent)

                        Button {
                            model.dismissMusicDNAOptInPrompt()
                        } label: {
                            Text(watchLocalized(model.language, "Not now", "Niet nu"))
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                        .disabled(model.isUpdatingMusicDNAConsent)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 6)
                }
            }
            .navigationTitle("Music DNA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(watchLocalized(model.language, "Close", "Sluit")) {
                        model.dismissMusicDNAOptInPrompt()
                    }
                }
            }
        }
    }
}

private struct AskDJWatchItemList: View {
    let items: [DJConnectAskDJHistoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(2)
                        if let value = item.value, !value.isEmpty {
                            Text(value)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.82))
                                .lineLimit(2)
                        }
                    }
                    if let detail = detailText(for: item) {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.56))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.09))
                }
            }
        }
    }

    private func detailText(for item: DJConnectAskDJHistoryItem) -> String? {
        let parts = [item.source, item.confidence]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct AskDJWatchPlaybackActionStack: View {
    let actions: [DJConnectAskDJPlaybackAction]
    let playingActionID: String?
    let playAction: (DJConnectAskDJPlaybackAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(actions.filter(Self.isSupportedAction)) { action in
                Button {
                    playAction(action)
                } label: {
                    HStack(spacing: 7) {
                        if action.isSaveCurrentTrackControlAction {
                            saveControlIcon(isComplete: action.active == true)
                                .frame(width: 28, height: 28)
                        } else if action.isOutputAction {
                            outputIcon(isActive: action.isActiveOutputAction)
                                .frame(width: 28, height: 28)
                        } else if let imageURL = action.imageURL {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    fallbackIcon
                                }
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        } else {
                            fallbackIcon
                                .frame(width: 28, height: 28)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.title)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            if let subtitle = action.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.66))
                                    .lineLimit(1)
                            } else if let reason = action.reason, !reason.isEmpty {
                                Text(reason)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.66))
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 4)
                        if playingActionID == action.id {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else if action.isSaveCurrentTrackControlAction, action.active == true {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                        } else if action.isActiveOutputAction {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                        } else {
                            Image(systemName: action.isSaveCurrentTrackControlAction ? "heart.fill" : (action.isOutputAction ? "speaker.wave.2.fill" : "play.fill"))
                                .font(.caption2.weight(.bold))
                        }
                        Text(buttonLabel(for: action))
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.white.opacity(0.13))
                    }
                }
                .buttonStyle(.plain)
                .disabled(playingActionID != nil || action.active == true)
            }
        }
    }

    private static func isSupportedAction(_ action: DJConnectAskDJPlaybackAction) -> Bool {
        if action.isSaveCurrentTrackControlAction {
            return true
        }
        if action.isRecommendationAction {
            return true
        }
        if action.isOutputAction {
            return action.outputDeviceID != nil
        }
        if action.isConfirmationAction {
            return true
        }
        return false
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white.opacity(0.14))
            Image(systemName: "music.note")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func buttonLabel(for action: DJConnectAskDJPlaybackAction) -> String {
        for candidate in [action.buttonLabel, action.title] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return action.isOutputAction ? watchLocalized("Activate", "Activeer") : "Play Now"
    }

    private func outputIcon(isActive: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isActive ? .white.opacity(0.24) : .white.opacity(0.14))
            Image(systemName: isActive ? "checkmark.circle.fill" : "speaker.wave.2.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(isActive ? 0.95 : 0.72))
        }
    }

    private func saveControlIcon(isComplete: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isComplete ? .white.opacity(0.24) : .white.opacity(0.14))
            Image(systemName: isComplete ? "checkmark.circle.fill" : "heart.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(isComplete ? 0.95 : 0.72))
        }
    }
}

private struct AskDJWatchRichText: View {
    let text: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 0) {
            ForEach(Array(Self.blocks(from: text).enumerated()), id: \.offset) { _, block in
                switch block {
                case let .heading(level, value):
                    Text(value)
                        .font(headingFont(level: level))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, compact ? 0 : (level == 1 ? 1 : 5))
                        .padding(.bottom, compact ? 2 : 3)
                case let .paragraph(value):
                    Text(value)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, compact ? 3 : 4)
                case let .bullet(value):
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("•")
                            .font((compact ? Font.caption2 : Font.caption).weight(.bold))
                        Text(value)
                            .font(compact ? .caption2 : .caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 5)
                    .padding(.bottom, compact ? 3 : 4)
                case .blank:
                    Spacer(minLength: compact ? 4 : 6)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func headingFont(level: Int) -> Font {
        if compact {
            return level == 1 ? .caption2.weight(.black) : .caption2.weight(.bold)
        }
        return level == 1 ? .caption.weight(.black) : .caption2.weight(.bold)
    }

    private enum Block {
        case heading(Int, String)
        case paragraph(String)
        case bullet(String)
        case blank
    }

    private static func blocks(from text: String) -> [Block] {
        let blocks = text.components(separatedBy: .newlines).map { line -> Block in
            if line.isEmpty {
                return .blank
            }
            if line.hasPrefix("## ") {
                return .heading(2, String(line.dropFirst(3)))
            }
            if line.hasPrefix("# ") {
                return .heading(1, String(line.dropFirst(2)))
            }
            if line.hasPrefix("- ") {
                return .bullet(String(line.dropFirst(2)))
            }
            return .paragraph(line)
        }
        return blocks.isEmpty ? [.paragraph(text)] : blocks
    }
}

private struct AskDJWatchLinkStack: View {
    let links: [DJConnectResponseLink]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(links) { link in
                if link.isPlaceholderSource {
                    row(for: link, showsArrow: false)
                } else {
                    Link(destination: link.url) {
                        row(for: link, showsArrow: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(for link: DJConnectResponseLink, showsArrow: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: showsArrow ? "link" : "doc.text.magnifyingglass")
                .font(.caption2.weight(.bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(link.title?.isEmpty == false ? link.title! : link.url.host ?? link.url.absoluteString)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                if let subtitle = link.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(2)
                }
            }
            if showsArrow {
                Image(systemName: "arrow.up.forward")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.13))
        }
    }
}

private extension DJConnectResponseLink {
    var isPlaceholderSource: Bool {
        url.scheme == "djconnect-source"
    }
}

private struct AskDJWatchImageStack: View {
    let images: [DJConnectResponseImage]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(images) { image in
                AskDJWatchImageCard(image: image)
            }
        }
    }
}

private struct AskDJWatchImageCard: View {
    let image: DJConnectResponseImage

    private var displayURL: URL {
        image.thumbnailURL ?? image.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            AsyncImage(url: displayURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    Color.white.opacity(0.12)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let title = image.title, !title.isEmpty {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            if let subtitle = image.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }
        }
        .padding(7)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchCanvas: View {
    var body: some View {
        LinearGradient(
            colors: [
                watchDeepNavy,
                Color(red: 0.06, green: 0.04, blue: 0.13),
                Color(red: 0.03, green: 0.07, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct DJConnectWatchPanel: View {
    var cornerRadius: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color(red: 0.20, green: 0.09, blue: 0.32).opacity(0.42),
                        Color(red: 0.06, green: 0.10, blue: 0.22).opacity(0.54)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct DJConnectWatchRoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                watchAccentPurple.opacity(configuration.isPressed ? 0.72 : 0.92),
                                watchAccentBlue.opacity(configuration.isPressed ? 0.66 : 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
    }
}

private struct DJConnectWatchGradientButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
        case recording
        case processing
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }

    private func background(isPressed: Bool) -> LinearGradient {
        let opacity = isPressed ? 0.78 : 1.0
        return LinearGradient(
            colors: colors.map { $0.opacity(opacity) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var colors: [Color] {
        switch kind {
        case .primary:
            return [watchAccentBlue, watchAccentPurple]
        case .secondary:
            return [watchAccentBlue.opacity(0.42), watchAccentPurple.opacity(0.56)]
        case .destructive:
            return [watchAccentBlue.opacity(0.30), watchAccentPurple.opacity(0.46)]
        case .recording:
            return [Color(red: 1.0, green: 0.18, blue: 0.38), watchAccentPurple]
        case .processing:
            return [Color(red: 1.0, green: 0.48, blue: 0.16), watchAccentPurple]
        }
    }

    private var foregroundColor: Color {
        switch kind {
        case .destructive:
            return Color(red: 1.0, green: 0.24, blue: 0.34)
        default:
            return .white
        }
    }

    private var shadowColor: Color {
        switch kind {
        case .primary, .secondary, .destructive:
            return watchAccentBlue
        case .recording:
            return Color(red: 1.0, green: 0.18, blue: 0.38)
        case .processing:
            return Color(red: 1.0, green: 0.48, blue: 0.16)
        }
    }
}
