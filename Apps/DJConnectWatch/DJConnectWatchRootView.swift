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

    @State private var confirmsPairingRepair = false

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
        .overlay {
            if scenePhase == .active && model.isUpdatingSessionSettings {
                ProgressView()
                    .tint(.white)
                    .padding(10)
                    .background(.black.opacity(0.55), in: Circle())
                    .accessibilityLabel(watchLocalizedKey(model.language, "watch.session.loading"))
                    .allowsHitTesting(false)
            }
        }
        .tint(.white)
        .buttonStyle(DJConnectWatchFlatActionRowStyle())
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
                .interactiveDismissDisabled()
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
            } else if model.needsCompanionPairingRepair && !model.isDemoMode {
                pairingView(message: watchLocalizedKey(model.language, "watch.session.pair_again"), repairing: true)
            } else {
                pairedView
            }
        case .pairing:
            pairingView(message: watchLocalizedKey(model.language, "watch.waiting.for.iphone.to.pair.this.watch.with"), waiting: true)
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
        case "games":
            DJConnectWatchGamesView()
        case "settings":
            DJConnectWatchSettingsView()
        case "about":
            DJConnectWatchAboutView()
        case "legal":
            DJConnectWatchLegalView()
        case "privacy":
            DJConnectWatchPrivacyView()
        case "feedback":
            DJConnectWatchFeedbackView()
        default:
            if screen.hasPrefix("game-"), let game = DJConnectWatchArcadeGame(rawValue: String(screen.dropFirst(5))) {
                DJConnectWatchGameView(game: game, language: model.language)
            } else {
                pairedView
            }
        }
    }
    #endif

    private var pairedView: some View {
        DJConnectWatchCompanionPages(model: model, state: model.foregroundSession)
            .task {
                await model.refreshMainScreenStatusIfNeeded()
                if !model.isDemoMode { await model.refreshForegroundSession() }
            }
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
                .buttonStyle(DJConnectWatchFlatActionRowStyle())
            }
            .padding(.horizontal, watchRowInset)
        }
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
            let fillsPage = model.currentTrackInsight != nil || model.isDemoMode
            ZStack {
                DJConnectWatchCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        DJConnectWatchTrackInsightVisualCard(
                            insight: insight,
                            language: model.language,
                            moodStepIndex: model.askDJMoodStepIndex,
                            isPlaying: model.playback?.isPlaying == true,
                            usesDemoArtwork: model.isDemoMode,
                            fillsPage: fillsPage
                        )
                        .id(trackInsightVisualizerRenderID(for: insight))

                        VStack(alignment: .leading, spacing: 10) {
                            DJConnectWatchTrackInsightAnalysisCard(insight: insight, language: model.language)
                            if !insight.displayMetrics.isEmpty {
                                DJConnectWatchTrackInsightMetricsGrid(insight: insight, language: model.language)
                            }
                        }
                        .padding(.horizontal, fillsPage ? watchRowInset : 0)
                        .padding(.bottom, 8)
                    }
                    .padding(.top, fillsPage ? 0 : 8)
                }
                .ignoresSafeArea(.container, edges: fillsPage ? .all : [])
            }
            .navigationTitle(fillsPage ? "" : "Track Insight")
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
            .padding(watchListItemPadding)
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
            .padding(.horizontal, watchListItemPadding)
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

        var fillsPage = false

        var body: some View {
            if fillsPage {
                visualizer
                    .containerRelativeFrame([.horizontal, .vertical])
                    .clipped()
            } else {
                visualizer
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    }
            }
        }

        private var visualizer: some View {
            DJConnectWatchTrackInsightVisualizer(
                insight: insight,
                profile: TrackVibeProfile.make(for: insight)
                    .applyingWatchTrackInsightMoodRenderOverride(stepIndex: moodStepIndex),
                isPlaying: isPlaying,
                usesDemoArtwork: usesDemoArtwork,
                fallbackArtworkURL: fallbackArtworkURL
            )
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
                let width = geometry.size.width
                let spacing = min(3, width / CGFloat(2 * count - 1))
                let barWidth = (width - CGFloat(count - 1) * spacing) / CGFloat(count)
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
                    .padding(.horizontal, watchRowInset)
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
            .padding(watchListItemPadding)
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
            .padding(.horizontal, watchListItemPadding)
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
                .buttonStyle(DJConnectWatchFlatActionRowStyle())
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
                .buttonStyle(DJConnectWatchFlatActionRowStyle())
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
                    favoriteArtistsPanel(profile.favoriteArtists ?? [])
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

        @ViewBuilder
        private func favoriteArtistsPanel(_ values: [DJConnectMusicDNANameValue]) -> some View {
            let title = watchLocalizedKey(model.language, "ui.favorite.artists")
            let artists = values.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.prefix(3)
            if artists.isEmpty {
                metricPanel(title: title, value: names(values), icon: "person.2")
            } else {
                watchPanel {
                    Label(title, systemImage: "person.2")
                        .font(.caption.weight(.semibold))
                    ForEach(artists) { artist in
                        HStack(spacing: 8) {
                            AsyncImage(url: model.resolvedDiscoveryArtworkURL(artist.imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable().scaledToFit()
                                        .foregroundStyle(watchAccentPurple)
                                }
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                            Text(artist.name)
                                .font(.caption.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
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
            .padding(watchListItemPadding)
            .background(DJConnectWatchPanel(cornerRadius: 12))
        }

        private func watchPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 8, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(watchListItemPadding)
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

    private func pairingView(message: String?, repairing: Bool = false, waiting: Bool = false) -> some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    VStack(spacing: 6) {
                        DJConnectHeroGlyph(systemImage: "applewatch")
                            .scaleEffect(0.82)
                            .frame(height: 44)
                        Text(watchLocalizedKey(model.language, "watch.pair.djconnect"))
                            .font(.headline.weight(.bold))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                    .padding(.horizontal, watchRowInset)
                    .frame(maxWidth: .infinity)
                    .background(DJConnectWatchPanel(cornerRadius: 12))

                    Text(watchLocalizedKey(model.language, "watch.open.djconnect.on.your.iphone.the.iphone.will.show.apple"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(watchListItemPadding)
                    .background(DJConnectWatchPanel(cornerRadius: 12))

                    if let networkRequirementMessage = model.networkRequirementMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Text(networkRequirementMessage)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "iphone")
                                .accessibilityHidden(true)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.28))
                        .padding(watchListItemPadding)
                        .background(DJConnectWatchPanel(cornerRadius: 12))
                    }

                    pairingValueCard(
                        title: watchLocalizedKey(model.language, "watch.iphone.companion"),
                        value: model.companionPairingStatus,
                        systemImage: model.companionPairingStatus == "Klaar om te koppelen" ? "checkmark.circle" : "iphone",
                        prominent: false
                    )

                    if let message {
                        if waiting {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(watchListItemPadding)
                                .background(DJConnectWatchPanel(cornerRadius: 12))
                        } else {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.58))
                        }
                    }

                    if repairing {
                        Button {
                            confirmsPairingRepair = true
                        } label: {
                            Label(watchLocalizedKey(model.language, "watch.pair.again"), systemImage: "applewatch")
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(DJConnectWatchFlatActionRowStyle())
                    }

                    Button {
                        model.startDemoMode()
                    } label: {
                        Label(watchLocalizedKey(model.language, "watch.demo.mode"), systemImage: "play.circle")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())
                }
                .padding(.vertical, 8)
                .padding(.horizontal, watchRowInset)
            }
        }
        .alert(watchLocalizedKey(model.language, "watch.pair.again.9b37ad"), isPresented: $confirmsPairingRepair) {
            Button(watchLocalizedKey(model.language, "watch.cancel"), role: .cancel) {}
            Button(watchLocalizedKey(model.language, "watch.pair.again"), role: .destructive) {
                model.resetPairing()
            }
        } message: {
            Text(watchLocalizedKey(model.language, "watch.this.clears.local.watch.pairing.and.opens.the"))
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
                    .font(prominent ? .title3.weight(.bold) : .caption2)
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
        .padding(watchListItemPadding)
        .background(DJConnectWatchPanel(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// Watch has its own small-screen presentation target; keep its logo treatment
/// aligned with DJConnectGlassBrandIcon without importing the full phone UI.
private struct DJConnectWatchGlassBrandIcon: View {
    let size: CGFloat
    var winksOnAppear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var winkEyeOpenness: CGFloat?
    @Environment(\.watchSessionTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        DJPersonaGraphic(colors: theme.watchColors, highContrast: contrast == .increased, opaque: reduceTransparency,
                        winkEyeOpenness: winkEyeOpenness)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .task(id: reduceMotion) {
                winkEyeOpenness = nil
                guard winksOnAppear, !reduceMotion else { return }
                do {
                    try await Task.sleep(for: .milliseconds(180))
                    winkEyeOpenness = 1
                    try await Task.sleep(for: .milliseconds(120))
                    withAnimation(.easeInOut(duration: 0.22)) { winkEyeOpenness = 0.28 }
                    try await Task.sleep(for: .milliseconds(420))
                    withAnimation(.easeInOut(duration: 0.28)) { winkEyeOpenness = 1 }
                    try await Task.sleep(for: .milliseconds(400))
                    winkEyeOpenness = nil
                } catch {
                    // The splash may disappear before the wink completes.
                }
            }
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
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())
                }
                .padding(.vertical, watchListItemPadding)
                .padding(.horizontal, watchRowInset)
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
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())

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
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())
                }
                .padding(.vertical, watchListItemPadding)
                .padding(.horizontal, watchRowInset)
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
                    DJConnectHeroGlyph(systemImage: "bell.badge.fill")

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
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())

                    Button {
                        model.cancelAskDJNotificationPermissionExplanation()
                    } label: {
                        Text(watchLocalizedKey(model.language, "watch.not.now"))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())
                }
                .padding(watchListItemPadding)
                .background(DJConnectWatchPanel(cornerRadius: 14))
                .padding(.horizontal, watchRowInset)
                .padding(.vertical, 8)
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
                    VStack(spacing: 10) {
                        DJConnectWatchGlassBrandIcon(size: 44)

                        Text("DJConnect")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        Text(watchLocalizedKey(model.language, "brand.tagline"))
                            .fixedSize(horizontal: false, vertical: true)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(watchListItemPadding)
                    .background(DJConnectWatchPanel(cornerRadius: 12))

                    DJConnectWatchSettingsSection(title: "App") {
                        aboutRow(watchLocalizedKey(model.language, "watch.version"), appVersion)
                        aboutRow(watchLocalizedKey(model.language, "watch.device.name"), model.identity.deviceName)
                        aboutRow("Website", "https://djconnect.dev")
                        aboutRow("Device ID", model.identity.deviceID)
                    }

                    DJConnectWatchSettingsSection(title: watchLocalizedKey(model.language, "watch.connection")) {
                        aboutRow("iPhone", model.companionPairingStatus)
                        if model.isDemoMode {
                            demoConnectionRows
                        } else {
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
                .padding(.vertical, watchListItemPadding)
                .padding(.horizontal, watchRowInset)
            }
        }
        .navigationTitle(watchLocalizedKey(model.language, "watch.about"))
    }

    private var demoConnectionRows: some View {
        let inactive = watchLocalizedKey(model.language, "ui.not.active")
        let muted = Color.white.opacity(0.62)
        return Group {
            aboutRow(watchLocalizedKey(model.language, "ui.connection.status"),
                     watchLocalizedKey(model.language, "ui.connection.combined.demo"),
                     foregroundStyle: watchAccentPurple)
            aboutRow(watchLocalizedKey(model.language, "ui.connection.type"),
                     watchLocalizedKey(model.language, "ui.local.demo.mode"),
                     foregroundStyle: watchAccentPurple)
            aboutRow(watchLocalizedKey(model.language, "ui.connection.transport"),
                     watchLocalizedKey(model.language, "ui.demo"), foregroundStyle: muted)
            aboutRow(watchLocalizedKey(model.language, "ui.connection.address.active"), inactive)
            aboutRow(watchLocalizedKey(model.language, "ui.push.notifications"), inactive, foregroundStyle: muted)
            aboutRow(watchLocalizedKey(model.language, "ui.music"),
                     watchLocalizedKey(model.language, "ui.music.availability.unconfirmed"), foregroundStyle: muted)
        }
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
                .padding(.horizontal, watchRowInset)
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
        .padding(watchListItemPadding)
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
                .padding(.horizontal, watchRowInset)
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
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())

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
                    .padding(watchListItemPadding)
                    .background(DJConnectWatchPanel(cornerRadius: 12))
                }
                .padding(.vertical, watchListItemPadding)
                .padding(.horizontal, watchRowInset)
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
                        .buttonStyle(.plain)
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
                            .buttonStyle(DJConnectWatchFlatActionRowStyle())
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
                            .buttonStyle(DJConnectWatchFlatActionRowStyle())
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
                            .buttonStyle(DJConnectWatchFlatActionRowStyle())
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
                        .buttonStyle(DJConnectWatchFlatActionRowStyle())
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


                }
                .padding(.vertical, 8)
                .padding(.horizontal, watchRowInset)
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
        .padding(watchListItemPadding)
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

