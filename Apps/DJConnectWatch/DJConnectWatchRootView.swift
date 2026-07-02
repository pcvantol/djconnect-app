import DJConnectCore
import SwiftUI
import WatchKit

private let watchAccentPurple = Color(red: 0.84, green: 0.18, blue: 1.0)
private let watchAccentBlue = Color(red: 0.12, green: 0.45, blue: 1.0)
private let watchAccentGreen = Color(red: 0.20, green: 0.86, blue: 0.48)
private let watchDeepNavy = Color(red: 0.02, green: 0.03, blue: 0.09)
private let watchIconGradient = LinearGradient(
    colors: [watchAccentBlue, watchAccentPurple],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private func watchLocalizedKey(_ language: String, _ key: String, arguments: CVarArg...) -> String {
    String(
        format: DJConnectLocalization.localized(key: key, language: language),
        locale: Locale(identifier: DJConnectLocalization.supportedLanguageCode(language)),
        arguments: arguments
    )
}

private func watchLocalizedKey(_ key: String, arguments: CVarArg...) -> String {
    String(
        format: DJConnectLocalization.localized(key: key),
        locale: Locale(identifier: DJConnectLocalization.preferredLanguageCode()),
        arguments: arguments
    )
}

private func watchNonEmpty(_ value: String, fallback: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
}

private func watchAskDJTimestamp(_ date: Date, language: String, now: Date = Date()) -> String {
    let elapsed = max(0, now.timeIntervalSince(date))
    if elapsed < 3_600 {
        let minutes = max(1, Int(elapsed / 60))
        return watchLocalizedKey(language, "watch.value.m.ago", arguments: minutes)
    }
    if Calendar.current.isDate(date, inSameDayAs: now) {
        return date.formatted(date: .omitted, time: .shortened)
    }
    let days = max(1, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 1)
    switch days {
    case 1:
        return watchLocalizedKey(language, "watch.yesterday")
    case 2...6:
        return watchLocalizedKey(language, "watch.value.d.ago", arguments: days)
    case 7...13:
        return watchLocalizedKey(language, "watch.last.week")
    case 14...30:
        let weeks = max(2, days / 7)
        return watchLocalizedKey(language, "watch.value.w.ago", arguments: weeks)
    case 31...61:
        return watchLocalizedKey(language, "watch.last.month")
    default:
        let months = max(2, days / 30)
        return watchLocalizedKey(language, "watch.value.mo.ago", arguments: months)
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

    #if DEBUG
    private var screenshotScreen: String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--screenshot-screen=") }?
            .split(separator: "=", maxSplits: 1)
            .last
            .map(String.init)
    }
    #endif

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
        .sheet(isPresented: $model.isShowingAskDJNotificationPermissionExplanation) {
            DJConnectWatchAskDJNotificationPermissionView()
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
        #if DEBUG
        if let screenshotScreen {
            screenshotContent(screenshotScreen)
        } else {
            regularContent
        }
        #else
        regularContent
        #endif
    }

    @ViewBuilder
    private var regularContent: some View {
        switch model.connectionState {
        case .paired:
            if model.isShowingPairingSuccess {
                pairingSuccessView
            } else {
                pairedView
            }
        case .pairing:
            pairingView(message: watchLocalizedKey(model.language, "watch.waiting.for.iphone.to.pair.this.watch.with"))
        case let .failed(message):
            pairingView(message: message)
        case .unpaired:
            pairingView(message: nil)
        }
    }

    #if DEBUG
    @ViewBuilder
    private func screenshotContent(_ screen: String) -> some View {
        switch screen {
        case "now-playing":
            pairedView
        case "outputs":
            DJConnectWatchOutputsView()
        case "queue":
            DJConnectWatchQueueView()
        case "ask-dj":
            DJConnectWatchAskDJChatView()
        case "track-insight":
            DJConnectWatchTrackInsightView()
        case "music-dna":
            DJConnectWatchMusicDNAView()
        case "playlists":
            DJConnectWatchPlaylistsView()
        case "settings":
            DJConnectWatchSettingsView()
        case "logs":
            DJConnectWatchLogsView()
        case "about":
            DJConnectWatchAboutView()
        case "legal":
            DJConnectWatchLegalView()
        case "privacy":
            DJConnectWatchPrivacyView()
        case "feedback":
            DJConnectWatchFeedbackView()
        default:
            pairedView
        }
    }
    #endif

    private var canUsePlaybackControls: Bool {
        model.isDemoMode || model.canUseBackend
    }

    private var shouldShowHomeStatusMessage: Bool {
        let statusText = model.statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !statusText.isEmpty else {
            return false
        }
        return !model.askDJMessages.contains { message in
            message.role == .dj && message.text.trimmingCharacters(in: .whitespacesAndNewlines) == statusText
        }
    }

    private var pairedView: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 12) {
                    mainHeader

                    nowPlaying

                    HStack(spacing: 12) {
                        commandButton("backward.fill", command: "previous", accessibilityLabel: watchLocalizedKey(model.language, "watch.previous.track"))
                        commandButton(
                            model.playback?.isPlaying == true ? "pause.fill" : "play.fill",
                            command: model.playback?.isPlaying == true ? "pause" : "play",
                            accessibilityLabel: model.playback?.isPlaying == true
                                ? watchLocalizedKey(model.language, "watch.pause")
                                : watchLocalizedKey(model.language, "watch.play"),
                            isPrimary: true
                        )
                        commandButton("forward.fill", command: "next", accessibilityLabel: watchLocalizedKey(model.language, "watch.next.track"))
                    }

                    volumeControl

                    favoriteButton

                    NavigationLink {
                        DJConnectWatchOutputsView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(watchAccentPurple.opacity(0.94))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(watchLocalizedKey(model.language, "watch.output"))
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
                        Label(watchLocalizedKey(model.language, "watch.queue"), systemImage: "text.line.first.and.arrowtriangle.forward")
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

                    if shouldShowHomeStatusMessage {
                        Text(model.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }

                    if !model.responseImages.isEmpty {
                        AskDJWatchImageStack(images: model.responseImages)
                    }

                    NavigationLink {
                        DJConnectWatchPlaylistsView()
                    } label: {
                        Label(watchLocalizedKey(model.language, "watch.playlists"), systemImage: "music.note.list")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchSettingsView()
                    } label: {
                        Label(watchLocalizedKey(model.language, "watch.settings"), systemImage: "gearshape")
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
                        Label(watchLocalizedKey(model.language, "watch.about"), systemImage: "info.circle")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchLegalView()
                    } label: {
                        Label(watchLocalizedKey(model.language, "watch.legal"), systemImage: "doc.text")
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
                        Label(watchLocalizedKey(model.language, "watch.share.feedback"), systemImage: "bubble.left.and.bubble.right")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    if model.isDemoMode {
                        Button {
                            model.stopDemoMode()
                        } label: {
                            Label(watchLocalizedKey(model.language, "watch.stop.demo"), systemImage: "xmark.circle")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                    }
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
        .accessibilityLabel(watchLocalizedKey(model.language, "watch.refresh"))
    }

    private var pairingSuccessView: some View {
        ZStack {
            DJConnectWatchCanvas()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [watchAccentPurple, watchAccentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(watchLocalizedKey(model.language, "watch.apple.watch.paired"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(watchLocalizedKey(model.language, "watch.apple.watch.is.paired.with.home.assistant.through"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                Button {
                    model.dismissPairingSuccess()
                } label: {
                    Text(watchLocalizedKey(model.language, "watch.continue"))
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
                    .foregroundStyle(watchAccentPurple.opacity(0.92))
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
                                .stroke(isSelected ? watchAccentPurple.opacity(0.82) : Color.white.opacity(0.14), lineWidth: 1)
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
                    .foregroundStyle(watchAccentPurple.opacity(0.92))
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
        .accessibilityLabel(watchLocalizedKey(model.language, "watch.volume"))
        .accessibilityValue(volumePercent.map { "\($0)%" } ?? watchLocalizedKey(model.language, "watch.unknown"))
    }

    private var nowPlaying: some View {
        HStack(spacing: 9) {
            DJConnectWatchArtwork(
                url: model.playback?.albumImageURL,
                fallbackSystemImage: "music.note"
            )
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.playback?.trackName ?? watchLocalizedKey(model.language, "watch.no.track"))
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
                        .foregroundStyle(watchAccentPurple.opacity(0.92))
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
                summary: watchLocalizedKey(model.language, "watch.ask.dj.can.fill.track.insight.details.for"),
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
                                .foregroundStyle(watchIconGradient)
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
                            watchLocalizedKey(model.language, "watch.rendered.privately.on.your.device"),
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
                Text(watchLocalizedKey(language, "watch.track.energy"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchNonEmpty(insight.summary, fallback: watchLocalizedKey(language, "watch.not.enough.signals")))
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
                GridItem(.flexible(), spacing: 7, alignment: .top)
            ]
        }

        var body: some View {
            LazyVGrid(columns: columns, spacing: 7) {
                DJConnectWatchTrackInsightMetric(title: "BPM", value: insight.bpm.map { String(Int($0.rounded())) })
                DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.key"), value: insight.key)
                DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.genre"), value: insight.genre)
                DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.mood"), value: insight.mood)
                DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.energy"), value: percent(insight.energy))
                DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.dance"), value: percent(insight.danceability))
                DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.intensity"), value: percent(insight.intensity))
                DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.vibe"), value: insight.vibe)
                DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.texture"), value: insight.texture)
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
                DJConnectWatchTrackInsightStructuredGroup(id: "production", title: watchLocalizedKey(language, "watch.production"), values: insight.productionNotes),
                DJConnectWatchTrackInsightStructuredGroup(id: "instrumentation", title: watchLocalizedKey(language, "watch.instrumentation"), values: insight.instrumentation),
                DJConnectWatchTrackInsightStructuredGroup(id: "arrangement", title: watchLocalizedKey(language, "watch.arrangement"), values: insight.arrangementNotes),
                DJConnectWatchTrackInsightStructuredGroup(id: "listening", title: watchLocalizedKey(language, "watch.listening.cues"), values: insight.listeningCues),
                DJConnectWatchTrackInsightStructuredGroup(
                    id: "similar",
                    title: watchLocalizedKey(language, "watch.similar.tracks"),
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
                return watchLocalizedKey(language, "watch.matches.music.dna")
            case .expandsMusicDNA:
                return watchLocalizedKey(language, "watch.expands.music.dna")
            case .outsideMusicDNA:
                return watchLocalizedKey(language, "watch.outside.music.dna")
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
                            .foregroundStyle(watchIconGradient)
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
                    .accessibilityLabel(watchLocalizedKey(model.language, "watch.refresh.music.dna"))
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
                Text(watchLocalizedKey(model.language, "watch.with.music.dna.djconnect.can.learn.from.your.taste.and"))
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
                    Text(watchLocalizedKey(model.language, "watch.loading.music.dna"))
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
                Label(watchLocalizedKey(model.language, "watch.not.enabled"), systemImage: "lock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchLocalizedKey(model.language, "watch.enable.music.dna.to.let.home.assistant.build.a.private"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                Button {
                    model.showMusicDNAOptInPrompt()
                } label: {
                    Label(watchLocalizedKey(model.language, "watch.enable"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
                .disabled(model.isUpdatingMusicDNA)
            }
        }

        private var noProfilePanel: some View {
            watchPanel {
                Label(watchLocalizedKey(model.language, "watch.no.profile.yet"), systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchLocalizedKey(model.language, "watch.music.dna.is.on.but.home.assistant.has.not.built"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
            }
        }

        private var unavailablePanel: some View {
            watchPanel {
                Label(watchLocalizedKey(model.language, "watch.could.not.load"), systemImage: "wifi.exclamationmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchLocalizedKey(model.language, "watch.this.is.a.temporary.backend.or.connection.issue.not.the"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                Button {
                    Task { await model.refreshMusicDNAProfile() }
                } label: {
                    Label(watchLocalizedKey(model.language, "watch.try.again"), systemImage: "arrow.clockwise")
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
                        Label(watchLocalizedKey(model.language, "watch.summary"), systemImage: "text.quote")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                        Text(summary)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LazyVStack(spacing: 8) {
                    metricPanel(title: watchLocalizedKey(model.language, "watch.genres"), value: names(profile.favoriteGenres), icon: "music.note.list")
                    metricPanel(title: watchLocalizedKey(model.language, "watch.artists"), value: names(profile.favoriteArtists), icon: "person.2")
                    metricPanel(title: watchLocalizedKey(model.language, "watch.mood"), value: mood(profile.mood), icon: "sparkles")
                    metricPanel(title: watchLocalizedKey(model.language, "watch.recent"), value: tracks(profile.recentTracks), icon: "clock.arrow.circlepath")
                    metricPanel(title: watchLocalizedKey(model.language, "watch.signals"), value: signals(profile.recommendationSignals), icon: "slider.horizontal.3")
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
            return watchNonEmpty(value, fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
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
            return watchNonEmpty(value, fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func signals(_ values: [DJConnectMusicDNASignal]) -> String {
            let value = values.compactMap { $0.title ?? $0.name ?? $0.value }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
                .joined(separator: ", ")
            return watchNonEmpty(value, fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func mood(_ mood: DJConnectMusicDNAMood?) -> String {
            guard let mood else {
                return watchLocalizedKey(model.language, "watch.not.enough.signals")
            }
            let zone = mood.zone?.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = mood.value.map { "\($0)%" }
            let summary = [zone, value]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " - ")
            return watchNonEmpty(summary, fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
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
                            Text(watchLocalizedKey(model.language, "watch.pair.djconnect"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(watchLocalizedKey(model.language, "watch.lan.pairing.runs.through.your.iphone"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Label(
                        watchLocalizedKey(model.language, "watch.open.djconnect.on.your.iphone.the.iphone.will.show.apple"),
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
                        title: watchLocalizedKey(model.language, "watch.iphone.companion"),
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
                        Label(watchLocalizedKey(model.language, "watch.demo.mode"), systemImage: "play.circle")
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

    private var favoriteButton: some View {
        let isFavorite = model.playback?.currentTrackFavoriteStatus == true
        return Button {
            Task { await model.saveCurrentTrack() }
        } label: {
            Image(systemName: model.isSavingCurrentTrack ? "hourglass" : (isFavorite ? "heart.fill" : "heart"))
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isFavorite ? watchAccentPurple : .white)
                .foregroundColor(isFavorite ? watchAccentPurple : .white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isFavorite ? watchAccentPurple.opacity(0.18) : Color.white.opacity(0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isFavorite ? watchAccentPurple.opacity(0.46) : Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canUsePlaybackControls || model.isSavingCurrentTrack)
        .focusable(false)
        .accessibilityLabel(
            isFavorite
                ? watchLocalizedKey(model.language, "watch.remove.from.favorites")
                : watchLocalizedKey(model.language, "watch.add.to.favorites")
        )
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

                    Text(watchLocalizedKey(model.language, "watch.welcome.to.djconnect"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(watchLocalizedKey(model.language, "watch.configure.djconnect.in.home.assistant.then.pair.this"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        model.dismissWelcome()
                    } label: {
                        Text(watchLocalizedKey(model.language, "watch.continue"))
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
            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [watchAccentPurple, watchAccentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(watchLocalizedKey(model.language, "watch.microphone"))
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
                        Text(watchLocalizedKey(model.language, "watch.continue"))
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
                        Text(watchLocalizedKey(model.language, "watch.not.now"))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
        }
    }

    private var bodyText: String {
        switch kind {
        case .pushToTalk:
            return watchLocalizedKey(model.language, "watch.djconnect.only.uses.the.microphone.when.you.start")
        case .voiceActivation:
            return watchLocalizedKey(model.language, "watch.voice.activation.only.listens.for.hey.dj.while")
        }
    }

    private var secondaryText: String {
        switch kind {
        case .pushToTalk:
            return watchLocalizedKey(model.language, "watch.apple.will.ask.for.permission.next")
        case .voiceActivation:
            return watchLocalizedKey(model.language, "watch.no.wake.word.outside.the.app.apple.will")
        }
    }
}

private struct DJConnectWatchAskDJNotificationPermissionView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [watchAccentPurple, watchAccentPurple.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(watchLocalizedKey(model.language, "ui.ask.dj.notifications"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(watchLocalizedKey(model.language, "watch.push.notifications.are.only.used.for.djconnect.notifications"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(watchLocalizedKey(model.language, "watch.apple.will.ask.for.permission.next"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.56))
                        .multilineTextAlignment(.center)

                    Button {
                        model.continueAfterAskDJNotificationPermissionExplanation()
                    } label: {
                        Text(watchLocalizedKey(model.language, "watch.continue"))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))

                    Button {
                        model.cancelAskDJNotificationPermissionExplanation()
                    } label: {
                        Text(watchLocalizedKey(model.language, "watch.not.now"))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
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

                    Text(watchLocalizedKey(model.language, "watch.music.control.with.character"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    DJConnectWatchSettingsSection(title: "App") {
                        aboutRow(watchLocalizedKey(model.language, "watch.version"), appVersion)
                        aboutRow(watchLocalizedKey(model.language, "watch.device.name"), model.identity.deviceName)
                        aboutRow("Website", "https://djconnect.dev")
                        aboutRow("Device ID", model.identity.deviceID)
                    }

                    DJConnectWatchSettingsSection(title: watchLocalizedKey(model.language, "watch.connection")) {
                        aboutRow("iPhone", model.companionPairingStatus)
                        aboutRow(watchLocalizedKey(model.language, "watch.connection"), "\(watchLocalizedKey(model.language, "watch.through.iphone")), \(connectionModeTitle(model.iPhoneConnectionMode))")
                        aboutRow(
                            watchLocalizedKey(model.language, "ui.backend"),
                            backendTitle,
                            foregroundStyle: model.musicBackendSummary.musicBackendAvailable == false ? Color.red : Color.green
                        )
                        if let target = model.musicBackendSummary.musicTargetPlayer?.name ?? model.musicBackendSummary.musicTargetPlayer?.id {
                            aboutRow(watchLocalizedKey(model.language, "watch.target"), target)
                        }
                        if let error = model.musicBackendSummary.musicBackendError {
                            aboutRow(watchLocalizedKey(model.language, "watch.backend.error"), error, foregroundStyle: .red)
                        }
                    }

                    DJConnectWatchSettingsSection(title: watchLocalizedKey(model.language, "ui.notices")) {
                        aboutRow("Copyright", "2026 Peter van Tol")
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
            }
        }
        .navigationTitle(watchLocalizedKey(model.language, "watch.about"))
    }

    private var backendTitle: String {
        let name = localizedBackendName
        if model.musicBackendSummary.musicBackendAvailable == false {
            return "\(name) \(watchLocalizedKey(model.language, "watch.unavailable"))"
        }
        if let revision = model.musicBackendSummary.musicBackendRevision {
            return "\(name) rev \(revision)"
        }
        return name
    }

    private var localizedBackendName: String {
        let rawName = model.musicBackendSummary.musicBackendName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawBackend = model.musicBackendSummary.musicBackend?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = [rawName, rawBackend].compactMap { $0 }.first { !$0.isEmpty } ?? "unknown"
        return localizedBackendValue(value)
    }

    private func localizedBackendValue(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "", "unknown", "none", "missing", "not_configured", "unconfigured":
            return watchLocalizedKey(model.language, "watch.backend.unknown")
        case "spotify", "spotify_connect", "spotify_direct":
            return "Spotify"
        case "music_assistant", "musicassistant", "music_assistant_player":
            return "Music Assistant"
        case "music_assistant_plus", "musicassistant_plus":
            return "Music Assistant Plus"
        case "demo":
            return watchLocalizedKey(model.language, "watch.demo")
        default:
            return value
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { word in
                    word.prefix(1).uppercased() + word.dropFirst()
                }
                .joined(separator: " ")
        }
    }

    private func connectionModeTitle(_ mode: DJConnectHAConnectionMode) -> String {
        switch mode {
        case .local:
            return watchLocalizedKey(model.language, "watch.local")
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
                    DJConnectWatchLegalSection(title: watchLocalizedKey(model.language, "watch.legal")) {
                        Text(watchLocalizedKey(model.language, "watch.djconnect.is.not.affiliated.with.endorsed.by.or"))
                        Text(watchLocalizedKey(model.language, "watch.spotify.is.a.trademark.of.spotify.ab.home"))
                    }

                    DJConnectWatchLegalSection(title: "OSS") {
                        Text(watchLocalizedKey(model.language, "watch.djconnect.uses.apple.platform.frameworks.and.swift.package"))
                        Text(watchLocalizedKey(model.language, "watch.third.party.notices.are.documented.in.the.repository"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.76))
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalizedKey(model.language, "watch.legal"))
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
                        Text(watchLocalizedKey(model.language, "watch.djconnect.itself.does.not.collect.sell.or.process"))
                        Text(watchLocalizedKey(model.language, "watch.device.tokens.are.stored.locally.in.private.app"))
                        Text(watchLocalizedKey(model.language, "watch.push.notifications.are.only.used.for.djconnect.notifications"))
                        Text(watchLocalizedKey(model.language, "watch.diagnostics.are.only.shared.when.you.copy.them"))
                        Text(watchLocalizedKey(model.language, "watch.music.playback.and.voice.requests.run.through.your"))
                        Text(watchLocalizedKey(model.language, "watch.ai.and.assist.answers.can.be.incorrect.and"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.76))
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalizedKey(model.language, "watch.privacy"))
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
            DJConnect watchOS feedback

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
                        .foregroundStyle(watchIconGradient)

                    Text(watchLocalizedKey(model.language, "watch.share.feedback"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(watchLocalizedKey(model.language, "watch.open.a.github.issue.with.app.context.nothing"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        openURL(feedbackURL)
                    } label: {
                        Label(watchLocalizedKey(model.language, "watch.open.github.issue"), systemImage: "arrow.up.right.square")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(watchLocalizedKey(model.language, "watch.does.opening.not.work.on.the.watch"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(watchLocalizedKey(model.language, "watch.use.this.link.on.iphone.or.mac"))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                        Text("github.com/pcvantol/djconnect/issues/new")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(watchAccentPurple.opacity(0.92))
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
        .navigationTitle(watchLocalizedKey(model.language, "watch.feedback"))
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
            return watchLocalizedKey(model.language, "watch.checking.status")
        }
        if musicDNAEnabled {
            return watchLocalizedKey(model.language, "watch.music.dna.is.enabled")
        }
        if model.musicDNAProfileResponse?.enabled == false {
            return watchLocalizedKey(model.language, "watch.music.dna.is.disabled")
        }
        return watchLocalizedKey(model.language, "watch.status.not.loaded.yet")
    }

    private var musicDNAHowItWorksText: String {
        if musicDNAEnabled {
            return watchLocalizedKey(model.language, "watch.music.dna.is.enabled.home.assistant.can.build.a.private")
        }
        if model.musicDNAProfileResponse?.enabled == false {
            return watchLocalizedKey(model.language, "watch.music.dna.is.disabled.no.profile.is.being.built.and")
        }
        return watchLocalizedKey(model.language, "watch.djconnect.is.still.checking.the.current.music.dna.status")
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DJConnectWatchSettingsSection(title: watchLocalizedKey(model.language, "watch.app")) {
                        Picker(
                            watchLocalizedKey(model.language, "watch.app.language"),
                            selection: Binding(
                                get: { model.appLanguageOverrideCode },
                                set: { model.setAppLanguageOverride($0) }
                            )
                        ) {
                            Text(watchLocalizedKey(model.language, "watch.system.language")).tag("")
                            ForEach(DJConnectLocalization.supportedLanguageCodes, id: \.self) { code in
                                Text(DJConnectLocalization.nativeLanguageName(for: code)).tag(code)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.navigationLink)
                    }

                    if model.isDemoMode {
                        DJConnectWatchSettingsSection(title: watchLocalizedKey(model.language, "watch.mode")) {
                            Text(watchLocalizedKey(model.language, "watch.demo.mode.active"))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                            Button {
                                model.stopDemoMode()
                            } label: {
                                Label(watchLocalizedKey(model.language, "watch.stop.demo"), systemImage: "xmark.circle")
                                    .font(.caption2.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                        }
                    }

                    if !model.isDemoMode {
                        DJConnectWatchSettingsSection(title: watchLocalizedKey(model.language, "watch.pairing")) {
                            Text(watchLocalizedKey(model.language, "watch.reset.watch.pairing.and.pair.again.through.the"))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                            Button(role: .destructive) {
                                isShowingResetPairingConfirmation = true
                            } label: {
                                Label(watchLocalizedKey(model.language, "watch.pair.again"), systemImage: "arrow.triangle.2.circlepath")
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
                                DJConnectWatchCenteredButtonLabel(
                                    title: watchLocalizedKey(model.language, "watch.clear.music.dna"),
                                    systemImage: "trash"
                                )
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
                                    ? watchLocalizedKey(model.language, "watch.turn.off.music.dna")
                                    : watchLocalizedKey(model.language, "watch.turn.on.music.dna"),
                                systemImage: musicDNAEnabled ? "power" : "sparkles"
                            )
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: musicDNAEnabled ? .secondary : .primary))
                        .disabled(model.isLoadingMusicDNA || model.isUpdatingMusicDNA || (!model.canUseBackend && !model.isDemoMode))
                    }

                    DJConnectWatchSettingsSection(title: watchLocalizedKey(model.language, "watch.voice.activation")) {
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

                        Text(watchLocalizedKey(model.language, "watch.stops.automatically.in.the.background.or.during.sleep"))
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
        .navigationTitle(watchLocalizedKey(model.language, "watch.settings"))
        .task {
            await model.refreshMusicDNAProfile()
        }
        .alert(watchLocalizedKey(model.language, "watch.pair.again.9b37ad"), isPresented: $isShowingResetPairingConfirmation) {
            Button(watchLocalizedKey(model.language, "watch.cancel"), role: .cancel) {}
            Button(watchLocalizedKey(model.language, "watch.pair.again"), role: .destructive) {
                model.resetPairing()
                dismiss()
            }
        } message: {
            Text(watchLocalizedKey(model.language, "watch.this.clears.local.watch.pairing.and.opens.the"))
        }
        .alert(watchLocalizedKey(model.language, "watch.turn.off.music.dna.9e036e"), isPresented: $isShowingMusicDNADisableConfirmation) {
            Button(watchLocalizedKey(model.language, "watch.cancel"), role: .cancel) {}
            Button(watchLocalizedKey(model.language, "watch.turn.off"), role: .destructive) {
                Task { await model.setMusicDNAEnabled(false) }
            }
        } message: {
            Text(watchLocalizedKey(model.language, "watch.this.clears.learned.music.dna.on.home.assistant.and.stops"))
        }
        .alert(
            watchLocalizedKey(model.language, "watch.clear.music.dna.3c1f0b"),
            isPresented: $isShowingMusicDNAClearConfirmation
        ) {
            Button(watchLocalizedKey(model.language, "watch.cancel"), role: .cancel) {}
            Button(
                model.isDemoMode
                    ? watchLocalizedKey(model.language, "watch.keep.demo.profile")
                    : watchLocalizedKey(model.language, "watch.clear.music.dna"),
                role: model.isDemoMode ? nil : .destructive
            ) {
                Task { await model.clearMusicDNA() }
            }
        } message: {
            if model.isDemoMode {
                Text(watchLocalizedKey(model.language, "watch.in.the.real.app.this.clears.learned.music.dna.on"))
            } else {
                Text(watchLocalizedKey(model.language, "watch.this.clears.learned.music.dna.if.music.dna.stays.enabled"))
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
                                    colors: [watchAccentPurple, watchAccentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(watchLocalizedKey(model.language, "watch.no.logs"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(watchLocalizedKey(model.language, "watch.new.watch.actions.appear.here"))
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
                Label(watchLocalizedKey(model.language, "watch.clear.logs"), systemImage: "trash")
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
            .disabled(model.diagnosticLogLines.isEmpty)
            .padding(.horizontal, 4)
            .padding(.bottom, 0)
        }
        .navigationTitle("Logs")
        .alert(watchLocalizedKey(model.language, "watch.clear.logs.9f65b0"), isPresented: $isShowingClearConfirmation) {
            Button(watchLocalizedKey(model.language, "watch.cancel"), role: .cancel) {}
            Button(watchLocalizedKey(model.language, "watch.clear.logs"), role: .destructive) {
                model.clearDiagnosticLog()
            }
        } message: {
            Text(watchLocalizedKey(model.language, "watch.this.removes.diagnostic.logs.on.this.watch"))
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
                                        colors: [watchAccentPurple, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(watchLocalizedKey(model.language, "watch.no.output.devices.found"))
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
        .navigationTitle(watchLocalizedKey(model.language, "watch.output"))
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
                .accessibilityLabel(watchLocalizedKey(model.language, "watch.refresh.output"))
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

    private var activeColor: Color {
        watchAccentPurple
    }

    private var activeTextColor: Color {
        watchAccentPurple.opacity(0.92)
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .renderingMode(.template)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isActive ? activeColor : .white.opacity(0.68))
                .foregroundColor(isActive ? activeColor : .white.opacity(0.68))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.18) : Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(output.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    if isActive {
                        Text(watchLocalizedKey(model.language, "watch.active"))
                    } else if let volume = output.volumePercent {
                        Text("\(volume)%")
                    } else {
                        Text(output.type ?? watchLocalizedKey(model.language, "watch.output"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(isActive ? activeTextColor : .white.opacity(0.56))
                .foregroundColor(isActive ? activeTextColor : .white.opacity(0.56))
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .renderingMode(.template)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(activeColor)
                    .foregroundColor(activeColor)
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
                                        colors: [watchAccentPurple, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(watchLocalizedKey(model.language, "watch.no.playlists.found"))
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
        .navigationTitle(watchLocalizedKey(model.language, "watch.playlists"))
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
                .accessibilityLabel(watchLocalizedKey(model.language, "watch.refresh.playlists"))
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
                                        colors: [watchAccentPurple, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(watchLocalizedKey(model.language, "watch.no.queue.found"))
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
        .navigationTitle(watchLocalizedKey(model.language, "watch.queue"))
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
                .accessibilityLabel(watchLocalizedKey(model.language, "watch.refresh.queue"))
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
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let artist = item.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [watchAccentPurple, watchAccentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchPlaylistRow: View {
    let playlist: DJConnectPlaylist
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            DJConnectWatchArtwork(url: playlist.imageURL, fallbackSystemImage: "music.note.list")
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = playlist.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [watchAccentPurple, watchAccentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
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
            .renderingMode(.template)
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(watchAccentPurple.opacity(0.88))
            .foregroundColor(watchAccentPurple.opacity(0.88))
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
                                            colors: [watchAccentPurple, watchAccentPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(watchLocalizedKey(model.language, "watch.ask.something.about.the.music.or.give.your"))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .multilineTextAlignment(.center)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(watchLocalizedKey(model.language, "watch.why.this.track"))
                                    Text(watchLocalizedKey(model.language, "watch.surprise.me.with.new.music"))
                                    Text(watchLocalizedKey(model.language, "watch.give.track.insight"))
                                    Text(watchLocalizedKey(model.language, "watch.play.something.for.cooking"))
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.84))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.white.opacity(0.09))
                                }
                                Text(watchLocalizedKey(model.language, "watch.ask.dj.can.adjust.music.when.you.ask"))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.48))
                                    .multilineTextAlignment(.center)
                                if model.isRequestingAskDJIdleSuggestion {
                                    HStack(spacing: 5) {
                                        ProgressView()
                                            .controlSize(.mini)
                                            .tint(.white)
                                        Text(watchLocalizedKey(model.language, "watch.finding.something"))
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
                                    ? watchLocalizedKey(model.language, "watch.clearing")
                                    : watchLocalizedKey(model.language, "watch.clear.chat"),
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
                                        colors: [watchAccentPurple.opacity(0.96), watchAccentPurple.opacity(0.92)],
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
                .accessibilityLabel(watchLocalizedKey(model.language, "watch.refresh.ask.dj"))
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
            return watchLocalizedKey(model.language, "watch.working")
        case .failed:
            return watchLocalizedKey(model.language, "watch.retry")
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
                        ? watchLocalizedKey(model.language, "watch.dj.fact")
                        : watchLocalizedKey(model.language, "watch.dj.note"))
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
        .overlay {
            RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
                .stroke(bubbleStrokeColor, lineWidth: 1)
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
                    ? watchLocalizedKey(model.language, "watch.stop.audio")
                    : watchLocalizedKey(model.language, "watch.play.audio"))
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
            RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
                .fill(Color(red: 0.06, green: 0.43, blue: 1.00))
        } else if isSystemMessage {
            RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.45, blue: 1.00).opacity(0.34),
                            Color(red: 0.47, green: 0.30, blue: 0.98).opacity(0.26),
                            .white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.49, blue: 0.27),
                            Color(red: 0.74, green: 0.20, blue: 0.77)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var bubbleCornerRadius: CGFloat {
        isSystemMessage ? 13 : 14
    }

    private var bubbleStrokeColor: Color {
        Color.white.opacity(isUser ? 0.12 : isSystemMessage ? 0.14 : 0.18)
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
                                    colors: [watchAccentPurple, watchAccentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(watchLocalizedKey(model.language, "watch.enable.music.dna"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        Text(watchLocalizedKey(model.language, "watch.with.music.dna.djconnect.can.learn.from.your.taste.and"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                        if model.isDemoMode {
                            Text(watchLocalizedKey(model.language, "watch.demo.mode.only.unlocks.fictional.sample.data.on.this.watch"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label(watchLocalizedKey(model.language, "watch.explicit.opt.in"), systemImage: "checkmark.shield")
                            Label(watchLocalizedKey(model.language, "watch.clear.anytime"), systemImage: "trash")
                            Label(watchLocalizedKey(model.language, "watch.can.be.turned.off.in.settings"), systemImage: "switch.2")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))

                        Button {
                            model.acceptMusicDNAOptInPrompt()
                        } label: {
                            Label(
                                model.isUpdatingMusicDNAConsent
                                    ? watchLocalizedKey(model.language, "watch.enabling")
                                    : watchLocalizedKey(model.language, "watch.enable"),
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
                            Text(watchLocalizedKey(model.language, "watch.not.now"))
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
                    Button(watchLocalizedKey(model.language, "watch.close")) {
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
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(watchAccentPurple.opacity(0.88))
                .foregroundColor(watchAccentPurple.opacity(0.88))
        }
    }

    private func buttonLabel(for action: DJConnectAskDJPlaybackAction) -> String {
        for candidate in [action.buttonLabel, action.title] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return action.isOutputAction ? watchLocalizedKey("watch.activate") : "Play Now"
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
                                Color(red: 0.14, green: 0.70, blue: 1.0).opacity(configuration.isPressed ? 0.72 : 0.94),
                                Color(red: 0.38, green: 0.20, blue: 0.96).opacity(configuration.isPressed ? 0.70 : 0.92)
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
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .background(background(isPressed: configuration.isPressed))
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(kind == .primary ? 0.22 : 0.12), lineWidth: 1)
            )
            .shadow(color: shadowColor.opacity(kind == .primary ? 0.32 : 0.18), radius: 8, y: 4)
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
            return djConnectGradientColors
        case .secondary:
            return djConnectGradientColors.map { $0.opacity(0.78) }
        case .destructive:
            return djConnectGradientColors.map { $0.opacity(0.64) }
        case .recording:
            return djConnectGradientColors
        case .processing:
            return djConnectGradientColors.map { $0.opacity(0.88) }
        }
    }

    private var djConnectGradientColors: [Color] {
        [
            Color(red: 0.14, green: 0.70, blue: 1.0),
            Color(red: 0.36, green: 0.22, blue: 0.98),
            Color(red: 0.56, green: 0.20, blue: 0.96)
        ]
    }

    private var foregroundColor: Color {
        switch kind {
        case .destructive:
            return .white
        default:
            return .white
        }
    }

    private var shadowColor: Color {
        switch kind {
        case .primary, .secondary, .destructive:
            return watchAccentPurple
        case .recording:
            return Color(red: 1.0, green: 0.18, blue: 0.38)
        case .processing:
            return Color(red: 1.0, green: 0.48, blue: 0.16)
        }
    }
}
