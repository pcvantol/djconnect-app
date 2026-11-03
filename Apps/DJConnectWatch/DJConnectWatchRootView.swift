import DJConnectCore
import ImageIO
import SwiftUI
import WatchKit

private let watchAccentPurple = Color(red: 0.84, green: 0.18, blue: 1.0)
private let watchAccentBlue = Color(red: 0.12, green: 0.45, blue: 1.0)
private let watchAccentGreen = Color(red: 0.20, green: 0.86, blue: 0.48)
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
    @State private var isShowingNowPlayingArtwork = false
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
                .navigationTitle(model.connectionState == .paired ? "" : "DJConnect")
                .navigationBarTitleDisplayMode(.inline)
        }
        .id(model.watchHomeOpenSequence)
        .tint(.white)
        .buttonStyle(DJConnectWatchStandardButtonStyle())
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
        .sheet(isPresented: $isShowingNowPlayingArtwork) {
            DJConnectWatchArtworkPreviewView(
                artworkURL: model.isDemoMode ? nil : model.playback?.albumImageURL,
                usesDemoArtwork: model.isDemoMode,
                isPlaying: model.playback?.isPlaying == true
            )
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
        case "discover":
            DJConnectWatchDiscoveryView()
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
        DJConnectWatchCompanionPages(model: model, state: model.foregroundSession)
            .task {
                await model.refreshMainScreenStatusIfNeeded()
                if !model.isDemoMode { await model.refreshForegroundSession() }
            }
    }

    private var mainHeader: some View {
        HStack {
            Text("DJConnect")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            Spacer(minLength: 8)

            if model.isOfflineModeActive {
                Label {
                    Text(watchLocalizedKey(model.language, "ui.offline").lowercased())
                } icon: {
                    Image(systemName: "wifi.slash")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.gray.opacity(0.95))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var refreshStatusButton: some View {
        Button {
            if model.isOfflineModeActive {
                model.refreshNetworkAvailability()
            } else {
                Task { await model.refreshStatus() }
            }
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
        .disabled((!model.canUseBackend && !model.isOfflineModeActive) || model.isRefreshingStatus)
        .accessibilityLabel(watchLocalizedKey(model.language, "watch.refresh"))
    }

    private var pairingSuccessView: some View {
        ZStack {
            DJConnectWatchCanvas()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.green)
                Text(watchLocalizedKey(model.language, "watch.apple.watch.paired"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Button {
                    model.dismissPairingSuccess()
                } label: {
                    Text("Let's Rock!")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(DJConnectWatchStandardButtonStyle())
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
    }

    private func setMoodStep(_ index: Int) {
        guard index != model.askDJMoodStepIndex else {
            isMoodControlFocused = false
            return
        }
        model.setAskDJMoodStep(index)
        moodCrownValue = Double(model.askDJMoodStepIndex)
        isMoodControlFocused = false
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
            return "party.popper.fill"
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
                url: model.isDemoMode ? nil : model.playback?.albumImageURL,
                fallbackSystemImage: "music.note",
                usesVinylPlaceholder: model.isDemoMode,
                isPlaying: model.playback?.isPlaying == true
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
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            isShowingNowPlayingArtwork = true
        }
        .accessibilityAddTraits(.isButton)
    }

    fileprivate struct DJConnectWatchTrackInsightView: View {
        @EnvironmentObject private var model: DJConnectWatchModel

        private var insight: TrackInsight {
            if let currentTrackInsight = model.currentTrackInsight {
                return currentTrackInsight
            }
            if model.isDemoMode, let demoInsight = DemoTrackInsightService.localizedDefaultTracks(language: model.language).first {
                return demoInsight
            }
            return TrackInsight(
                title: model.playback?.trackName ?? "Track Insight",
                artist: model.playback?.artistName ?? "DJConnect",
                artwork: model.playback?.albumImageURL,
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
                        DJConnectWatchTrackInsightVisualCard(
                            insight: insight,
                            language: model.language,
                            moodStepIndex: model.askDJMoodStepIndex,
                            isPlaying: model.playback?.isPlaying == true,
                            usesDemoArtwork: model.isDemoMode
                        )
                        .id(trackInsightVisualizerRenderID(for: insight))

                        DJConnectWatchTrackInsightAnalysisCard(insight: insight, language: model.language)
                        if !insight.displayMetrics.isEmpty {
                            DJConnectWatchTrackInsightMetricsGrid(insight: insight, language: model.language)
                        }

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refreshTrackInsight() }
                    } label: {
                        if model.isRefreshingTrackInsight {
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
                    .disabled(model.isRefreshingTrackInsight || (!model.canUseBackend && !model.isDemoMode))
                    .accessibilityLabel(watchLocalizedKey(model.language, "ui.refresh.track.insight"))
                }
            }
        }

        private func trackInsightVisualizerRenderID(for insight: TrackInsight) -> String {
            [
                insight.id,
                insight.title,
                insight.artist,
                insight.visualProfile?.motionStyle?.rawValue ?? "",
                insight.visualProfile?.palette.joined(separator: ",") ?? "",
                String(model.askDJMoodStepIndex),
                String(model.askDJMoodInt)
            ].joined(separator: "|")
        }
    }

    fileprivate struct DJConnectWatchTrackInsightAnalysisCard: View {
        let insight: TrackInsight
        let language: String

        var body: some View {
            VStack(alignment: .leading, spacing: 9) {
                Text(watchLocalizedKey(language, insight.verifiedCredit == nil ? "ui.trackInsight.analysis.title" : "ui.trackInsight.verified_credits"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                if let credit = insight.verifiedCredit {
                    Text(credit.context).font(.caption2).fixedSize(horizontal: false, vertical: true)
                    Link(credit.source.provider + " · " + credit.source.license, destination: credit.source.url)
                        .font(.caption2)
                    Text(watchLocalizedKey(language, "ui.trackInsight.interpretation")).font(.caption.weight(.bold))
                }
                Text(watchNonEmpty(insight.displaySummary(language: language), fallback: watchLocalizedKey(language, "watch.not.enough.signals")))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                if insight.hasUnmeasuredAudio && !insight.hasUnavailableAnalysis {
                    Text(watchLocalizedKey(language, "ui.trackInsight.analysis.unavailable")).font(.caption2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let groups = insight.hasUnavailableAnalysis ? [] : DJConnectWatchTrackInsightGroups.make(for: insight, language: language)
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
            VStack(spacing: 7) {
                if insight.displayMetrics.numericCount > 0 {
                    HStack(spacing: 7) {
                        if let value = insight.displayMetrics.energy {
                            DJConnectWatchTrackInsightMetricRing(title: watchLocalizedKey(language, "watch.energy"), value: value)
                        }
                        if let value = insight.displayMetrics.danceability {
                            DJConnectWatchTrackInsightMetricRing(title: watchLocalizedKey(language, "watch.dance"), value: value)
                        }
                        if let value = insight.displayMetrics.intensity {
                            DJConnectWatchTrackInsightMetricRing(title: watchLocalizedKey(language, "watch.intensity"), value: value)
                        }
                    }
                }

                if insight.displayMetrics.hasLabels {
                    LazyVGrid(columns: columns, spacing: 7) {
                        if let value = insight.displayMetrics.genre {
                            DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.genre"), value: value)
                        }
                        if let value = insight.displayMetrics.mood {
                            DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.mood"), value: value)
                        }
                        if let value = insight.displayMetrics.vibe {
                            DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.vibe"), value: value)
                        }
                        if let value = insight.displayMetrics.texture {
                            DJConnectWatchTrackInsightMetric(title: watchLocalizedKey(language, "watch.texture"), value: value)
                        }
                    }
                }
            }
        }
    }

    private struct DJConnectWatchTrackInsightMetricRing: View {
        let title: String
        let value: Double?

        private var normalizedValue: Double {
            min(1, max(0, value ?? 0))
        }

        private var percentText: String {
            guard let value else { return "-" }
            return "\(Int((min(1, max(0, value)) * 100).rounded()))%"
        }

        var body: some View {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: normalizedValue)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.30, green: 0.63, blue: 1.0),
                                    Color(red: 0.82, green: 0.28, blue: 1.0),
                                    Color(red: 0.23, green: 0.91, blue: 0.84),
                                    Color(red: 0.30, green: 0.63, blue: 1.0)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text(percentText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)
                }
                .frame(width: 52, height: 52)

                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

            return groups
        }
    }

    fileprivate struct DJConnectWatchTrackInsightVisualCard: View {
        let insight: TrackInsight
        let language: String
        let moodStepIndex: Int
        let isPlaying: Bool
        var usesDemoArtwork = false
        var fallbackArtworkURL: URL?

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                DJConnectWatchTrackInsightVisualizer(
                    insight: insight,
                    profile: TrackVibeProfile.make(for: insight)
                        .applyingWatchTrackInsightMoodRenderOverride(stepIndex: moodStepIndex),
                    isPlaying: isPlaying,
                    usesDemoArtwork: usesDemoArtwork,
                    fallbackArtworkURL: fallbackArtworkURL
                )
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
                Text(watchLocalizedKey(language, "ui.trackInsight.visual.decorative"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct DJConnectWatchTrackInsightVisualizer: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let insight: TrackInsight
        let profile: TrackVibeProfile
        let isPlaying: Bool
        var usesDemoArtwork = false
        var fallbackArtworkURL: URL?

        private var shouldAnimate: Bool {
            !reduceMotion && isPlaying
        }

        var body: some View {
            TimelineView(.periodic(from: .now, by: shouldAnimate ? 0.08 : 60)) { timeline in
                let phase = shouldAnimate ? timeline.date.timeIntervalSinceReferenceDate : 0
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let artworkSize = min(width * 0.36, height * 0.36, 62)

                    ZStack {
                        background(phase: phase)
                        lightField(phase: phase)

                        artwork
                            .frame(width: artworkSize, height: artworkSize)
                            .position(x: width / 2, y: height * 0.30)

                        VStack(spacing: 3) {
                            Text(insight.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                            Text(insight.artist)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)
                        }
                        .multilineTextAlignment(.center)
                        .frame(width: width * 0.88)
                        .position(x: width / 2, y: height * 0.61)

                        spectrum(phase: phase)
                            .frame(height: height * 0.28)
                            .padding(.horizontal, 22)
                            .position(x: width / 2, y: height * 0.87)
                    }
                }
            }
        }

        private func background(phase: TimeInterval) -> some View {
            let colors = paletteColors
            return ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.015, green: 0.020, blue: 0.050),
                        (colors.first ?? watchAccentPurple).opacity(0.42),
                        .black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [(colors.last ?? watchAccentGreen).opacity(0.44), .clear],
                    center: UnitPoint(x: 0.22 + 0.26 * sin(phase * 0.22), y: 0.20 + 0.06 * cos(phase * 0.18)),
                    startRadius: 6,
                    endRadius: 150
                )
                RadialGradient(
                    colors: [.white.opacity(0.14), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: 180
                )
                LinearGradient(
                    colors: [.clear, .black.opacity(0.64)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }

        private var artwork: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .blur(radius: 10)
                    .scaleEffect(1.16)

                ZStack {
                    if usesDemoArtwork {
                        AlbumArtworkPlaceholder(tint: watchAccentPurple, isPlaying: isPlaying)
                    } else if let artworkURL = insight.artwork ?? fallbackArtworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                artworkFallback
                            }
                        }
                    } else {
                        artworkFallback
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.30), lineWidth: 1)
                }
                .shadow(color: (paletteColors.last ?? watchAccentPurple).opacity(0.40), radius: 12, x: 0, y: 6)
            }
        }

        private var artworkFallback: some View {
            ZStack {
                profileGradient
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }

        private func lightField(phase: TimeInterval) -> some View {
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let colors = paletteColors
                let density = min(max(profile.particleDensity, 0.12), 0.95)
                let circleCount = Int(8 + density * 12)
                let sparkCount = Int(3 + profile.pulseSpeed * 4)

                for index in 0..<circleCount {
                    let seed = Double(index + 1)
                    let drift = shouldAnimate ? phase * (0.012 + noise(seed, 3) * 0.028) : 0
                    let x = wrap(CGFloat(noise(seed, 0) + drift)) * size.width
                    let y = size.height * CGFloat(0.12 + noise(seed, 1) * 0.58 + sin(phase * 0.15 + seed) * 0.024)
                    let radius = CGFloat(2.0 + density * 4.0 + noise(seed, 4) * 5.0)
                    let color = colors[safe: index % max(colors.count, 1)] ?? watchAccentPurple
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(color.opacity(0.10 + density * 0.08 + noise(seed, 5) * 0.08))
                    )
                }

                for index in 0..<sparkCount {
                    let seed = Double(index + 101)
                    let drift = shouldAnimate ? phase * (0.030 + noise(seed, 2) * 0.038) : 0
                    let x = wrap(CGFloat(noise(seed, 0) + drift)) * size.width
                    let y = wrap(CGFloat(noise(seed, 1) + drift * 0.6)) * size.height
                    let length = CGFloat(10 + profile.glow * 12 + noise(seed, 3) * 14)
                    let tilt = CGFloat(-0.7 + noise(seed, 4) * 1.4)
                    let dx = cos(tilt) * length * 0.5
                    let dy = sin(tilt) * length * 0.5
                    let start = CGPoint(x: x - dx, y: y - dy)
                    let end = CGPoint(x: x + dx, y: y + dy)
                    let color = colors[safe: (index + 2) % max(colors.count, 1)] ?? watchAccentBlue
                    var spark = Path()
                    spark.move(to: start)
                    spark.addLine(to: end)
                    context.stroke(
                        spark,
                        with: .linearGradient(
                            Gradient(colors: [.clear, color.opacity(0.30), .clear]),
                            startPoint: start,
                            endPoint: end
                        ),
                        style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
                    )
                }
            }
            .blur(radius: 0.25)
        }

        private func spectrum(phase: TimeInterval) -> some View {
            GeometryReader { geometry in
                let count = 30
                let spacing: CGFloat = 3
                let barWidth = max(2.2, (geometry.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(0..<count), id: \.self) { index in
                        let normalized = spectrumValue(index: index, count: count, phase: phase)
                        RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                            .fill(barGradient(index: index, count: count))
                            .frame(width: barWidth, height: max(6, geometry.size.height * normalized))
                            .shadow(color: (paletteColors[safe: index % max(paletteColors.count, 1)] ?? watchAccentPurple).opacity(0.26), radius: 5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }

        private func spectrumValue(index: Int, count: Int, phase: TimeInterval) -> CGFloat {
            let spectrum = profile.spectrumProfile.isEmpty ? [0.5] : profile.spectrumProfile
            let base = spectrum[index % spectrum.count]
            let position = Double(index) / Double(max(count - 1, 1))
            let playhead = shouldAnimate ? max(0, 1 - abs(position - wrapDouble(phase * 0.045)) * 7) : 0.34
            let pulse = (sin(Double(index) * 0.55 + phase * profile.pulseSpeed) + 1) * 0.5
            return CGFloat(min(1.0, 0.16 + base * 0.44 + pulse * 0.22 + playhead * 0.22))
        }

        private func barGradient(index: Int, count: Int) -> LinearGradient {
            let progress = Double(index) / Double(max(count - 1, 1))
            let colors = paletteColors
            return LinearGradient(
                colors: [
                    (colors.first ?? watchAccentBlue).opacity(0.74),
                    (colors[safe: 1] ?? watchAccentPurple).opacity(0.82),
                    (colors.last ?? watchAccentGreen).opacity(0.92)
                ],
                startPoint: UnitPoint(x: progress, y: 1),
                endPoint: UnitPoint(x: 1 - progress, y: 0)
            )
        }

        private var paletteColors: [Color] {
            let colors = profile.palette.compactMap { Color(watchHex: $0) }
            return colors.isEmpty ? [watchAccentBlue, watchAccentPurple, watchAccentGreen] : colors
        }

        private var profileGradient: LinearGradient {
            let colors = paletteColors
            return LinearGradient(
                colors: [
                    colors.first ?? watchAccentBlue,
                    colors[safe: 1] ?? watchAccentPurple,
                    colors.last ?? watchAccentGreen
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        private func wrap(_ value: CGFloat) -> CGFloat {
            let remainder = value.truncatingRemainder(dividingBy: 1)
            return remainder < 0 ? remainder + 1 : remainder
        }

        private func wrapDouble(_ value: Double) -> Double {
            let remainder = value.truncatingRemainder(dividingBy: 1)
            return remainder < 0 ? remainder + 1 : remainder
        }

        private func noise(_ seed: Double, _ offset: Double) -> Double {
            let value = sin(seed * 12.9898 + offset * 78.233) * 43_758.5453
            return value - floor(value)
        }
    }

    private struct DJConnectWatchMusicDNAHelixView: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            TimelineView(.periodic(from: .now, by: reduceMotion ? 60 : 1.0 / 24.0)) { timeline in
                Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let rect = CGRect(origin: .zero, size: size)
                    context.fill(
                        Path(rect),
                        with: .linearGradient(
                            Gradient(colors: [
                                Color(red: 0.04, green: 0.06, blue: 0.12),
                                Color(red: 0.18, green: 0.09, blue: 0.32),
                                Color(red: 0.02, green: 0.25, blue: 0.30)
                            ]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )

                    let strandCount = 22
                    for index in 0..<strandCount {
                        let progress = CGFloat(index) / CGFloat(max(strandCount - 1, 1))
                        let y = size.height * (0.13 + progress * 0.74)
                        let phase = Double(progress) * .pi * 4 + time * 0.9
                        let amplitude = size.width * 0.27
                        let centerX = size.width * 0.50
                        let leftX = centerX + CGFloat(sin(phase)) * amplitude
                        let rightX = centerX + CGFloat(sin(phase + .pi)) * amplitude
                        let color = Color(hue: 0.58 + Double(progress) * 0.22, saturation: 0.80, brightness: 1.0)
                        let frontOpacity = 0.62 + (sin(phase) + 1) * 0.16
                        let rearOpacity = 0.50 + (sin(phase + .pi) + 1) * 0.12

                        var connector = Path()
                        connector.move(to: CGPoint(x: leftX, y: y))
                        connector.addLine(to: CGPoint(x: rightX, y: y))
                        context.stroke(
                            connector,
                            with: .color(.white.opacity(0.11)),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round)
                        )

                        context.fill(
                            Path(ellipseIn: CGRect(x: leftX - 3.4, y: y - 3.4, width: 6.8, height: 6.8)),
                            with: .color(color.opacity(frontOpacity))
                        )
                        context.fill(
                            Path(ellipseIn: CGRect(x: rightX - 2.8, y: y - 2.8, width: 5.6, height: 5.6)),
                            with: .color(.white.opacity(rearOpacity))
                        )
                    }
                }
            }
            .accessibilityHidden(true)
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

        @ViewBuilder
        private var header: some View {
            if model.musicDNAProfileResponse?.enabled == true {
                activeHeader
            } else {
                inactiveHeader
            }
        }

        private var activeHeader: some View {
            VStack(alignment: .leading, spacing: 7) {
                Label("Music DNA", systemImage: "heart")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                DJConnectWatchMusicDNAHelixView()
                    .frame(height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    }
                Text(headerText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(DJConnectWatchPanel(cornerRadius: 12))
        }

        private var inactiveHeader: some View {
            VStack(spacing: 10) {
                Image(systemName: "heart")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(watchIconGradient)
                    .frame(width: 52, height: 52)

                Text("Music DNA")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(watchLocalizedKey(model.language, "ui.djconnect.in.your.home.assistant.environment.does.not.build.a"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 142)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.03, blue: 0.13).opacity(0.98),
                        Color(red: 0.10, green: 0.04, blue: 0.22).opacity(0.97),
                        Color(red: 0.11, green: 0.06, blue: 0.26).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
        }

        private var headerText: String {
            watchLocalizedKey(model.language, "ui.with.music.dna.djconnect.can.learn.from.your.taste.and")
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
                Label(watchLocalizedKey(model.language, "ui.music.dna.is.not.enabled"), systemImage: "lock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(watchLocalizedKey(model.language, "ui.enable.music.dna.to.get.recommendations.tailored.to.your.listening"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                Button {
                    model.showMusicDNAOptInPrompt()
                } label: {
                    Label(watchLocalizedKey(model.language, "ui.enable.music.dna.1adf61"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(DJConnectWatchStandardButtonStyle())
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
                .buttonStyle(DJConnectWatchStandardButtonStyle())
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
                    metricPanel(title: watchLocalizedKey(model.language, "watch.genres"), value: names(profile.favoriteGenres ?? []), icon: "music.note.list")
                    metricPanel(title: watchLocalizedKey(model.language, "watch.artists"), value: names(profile.favoriteArtists ?? []), icon: "person.2")
                    metricPanel(title: watchLocalizedKey(model.language, "watch.mood"), value: mood(profile.mood), icon: moodIcon(for: profile.mood?.zone))
                    if let energyProfile = profile.energyProfile {
                        metricPanel(title: watchLocalizedKey(model.language, "ui.energy.profile"), value: energy(energyProfile), icon: "bolt.fill")
                    }
                    if let listeningRhythm = profile.listeningRhythm, listeningRhythm.isDisplayable {
                        metricPanel(title: watchLocalizedKey(model.language, "ui.listening.rhythm"), value: listeningRhythmText(listeningRhythm), icon: "clock")
                    }
                    if let moodMix = profile.moodMix, moodMix.isDisplayable {
                        metricPanel(title: watchLocalizedKey(model.language, "ui.mood.mix"), value: moodMixText(moodMix), icon: moodIcon(for: moodMix.topZone))
                    }
                    if let playtime = profile.playtime, playtime.isDisplayable {
                        metricPanel(title: watchLocalizedKey(model.language, "ui.playtime"), value: playtimeText(playtime), icon: "timer")
                    }
                    if let repeatMagnets = profile.repeatMagnets, repeatMagnets.isDisplayable {
                        metricPanel(title: watchLocalizedKey(model.language, "ui.repeat.magnets"), value: repeatMagnetsText(repeatMagnets), icon: "repeat")
                    }
                    if let explicitPositives = profile.explicitPositives, explicitPositives.isDisplayable {
                        metricPanel(title: watchLocalizedKey(model.language, "ui.explicit.positives"), value: explicitPositivesText(explicitPositives), icon: "hand.thumbsup.fill")
                    }
                    if let tasteAnchors = profile.tasteAnchors, tasteAnchors.isDisplayable {
                        metricPanel(title: watchLocalizedKey(model.language, "ui.taste.anchors"), value: tasteAnchorsText(tasteAnchors), icon: "anchor")
                    }
                    metricPanel(title: watchLocalizedKey(model.language, "watch.recent"), value: tracks(profile.recentTracks ?? []), icon: "clock.arrow.circlepath")
                    if let recentFavorites = profile.recentFavoriteTracks, !recentFavorites.isEmpty {
                        metricPanel(title: watchLocalizedKey(model.language, "ui.recent.favorite.tracks"), value: tracks(recentFavorites), icon: "heart.fill")
                    }
                    metricPanel(title: watchLocalizedKey(model.language, "watch.signals"), value: signals(profile.recommendationSignals ?? []), icon: "slider.horizontal.3")
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

        private func moodIcon(for zone: String?) -> String {
            switch zone?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "chill": "moon.zzz.fill"
            case "groove": "waveform"
            case "energy": "bolt.fill"
            case "party": "party.popper.fill"
            default: "sparkles"
            }
        }

        private func energy(_ energyProfile: DJConnectMusicDNAEnergyProfile) -> String {
            let items = [
                energyProfile.energyPercent.map { "Energy \($0)%" },
                energyProfile.danceabilityPercent.map { "Dans \($0)%" },
                energyProfile.intensityPercent.map { "Intensiteit \($0)%" }
            ]
            .compactMap { $0 }
            return watchNonEmpty(items.joined(separator: ", "), fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func listeningRhythmText(_ rhythm: DJConnectMusicDNAListeningRhythm) -> String {
            let headline = [rhythm.topDaypart, rhythm.topWeekday]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " - ")
            let dayparts = rhythm.dayparts.prefix(2).compactMap { item -> String? in
                guard let label = item.daypart?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else {
                    return nil
                }
                return item.percent.map { "\(label) \(formatPercent($0))" } ?? label
            }
            return watchNonEmpty(([headline] + dayparts).filter { !$0.isEmpty }.joined(separator: ", "), fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func moodMixText(_ moodMix: DJConnectMusicDNAMoodMix) -> String {
            let headline = [
                moodMix.topZone?.trimmingCharacters(in: .whitespacesAndNewlines),
                moodMix.average.map { "Gemiddeld \($0)/100" }
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
            let zones = moodMix.zones.prefix(3).map { zone in
                zone.percent.map { "\(zone.zone) \(formatPercent($0))" } ?? zone.zone
            }
            return watchNonEmpty(([headline] + zones).filter { !$0.isEmpty }.joined(separator: ", "), fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func playtimeText(_ playtime: DJConnectMusicDNAPlaytime) -> String {
            let total = playtime.formattedTotal?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? playtime.formattedTotal!
                : "\(playtime.totalSeconds)s"
            let artists = playtime.visibleTopArtists.prefix(2).map { item in
                [item.name, item.formatted].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
            }
            return watchNonEmpty(([total] + artists).filter { !$0.isEmpty }.joined(separator: ", "), fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func repeatMagnetsText(_ repeatMagnets: DJConnectMusicDNARepeatMagnets) -> String {
            let value = repeatMagnets.visibleItems.prefix(3).map { item in
                if let formatted = item.formatted?.trimmingCharacters(in: .whitespacesAndNewlines), !formatted.isEmpty {
                    return "\(item.name) \(formatted)"
                }
                if let count = item.count {
                    return count == 1 ? "\(item.name) 1 keer" : "\(item.name) \(count) keer"
                }
                return item.name
            }
            .joined(separator: ", ")
            return watchNonEmpty(value, fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func explicitPositivesText(_ positives: DJConnectMusicDNAExplicitPositives) -> String {
            let favorites = positives.visibleFavoriteTracks.prefix(2).map { track in
                [track.title, track.artist].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " - ")
            }
            let recommendations = positives.visibleAcceptedRecommendations.prefix(2).map { item in
                [item.title, item.subtitle].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " - ")
            }
            return watchNonEmpty((favorites + recommendations).filter { !$0.isEmpty }.joined(separator: ", "), fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func tasteAnchorsText(_ anchors: DJConnectMusicDNATasteAnchors) -> String {
            let value = anchors.visibleItems.prefix(4).map { item in
                if let playCount = item.playCount {
                    return playCount == 1 ? "\(item.name) 1 keer" : "\(item.name) \(playCount) keer"
                }
                return item.name
            }
            .joined(separator: ", ")
            return watchNonEmpty(value, fallback: watchLocalizedKey(model.language, "watch.not.enough.signals"))
        }

        private func formatPercent(_ value: Double) -> String {
            if value.rounded() == value {
                return "\(Int(value))%"
            }
            return String(format: "%.1f%%", value)
        }
    }

    private func pairingView(message: String?) -> some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .center, spacing: 9) {
                        DJConnectWatchGlassBrandIcon(size: 34)

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
                    .buttonStyle(DJConnectWatchStandardButtonStyle())
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

/// Watch has its own small-screen presentation target; keep its logo treatment
/// aligned with DJConnectGlassBrandIcon without importing the full phone UI.
private struct DJConnectWatchGlassBrandIcon: View {
    let size: CGFloat
    @Environment(\.watchSessionTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        DJPersonaGraphic(colors: theme.watchColors, highContrast: contrast == .increased, opaque: reduceTransparency)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct DJConnectWatchWelcomeView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(spacing: 11) {
                    DJConnectWatchGlassBrandIcon(size: 44)

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
                    .buttonStyle(DJConnectWatchStandardButtonStyle())
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
                    .buttonStyle(DJConnectWatchStandardButtonStyle())

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
                    .buttonStyle(DJConnectWatchStandardButtonStyle())
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
                    .buttonStyle(DJConnectWatchStandardButtonStyle())

                    Button {
                        model.cancelAskDJNotificationPermissionExplanation()
                    } label: {
                        Text(watchLocalizedKey(model.language, "watch.not.now"))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(DJConnectWatchStandardButtonStyle())
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
        "\(DJConnectApplicationVersion.releaseVersion) (\(DJConnectApplicationVersion.buildVersion))"
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DJConnectWatchGlassBrandIcon(size: 44)
                        .frame(maxWidth: .infinity)

                    Text("DJConnect")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)

                    Text(watchLocalizedKey(model.language, "brand.tagline"))
                        .fixedSize(horizontal: false, vertical: true)
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
                        aboutRow(
                            watchLocalizedKey(model.language, "ui.connection.type"),
                            connectionTypeTitle,
                            foregroundStyle: connectionModeColor
                        )
                        aboutRow(
                            watchLocalizedKey(model.language, "ui.connection.speed"),
                            connectionTransportTitle,
                            foregroundStyle: connectionTransportColor
                        )
                        aboutRow(
                            watchLocalizedKey(model.language, "ui.push.notifications"),
                            pushNotificationStatusTitle,
                            foregroundStyle: pushNotificationStatusColor
                        )
                        aboutRow(
                            watchLocalizedKey(model.language, "ui.music"),
                            musicStatusTitle,
                            foregroundStyle: musicStatusColor
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
                        Link(destination: URL(string: "https://github.com/pcvantol/djconnect")!) {
                            Label("GitHub", systemImage: "arrow.up.right.square")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("about-djconnect-github")
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
            }
        }
        .navigationTitle(watchLocalizedKey(model.language, "watch.about"))
    }

    private var connectionTypeTitle: String {
        [
            watchLocalizedKey(model.language, "watch.through.iphone"),
            connectionModeTitle(model.iPhoneConnectionMode)
        ].joined(separator: ", ")
    }

    private var connectionModeColor: Color {
        switch model.iPhoneConnectionMode {
        case .local:
            return .green
        case .remote:
            return watchAccentPurple
        case .offline:
            return .red
        }
    }

    private var connectionTransportTitle: String {
        switch model.iPhoneConnectionMode {
        case .local, .remote:
            return watchLocalizedKey(model.language, "ui.normal.link.http")
        case .offline:
            return watchLocalizedKey(model.language, "ui.not.active")
        }
    }

    private var connectionTransportColor: Color {
        model.iPhoneConnectionMode == .offline ? .red : .white.opacity(0.82)
    }

    private var pushNotificationStatusTitle: String {
        let status = model.pushNotificationStatus
        switch status.state {
        case .registered:
            if let environment = status.environment {
                return "\(watchLocalizedKey(model.language, "ui.registered")) (\(pushEnvironmentTitle(environment)))"
            }
            return watchLocalizedKey(model.language, "ui.registered")
        case .unavailable:
            return watchLocalizedKey(model.language, "ui.not.supported")
        case .actionNeeded:
            return watchLocalizedKey(model.language, "ui.action.needed")
        case .inactive:
            return watchLocalizedKey(model.language, "ui.not.active")
        }
    }

    private var pushNotificationStatusColor: Color {
        switch model.pushNotificationStatus.state {
        case .registered:
            return .green
        case .unavailable:
            return .white.opacity(0.62)
        case .actionNeeded:
            return .orange
        case .inactive:
            return .white.opacity(0.62)
        }
    }

    private func pushEnvironmentTitle(_ environment: DJConnectPushEnvironment) -> String {
        switch environment {
        case .sandbox:
            return watchLocalizedKey(model.language, "ui.sandbox")
        case .production:
            return watchLocalizedKey(model.language, "ui.production")
        }
    }

    private var musicStatusTitle: String {
        isMusicAvailable
            ? watchLocalizedKey(model.language, "ui.available")
            : watchLocalizedKey(model.language, "ui.unavailable")
    }

    private var musicStatusColor: Color {
        isMusicAvailable ? .green : .red
    }

    private var isMusicAvailable: Bool {
        model.canUseBackend && model.musicBackendSummary.musicBackendAvailable != false
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
                    .buttonStyle(DJConnectWatchStandardButtonStyle())

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
                        DJConnectGlassPreferenceToggle(language: model.language)
                    }

                    DJConnectWatchSettingsSection(title: watchLocalizedKey(model.language, "ui.device_speech.title")) {
                        DeviceSpeechSettingsView(language: model.language, preferences: $model.deviceSpeechPreferences,
                            previewAllowed: model.canPreviewDeviceSpeech, isSpeaking: model.deviceSpeechPreviewIsPlaying,
                            preview: model.previewDeviceSpeech, stop: model.stopDeviceSpeechPreview)
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
                            .buttonStyle(DJConnectWatchStandardButtonStyle())
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
                            .buttonStyle(DJConnectWatchStandardButtonStyle())
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
                            .buttonStyle(DJConnectWatchStandardButtonStyle())
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
                        .buttonStyle(DJConnectWatchStandardButtonStyle())
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
        ZStack {
            DJConnectWatchCanvas()
            VStack(spacing: 8) {
                if model.diagnosticLogLines.isEmpty {
                    Spacer(minLength: 8)
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
                    Spacer(minLength: 8)
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
                            .padding(.top, 2)
                            .padding(.bottom, 6)
                            .padding(.horizontal, 4)
                        }
                        .frame(maxHeight: .infinity)
                        .onAppear {
                            scrollToTop(proxy)
                        }
                        .onChange(of: model.diagnosticLogLines.first?.id) {
                            scrollToTop(proxy)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isShowingClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(model.diagnosticLogLines.isEmpty ? .white.opacity(0.28) : Color(red: 1.0, green: 0.42, blue: 0.54))
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
                .disabled(model.diagnosticLogLines.isEmpty)
                .accessibilityLabel(watchLocalizedKey(model.language, "watch.clear.logs"))
            }
        }
        .alert(watchLocalizedKey(model.language, "watch.clear.logs.9f65b0"), isPresented: $isShowingClearConfirmation) {
            Button(watchLocalizedKey(model.language, "watch.cancel"), role: .cancel) {}
            Button(watchLocalizedKey(model.language, "watch.clear.logs"), role: .destructive) {
                model.clearDiagnosticLog()
            }
        } message: {
            Text(watchLocalizedKey(model.language, "watch.this.removes.diagnostic.logs.on.this.watch"))
        }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        guard let firstID = model.diagnosticLogLines.first?.id else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(firstID, anchor: .top)
            }
        }
    }
}

private struct DJConnectWatchOutputsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var pendingOutput: DJConnectOutputDevice?
    @State private var confirmsTransfer = false

    var body: some View {
        List {
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
                        if model.playback?.isPlaying == true && output.active != true {
                            pendingOutput = output; confirmsTransfer = true
                        } else { Task { await model.selectOutput(output) } }
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
        .listStyle(.plain)
        .watchStandardBackground()
        .navigationTitle(watchLocalizedKey(model.language, "watch.output"))
        .confirmationDialog(watchLocalizedKey(model.language, "watch.v2.transfer.confirm"), isPresented: $confirmsTransfer) {
            Button(pendingOutput?.name ?? "") {
                guard let original = pendingOutput else { return }
                Task { await model.selectOutput(original) }
            }
            Button(watchLocalizedKey(model.language, "ui.cancel"), role: .cancel) { pendingOutput = nil }
        }
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


            VStack(alignment: .leading, spacing: 2) {
                Text(output.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    if isActive {
                        Text(watchLocalizedKey(model.language, "watch.active"))
                    } else if output.isCachedSpotifyOutput {
                        Text(watchLocalizedKey(model.language, "ui.output.recently.seen"))
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
        .padding(.vertical, 8)
    }
}

private struct DJConnectWatchDiscoveryView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    private var sections: [DJConnectMusicDiscoverySection] {
        model.musicDiscoveryResponse?.visibleSections ?? []
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.isLoadingMusicDiscovery && model.musicDiscoveryResponse == nil {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    } else if model.musicDiscoveryResponse?.isMusicDNADisabled == true {
                        discoveryState(
                            title: watchLocalizedKey(model.language, "ui.music.dna.is.not.enabled"),
                            message: watchLocalizedKey(model.language, "ui.enable.music.dna.to.get.recommendations.tailored.to.your.listening"),
                            systemImage: "lock.fill",
                            showsMusicDNAActivation: true
                        )
                    } else if sections.isEmpty {
                        discoveryState(
                            title: watchLocalizedKey(model.language, "ui.discover"),
                            message: model.musicDiscoveryErrorMessage
                                ?? watchLocalizedKey(model.language, "ui.no.discovery.recommendations.available.currently"),
                            systemImage: "sparkles"
                        )
                    } else {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(section.title)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(2)

                                ForEach(section.visibleItems) { item in
                                    NavigationLink {
                                        DJConnectWatchDiscoveryDetailView(sectionID: section.id, item: item)
                                    } label: {
                                        DJConnectWatchDiscoveryRow(
                                            item: item,
                                            isLoading: model.playingMusicDiscoveryItemID == item.id
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if let message = model.musicDiscoveryErrorMessage, !sections.isEmpty {
                        Text(message)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalizedKey(model.language, "ui.discover"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshMusicDiscovery() }
                } label: {
                    if model.isRefreshingMusicDiscovery {
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
                .disabled(model.isRefreshingMusicDiscovery || model.isLoadingMusicDiscovery)
                .accessibilityLabel(watchLocalizedKey(model.language, "ui.refresh.discover"))
            }
        }
        .task {
            await model.loadMusicDiscovery()
            await model.prepareMusicDNAConsentPromptIfNeeded()
        }
    }

    private func discoveryState(
        title: String,
        message: String,
        systemImage: String,
        showsMusicDNAActivation: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(watchAccentPurple)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
            if showsMusicDNAActivation {
                Button {
                    model.showMusicDNAOptInPrompt()
                } label: {
                    Label(watchLocalizedKey(model.language, "ui.enable.music.dna.1adf61"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(DJConnectWatchStandardButtonStyle())
                .disabled(model.isUpdatingMusicDNA)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchDiscoveryDetailView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.dismiss) private var dismiss
    let sectionID: String
    let item: DJConnectMusicDiscoveryItem

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        DJConnectWatchArtwork(
                            url: model.resolvedDiscoveryArtworkURL(item.imageURL),
                            fallbackSystemImage: "sparkles"
                        )
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.68))
                                    .lineLimit(2)
                            }
                            Text(item.kind.rawValue.capitalized)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(watchAccentPurple)
                        }
                    }

                    Text(item.reason)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        Task {
                            await model.playMusicDiscoveryItem(item, sectionID: sectionID)
                            if model.musicDiscoveryErrorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if model.playingMusicDiscoveryItemID == item.id {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                                .frame(maxWidth: .infinity, minHeight: 34)
                        } else {
                            Label(watchLocalizedKey(model.language, "ui.play.now"), systemImage: "play.fill")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                    }
                    .buttonStyle(DJConnectWatchStandardButtonStyle())
                    .disabled(model.playingMusicDiscoveryItemID != nil)

                    if let message = model.musicDiscoveryErrorMessage {
                        Text(message)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(watchLocalizedKey(model.language, "ui.discover"))
    }
}

private struct DJConnectWatchDiscoveryRow: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    let item: DJConnectMusicDiscoveryItem
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            DJConnectWatchArtwork(url: model.resolvedDiscoveryArtworkURL(item.imageURL), fallbackSystemImage: "sparkles")
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
                Text(item.reason)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
                    .padding(.top, 8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
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

    private var subtitle: String? {
        Self.trimmedNonEmpty(item.displaySubtitle)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            DJConnectWatchArtwork(url: item.albumImageURL, fallbackSystemImage: "music.note")
                .frame(width: 34, height: 34)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(3)
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
                    .padding(.top, 4)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

private struct DJConnectWatchPlaylistRow: View {
    let playlist: DJConnectPlaylist
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            DJConnectWatchArtwork(url: playlist.imageURL, fallbackSystemImage: "music.note.list")
                .frame(width: 34, height: 34)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = playlist.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(3)
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
                    .padding(.top, 4)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchArtwork: View {
    let url: URL?
    let fallbackSystemImage: String
    var usesVinylPlaceholder = false
    var isPlaying = false

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

    @ViewBuilder private var fallback: some View {
        if usesVinylPlaceholder {
            AlbumArtworkPlaceholder(tint: watchAccentPurple, isPlaying: isPlaying)
        } else {
            Image(systemName: fallbackSystemImage)
                .renderingMode(.template)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(watchAccentPurple.opacity(0.88))
                .foregroundColor(watchAccentPurple.opacity(0.88))
        }
    }
}

private struct DJConnectWatchArtworkPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let artworkURL: URL?
    var usesDemoArtwork = false
    var isPlaying = false

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()

            GeometryReader { geometry in
                let artworkSize = min(geometry.size.width, geometry.size.height)

                artwork
                    .frame(width: artworkSize, height: artworkSize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .shadow(color: watchAccentPurple.opacity(0.32), radius: 18, y: 8)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            watchAccentPurple.opacity(0.34),
                            watchAccentBlue.opacity(0.22),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    @ViewBuilder private var fallbackArtwork: some View {
        if usesDemoArtwork {
            AlbumArtworkPlaceholder(tint: watchAccentPurple, isPlaying: isPlaying)
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(watchIconGradient)
        }
    }
}

private struct DJConnectWatchAskDJChatView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var toast: String?

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 8) {
                    Button {
                        model.toggleRecording()
                    } label: {
                        Label(voiceButtonTitle, systemImage: voiceButtonIcon)
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchStandardButtonStyle())
                    .disabled(!model.isDemoMode && !model.canUseBackend)

                    if model.isCheckingAskDJHistoryState {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 18)
                    } else if model.askDJMessages.isEmpty && model.transientAskDJMoodMessage == nil {
                        emptyState
                    } else {
                        if let transientMessage = model.transientAskDJMoodMessage {
                            DJConnectWatchAskDJBubble(message: transientMessage)
                                .id(transientMessage.id)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        ForEach(Array(model.askDJMessages.reversed())) { message in
                            DJConnectWatchAskDJBubble(message: message)
                                .id(message.id)
                        }
                    }

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
                    .buttonStyle(DJConnectWatchStandardButtonStyle())
                    .disabled(model.askDJMessages.isEmpty || model.isClearingAskDJHistory)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
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

    private var emptyState: some View {
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

    private var shouldShowGeneratedTextIcon: Bool {
        !isUser
            && !isSystemMessage
            && message.isGeneratedText == true
            && message.textSource?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "fallback"
    }

    private var hasPlayableAudio: Bool {
        guard let audioURL = message.audioURL else {
            return false
        }
        return !audioURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var assistantMood: Int? {
        guard !isUser && !isSystemMessage else {
            return nil
        }
        return max(0, min(100, message.mood ?? model.askDJMoodInt))
    }

    private var assistantMoodColors: [Color]? {
        guard let assistantMood else {
            return nil
        }
        switch assistantMood {
        case ...24:
            return [
                Color(red: 0.24, green: 0.25, blue: 0.63),
                Color(red: 0.38, green: 0.24, blue: 0.58),
                Color(red: 0.58, green: 0.30, blue: 0.48)
            ]
        case 25...59:
            return [
                Color(red: 0.02, green: 0.47, blue: 0.55),
                Color(red: 0.12, green: 0.34, blue: 0.82),
                Color(red: 0.49, green: 0.25, blue: 0.86)
            ]
        case 60...84:
            return [
                Color(red: 0.11, green: 0.45, blue: 1.00),
                Color(red: 0.44, green: 0.28, blue: 0.98),
                Color(red: 0.84, green: 0.18, blue: 0.90)
            ]
        default:
            return [
                Color(red: 1.00, green: 0.46, blue: 0.26),
                Color(red: 0.94, green: 0.20, blue: 0.55),
                Color(red: 0.70, green: 0.18, blue: 0.86)
            ]
        }
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
                    Image(systemName: "info.circle")
                    Text(message.origin == "spotify_playback_context"
                        ? watchLocalizedKey(model.language, "watch.dj.fact")
                        : watchLocalizedKey(model.language, "watch.dj.note"))
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
            }
            if !message.text.isEmpty {
                if shouldShowGeneratedTextIcon {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(watchIconGradient)
                        AskDJWatchRichText(text: message.text, compact: false)
                    }
                } else {
                    AskDJWatchRichText(text: message.text, compact: isSystemMessage)
                }
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
            if !isUser, hasPlayableAudio {
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
        } else if let assistantMoodColors {
            RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            assistantMoodColors[0].opacity(0.82),
                            assistantMoodColors[1].opacity(0.72),
                            assistantMoodColors[2].opacity(0.78),
                            Color.black.opacity(0.20)
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
        if assistantMoodColors != nil {
            return Color.white.opacity(0.24)
        }
        return Color.white.opacity(isUser ? 0.12 : isSystemMessage ? 0.14 : 0.18)
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
                        DJConnectWatchMusicDNAPromptIcon()

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
                            Label(
                                watchLocalizedKey(model.language, "ui.you.can.clear.the.learned.profile.at.any"),
                                systemImage: "trash"
                            )
                            Label(
                                watchLocalizedKey(model.language, "ui.you.can.always.turn.music.dna.off.in"),
                                systemImage: "switch.2"
                            )
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
                        .buttonStyle(DJConnectWatchStandardButtonStyle())
                        .disabled(model.isUpdatingMusicDNAConsent)

                        Button {
                            model.dismissMusicDNAOptInPrompt()
                        } label: {
                            Text(watchLocalizedKey(model.language, "watch.not.now"))
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(DJConnectWatchStandardButtonStyle())
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

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

private struct DJConnectWatchMusicDNAPromptIcon: View {
    var body: some View {
        Image(systemName: "heart")
            .font(.system(size: 38, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(watchIconGradient)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)
            .accessibilityHidden(true)
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
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .top, spacing: 7) {
                            if action.isSaveCurrentTrackControlAction {
                                saveControlIcon(isComplete: action.active == true)
                                    .frame(width: 34, height: 34)
                            } else if action.isOutputAction {
                                outputIcon(isActive: action.isActiveOutputAction)
                                    .frame(width: 34, height: 34)
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
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            } else {
                                fallbackIcon
                                    .frame(width: 34, height: 34)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let subtitle = action.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.66))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else if let reason = action.reason, !reason.isEmpty {
                                    Text(reason)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.66))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(spacing: 5) {
                            Spacer(minLength: 0)
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
                                .minimumScaleFactor(0.72)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 7)
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
        if action.isAskDJMessageAction {
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

private extension EnvironmentValues {
    @Entry var watchSessionTheme: DJConnectSessionMoodTheme = .brand
}

extension DJConnectSessionMoodTheme {
    var watchIcon: String {
        switch self {
        case .brand: "waveform"
        case .chill: "moon.zzz.fill"
        case .groove: "waveform"
        case .energy: "bolt.fill"
        case .party: "party.popper.fill"
        }
    }

    var watchIconGradient: LinearGradient {
        LinearGradient(colors: watchColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var watchColors: [Color] {
        colorValues.map { value in
            Color(red: Double(value >> 16 & 255) / 255, green: Double(value >> 8 & 255) / 255,
                  blue: Double(value & 255) / 255)
        }
    }
}

private struct DJConnectWatchCanvas: View {
    var theme: DJConnectSessionMoodTheme = .brand

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.04, blue: 0.13)
            LinearGradient(colors: zip(theme.watchColors, [0.30, 0.20, 0.32]).map { color, opacity in
                color.opacity(opacity)
            }, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func watchStandardBackground() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background { DJConnectWatchCanvas() }
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

private struct DJConnectWatchStandardButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        let tint = Color(red: 0.71, green: 0.61, blue: 0.86)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let label = configuration.label
            .foregroundStyle(configuration.role == .destructive ? Color.red : Color.white)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.52)
        if #available(watchOS 26, *), glassEnabled && !reduceTransparency {
            label.glassEffect(.regular.tint(tint.opacity(configuration.isPressed ? 0.32 : 0.20)).interactive(),
                              in: shape)
        } else {
            label.background(glassEnabled && !reduceTransparency
                ? tint.opacity(configuration.isPressed ? 0.38 : 0.28)
                : Color(red: 0.34, green: 0.27, blue: 0.45), in: shape)
        }
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
                                Color(red: 0.77, green: 0.18, blue: 1.0).opacity(configuration.isPressed ? 0.72 : 0.96),
                                Color(red: 0.46, green: 0.24, blue: 1.0).opacity(configuration.isPressed ? 0.70 : 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
    }
}

private extension TrackVibeProfile {
    func applyingWatchTrackInsightMoodRenderOverride(stepIndex: Int) -> TrackVibeProfile {
        var copy = self
        let clampedStep = max(0, min(3, stepIndex))
        switch clampedStep {
        case 0:
            copy.palette = ["#4DA3FF", "#7B61FF", "#D184FF"]
            copy.glow = max(0.30, glow * 0.76)
            copy.pulseSpeed = max(0.35, pulseSpeed * 0.70)
            copy.waveform = max(0.20, waveform * 0.72)
            copy.particleDensity = max(0.12, particleDensity * 0.68)
            copy.particleVelocity = max(0.18, particleVelocity * 0.68)
            copy.animationSpeed = max(0.45, animationSpeed * 0.68)
            copy.motionStyle = .dreamy
        case 1:
            copy.palette = ["#2EC4B6", "#7B61FF", "#D184FF"]
            copy.glow = max(0.36, glow * 0.94)
            copy.pulseSpeed = max(0.52, pulseSpeed * 0.90)
            copy.waveform = max(0.32, waveform * 0.94)
            copy.particleDensity = max(0.20, particleDensity * 0.90)
            copy.particleVelocity = max(0.24, particleVelocity * 0.86)
            copy.animationSpeed = max(0.56, animationSpeed * 0.88)
            copy.motionStyle = .balanced
        case 2:
            copy.palette = ["#8AC926", "#FFD166", "#FF6A3D"]
            copy.glow = min(0.95, max(0.46, glow * 1.14))
            copy.pulseSpeed = min(2.2, max(0.72, pulseSpeed * 1.16))
            copy.waveform = min(1.0, max(0.44, waveform * 1.12))
            copy.particleDensity = min(0.92, max(0.28, particleDensity * 1.12))
            copy.particleVelocity = min(1.18, max(0.32, particleVelocity * 1.08))
            copy.animationSpeed = min(1.9, max(0.72, animationSpeed * 1.12))
            copy.motionStyle = .energetic
        default:
            copy.palette = ["#FF2E63", "#A855F7", "#FFD166"]
            copy.glow = min(0.95, max(0.52, glow * 1.24))
            copy.pulseSpeed = min(2.2, max(0.88, pulseSpeed * 1.30))
            copy.waveform = min(1.0, max(0.52, waveform * 1.22))
            copy.particleDensity = min(0.92, max(0.40, particleDensity * 1.24))
            copy.particleVelocity = min(1.18, max(0.40, particleVelocity * 1.16))
            copy.animationSpeed = min(1.9, max(0.84, animationSpeed * 1.22))
            copy.motionStyle = .energetic
        }
        copy.spectrumProfile = copy.spectrumProfile.enumerated().map { index, value in
            let position = Double(index) / Double(max(copy.spectrumProfile.count - 1, 1))
            let lift: Double
            switch clampedStep {
            case 0:
                lift = 0.78 - position * 0.08
            case 1:
                lift = 0.88 + (1.0 - abs(position - 0.5) * 2.0) * 0.18
            case 2:
                lift = 0.96 + position * 0.24
            default:
                lift = 1.02 + sin(position * .pi * 3.0) * 0.20
            }
            return min(1.0, max(0.12, value * lift))
        }
        return copy
    }
}

private struct DJConnectWatchScrollingTitle: View {
    let title: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var textWidth: CGFloat = 0
    @State private var startedAt = Date()

    var body: some View {
        if reduceMotion || dynamicTypeSize.isAccessibilitySize {
            Text(title).fixedSize(horizontal: false, vertical: true)
        } else {
            Text(title).lineLimit(1).hidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    GeometryReader { geometry in
                        let distance = max(0, textWidth - geometry.size.width)
                        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: distance <= 1 || scenePhase != .active)) { clock in
                            Text(title)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
                                .offset(x: -offset(at: clock.date, distance: distance))
                        }
                    }
                }
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { startedAt = Date() }
                }
        }
    }

    private func offset(at date: Date, distance: CGFloat) -> CGFloat {
        guard distance > 1, scenePhase == .active else { return 0 }
        let travel = Double(distance) / 24
        let elapsed = max(0, date.timeIntervalSince(startedAt))
            .truncatingRemainder(dividingBy: 2 * (travel + 1.4))
        if elapsed < travel + 1.4 {
            return min(distance, CGFloat(max(0, elapsed - 1.4) * 24))
        }
        return max(0, distance - CGFloat(max(0, elapsed - travel - 2.8) * 24))
    }
}

/// Existing Watch app, reorganized around one compact home and two secondary pages.
private struct DJConnectWatchCompanionPages: View {
    private static let avatarSize: CGFloat = 60
    @ObservedObject var model: DJConnectWatchModel
    @ObservedObject var state: DJConnectWatchForegroundSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page = 0
    @State private var flowRows: [DJConnectWatchFlowRow]?
    @State private var flowOwner: String?
    @State private var flowSessionID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var crownFocused: Bool
    @State private var flowPosition = 0.0
    @State private var crownPosition = 0.0
    @State private var unseenFlowID: String?
    @GestureState private var holdingVoice = false
    @State private var heldVoice: (generation: UUID, context: DJConnectConversationContext)?
    // Presented outside the conditional pages, so runtime refreshes never replace
    // a question's original context or pop a reader off its original Moment.
    private enum Destination { case text(DJConnectConversationContext), voice(DJConnectConversationContext), moment(DJConnectMoment), flow(DJConnectWatchFlowRow, String, String), notification(DJConnectWatchMomentOpenIntent) }
    @State private var destination: Destination?
    private func text(_ key: String) -> String { watchLocalizedKey(model.language, key) }
    private var snapshot: DJConnectWatchSessionSnapshot? { state.current() }
    private var isLoadingSession: Bool { snapshot == nil && !model.isDemoMode }
    private var session: DJConnectSessionRuntime? { snapshot?.session }
    private var context: DJConnectConversationContext { .init(sessionID: session?.id) }
    private var theme: DJConnectSessionMoodTheme { .init(sessionMood: session?.selectedMood) }
    private var accent: Color { theme.watchColors[1] }
    private var visibleFlowRow: DJConnectWatchFlowRow? {
        guard page == 0, destination == nil, flowPosition > 0 else { return nil }
        let rows = currentFlowRows
        let index = min(Int(flowPosition.rounded()), rows.count)
        return index > 0 ? rows[index - 1] : nil
    }

    var body: some View {
        ZStack {
            if page == 0 && (flowPosition == 0 || currentFlowRows.isEmpty) {
                homeBackground
            } else {
                DJConnectWatchCanvas(theme: page == 0 ? theme : .brand)
            }
            TabView(selection: Binding(get: { page }, set: { next in
                guard page != 0 || flowPosition == 0 || currentFlowRows.isEmpty else { return }
                page = next
            })) {
                more
                    .background { DJConnectWatchCanvas() }
                    .tag(2)
                crownHome.tag(0)
            }
            .tabViewStyle(.page(indexDisplayMode: isLoadingSession && page == 0 ? .never : .automatic))
            .scrollDisabled(visibleFlowRow != nil)
            .highPriorityGesture(
                DragGesture(minimumDistance: 16).onEnded { drag in
                    guard let row = visibleFlowRow else { return }
                    let translation = drag.translation
                    if abs(translation.height) > abs(translation.width) {
                        moveFlowFromSwipe(vertical: translation.height)
                    } else if translation.width >= 16 {
                        openFlowRow(row)
                    }
                },
                including: visibleFlowRow != nil ? .all : .none
            )
        }
        .tint(accent)
        .navigationDestination(isPresented: Binding(get: { destination != nil }, set: { if !$0 { destination = nil } })) {
            switch destination {
            case .text(let context):
                DJConnectWatchCompanionTextView(context: context)
            case .voice(let context):
                DJConnectWatchCompanionVoiceView(context: context).watchStandardBackground()
            case .moment(let moment):
                DJConnectWatchCompanionMomentView(moment: moment, state: state).watchStandardBackground()
            case .flow(let row, let binding, let sessionID):
                flowDetail(row, binding: binding, sessionID: sessionID)
                    .watchStandardBackground()
            case .notification(let intent):
                DJConnectWatchMomentNotificationView(intent: intent, state: state).watchStandardBackground()
            case nil: EmptyView()
            }
        }
        .scrollContentBackground(.hidden)
        .environment(\.watchSessionTheme, theme)
        .navigationTitle(page == 2 ? text("watch.v2.more") : isLoadingSession || session != nil ? "" : "Ask DJ")
        .onChange(of: model.watchHomeOpenSequence) { _, _ in page = 0; flowPosition = 0; destination = nil }
        .onChange(of: model.watchMomentOpenIntent, initial: true) { _, intent in
            if let intent { destination = .notification(intent) }
        }
        .onChange(of: session?.id) { _, _ in flowPosition = 0; unseenFlowID = nil }
        .task(id: page == 0 ? session.map { (snapshot?.settings.binding ?? "") + ":" + $0.id } : nil) {
            guard page == 0, let binding = snapshot?.settings.binding, let sessionID = session?.id else { return }
            if flowOwner != binding || flowSessionID != sessionID {
                flowRows = nil
                flowPosition = 0
            }
            flowOwner = binding
            flowSessionID = sessionID
            while !Task.isCancelled {
                let incoming = await model.loadWatchSessionFlow(binding: binding, sessionID: sessionID)
                guard !Task.isCancelled else { return }
                flowRows = incoming
                let nextExpiry = incoming?.map(\.expiresAt).min()?.timeIntervalSinceNow ?? 15
                do { try await Task.sleep(for: .seconds(max(1, min(15, nextExpiry)))) } catch { return }
            }
        }
        .task {
            guard !model.isDemoMode else { return }
            while !Task.isCancelled {
                await model.refreshForegroundSession()
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
            }
        }
    }
    private var homeBackground: some View {
        ZStack {
            DJConnectWatchCanvas(theme: theme)
            if session != nil, let url = model.playback?.albumImageURL {
                GeometryReader { geometry in
                    AsyncImage(url: url) { phase in
                        if let artwork = phase.image {
                            artwork.resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .overlay {
                                    LinearGradient(colors: [.black.opacity(0.48), .black.opacity(0.56), .black.opacity(0.82)],
                                                   startPoint: .top, endPoint: .bottom)
                                }
                        }
                    }
                    .id(url)
                }
                .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var home: some View {
        if isLoadingSession || (session != nil && !dynamicTypeSize.isAccessibilitySize) {
            ZStack {
                if isLoadingSession {
                    DJConnectWatchGlassBrandIcon(size: Self.avatarSize)
                        .overlay(alignment: .bottom) {
                            ProgressView()
                                .tint(.white)
                                .accessibilityLabel(text(state.failureKey ?? "watch.session.loading"))
                                .alignmentGuide(.bottom) { $0[.top] - 12 }
                        }
                } else {
                    VStack(spacing: 0) {
                        homeHeading
                        Spacer(minLength: 0)
                        homeActions
                    }
                    homePlaybackControls
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 42)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .vertical)
            .accessibilityIdentifier(isLoadingSession ? "watch-session-loading" : "watch-session-home")
        } else if dynamicTypeSize.isAccessibilitySize {
            ScrollView { homeContent.padding(.horizontal, 4) }
        } else {
            homeContent.padding(.horizontal, 4)
        }
    }

    private var homeContent: some View {
        VStack(spacing: 2) {
            homeHeading
            homePlaybackControls
            homeActions
        }
        .accessibilityIdentifier(session == nil ? "watch-general-home" : "watch-session-home")
    }

    @ViewBuilder private var homeHeading: some View {
        if session != nil {
            NavigationLink { DJConnectWatchCompanionTrackView(playback: model.playback, context: context, binding: snapshot?.settings.binding) } label: {
            VStack(alignment: .leading, spacing: 1) {
                let title = model.playback?.trackName ?? "DJConnect"
                DJConnectWatchScrollingTitle(title: title)
                    .font(.caption.weight(.semibold))
                    .id(title)
                if let artist = model.playback?.artistName {
                    Text(artist)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
        } else {
            Text(text("watch.v2.ask.prompt")).font(.caption).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var homePlaybackControls: some View {
        HStack(spacing: 6) {
            if session != nil {
                Button { Task { await model.sendCommand(model.playback?.isPlaying == true ? "pause" : "play") } } label: {
                    Image(systemName: model.playback?.isPlaying == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(text(model.playback?.isPlaying == true ? "watch.pause" : "watch.play"))
            }
            Button {
                destination = .voice(context)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    DJConnectWatchGlassBrandIcon(size: Self.avatarSize)
                    Image(systemName: heldVoice != nil && model.voiceState == .recording ? "stop.fill" : "mic.fill")
                        .font(.caption2).padding(3).background(.regularMaterial, in: Circle())
                }.frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text("watch.v2.speak"))
            .highPriorityGesture(holdToSpeak)
            .onChange(of: holdingVoice) { _, holding in
                guard !holding, let generation = heldVoice?.generation else { return }
                // A completed gesture gets first chance to finish. A cancelled
                // gesture only clears the capture it originally started.
                Task { @MainActor in
                    await Task.yield()
                    if heldVoice?.generation == generation { finishHeldVoice(send: false) }
                }
            }
            .onDisappear { finishHeldVoice(send: false) }
            if session != nil {
                Button { Task { await model.sendCommand("next") } } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(text("watch.next.track"))
            }
        }
    }

    private var holdToSpeak: some Gesture {
        LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($holdingVoice) { value, holding, _ in
                if case .second(true, _) = value { holding = true }
            }
            .onChanged { value in
                guard case .second(true, _) = value, heldVoice == nil,
                      page == 0, flowPosition == 0, destination == nil else { return }
                let original = context
                if let generation = model.beginHeldWatchQuestion(context: original) {
                    heldVoice = (generation, original)
                }
            }
            .onEnded { value in
                guard case .second(true, let drag) = value else {
                    finishHeldVoice(send: false)
                    return
                }
                let offset = drag?.translation ?? .zero
                let canSend = abs(offset.width) < 24 && abs(offset.height) < 24 &&
                    page == 0 && flowPosition == 0 && destination == nil
                if heldVoice == nil && canSend { destination = .voice(context) }
                else { finishHeldVoice(send: canSend) }
            }
    }

    private func finishHeldVoice(send: Bool) {
        guard let heldVoice else { return }
        self.heldVoice = nil
        if model.endHeldWatchQuestion(heldVoice.generation, send: send) {
            destination = .voice(heldVoice.context)
        }
    }

    private var homeActions: some View {
        HStack {
            Button { destination = .text(context) } label: {
                if dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "square.and.pencil").frame(width: 44, height: 44)
                } else {
                    Label(text("watch.v2.text"), systemImage: "square.and.pencil")
                        .font(.caption)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }.accessibilityIdentifier("watch-question-text").accessibilityLabel(text("watch.v2.text"))
            if session != nil {
                NavigationLink { DJConnectWatchCompanionSoundView() } label: {
                    Image(systemName: "speaker.wave.2").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel(text("watch.v2.sound"))
            }
        }.buttonStyle(.plain)
    }

    private var crownHome: some View {
        let acceptsCrown = page == 0 && destination == nil && scenePhase == .active && !currentFlowRows.isEmpty
        return TimelineView(.explicit([Date()] + (flowRows ?? []).map(\.expiresAt).sorted())) { _ in
            let rows = currentFlowRows
            let index = min(Int(flowPosition.rounded()), rows.count)
            let canScroll = page == 0 && destination == nil && !rows.isEmpty
            let transition: AnyTransition = reduceMotion ? .identity : .asymmetric(insertion: .opacity, removal: .identity)
            ZStack {
                if index == 0 {
                    home
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(transition)
                } else {
                    let row = rows[index - 1]
                    flowCard(row, index: index, count: rows.count)
                        .id(row.id)
                        .transition(transition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: flowPosition) { _, value in
                if crownPosition.rounded() != value { crownPosition = value }
            }
            .simultaneousGesture(
                flowSwipe,
                including: canScroll && index == 0 ? .all : .none
            )
            .onChange(of: rows.map(\.id)) { old, new in
                if let unseenFlowID, !new.contains(unseenFlowID) { self.unseenFlowID = nil }
                let previous = Int(flowPosition.rounded())
                guard previous > 0 else { return }
                if !old.isEmpty, let newest = new.first, !old.contains(newest) {
                    unseenFlowID = newest
                }
                if let id = old.indices.contains(previous - 1) ? old[previous - 1] : nil, let current = new.firstIndex(of: id) {
                    flowPosition = Double(current + 1)
                } else {
                    flowPosition = Double(min(previous, new.count))
                }
            }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: moveFlow(to: Double(index + 1), count: rows.count)
                case .decrement: moveFlow(to: Double(index - 1), count: rows.count)
                @unknown default: break
                }
            }
        }
        // Keep the Crown's focus target outside the timeline and card transitions.
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownPosition, from: 0, through: Double(max(1, currentFlowRows.count)), by: 1,
            sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: false
        )
        .onChange(of: crownPosition) { _, value in
            if acceptsCrown { moveFlow(to: value, count: currentFlowRows.count) }
        }
        .defaultFocus($crownFocused, acceptsCrown)
        .task(id: acceptsCrown) {
            guard acceptsCrown else { crownFocused = false; return }
            // Tab and navigation focus settle after the page becomes visible.
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            crownFocused = true
        }
    }

    private var flowSwipe: some Gesture {
        DragGesture(minimumDistance: 20).onEnded { drag in
            let translation = drag.translation
            if abs(translation.height) > abs(translation.width) {
                moveFlowFromSwipe(vertical: translation.height)
            }
        }
    }

    private func moveFlowFromSwipe(vertical: CGFloat) {
        let count = currentFlowRows.count
        let index = min(flowPosition.rounded(), Double(count))
        moveFlow(to: index + (vertical < 0 ? 1 : -1), count: count)
    }

    private var currentFlowRows: [DJConnectWatchFlowRow] {
        guard flowOwner == snapshot?.settings.binding, flowSessionID == session?.id else { return [] }
        let now = Date()
        return (flowRows ?? []).filter { now < $0.expiresAt }
    }

    private func moveFlow(to value: Double, count: Int) {
        let next = min(max(0, value.rounded()), Double(count))
        guard next != flowPosition else { return }
        if next <= 1 { unseenFlowID = nil }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { flowPosition = next }
        if next > 0 { playWatchHaptic(.click, enabled: true) }
    }

    private func flowCard(_ row: DJConnectWatchFlowRow, index: Int, count: Int) -> some View {
        Button { openFlowRow(row) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(text(row.labelKey)).font(.caption.weight(.semibold)).foregroundStyle(accent)
                    Spacer(minLength: 4)
                    if index > 1, unseenFlowID != nil {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                            .foregroundStyle(accent)
                            .accessibilityLabel(text("ui.session.history.new_entries"))
                    }
                    Text("\(index)/\(count)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                Text(row.text.isEmpty ? text("ui.session.history.contribution_unavailable") : row.text)
                    .font(.body).lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(row.date, style: .time).font(.caption2).foregroundStyle(.secondary)
                    if row.spotifyAttribution { flowSpotifyAttribution }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openFlowRow(_ row: DJConnectWatchFlowRow) {
        guard let binding = snapshot?.settings.binding, let session, Date() < row.expiresAt else { return }
        let now = Date()
        let current = session.broadcast.nativeCurrentMoment(at: now, spotifyAttributionAvailable: true)
        let live = [current].compactMap { $0 } + session.broadcast.nativeFlowMoments(at: now)
        if let moment = live.first(where: { $0.id == row.momentID }) {
            destination = .moment(moment)
        } else {
            destination = .flow(row, binding, session.id)
        }
    }

    private var flowSpotifyAttribution: some View {
        Image("SpotifyAttribution").resizable().scaledToFit()
            .frame(width: 54, height: 18).accessibilityLabel("Spotify")
    }

    private func flowDetail(_ row: DJConnectWatchFlowRow, binding: String, sessionID: String) -> some View {
        TimelineView(.explicit([Date(), row.expiresAt])) { _ in
            ScrollView {
                if snapshot?.settings.binding == binding, session?.id == sessionID, Date() < row.expiresAt,
                   flowRows?.contains(where: { $0.id == row.id && $0.text == row.text }) == true {
                    VStack(alignment: .leading, spacing: 8) {
                        if row.labelKey == "ui.session.history.playback", let reference = row.reference {
                            DJConnectWatchFlowArtworkView(reference: reference, binding: binding)
                        }
                        Text(row.text.isEmpty ? text("ui.session.history.contribution_unavailable") : row.text)
                        if row.spotifyAttribution { flowSpotifyAttribution }
                        ForEach(row.sources.indices, id: \.self) { index in
                            let source = row.sources[index]
                            if let url = source.destination {
                                Link(source.attributionLabel, destination: url)
                                    .font(.caption2).accessibilityLabel(source.accessibilityLabel)
                            }
                        }
                        if let reference = row.reference {
                            NavigationLink {
                                DJConnectWatchCompanionTextView(context: .init(sessionID: sessionID, selectedEntry: reference))
                            } label: {
                                Label(text("watch.v2.ask_about"), systemImage: "bubble.left")
                            }
                            .buttonStyle(DJConnectWatchFlatActionRowStyle())
                        }
                    }
                } else {
                    Text(text("ui.session.history.contribution_unavailable")).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(text(row.labelKey))
    }
    private var more: some View {
        List {
            if session != nil {
                NavigationLink {
                    DJConnectWatchSessionView(state: state, settings: model.profileDJSettings, speech: model.sessionSpeech)
                        .watchStandardBackground()
                } label: {
                    Label {
                        Text(text("ui.session.title"))
                    } icon: {
                        DJPersonaMenuSymbol().accessibilityHidden(true)
                    }
                }
            }
            NavigationLink { DJConnectWatchCompanionMusicView() } label: { Label(text("watch.v2.music"), systemImage: "music.note") }
            NavigationLink { DJConnectWatchSessionSpeechSettingsView() } label: { Label(text("watch.v2.voice"), systemImage: "speaker.wave.2") }
            NavigationLink { DJConnectWatchCompanionNotificationsView() } label: { Label(text("watch.v2.notifications"), systemImage: "bell") }
            NavigationLink { DJConnectWatchAboutView() } label: { Label(text("watch.about"), systemImage: "info.circle") }
        }.listStyle(.plain)
    }
}

private struct DJConnectWatchFlowArtworkView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.scenePhase) private var scenePhase
    let reference: DJConnectSessionEntryReference
    let binding: String
    @State private var artwork: (image: CGImage, expiresAt: Date)?

    var body: some View {
        TimelineView(.explicit([Date()] + [artwork?.expiresAt].compactMap { $0 })) { _ in
            if scenePhase == .active, let artwork, artwork.expiresAt > Date() {
                Image(decorative: artwork.image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity)
            }
        }
        .task(id: scenePhase) {
            artwork = nil
            guard scenePhase == .active,
                  let result = await model.loadWatchFlowArtwork(reference, binding: binding),
                  !Task.isCancelled,
                  let source = CGImageSourceCreateWithData(result.jpeg as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            artwork = (image, result.expiresAt)
        }
        .onDisappear { artwork = nil }
    }
}

private struct DJConnectWatchCompanionMomentView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    let moment: DJConnectMoment
    @ObservedObject var state: DJConnectWatchForegroundSession
    private var available: Bool {
        guard let session = state.current()?.session, session.id == moment.sessionID else { return false }
        let original = session.broadcast.nativeCurrentMoment(at: Date(), spotifyAttributionAvailable: true)
        let visible = session.broadcast.nativeFlowMoments(at: Date())
        return ([original].compactMap { $0 } + visible).contains { $0.id == moment.id && $0.content == moment.content }
    }
    var body: some View {
        TimelineView(.explicit(([Date()] + state.displayDeadlines).sorted())) { _ in
        ScrollView {
            if available {
            VStack(alignment: .leading, spacing: 10) {
                Text(moment.content).fixedSize(horizontal: false, vertical: true)
                if moment.sourceAttribution?["provider"] == "Spotify",
                   let url = moment.nativeSourceURLs.first(where: { $0.host == "open.spotify.com" }) {
                    Link(destination: url) {
                        Image("SpotifyAttribution").resizable().scaledToFit().frame(width: 72, height: 24).accessibilityLabel("Spotify")
                    }
                }
                ForEach(moment.nativeSourceURLs.filter { $0.host != "open.spotify.com" }, id: \.absoluteString) { url in
                    Link(url.host ?? "", destination: url).font(.caption2)
                }
                if model.canPlaySessionMoment(moment) {
                    Button { model.playSessionMoment(moment) } label: { Label(watchLocalizedKey(model.language, "watch.v2.listen"), systemImage: "speaker.wave.2") }
                    Button(watchLocalizedKey(model.language, "watch.session.stop_speech")) { model.sessionSpeech.stop() }
                }
                NavigationLink {
                    DJConnectWatchCompanionTextView(context: .init(sessionID: moment.sessionID,
                        selectedMoment: .init(sessionID: moment.sessionID, momentID: moment.id)))
                } label: { Label(watchLocalizedKey(model.language, "watch.v2.ask_about"), systemImage: "bubble.left") }
            }.padding(8)
            } else { Text(watchLocalizedKey(model.language, "ui.session.history.contribution_unavailable")).padding(8) }
        }
        }.navigationTitle(watchLocalizedKey(model.language, "watch.v2.moments"))
        .onDisappear { model.sessionSpeech.stop() }
    }
}
private struct DJConnectWatchCompanionTextView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var text: String
    @State private var context: DJConnectConversationContext
    @State private var sent = false
    @State private var answer: DJConnectWatchAskDJMessage?
    @State private var originalBinding: String?
    @State private var originalEntry: DJConnectHistoryEntry?
    @State private var isResolvingRecording = false
    private let recording: DJConnectWatchOriginalContext?
    init(context: DJConnectConversationContext, initialText: String = "", binding: String? = nil,
         recording: DJConnectWatchOriginalContext? = nil) {
        _context = State(initialValue: context); _text = State(initialValue: initialText)
        _originalBinding = State(initialValue: binding)
        self.recording = recording
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                TextField(watchLocalizedKey(model.language, "watch.v2.text"), text: $text)
                Button(watchLocalizedKey(model.language, "watch.v2.send")) {
                    let selectedContext: DJConnectConversationContext
                    if recording != nil {
                        guard let originalEntry, originalEntry.isRetained() else { return }
                        selectedContext = .init(sessionID: context.sessionID, selectedEntry: originalEntry.reference)
                    } else {
                        selectedContext = context
                    }
                    Task { sent = await model.sendWatchText(text, context: selectedContext, expectedBinding: originalBinding); if sent { answer = model.lastWatchTextReply; text = "" } }
                }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.watchTextPending || model.watchTextOutcomeUnknown ||
                           (recording != nil && originalEntry?.isRetained() != true))
                if isResolvingRecording { ProgressView() }
                if recording != nil && !isResolvingRecording && originalEntry?.isRetained() != true {
                    Text(watchLocalizedKey(model.language, "ui.session.history.contribution_unavailable")).font(.caption)
                }
                if model.watchTextPending { ProgressView() }
                if sent, let answer { Text(answer.text) }
                if model.watchTextOutcomeUnknown {
                    Text(watchLocalizedKey(model.language, "watch.session.check_outcome"))
                    Button(watchLocalizedKey(model.language, "ui.refresh")) {
                        Task { await model.checkWatchTextOutcome(); if !model.watchTextOutcomeUnknown { answer = model.lastWatchTextReply; sent = true; text = "" } }
                    }
                    Button(watchLocalizedKey(model.language, "watch.v2.question.new")) {
                        model.beginNewWatchTextTurn(); text = ""; answer = nil; sent = false
                    }
                }
            }.padding(8)
        }
        .watchStandardBackground()
        .navigationTitle("Ask DJ")
        .task {
            if originalBinding == nil { originalBinding = model.foregroundSession.current()?.settings.binding }
            if let recording {
                isResolvingRecording = true
                originalEntry = await model.loadOriginalHistoryEntry(recording, isMoment: false)
                isResolvingRecording = false
            }
        }
    }
}
private struct DJConnectWatchCompanionVoiceView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var context: DJConnectConversationContext
    init(context: DJConnectConversationContext) { _context = State(initialValue: context) }
    private var isRecording: Bool { if case .recording = model.voiceState { return true }; return false }
    private var isPending: Bool { if case .processing = model.voiceState { return true }; return false }
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                DJConnectWatchGlassBrandIcon(size: 64)
                Text(model.statusMessage).font(.caption).multilineTextAlignment(.center).lineLimit(3)
                if isPending { ProgressView() }
                Button { model.toggleWatchQuestionRecording(context: context) } label: {
                    Label(watchLocalizedKey(model.language, isRecording ? "watch.v2.stop_send" : "watch.v2.speak"),
                          systemImage: isRecording ? "stop.fill" : "mic.fill")
                }.disabled(!model.canUseBackend || isPending)
                if isRecording { Button(watchLocalizedKey(model.language, "ui.cancel")) { model.cancelWatchQuestionRecording() } }
            }
            .padding(.bottom, 8)
        }
        .navigationTitle("Ask DJ")
        .onDisappear { model.cancelWatchQuestionRecording() }
    }
}
private struct DJConnectWatchCompanionMusicView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    var body: some View {
        List {
            NavigationLink { DJConnectWatchQueueView() } label: {
                Label(watchLocalizedKey(model.language, "watch.queue"), systemImage: "list.number")
            }
            NavigationLink { DJConnectWatchPlaylistsView() } label: {
                Label(watchLocalizedKey(model.language, "watch.playlists"), systemImage: "music.note.list")
            }
            NavigationLink { DJConnectWatchDiscoveryView() } label: {
                Label(watchLocalizedKey(model.language, "ui.discover"), systemImage: "sparkles")
            }
            NavigationLink { DJConnectWatchCompanionSoundView() } label: {
                Label(watchLocalizedKey(model.language, "watch.v2.sound"), systemImage: "speaker.wave.2")
            }
        }
        .watchStandardBackground()
        .navigationTitle(watchLocalizedKey(model.language, "watch.v2.music"))
    }
}
private struct DJConnectWatchFlatActionRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 12)
            .background(.white.opacity(configuration.isPressed ? 0.20 : 0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
    }
}

private struct DJConnectWatchCompanionTrackView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.watchSessionTheme) private var theme
    @State private var original: DJConnectPlayback?
    @State private var progressObservedAt = Date()
    @State private var controlsVisit: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var context: DJConnectConversationContext
    @State private var originalBinding: String?
    init(playback: DJConnectPlayback?, context: DJConnectConversationContext, binding: String?) {
        _original = State(initialValue: playback)
        _context = State(initialValue: context)
        _originalBinding = State(initialValue: binding)
    }
    private var originalQuestion: String {
        watchLocalizedKey(model.language, "watch.v2.track.question", arguments: original?.trackName ?? "", original?.artistName ?? "")
    }
    private var isPlaying: Bool { model.playback?.isPlaying == true }

    var body: some View {
        AsyncImage(url: original?.albumImageURL) { phase in
            detail(artwork: phase.image)
        }
        .navigationTitle(watchLocalizedKey(model.language, "watch.v2.music"))
        .onReceive(model.$playback) { _ in progressObservedAt = Date() }
        .onAppear { setControlsVisible(true) }
        .task(id: controlsVisit) { [visit = controlsVisit] in
            guard let visit else { return }
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard controlsVisit == visit else { return }
            setControlsVisible(false)
        }
        .onDisappear { controlsVisit = nil }
    }

    private func detail(artwork: Image?) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                trackArtwork(artwork)
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(original?.trackName ?? "").font(.headline)
                        Text(original?.artistName ?? "").foregroundStyle(.secondary)
                        trackTiming
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                }
                .padding(.horizontal, 8)
                VStack(spacing: 6) {
                    if let recording = original?.uri, DJConnectCurrentInsightSubject.isRecordingURI(recording),
                       let binding = originalBinding, let sessionID = context.sessionID {
                        NavigationLink {
                            DJConnectWatchCompanionTextView(context: context, initialText: originalQuestion, binding: binding,
                                recording: .init(binding: binding, sessionID: sessionID, originalID: recording))
                        } label: { Label(watchLocalizedKey(model.language, "watch.v2.ask_about"), systemImage: "bubble.left") }
                    }
                    if model.isDemoMode {
                        NavigationLink {
                            DJConnectWatchRootView.DJConnectWatchTrackInsightView()
                        } label: {
                            Label("Track Insight", systemImage: "waveform.path.ecg")
                        }
                    } else if let recording = original?.uri, DJConnectCurrentInsightSubject.isRecordingURI(recording),
                              let binding = originalBinding {
                        NavigationLink {
                            DJConnectWatchRecordingInsightView(recording: recording, binding: binding,
                                                              session: model.foregroundSession,
                                                              artworkURL: original?.albumImageURL)
                        } label: {
                            Label("Track Insight", systemImage: "waveform.path.ecg")
                        }
                    }
                }
                .buttonStyle(DJConnectWatchFlatActionRowStyle())
            }
            .padding(.bottom, 12)
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .ignoresSafeArea(.container, edges: .vertical)
        .background {
            DJConnectWatchCanvas(theme: theme)
            if let artwork {
                GeometryReader { geometry in
                    artwork.resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .blur(radius: 32, opaque: true)
                        .overlay(.black.opacity(0.58))
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var trackTiming: some View {
        let live = original?.uri != nil && model.playback?.uri == original?.uri ? model.playback : nil
        let timing = live ?? original
        if let progress = timing?.progressMS, let duration = timing?.durationMS, duration > 0 {
            TimelineView(.animation(minimumInterval: 1, paused: live?.isPlaying != true)) { clock in
                let sinceObservation = live?.isPlaying == true ? max(0, clock.date.timeIntervalSince(progressObservedAt)) : 0
                let elapsed = min(Double(duration) / 1000, Double(max(0, progress)) / 1000 + sinceObservation)
                Text("\(trackTime(Int(elapsed))) / \(trackTime(duration / 1000))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func trackTime(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    private func trackArtwork(_ artwork: Image?) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            Button { setControlsVisible(true) } label: {
                Group {
                    if let artwork {
                        artwork.resizable().scaledToFill()
                    } else {
                        AlbumArtworkPlaceholder(tint: watchAccentPurple, isPlaying: isPlaying)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                .overlay {
                    LinearGradient(stops: [.init(color: .black.opacity(0.48), location: 0),
                                           .init(color: .clear, location: 0.32)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(watchLocalizedKey(model.language, "watch.playback.controls"))
            .accessibilityAddTraits(controlsVisit != nil ? [.isSelected] : [])
            .overlay {
                if controlsVisit != nil {
                    Color.black.opacity(0.52).allowsHitTesting(false)
                    artworkControls
                        .padding(.top, 44)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.20, style: .continuous))
        }
        .containerRelativeFrame([.horizontal, .vertical])
    }

    private func setControlsVisible(_ visible: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            controlsVisit = visible ? UUID() : nil
        }
    }

    private var artworkControls: some View {
        let playback = model.playback
        let canSeek = playback?.hasPlayback == true
        let shuffle = playback?.shuffle == true
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                playbackButton(icon: "arrow.counterclockwise", label: "watch.playback.replay") {
                    guard let progress = model.playback?.progressMS else { return }
                    let elapsed = isPlaying ? Int(max(0, Date().timeIntervalSince(progressObservedAt)) * 1_000) : 0
                    await model.sendCommand("seek_relative", value: .int(-max(0, progress + elapsed)))
                }
                .disabled(!canSeek || playback?.progressMS == nil)
                playbackButton(icon: "shuffle", label: "ui.shuffle", selected: shuffle) {
                    await model.sendCommand("set_shuffle", value: .bool(model.playback?.shuffle != true))
                }
                .disabled(!canSeek)
                favoriteButton
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                playbackButton(icon: "backward.end.fill", label: "watch.previous.track") {
                    await model.sendCommand("previous")
                }
                playbackButton(icon: isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "watch.pause" : "watch.play") {
                    await model.sendCommand(isPlaying ? "pause" : "play")
                }
                playbackButton(icon: "forward.end.fill", label: "watch.next.track") {
                    await model.sendCommand("next")
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                playbackButton(icon: "gobackward.15", label: "ui.back.15.seconds") {
                    await model.sendCommand("seek_relative", value: .int(-15_000))
                }
                playbackButton(icon: "goforward.15", label: "ui.forward.15.seconds") {
                    await model.sendCommand("seek_relative", value: .int(15_000))
                }
            }
            .disabled(!canSeek)
        }
        .disabled(!model.canUseBackend && !model.isDemoMode)
    }

    private var favoriteButton: some View {
        let isCurrentTrack = original?.uri != nil && model.playback?.uri == original?.uri
        let isFavorite = isCurrentTrack && model.playback?.currentTrackFavoriteStatus == true

        return Button {
            setControlsVisible(true)
            Task { await model.saveCurrentTrack() }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isFavorite ? watchAccentPurple : .white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isSavingCurrentTrack || !isCurrentTrack)
        .accessibilityLabel(watchLocalizedKey(
            model.language,
            isFavorite ? "watch.remove.from.favorites" : "watch.add.to.favorites"
        ))
    }

    private func playbackButton(icon: String, label: String, selected: Bool = false,
                                action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            setControlsVisible(true)
            Task { await action() }
        } label: {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(selected ? watchAccentPurple : .white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(watchLocalizedKey(model.language, label))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
private struct DJConnectWatchRecordingInsightView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    let recording: String
    let binding: String
    @ObservedObject var session: DJConnectWatchForegroundSession
    let artworkURL: URL?
    @State private var result: (insight: TrackInsight, expiresAt: Date)?
    @State private var isLoading = true

    var body: some View {
        TimelineView(.explicit([Date()] + [result?.expiresAt].compactMap { $0 })) { _ in
            ScrollView {
                if isLoading {
                    ProgressView()
                } else if let result, Date() < result.expiresAt, session.current()?.settings.binding == binding {
                    let insight = result.insight
                    VStack(alignment: .leading, spacing: 8) {
                        DJConnectWatchRootView.DJConnectWatchTrackInsightVisualCard(
                            insight: insight,
                            language: model.language,
                            moodStepIndex: model.askDJMoodStepIndex,
                            isPlaying: model.playback?.uri == recording && model.playback?.isPlaying == true,
                            fallbackArtworkURL: artworkURL
                        )
                        DJConnectWatchRootView.DJConnectWatchTrackInsightAnalysisCard(insight: insight, language: model.language)
                    }
                } else {
                    Text(watchLocalizedKey(model.language, "appModel.track.insight.is.unavailable.for.this.track"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .watchStandardBackground()
        .navigationTitle("Track Insight")
        .task {
            result = await model.loadRecordingInsight(recording, binding: binding)
            isLoading = false
        }
        .onChange(of: session.current()?.settings.binding) { _, current in
            if current != binding { result = nil }
        }
    }
}

private struct DJConnectWatchCompanionSoundView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    var body: some View {
        List {
            Text(model.selectedOutput)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            Slider(value: Binding(get: { model.volume }, set: { model.volume = $0 }), in: 0...1)
                .onChange(of: model.volume) { _, _ in model.commitVolume() }
                .disabled(model.playback?.device?.supportsVolume != true)
                .accessibilityLabel(watchLocalizedKey(model.language, "watch.volume"))
                .listRowBackground(Color.clear)
            NavigationLink { DJConnectWatchOutputsView() } label: {
                Text(watchLocalizedKey(model.language, "watch.output"))
            }
        }
        .listStyle(.plain)
        .watchStandardBackground()
        .navigationTitle(watchLocalizedKey(model.language, "watch.v2.sound"))
    }
}

/// Shows only confirmed Mood while the producer's requested Session-only write
/// scope remains unselected. settings3 currently writes Profile + active Session;
/// using it here would silently change the owner's Profile defaults.
struct DJConnectWatchCompanionMoodView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @ObservedObject var state: DJConnectWatchForegroundSession
    @ObservedObject var settings: ProfileDJSettingsModel

    @State private var updateFailed = false

    private let moods: [DJConnectSessionMoodTheme] = [.chill, .groove, .energy, .party]

    var body: some View {
        List {
            if let current = state.current(), let session = current.session,
               settings.response?.binding == current.settings.binding, !current.settings.requiresSelection,
               let revision = session.confirmedMoodRevision {
                ForEach(moods, id: \.self) { option in
                    let mood = option.rawValue
                    Button {
                        guard session.selectedMood != mood else { return }
                        let intent = DJConnectWatchSessionMoodIntent(binding: current.settings.binding,
                            sessionID: session.id, mood: mood, expectedRevision: revision)
                        Task { updateFailed = !(await model.updateSessionMood(intent)) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: option.watchIcon)
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(option.watchIconGradient)
                                .frame(width: 22)
                                .accessibilityHidden(true)
                            Text(watchLocalizedKey(model.language, "ui.session.mood." + mood))
                            Spacer()
                            if session.selectedMood == mood { Image(systemName: "checkmark").accessibilityHidden(true) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(session.selectedMood == mood ? .isSelected : [])
                    .disabled(model.isUpdatingSessionMood || state.isRefreshing || state.isChanging || state.outcomeUnknown ||
                              settings.hasUncertainOperation)
                }
            } else {
                Text(watchLocalizedKey(model.language, "ui.dj_settings.unavailable")).font(.caption).foregroundStyle(.secondary)
            }
            if model.isUpdatingSessionMood { ProgressView() }
            if updateFailed {
                Text(watchLocalizedKey(model.language, "watch.session.check_outcome")).font(.caption)
            }
        }
        .listStyle(.plain)
        .watchStandardBackground()
        .navigationTitle(watchLocalizedKey(model.language, "ui.dj_settings.mood"))
    }
}

/// A locator never grants access. Read only the exact original publication.
private struct DJConnectWatchMomentNotificationView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    let intent: DJConnectWatchMomentOpenIntent
    @ObservedObject var state: DJConnectWatchForegroundSession
    @State private var retained: DJConnectHistoryEntry?
    @State private var originalBinding: String?
    @State private var isLoading = true

    private var original: DJConnectMoment? {
        guard intent.isPending(), let session = state.current()?.session, session.id == intent.sessionID else { return nil }
        let current = session.broadcast.nativeCurrentMoment(at: Date(), spotifyAttributionAvailable: true)
        return ([current].compactMap { $0 } + session.broadcast.nativeFlowMoments(at: Date())).first { $0.id == intent.momentID }
    }

    var body: some View {
        TimelineView(.explicit([Date()] + [retained.flatMap { DJConnectHistoryEntry.date($0.retainedUntil) }].compactMap { $0 })) { _ in
            Group {
                if let original {
                    DJConnectWatchCompanionMomentView(moment: original, state: state)
                } else if isLoading || state.isRefreshing {
                    ProgressView()
                } else if let retained, retained.isRetained(),
                          let originalBinding, state.current()?.settings.binding == originalBinding {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(retained.text ?? "").fixedSize(horizontal: false, vertical: true)
                            if retained.requiresSpotifyAttribution == true {
                                Image("SpotifyAttribution").resizable().scaledToFit()
                                    .frame(width: 72, height: 24).accessibilityLabel("Spotify")
                            }
                            NavigationLink {
                                DJConnectWatchCompanionTextView(context: .init(sessionID: nil, selectedEntry: retained.reference),
                                                               binding: originalBinding)
                            } label: {
                                Label(watchLocalizedKey(model.language, "watch.v2.ask_about"), systemImage: "bubble.left")
                            }
                        }.padding(8)
                    }
                    .navigationTitle(watchLocalizedKey(model.language, "watch.v2.moments"))
                } else {
                    Text(watchLocalizedKey(model.language, "ui.session.history.contribution_unavailable")).padding(8)
                }
            }
        }
        .task(id: intent) {
            retained = nil
            originalBinding = nil
            isLoading = true
            defer { isLoading = false }
            await model.refreshForegroundSession(force: true)
            guard !Task.isCancelled, intent.isPending(), original == nil,
                  let binding = state.current()?.settings.binding else { return }
            originalBinding = binding
            let entry = await model.loadOriginalHistoryEntry(
                .init(binding: binding, sessionID: intent.sessionID, originalID: intent.momentID), isMoment: true)
            if intent.isPending(), !Task.isCancelled { retained = entry }
        }
        .onChange(of: state.current()?.settings.binding) { _, binding in
            if binding != originalBinding { retained = nil }
        }
        .onDisappear { model.clearWatchMomentIntent() }
    }
}

private struct DJConnectWatchCompanionNotificationsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    var body: some View {
        List {
            Toggle(watchLocalizedKey(model.language, "watch.v2.moments"), isOn: $model.watchMomentNotificationsEnabled)
            Text(watchLocalizedKey(model.language, model.watchMomentNotificationPreferenceConfirmed ? "watch.v2.notification.confirmed" : "watch.v2.notification.pending"))
                .font(.caption).foregroundStyle(.secondary)
            Button(watchLocalizedKey(model.language, "watch.v2.notification.permission")) { model.requestWatchNotificationPermission() }
                .buttonStyle(.plain)
        }
        .watchStandardBackground()
        .navigationTitle(watchLocalizedKey(model.language, "watch.v2.notifications"))
    }
}