private struct DJConnectWatchOutputsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.dismiss) private var dismiss
    @State private var requestedOutputID: String?

    var body: some View {
        DJConnectWatchList {
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
                        Task {
                            let changesOutput = output.active != true
                            if changesOutput { requestedOutputID = output.id }
                            await model.selectOutput(output)
                            if changesOutput, model.availableOutputs.contains(where: { $0.id == output.id && $0.active == true }) {
                                dismiss()
                            }
                        }
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
        .onChange(of: model.availableOutputs.first(where: { $0.active == true })?.id) { _, activeID in
            if let requestedOutputID, activeID == requestedOutputID {
                self.requestedOutputID = nil
                dismiss()
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
                    if !isActive && output.isCachedSpotifyOutput {
                        Text(watchLocalizedKey(model.language, "ui.output.recently.seen"))
                    } else if let volume = isActive ? (model.playback?.volumePercent ?? output.volumePercent) : output.volumePercent {
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
                            .padding(.horizontal, watchListItemPadding)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, watchRowInset)
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
                .buttonStyle(DJConnectWatchFlatActionRowStyle())
                .disabled(model.isUpdatingMusicDNA)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, watchListItemPadding)
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
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                    }
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())
                    .disabled(model.playingMusicDiscoveryItemID != nil)

                    if let message = model.musicDiscoveryErrorMessage {
                        Text(message)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, watchRowInset)
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
        .padding(.horizontal, watchListItemPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(DJConnectWatchFlatRowBackground())
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
                .padding(.horizontal, watchRowInset)
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
                .padding(.horizontal, watchRowInset)
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
        .padding(.horizontal, watchListItemPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(DJConnectWatchFlatRowBackground())
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
        .padding(.horizontal, watchListItemPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(DJConnectWatchFlatRowBackground())
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
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())
                    .disabled(!model.isDemoMode && !model.canUseBackend)

                    if model.isCheckingAskDJHistoryState {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 18)
                    } else if model.askDJMessages.isEmpty {
                        emptyState
                    } else {
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
                    .buttonStyle(DJConnectWatchFlatActionRowStyle())
                    .disabled(model.askDJMessages.isEmpty || model.isClearingAskDJHistory)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, watchRowInset)
            }
            if let toast {
                VStack {
                    Spacer()
                    Label(toast, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, watchListItemPadding)
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
                        .padding(.horizontal, watchRowInset)
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
            .padding(watchListItemPadding)
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
        .padding(.horizontal, watchListItemPadding)
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
        .padding(.horizontal, watchListItemPadding)
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
                        DJConnectHeroGlyph(systemImage: "heart")
                            .frame(maxWidth: .infinity)

                        Text(watchLocalizedKey(model.language, "watch.enable.music.dna"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

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
                        .buttonStyle(DJConnectWatchFlatActionRowStyle())
                        .disabled(model.isUpdatingMusicDNAConsent)

                        Button {
                            model.dismissMusicDNAOptInPrompt()
                        } label: {
                            Text(watchLocalizedKey(model.language, "watch.not.now"))
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(DJConnectWatchFlatActionRowStyle())
                        .disabled(model.isUpdatingMusicDNAConsent)
                    }
                    .padding(watchListItemPadding)
                    .background(DJConnectWatchPanel(cornerRadius: 14))
                    .padding(.horizontal, watchRowInset)
                    .padding(.vertical, 8)
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
                .padding(.horizontal, watchListItemPadding)
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
                    .padding(.horizontal, watchListItemPadding)
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
        .padding(.horizontal, watchListItemPadding)
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
        .padding(watchListItemPadding)
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
        // Small Energy glyphs use the green/lime mood stops; the cyan middle
        // stop otherwise dominates the narrow lightning-bolt silhouette.
        let colors = self == .energy ? watchColors(from: [colorValues[2], colorValues[0]]) : watchColors
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var watchColors: [Color] { watchColors(from: colorValues) }

    var watchHorizonHeroColors: [Color] { watchColors(from: horizonHeroColorValues) }

    private func watchColors(from values: [UInt32]) -> [Color] {
        values.map { value in
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

/// Same outside margin as the queue, shared by lists and scrolling button stacks.
let watchRowInset: CGFloat = 4
/// Content inset inside a list row, button or card; never a second screen margin.
let watchListItemPadding: CGFloat = 8

/// One flat surface shared by native list rows and standalone action buttons.
struct DJConnectWatchFlatRowBackground: View {
    var isPressed = false
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(isPressed ? 0.20 : 0.12))
    }
}

struct DJConnectWatchList<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        List {
            Group(content: content)
                .listRowInsets(.horizontal, watchListItemPadding)
                .listRowBackground(DJConnectWatchFlatRowBackground())
        }
        .listStyle(.plain)
        // The list owns the full-width row surface. Do not inherit the root's
        // standalone button background inside the already inset row content.
        .buttonStyle(.plain)
        .padding(.horizontal, watchRowInset)
    }
}

private struct DJConnectWatchMomentHeading: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    func watchStandardBackground(theme: DJConnectSessionMoodTheme = .brand) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background { DJConnectWatchCanvas(theme: theme) }
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

/// Session modes are paged from home. Flow Moments use their own navigation.
private struct DJConnectWatchCompanionPages: View {
    private static let avatarSize: CGFloat = 60
    @ObservedObject var model: DJConnectWatchModel
    @ObservedObject var state: DJConnectWatchForegroundSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page = 0
    @State private var pageIndicatorVisit: UUID?
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
    private enum Destination { case voice(DJConnectConversationContext), moment(DJConnectMoment), flow(DJConnectWatchFlowRow, String, String), notification(DJConnectWatchMomentOpenIntent), demoFlow(String, DJConnectWatchFlowRow) }
    @State private var destination: Destination?
    private func text(_ key: String) -> String { watchLocalizedKey(model.language, key) }
    private var snapshot: DJConnectWatchSessionSnapshot? { state.current() }
    private struct SessionScope: Equatable {
        let binding: String
        let sessionID: String?
    }
    @State private var confirmedScope: SessionScope?
    @State private var startupGraceElapsed = false
    private var scope: SessionScope? {
        snapshot.map { SessionScope(binding: $0.settings.binding, sessionID: $0.session?.id) }
    }
    private var needsSessionReadback: Bool { snapshot == nil && !model.isDemoMode }
    private var isLoadingSession: Bool {
        needsSessionReadback && confirmedScope == nil && !startupGraceElapsed && !state.unavailable
    }
    private var isWaitingForReadback: Bool { needsSessionReadback && !isLoadingSession }

    private var session: DJConnectSessionRuntime? { snapshot?.session }
    private var demoSession: DJConnectWatchDemoSession? { model.isDemoMode ? model.companionDemoSession : nil }
    private var context: DJConnectConversationContext { .init(sessionID: demoSession?.id ?? session?.id) }
    private var theme: DJConnectSessionMoodTheme { .init(sessionMood: demoSession?.mood ?? session?.selectedMood) }
    private var accent: Color { theme.watchColors[1] }
    private var visibleFlowRow: DJConnectWatchFlowRow? {
        guard page == 0, destination == nil, flowPosition > 0 else { return nil }
        let rows = currentFlowRows
        let index = min(Int(flowPosition.rounded()), rows.count)
        return index > 0 ? rows[index - 1] : nil
    }

    private var mainPageOrder: [Int] {
        if isLoadingSession { return [0] }
        let hasSession = demoSession != nil || (!model.isDemoMode && (scope ?? confirmedScope)?.sessionID != nil)
        return hasSession ? [0, 3, 1, 2] : [0, 2]
    }

    var body: some View {
        ZStack {
            if page == 0 && (flowPosition == 0 || currentFlowRows.isEmpty) {
                homeBackground
            } else {
                DJConnectWatchCanvas(theme: theme)
            }
            // Standard LTR paging: a leftward finger swipe reveals the next
            // page on the right. Flow remains the first, leftmost dot.
            TabView(selection: Binding(get: { mainPageOrder.firstIndex(of: page) ?? 0 }, set: { position in
                guard !isLoadingSession, visibleFlowRow == nil,
                      mainPageOrder.indices.contains(position) else { return }
                page = mainPageOrder[position]
            })) {
                ForEach(Array(mainPageOrder.enumerated()), id: \.element) { position, mainPage in
                    Group {
                        switch mainPage {
                        case 2:
                            more.background { DJConnectWatchCanvas(theme: theme) }
                        case 1:
                            if let demoSession {
                                DJConnectWatchVibeScapeView(mood: demoSession.mood,
                                    family: VibeScapeFamily(persona: demoSession.persona),
                                    isVisible: page == 1 && destination == nil, language: model.language)
                            } else if let session {
                                let family = session.confirmedPersona.map { VibeScapeFamily(persona: $0.selectedPersona) } ?? .neutral
                                DJConnectWatchVibeScapeView(mood: session.selectedMood, family: family,
                                    isVisible: page == 1 && destination == nil, language: model.language)
                                    .id(session.id)
                            } else {
                                sessionReadbackPlaceholder
                            }
                        case 3:
                            if let demoSession {
                                DJConnectWatchDemoHorizonView(session: demoSession, language: model.language,
                                    isVisible: page == 3 && destination == nil)
                            } else if let session, let binding = snapshot?.settings.binding {
                                DJConnectWatchHorizonView(session: session, binding: binding,
                                    isVisible: page == 3 && destination == nil)
                            } else {
                                sessionReadbackPlaceholder
                            }
                        default:
                            crownHome
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .tag(position)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .overlay {
                // Pin the dots to the screen edge, below the home volume control,
                // rather than to the TabView's bottom safe-area boundary.
                GeometryReader { _ in
                    VStack {
                        Spacer(minLength: 0)
                        if !isLoadingSession && visibleFlowRow == nil && mainPageOrder.count > 1 && pageIndicatorVisit != nil {
                            HStack(spacing: 5) {
                                ForEach(mainPageOrder, id: \.self) { mainPage in
                                    Circle()
                                        .fill(Color.white.opacity(page == mainPage ? 1 : 0.3))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .environment(\.layoutDirection, .leftToRight)
                            .padding(.bottom, watchRowInset)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\((mainPageOrder.firstIndex(of: page) ?? 0) + 1) / \(mainPageOrder.count)")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .allowsHitTesting(false)
            }
            .onChange(of: page) { pageIndicatorVisit = UUID() }
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { drag in
                guard visibleFlowRow == nil, abs(drag.translation.width) > abs(drag.translation.height) else { return }
                pageIndicatorVisit = UUID()
            })
            .task(id: pageIndicatorVisit) {
                guard let visit = pageIndicatorVisit else { return }
                do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
                guard pageIndicatorVisit == visit else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { pageIndicatorVisit = nil }
            }
            .scrollDisabled((page == 0 && isLoadingSession) || visibleFlowRow != nil)
            .highPriorityGesture(
                DragGesture(minimumDistance: 16).onEnded { drag in
                    guard let row = visibleFlowRow else { return }
                    let translation = drag.translation
                    if abs(translation.height) > abs(translation.width) {
                        moveFlowFromSwipe(vertical: translation.height)
                    } else if translation.width <= -16 {
                        openFlowRow(row)
                    }
                },
                including: visibleFlowRow != nil ? .all : .subviews
            )
        }
        .tint(accent)
        .navigationDestination(isPresented: Binding(get: { destination != nil }, set: { if !$0 { destination = nil } })) {
            switch destination {
            case .voice(let context):
                DJConnectWatchCompanionVoiceView(context: context, state: state).watchStandardBackground()
            case .moment(let moment):
                DJConnectWatchCompanionMomentView(moment: moment, state: state, speech: model.sessionSpeech).watchStandardBackground(theme: theme)
                    .tint(accent)
            case .flow(let row, let binding, let sessionID):
                flowDetail(row, binding: binding, sessionID: sessionID)
                    .watchStandardBackground(theme: theme)
                    .tint(accent)
            case .notification(let intent):
                DJConnectWatchMomentNotificationView(intent: intent, state: state).watchStandardBackground(theme: theme)
                    .tint(accent)
            case .demoFlow(let id, let row):
                ScrollView {
                    if demoSession?.id == id {
                        VStack(alignment: .leading, spacing: 8) {
                            DJConnectWatchMomentHeading(title: text(row.labelKey), color: accent)
                            if row.labelKey == "ui.session.history.playback" {
                                demoTrackArtwork()
                                    .frame(width: 120, height: 120)
                                    .frame(maxWidth: .infinity)
                            }
                            Text(row.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, watchRowInset)
                    }
                }
                .watchStandardBackground(theme: theme)
                    .tint(accent)
                .navigationTitle("")
            case nil: EmptyView()
            }
        }
        .scrollContentBackground(.hidden)
        .environment(\.watchSessionTheme, theme)
        .navigationTitle(page == 2 ? text("watch.v2.more") : page == 1 || page == 3 || demoSession != nil || needsSessionReadback || session != nil ? "" : "Ask DJ")
        .onChange(of: model.watchHomeOpenSequence) { _, _ in page = 0; flowPosition = 0; destination = nil }
        .onChange(of: model.watchMomentOpenIntent, initial: true) { _, intent in
            if let intent { destination = .notification(intent) }
        }
        .onChange(of: demoSession?.id) { _, _ in
            page = 0; flowPosition = 0; destination = nil
        }
        .onChange(of: scope, initial: true) { _, next in
            guard let next, next != confirmedScope else { return }
            confirmedScope = next
            flowPosition = 0
            unseenFlowID = nil
            if page == 1 || page == 3 || (page == 2 && next.sessionID != nil) { page = 0 }
        }
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
        .task(id: isLoadingSession) {
            guard isLoadingSession else { return }
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            startupGraceElapsed = true
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
            } else if demoSession != nil {
                AlbumArtworkPlaceholder(tint: accent, isPlaying: model.playback?.isPlaying == true)
                    .opacity(0.42)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var sessionReadbackPlaceholder: some View {
        VStack(spacing: 8) {
            if !state.isRefreshing, !model.isUpdatingSessionSettings {
                Text(text(state.failureKey ?? (model.canUseBackend ? "watch.session.retry" : "watch.session.connect_phone")))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                Button(text("watch.refresh")) { Task { await model.refreshForegroundSession(force: true) } }
            } else if !model.isUpdatingSessionSettings {
                ProgressView().accessibilityLabel(text("watch.session.loading"))
            }
        }
        .padding(.horizontal, watchRowInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var home: some View {
        if isWaitingForReadback {
            sessionReadbackPlaceholder
        } else if isLoadingSession || ((session != nil || demoSession != nil) && !dynamicTypeSize.isAccessibilitySize) {
            ZStack {
                if isLoadingSession {
                    DJConnectWatchGlassBrandIcon(size: Self.avatarSize, winksOnAppear: true)
                        .overlay(alignment: .top) {
                            VStack(spacing: 5) {
                                Text("DJConnect").font(.headline.weight(.bold))
                                Text(text("brand.tagline")).font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .alignmentGuide(.top) { $0[.bottom] + 5 }
                        }
                        .overlay(alignment: .bottom) {
                            ProgressView()
                                .tint(.white)
                                .accessibilityLabel(text(state.failureKey ?? "watch.session.loading"))
                                .alignmentGuide(.bottom) { $0[.top] - 5 }
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, watchRowInset)
            .padding(.top, 42)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .vertical)
            .accessibilityIdentifier(isLoadingSession ? "watch-session-loading" : "watch-session-home")
        } else if dynamicTypeSize.isAccessibilitySize {
            ScrollView { homeContent.padding(.horizontal, watchRowInset) }
        } else {
            homeContent.padding(.horizontal, watchRowInset)
        }
    }

    private var homeContent: some View {
        VStack(spacing: 2) {
            homeHeading
            homePlaybackControls
            homeActions
        }
        .accessibilityIdentifier(session == nil && demoSession == nil ? "watch-general-home" : "watch-session-home")
    }

    @ViewBuilder private var homeHeading: some View {
        if session != nil || demoSession != nil {
            NavigationLink { DJConnectWatchCompanionTrackView(playback: model.playback, context: context, binding: snapshot?.settings.binding) } label: {
                trackHeading(title: demoSession?.track ?? model.playback?.trackName ?? "DJConnect",
                             artist: demoSession?.artist ?? model.playback?.artistName,
                             album: demoSession?.album ?? model.playback?.albumName)
            }.buttonStyle(.plain)
        } else {
            Text(text("watch.v2.ask.prompt")).font(.caption).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func trackHeading(title: String, artist: String?, album: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            DJConnectWatchScrollingTitle(title: title)
                .font(.footnote.weight(.semibold))
                .id(title)
            if let artist {
                DJConnectWatchScrollingTitle(title: artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .id(artist)
            }
            if let album = album?.trimmingCharacters(in: .whitespacesAndNewlines), !album.isEmpty {
                DJConnectWatchScrollingTitle(title: album)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .id(album)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var homePlaybackControls: some View {
        HStack(spacing: 6) {
            if session != nil || demoSession != nil {
                Button { Task { await model.sendCommand(model.playback?.isPlaying == true ? "pause" : "play") } } label: {
                    Image(systemName: model.playback?.isPlaying == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(text(model.playback?.isPlaying == true ? "watch.pause" : "watch.play"))
            }
            Button {
                guard !holdingVoice, heldVoice == nil else { return }
                openVoiceComposer()
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    DJConnectWatchGlassBrandIcon(size: Self.avatarSize)
                    Image(systemName: heldVoice != nil && model.voiceState == .recording ? "stop.fill" : "mic.fill")
                        .font(.caption2).padding(3).background(.regularMaterial, in: Circle())
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text("watch.v2.speak"))
            .simultaneousGesture(holdToSpeak)
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
            if session != nil || demoSession != nil {
                Button { Task { await model.sendCommand("next") } } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(text("watch.next.track"))
            }
        }
    }

    private func openVoiceComposer() {
        guard page == 0, visibleFlowRow == nil, destination == nil else { return }
        destination = .voice(context)
    }

    private var holdToSpeak: some Gesture {
        LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($holdingVoice) { value, holding, _ in
                if case .second(true, _) = value { holding = true }
            }
            .onChanged { value in
                guard case .second(true, _) = value, heldVoice == nil,
                      page == 0, visibleFlowRow == nil, destination == nil else { return }
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
                    page == 0 && visibleFlowRow == nil && destination == nil
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

    @ViewBuilder private var homeActions: some View {
        if session != nil || demoSession != nil {
            HStack {
                if session != nil {
                    NavigationLink {
                        more
                            .navigationTitle(text("watch.v2.more"))
                            .watchStandardBackground()
                    } label: {
                        Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(text("watch.v2.more"))
                }

                Spacer(minLength: 0)

                NavigationLink { DJConnectWatchCompanionSoundView() } label: {
                    Image(systemName: "speaker.wave.2").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(text("watch.v2.sound"))
            }
        }
    }

    private var crownHome: some View {
        let acceptsCrown = page == 0 && destination == nil && scenePhase == .active && !isLoadingSession && !currentFlowRows.isEmpty
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
                including: canScroll && index == 0 ? .all : .subviews
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
        .focusable(acceptsCrown)
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
        if let demoSession { return demoSession.rows.filter { Date() < $0.expiresAt } }
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
                .layoutPriority(1)
                Text(row.text.isEmpty ? text("ui.session.history.contribution_unavailable") : row.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                if demoSession != nil, row.labelKey == "ui.session.history.playback" {
                    demoTrackArtwork()
                        .frame(maxWidth: 104, maxHeight: 104)
                        .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
                HStack {
                    Text(row.date, style: .time).font(.caption2).foregroundStyle(.secondary)
                    if row.spotifyAttribution { flowSpotifyAttribution }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, watchRowInset + watchListItemPadding)
            .padding(.top, 42)
            .padding(.bottom, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ignoresSafeArea(.container, edges: .vertical)
    }

    private func demoTrackArtwork() -> some View {
        AlbumArtworkPlaceholder(tint: accent, isPlaying: false)
            .background(DJConnectWatchPanel(cornerRadius: 16))
            .accessibilityHidden(true)
    }

    private func openFlowRow(_ row: DJConnectWatchFlowRow) {
        if let demoSession, Date() < row.expiresAt {
            destination = .demoFlow(demoSession.id, row)
            return
        }
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
                        DJConnectWatchMomentHeading(title: text(row.labelKey), color: accent)
                        if ["ui.session.history.playback", "ui.session.moment.music_announcement"].contains(row.labelKey), let reference = row.reference {
                            DJConnectWatchFlowArtworkView(reference: reference, binding: binding)
                        }
                        Text(row.text.isEmpty ? text("ui.session.history.contribution_unavailable") : row.text)
                            .padding(.vertical, 4)
                        if row.spotifyAttribution { flowSpotifyAttribution }
                        ForEach(row.sources.indices, id: \.self) { index in
                            let source = row.sources[index]
                            if source.destination != nil {
                                Text(source.attributionLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(source.accessibilityLabel)
                            }
                        }
                        if let reference = row.reference {
                            if ["ui.session.moment.generic", "ui.session.moment.music_announcement"].contains(row.labelKey), !row.text.isEmpty {
                                DJConnectWatchRetainedReplayButton(reference: reference, binding: binding, speech: model.sessionSpeech, momentType: row.labelKey == "ui.session.moment.music_announcement" ? "music_announcement" : nil)
                            }
                            NavigationLink {
                                DJConnectWatchCompanionTextView(context: .init(sessionID: sessionID, selectedEntry: reference))
                            } label: {
                                Label(text("watch.v2.ask_about"), systemImage: "bubble.left")
                            }
                            .buttonStyle(DJConnectWatchFlatActionRowStyle())
                        }
                    }
                    .padding(.horizontal, watchRowInset)
                } else {
                    Text(text("ui.session.history.contribution_unavailable")).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("")
    }
    private var more: some View {
        DJConnectWatchList {
            if model.isDemoMode {
                Button(role: .destructive) {
                    model.stopDemoMode()
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "stop.fill")
                            .accessibilityHidden(true)
                        Text(text("ui.stop.demo.mode"))
                    }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("watch-more-stop-demo")
            }
            if session != nil || demoSession != nil {
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
            NavigationLink { DJConnectWatchSessionSpeechSettingsView() } label: {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                        .accessibilityHidden(true)
                    Text(text("watch.v2.voice"))
                }
            }
            NavigationLink { DJConnectWatchCompanionNotificationsView() } label: { Label(text("watch.v2.notifications"), systemImage: "bell") }
            NavigationLink { DJConnectWatchGamesView() } label: {
                Label(text("ui.games"), systemImage: "gamecontroller")
            }
            NavigationLink { DJConnectWatchAboutView() } label: { Label(text("watch.about"), systemImage: "info.circle") }
            NavigationLink { DJConnectWatchLegalView() } label: { Label(text("watch.legal"), systemImage: "doc.text") }
            NavigationLink { DJConnectWatchPrivacyView() } label: { Label(text("watch.privacy"), systemImage: "hand.raised") }
        }
        .listStyle(.plain)
    }
}

private struct DJConnectWatchHorizonCard: View {
    let section: DJConnectSessionForecast.Section
    let language: String

    var body: some View {
        let symbol = ["current": "play.fill", "guidance": "clock", "aim": "target"][section.id]
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                Text(section.title)
                    .accessibilityAddTraits(.isHeader)
            }
            .font(.headline)
            Text(watchLocalizedKey(language, "ui.session.forecast.claim." + section.claim_type))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(section.text)
                .font(.caption)
                .lineSpacing(3)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(watchListItemPadding)
        .background(DJConnectWatchPanel(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch-horizon-" + section.id)
    }

}

private struct DJConnectWatchHorizonHero: View {
    let theme: DJConnectSessionMoodTheme
    let isVisible: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func movingWaves(colors: [Color]) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { clock in
            let cycle = clock.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 9)
            let phase = cycle * 2 * Double.pi / 9
            Canvas { context, size in
                for (index, color) in colors.enumerated() {
                    let band = Double(index)
                    var wave = Path()
                    for sample in 0...40 {
                        let x = Double(sample) / 40
                        let envelope = 0.35 + 0.65 * sin(.pi * x)
                        let y = 0.54 + band * 0.035
                            + sin(x * 4 * .pi + band * 1.15 - phase) * envelope * 0.075
                        let point = CGPoint(x: size.width * x, y: size.height * y)
                        if sample == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
                    }
                    context.stroke(wave, with: .color(color.opacity(0.12)), lineWidth: 3)
                    context.stroke(wave, with: .color(color.opacity(0.30)), lineWidth: 0.75)
                }
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    var body: some View {
        GeometryReader { geometry in
            let artwork = Image("HorizonHero")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
            Group {
                if theme == .brand {
                    artwork
                } else {
                    ZStack {
                        LinearGradient(colors: theme.watchHorizonHeroColors, startPoint: .leading, endPoint: .trailing)
                        artwork.blendMode(.luminosity)
                    }
                    .compositingGroup()
                }
            }
            .overlay {
                if isVisible && scenePhase == .active && !reduceMotion {
                    movingWaves(colors: theme.watchHorizonHeroColors)
                }
            }
            .clipShape(.rect(cornerRadius: 12))
        }
        .frame(height: 58)
        .accessibilityHidden(true)
    }
}

private struct DJConnectWatchDemoHorizonView: View {
    let session: DJConnectWatchDemoSession
    let language: String
    let isVisible: Bool

    private func text(_ key: String) -> String { watchLocalizedKey(language, key) }

    var body: some View {
        let theme = DJConnectSessionMoodTheme(sessionMood: session.mood)
        let sections: [DJConnectSessionForecast.Section] = [
            .init(id: "current", title: text("demo.horizon.current"), claim_type: "current",
                  text: [session.track, session.artist].compactMap { $0 }.joined(separator: " · ")),
            .init(id: "guidance", title: text("demo.horizon.guidance"), claim_type: "intention", text: text("demo.session.direction")),
            .init(id: "aim", title: text("demo.horizon.aim"), claim_type: "conditional_target", text: text("demo.horizon.direction"))
        ]
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                DJConnectWatchHorizonHero(theme: theme, isVisible: isVisible)
                Text(text("ui.session.forecast.title")).font(.headline).accessibilityAddTraits(.isHeader)
                Text(text("demo.horizon.notice")).font(.caption2).foregroundStyle(.secondary)
                ForEach(sections) { section in
                    DJConnectWatchHorizonCard(section: section, language: language)
                }
            }
            .padding(.horizontal, watchRowInset)
        }
        .watchStandardBackground(theme: theme)
    }
}

private struct DJConnectWatchHorizonView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.scenePhase) private var scenePhase
    let session: DJConnectSessionRuntime
    let binding: String
    let isVisible: Bool

    private struct Scope: Equatable {
        let sessionID: String
        let binding: String
        let mood: String
        let moodRevision: Int?
        let locale: String?
        let direction: String
        let persona: Int?
        let presence: Int?
        let item: String?
        let source: String?
        let playbackState: String?
    }

    @State private var cursor: DJConnectForecastCursor?
    @State private var loadedScope: Scope?

    private var scope: Scope {
        Scope(sessionID: session.id, binding: binding, mood: session.selectedMood,
              moodRevision: session.confirmedMoodRevision, locale: session.broadcast.session.locale,
              direction: session.broadcast.planner.currentDirection, persona: session.personaRevisionFloor, presence: session.presenceRevisionFloor,
              item: session.broadcast.playback?.itemID, source: session.broadcast.playback?.sourceURL,
              playbackState: session.broadcast.playback?.state)
    }

    private func text(_ key: String) -> String {
        watchLocalizedKey(model.language, key)
    }

    var body: some View {
        let theme = DJConnectSessionMoodTheme(sessionMood: session.selectedMood)
        let currentScope = scope
        let readScope = isVisible && scenePhase == .active ? currentScope : nil
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                DJConnectWatchHorizonHero(theme: theme, isVisible: isVisible)
                Text(text("ui.session.forecast.title"))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(text("ui.session.forecast.notice"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                TimelineView(.explicit([Date()] + [cursor?.projection?.valid_until]
                    .compactMap { DJConnectSessionForecast.timestamp($0) })) { clock in
                    if readScope == loadedScope, readScope != nil,
                       let forecast = cursor?.visible(playbackItemID: currentScope.item, playbackSource: currentScope.source, at: clock.date),
                       forecast.current_anchor == nil || currentScope.playbackState == "playing" {
                        let sectionOrder = ["current", "guidance", "aim"]
                        VStack(spacing: 8) {
                            ForEach(sectionOrder, id: \.self) { id in
                                if let section = forecast.sections.first(where: { $0.id == id }) {
                                    DJConnectWatchHorizonCard(section: section, language: model.language)
                                }
                            }
                        }
                    } else if readScope != nil && readScope != loadedScope {
                        ProgressView()
                            .accessibilityLabel(text("ui.session.forecast.loading"))
                    } else {
                        Text(text("ui.session.forecast.unavailable"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, watchRowInset)
            .padding(.bottom, 8)
        }
        .watchStandardBackground(theme: theme)
        .task(id: readScope) {
            guard let readScope else {
                cursor = nil
                loadedScope = nil
                return
            }
            var next = DJConnectForecastCursor(sessionID: readScope.sessionID)
            while !Task.isCancelled {
                let forecast = await model.loadWatchSessionForecast(binding: readScope.binding, sessionID: readScope.sessionID)
                guard !Task.isCancelled else { return }
                next.receive(forecast)
                cursor = next
                loadedScope = readScope
                let remaining = next.projection == nil ? nil : next.remainingLifetime
                let delay = remaining.map { $0 > 0 ? max(2, min(15, $0)) : 15 } ?? 15
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            }
        }
    }
}

private struct DJConnectWatchFlowArtworkView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.scenePhase) private var scenePhase
    let reference: DJConnectSessionEntryReference
    let binding: String
    @State private var artwork: (image: CGImage, tint: Color?, expiresAt: Date)?

    var body: some View {
        TimelineView(.explicit([Date()] + [artwork?.expiresAt].compactMap { $0 })) { _ in
            if scenePhase == .active, let artwork, artwork.expiresAt > Date() {
                let card = RoundedRectangle(cornerRadius: 20, style: .continuous)
                Image(decorative: artwork.image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(watchListItemPadding)
                    .background {
                        card.fill(artwork.tint?.opacity(0.72) ?? .clear)
                    }
                    .background(DJConnectMaterial(.regular), in: card)
                    .overlay {
                        card.strokeBorder(artwork.tint?.opacity(0.8) ?? .white.opacity(0.16))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .task(id: scenePhase) {
            artwork = nil
            guard scenePhase == .active,
                  let result = await model.loadWatchFlowArtwork(reference, binding: binding),
                  !Task.isCancelled,
                  let source = CGImageSourceCreateWithData(result.jpeg as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            artwork = (image, averageArtworkColor(from: image), result.expiresAt)
        }
        .onDisappear { artwork = nil }
    }
}

private struct DJConnectWatchRetainedReplayButton: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    let reference: DJConnectSessionEntryReference
    let binding: String
    @ObservedObject var speech: DJConnectWatchSessionSpeech

    var momentType: String? = nil
    var body: some View {
        let id = reference.entryID
        let isSpeaking = speech.momentID == id && (speech.state == .preparing || speech.state == .playing)
        Button {
            if isSpeaking {
                speech.stop()
            } else {
                model.replaySessionSpeech(.entry(sessionID: reference.sessionID, entryID: id), id: id, binding: binding, momentType: momentType)
            }
        } label: {
            Label(watchLocalizedKey(model.language, isSpeaking ? "watch.session.stop_speech" : "watch.v2.listen"),
                  systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2")
        }
        .buttonStyle(DJConnectWatchFlatActionRowStyle())
        .disabled(!isSpeaking && !model.canReplaySessionSpeech(binding: binding, momentType: momentType))
        .onDisappear {
            if speech.momentID == id { speech.stop() }
        }
        if speech.momentID == id && speech.state == .unavailable {
            Text(watchLocalizedKey(model.language, "watch.session.speech_unavailable"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DJConnectWatchCompanionMomentView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.watchSessionTheme) private var theme
    let moment: DJConnectMoment
    @ObservedObject var state: DJConnectWatchForegroundSession
    @ObservedObject var speech: DJConnectWatchSessionSpeech
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
                DJConnectWatchMomentHeading(title: watchLocalizedKey(model.language, moment.isMusicAnnouncementV1 ? "ui.session.moment.music_announcement" : "watch.v2.moments"), color: theme.watchColors[1])
                Text(moment.content).fixedSize(horizontal: false, vertical: true)
                if moment.sourceAttribution?["provider"] == "Spotify",
                   moment.nativeSourceURLs.contains(where: { $0.host == "open.spotify.com" }) {
                    Image("SpotifyAttribution").resizable().scaledToFit()
                        .frame(width: 54, height: 18)
                        .accessibilityLabel("Spotify")
                }
                ForEach(moment.nativeSourceURLs.filter { $0.host != "open.spotify.com" }, id: \.absoluteString) { url in
                    Text(url.host ?? "").font(.caption2).foregroundStyle(.secondary)
                }
                let isSpeaking = speech.momentID == moment.id && (speech.state == .preparing || speech.state == .playing)
                if isSpeaking || model.canPlaySessionMoment(moment) {
                    Button {
                        if isSpeaking { speech.stop() } else { model.playSessionMoment(moment) }
                    } label: {
                        Label(watchLocalizedKey(model.language, isSpeaking ? "watch.session.stop_speech" : "watch.v2.listen"),
                              systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2")
                    }
                }
                if speech.momentID == moment.id && speech.state == .unavailable {
                    Text(watchLocalizedKey(model.language, "watch.session.speech_unavailable"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                NavigationLink {
                    DJConnectWatchCompanionTextView(context: .init(sessionID: moment.sessionID,
                        selectedMoment: .init(sessionID: moment.sessionID, momentID: moment.id)))
                } label: { Label(watchLocalizedKey(model.language, "watch.v2.ask_about"), systemImage: "bubble.left") }
            }.padding(watchListItemPadding)
            } else { Text(watchLocalizedKey(model.language, "ui.session.history.contribution_unavailable")).padding(watchListItemPadding) }
        }
        }.navigationTitle("")
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
                Button {
                    let selectedContext: DJConnectConversationContext
                    if recording != nil {
                        guard let originalEntry, originalEntry.isRetained() else { return }
                        selectedContext = .init(sessionID: context.sessionID, selectedEntry: originalEntry.reference)
                    } else {
                        selectedContext = context
                    }
                    Task { sent = await model.sendWatchText(text, context: selectedContext, expectedBinding: originalBinding); if sent { answer = model.lastWatchTextReply; text = "" } }
                } label: {
                    Label(watchLocalizedKey(model.language, "watch.v2.send"), systemImage: "paperplane.fill")
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.watchTextPending || (!model.isDemoMode && model.watchTextOutcomeUnknown) ||
                           (recording != nil && originalEntry?.isRetained() != true))
                if isResolvingRecording { ProgressView() }
                if recording != nil && !isResolvingRecording && originalEntry?.isRetained() != true {
                    Text(watchLocalizedKey(model.language, "ui.session.history.contribution_unavailable")).font(.caption)
                }
                if model.watchTextPending { ProgressView() }
                if sent, let answer { Text(answer.text) }
                if !model.isDemoMode && model.watchTextOutcomeUnknown {
                    Button(watchLocalizedKey(model.language, "ui.refresh")) {
                        Task { await model.checkWatchTextOutcome(); if !model.watchTextOutcomeUnknown { answer = model.lastWatchTextReply; sent = true; text = "" } }
                    }
                    Button(watchLocalizedKey(model.language, "watch.v2.question.new")) {
                        model.beginNewWatchTextTurn(); text = ""; answer = nil; sent = false
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, watchRowInset)
        }
        .watchStandardBackground()
        .navigationTitle("Ask DJ")
        .onChange(of: model.lastWatchTextReply) { _, reply in
            if model.isDemoMode, let reply {
                answer = reply
                sent = true
                text = ""
            }
        }
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
    let context: DJConnectConversationContext
    @ObservedObject var state: DJConnectWatchForegroundSession
    private var isRecording: Bool { model.voiceState == .recording }
    private var isPending: Bool { model.voiceState == .processing }

    private var avatarEvidence: DJPersonaActivity.Evidence {
        var evidence = DJPersonaActivity.Evidence()
        evidence.authorized = model.isAppForeground && (model.canUseBackend || isRecording || isPending)
        evidence.capturing = isRecording
        evidence.pending = isPending
        evidence.explicitReply = model.hasWatchVoiceReply
        if case .playing = model.askDJAudioPlaybackState {
            evidence.speaking = model.hasWatchVoiceReply
        }
        return evidence
    }

    var body: some View {
        let evidence = avatarEvidence
        ScrollView {
            VStack(spacing: 10) {
                DJPersonaAvatarView(confirmedMood: state.current()?.session?.selectedMood,
                                    language: model.language, activity: DJPersonaActivity.resolve(evidence),
                                    speechIsPlaying: evidence.speaking)
                    .frame(width: 64, height: 64)
                if let reply = model.lastWatchVoiceReply {
                    Text(reply).font(.caption).multilineTextAlignment(.center)
                } else if case .failed(let message) = model.voiceState {
                    Text(message).font(.caption).multilineTextAlignment(.center)
                } else if !model.statusMessage.isEmpty && model.statusMessage != "Gereed" {
                    Text(model.statusMessage).font(.caption).multilineTextAlignment(.center).lineLimit(3)
                }
                if isPending || model.isStartingRecording { ProgressView() }
                Button { model.toggleWatchQuestionRecording(context: context) } label: {
                    Label(watchLocalizedKey(model.language, isRecording ? "watch.v2.stop_send" : "watch.v2.speak"),
                          systemImage: isRecording ? "stop.fill" : "mic.fill")
                }
                .disabled(!isRecording && !model.canStartWatchQuestionRecording(context: context))
                NavigationLink {
                    DJConnectWatchCompanionTextView(context: context)
                } label: {
                    Label(watchLocalizedKey(model.language, "watch.v2.text"), systemImage: "square.and.pencil")
                }
                .disabled(isRecording || isPending || model.isStartingRecording)
                .accessibilityIdentifier("watch-question-text")
                if isRecording { Button(watchLocalizedKey(model.language, "ui.cancel")) { model.cancelWatchQuestionRecording() } }
            }
            .padding(.bottom, 8)
            .padding(.horizontal, watchRowInset)
        }
        .navigationTitle("Ask DJ")
        .onDisappear { model.cancelWatchQuestionRecording() }
    }
}
private struct DJConnectWatchCompanionMusicView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    var body: some View {
        DJConnectWatchList {
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
struct DJConnectWatchFlatActionRowStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.role == .destructive ? Color.red : Color.white)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, watchListItemPadding)
            .background(DJConnectWatchFlatRowBackground(isPressed: configuration.isPressed))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.52)
    }
}

private struct DJConnectWatchCompanionTrackView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.watchSessionTheme) private var theme
    @State private var original: DJConnectPlayback?
    @State private var progressObservedAt = Date()
    private enum Page { case artwork, trackInfo }
    private struct InsightDestination: Hashable {
        let recording: String
        let binding: String
        let artworkURL: URL?
    }

    @State private var page: Page? = .artwork
    @State private var insightDestination: InsightDestination?
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
        .navigationTitle("")
        .navigationDestination(item: $insightDestination) { destination in
            DJConnectWatchRecordingInsightView(recording: destination.recording, binding: destination.binding,
                                               session: model.foregroundSession, artworkURL: destination.artworkURL)
        }
        .onReceive(model.$playback) { playback in
            guard let playback, playback.hasPlayback != false,
                  let title = playback.trackName, !title.isEmpty else { return }
            if !model.isDemoMode {
                guard let originalBinding, let snapshot = model.foregroundSession.current(),
                      snapshot.settings.binding == originalBinding,
                      snapshot.session?.id == context.sessionID else { return }
            }
            progressObservedAt = Date()
            original = playback
        }
        .onAppear {
            if page == .artwork { setControlsVisible(true) }
        }
        .task(id: controlsVisit) { [visit = controlsVisit] in
            guard let visit else { return }
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard controlsVisit == visit else { return }
            setControlsVisible(false)
        }
        .onDisappear { controlsVisit = nil }
    }

    private func detail(artwork: Image?) -> some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    trackArtwork(artwork)
                        .containerRelativeFrame(.vertical)
                        .id(Page.artwork)
                    trackInfo(insets: geometry.safeAreaInsets)
                        .containerRelativeFrame(.vertical)
                        .id(Page.trackInfo)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .vertical)
        }
        .onChange(of: page) { _, page in
            if page == .trackInfo { controlsVisit = nil }
        }
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

    private func trackInfo(insets: EdgeInsets) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                if let title = original?.trackName {
                    DJConnectWatchScrollingTitle(title: title)
                        .font(.headline)
                        .id(title)
                }
                if let artist = original?.artistName {
                    DJConnectWatchScrollingTitle(title: artist)
                        .foregroundStyle(.secondary)
                        .id(artist)
                }
                if let album = original?.albumName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !album.isEmpty {
                    DJConnectWatchScrollingTitle(title: album)
                        .foregroundStyle(.secondary)
                        .id(album)
                }
                trackTiming
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    Button {
                        insightDestination = .init(recording: recording, binding: binding, artworkURL: original?.albumImageURL)
                    } label: {
                        Label("Track Insight", systemImage: "waveform.path.ecg")
                    }
                }
            }
            .buttonStyle(DJConnectWatchFlatActionRowStyle())
        }
        .padding(.horizontal, watchRowInset)
        .padding(.top, max(52, insets.top + 6))
        .padding(.bottom, insets.bottom + 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var trackTiming: some View {
        let isCurrentTrack = model.isDemoMode || (original?.uri != nil && model.playback?.uri == original?.uri)
        let live = isCurrentTrack ? model.playback : nil
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
            Button {
                if controlsVisit == nil {
                    setControlsVisible(true)
                } else {
                    controlsVisit = nil
                }
            } label: {
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
                        .padding(.horizontal, watchRowInset + watchListItemPadding)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.20, style: .continuous))
        }
    }

    private func setControlsVisible(_ visible: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            controlsVisit = visible ? UUID() : nil
        }
    }

    private var artworkControls: some View {
        let playback = model.playback
        let canSeek = playback?.hasPlayback == true
        let shuffle = model.playbackShuffleEnabled
        let repeatMode = model.playbackRepeatMode
        let repeatValueKey = switch repeatMode {
        case .off: "ui.off"
        case .track: "ui.track"
        case .context: "ui.context"
        }
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                playbackButton(icon: repeatMode == .track ? "repeat.1" : "repeat",
                               label: "ui.repeat", selected: repeatMode != .off) {
                    await model.cycleRepeat()
                }
                .accessibilityValue(watchLocalizedKey(model.language, repeatValueKey))
                .disabled(!canSeek || model.isChangingRepeat)
                playbackButton(icon: "shuffle", label: "ui.shuffle", selected: shuffle) {
                    await model.sendCommand("set_shuffle", value: .bool(!model.playbackShuffleEnabled))
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
        let isCurrentTrack = model.isDemoMode || (original?.uri != nil && model.playback?.uri == original?.uri)
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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(watchLocalizedKey(model.language, label))
        .frame(maxWidth: .infinity)
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

    private var canReadInsight: Bool {
        model.isAppForeground && model.canUseBackend && model.playback?.uri == recording
            && session.current()?.settings.binding == binding
    }

    var body: some View {
        TimelineView(.explicit([Date()] + [result?.expiresAt].compactMap { $0 })) { _ in
            let insight = result.flatMap { Date() < $0.expiresAt && canReadInsight ? $0.insight : nil }
            ScrollView {
                if isLoading {
                    ProgressView()
                } else if let insight {
                    VStack(alignment: .leading, spacing: 8) {
                        DJConnectWatchRootView.DJConnectWatchTrackInsightVisualCard(
                            insight: insight,
                            language: model.language,
                            moodStepIndex: model.askDJMoodStepIndex,
                            isPlaying: model.playback?.uri == recording && model.playback?.isPlaying == true,
                            fallbackArtworkURL: artworkURL,
                            fillsPage: true
                        )
                        DJConnectWatchRootView.DJConnectWatchTrackInsightAnalysisCard(insight: insight, language: model.language)
                            .padding(.horizontal, watchRowInset)
                            .padding(.bottom, 8)
                    }
                } else {
                    Text(watchLocalizedKey(model.language, "appModel.track.insight.is.unavailable.for.this.track"))
                        .foregroundStyle(.secondary)
                }
            }
            .ignoresSafeArea(.container, edges: insight != nil && !isLoading ? .all : [])
            .navigationTitle(insight != nil && !isLoading ? "" : "Track Insight")
        }
        .watchStandardBackground()
        .task(id: canReadInsight) {
            guard canReadInsight else {
                result = nil
                isLoading = false
                return
            }
            while !Task.isCancelled {
                isLoading = true
                let fresh = await model.loadRecordingInsight(recording, binding: binding)
                guard !Task.isCancelled else { return }
                result = fresh
                isLoading = false
                guard let fresh else { return }
                do {
                    try await Task.sleep(for: .seconds(max(0, fresh.expiresAt.timeIntervalSinceNow)))
                } catch { return }
            }
        }
    }
}

private struct DJConnectWatchCompanionSoundView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var showsOutputs = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Button { showsOutputs = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2")
                            .accessibilityHidden(true)
                        Text(model.selectedOutput)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(DJConnectWatchFlatActionRowStyle())
                VStack(alignment: .leading, spacing: 4) {
                    Label(watchLocalizedKey(model.language, "watch.volume"), systemImage: "speaker.wave.2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Slider(value: Binding(get: { model.volume }, set: { value in
                        model.volume = value
                        model.commitVolume()
                    }), in: 0...1)
                        .disabled(model.playback?.device?.supportsVolume != true)
                        .accessibilityLabel(watchLocalizedKey(model.language, "watch.volume"))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, watchRowInset)
        }
        .navigationDestination(isPresented: $showsOutputs) { DJConnectWatchOutputsView() }
        .watchStandardBackground()
        .navigationTitle(watchLocalizedKey(model.language, "watch.v2.sound"))
    }
}

/// Shows only confirmed Mood while the producer's requested Session-only write
/// scope remains unselected. settings3 currently writes Profile + active Session;
/// using it here would silently change the owner's Profile defaults.
struct DJConnectWatchCompanionMoodView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingMood: String?
    @ObservedObject var state: DJConnectWatchForegroundSession
    @ObservedObject var settings: ProfileDJSettingsModel

    var demoSessionID: String? = nil

    private let moods: [DJConnectSessionMoodTheme] = [.chill, .groove, .energy, .party]

    var body: some View {
        DJConnectWatchList {
            if let demoSessionID, let demo = model.companionDemoSession, demo.id == demoSessionID, model.isDemoMode {
                moodChoices(selected: demo.mood, disabled: !model.canSendCompanionDemoCommands) { mood in
                    pendingMood = mood
                    model.chooseCompanionDemoSetting(.mood, value: mood, sessionID: demoSessionID)
                }
            } else if demoSessionID == nil, let current = state.current(), let session = current.session,
               settings.response?.binding == current.settings.binding, !current.settings.requiresSelection,
               let revision = session.confirmedMoodRevision {
                moodChoices(selected: session.selectedMood,
                            disabled: model.isUpdatingSessionMood || state.isRefreshing || state.isChanging ||
                                state.outcomeUnknown || settings.hasUncertainOperation) { mood in
                    let intent = DJConnectWatchSessionMoodIntent(binding: current.settings.binding,
                        sessionID: session.id, mood: mood, expectedRevision: revision)
                    Task {
                        if await model.updateSessionMood(intent) { dismiss() }
                    }
                }
            } else {
                Text(watchLocalizedKey(model.language, "ui.dj_settings.unavailable")).font(.caption).foregroundStyle(.secondary)
            }
            if model.isUpdatingSessionMood { ProgressView() }
        }
        .listStyle(.plain)
        .watchStandardBackground()
        .navigationTitle(watchLocalizedKey(model.language, "ui.dj_settings.mood"))
        .onChange(of: model.companionDemoSession?.mood) { _, mood in
            if let pendingMood, mood == pendingMood { dismiss() }
        }
    }

    private func moodChoices(selected: String, disabled: Bool, change: @escaping (String) -> Void) -> some View {
        ForEach(moods, id: \.self) { option in
            let mood = option.rawValue
            Button {
                if selected == mood { dismiss() }
                else { change(mood) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: option.watchIcon)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(option.watchIconGradient)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(watchLocalizedKey(model.language, "ui.session.mood." + mood))
                    Spacer()
                    if selected == mood { Image(systemName: "checkmark").accessibilityHidden(true) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected == mood ? .isSelected : [])
            .disabled(disabled)
        }
    }

}

/// A locator never grants access. Read only the exact original publication.
private struct DJConnectWatchMomentNotificationView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @Environment(\.watchSessionTheme) private var theme
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
                    DJConnectWatchCompanionMomentView(moment: original, state: state, speech: model.sessionSpeech)
                } else if isLoading || state.isRefreshing {
                    ProgressView()
                } else if let retained, retained.isRetained(),
                          let originalBinding, state.current()?.settings.binding == originalBinding {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            DJConnectWatchMomentHeading(title: watchLocalizedKey(model.language, retained.momentType == "music_announcement" ? "ui.session.moment.music_announcement" : "watch.v2.moments"), color: theme.watchColors[1])
                            Text(retained.text ?? "").fixedSize(horizontal: false, vertical: true)
                            if retained.requiresSpotifyAttribution == true {
                                Image("SpotifyAttribution").resizable().scaledToFit()
                                    .frame(width: 72, height: 24).accessibilityLabel("Spotify")
                            }
                            DJConnectWatchRetainedReplayButton(reference: retained.reference, binding: originalBinding,
                                                               speech: model.sessionSpeech, momentType: retained.momentType)
                            NavigationLink {
                                DJConnectWatchCompanionTextView(context: .init(sessionID: nil, selectedEntry: retained.reference),
                                                               binding: originalBinding)
                            } label: {
                                Label(watchLocalizedKey(model.language, "watch.v2.ask_about"), systemImage: "bubble.left")
                            }
                        }.padding(watchListItemPadding)
                    }
                    .navigationTitle("")
                } else {
                    Text(watchLocalizedKey(model.language, "ui.session.history.contribution_unavailable")).padding(watchListItemPadding)
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
        DJConnectWatchList {
            Toggle(watchLocalizedKey(model.language, "watch.v2.moments"), isOn: $model.watchMomentNotificationsEnabled)
            // Ordinary push registration does not acknowledge the Moment preference.
            Text(watchLocalizedKey(model.language, "watch.v2.notification.pending"))
                .font(.caption).foregroundStyle(.secondary)
            Button(watchLocalizedKey(model.language, "watch.v2.notification.permission")) { model.requestWatchNotificationPermission() }
                .buttonStyle(.plain)
        }
        .watchStandardBackground()
        .navigationTitle(watchLocalizedKey(model.language, "watch.v2.notifications"))
    }
}
