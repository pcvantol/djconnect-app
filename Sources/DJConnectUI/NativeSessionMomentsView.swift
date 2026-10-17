import SwiftUI
import DJConnectCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DJConnectAlbumArtworkLayout {
    static func maximumWidth(phone: Bool) -> CGFloat { phone ? .infinity : 270 }
}

extension View {
    func djSessionFrostedSurface(cornerRadius: CGFloat = DJConnectCardAppearance.cornerRadius, currentMomentBorder: Bool = false) -> some View {
        modifier(DJSessionGlassSurface(cornerRadius: cornerRadius, currentMomentBorder: currentMomentBorder))
    }

    func djAlbumArtworkGlassCard(artworkURL: URL? = nil) -> some View {
        modifier(DJAlbumArtworkGlassCard(artworkURL: artworkURL))
    }

    @ViewBuilder func djSessionNavigationTitleStyle(compactPhone: Bool = false) -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(compactPhone && UIDevice.current.userInterfaceIdiom == .phone ? .inline : .large)
        #else
        self
        #endif
    }
}

/// Sample only the displayed cover, sharing the player's artwork cache.
/// URL-bound state prevents a late previous-cover download from tinting the next cover.
private struct DJAlbumArtworkGlassCard: ViewModifier {
    let artworkURL: URL?
    @State private var sampledTint: Color?
    @State private var sampledURL: URL?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled

    init(artworkURL: URL?) {
        self.artworkURL = artworkURL
        let cached = artworkURL.flatMap { DJConnectArtworkTintCache.shared.value(for: $0) }
        _sampledTint = State(initialValue: cached?.color)
        _sampledURL = State(initialValue: cached == nil ? nil : artworkURL)
    }

    func body(content: Content) -> some View {
        let inset: CGFloat = 8
        let shape = RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius, style: .continuous)
        let tint = sampledURL == artworkURL ? sampledTint : nil
        content
            .clipShape(RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius - inset, style: .continuous))
            .padding(inset)
            .background { shape.fill(tint?.opacity(reduceTransparency || !glassEnabled ? 1 : 0.72) ?? .clear) }
            .djSessionFrostedSurface()
            .overlay {
                if let tint {
                    shape.stroke(tint.opacity(0.8), lineWidth: DJConnectCardAppearance.borderWidth)
                        .allowsHitTesting(false)
                }
            }
            .task(id: artworkURL) {
                guard let requestedURL = artworkURL else {
                    sampledTint = nil; sampledURL = nil; return
                }
                if let cached = DJConnectArtworkTintCache.shared.value(for: requestedURL) {
                    sampledTint = cached.color; sampledURL = requestedURL
                    return
                }
                let color = await DJConnectArtworkDataCache.shared.tint(for: requestedURL, fallback: Color(white: 0.22))
                guard !Task.isCancelled, requestedURL == artworkURL else { return }
                if let cached = await DJConnectArtworkDataCache.shared.cachedTint(for: requestedURL) {
                    DJConnectArtworkTintCache.shared.store(cached, for: requestedURL)
                }
                guard !Task.isCancelled, requestedURL == artworkURL else { return }
                sampledURL = requestedURL
                sampledTint = color
            }
    }
}

private struct CurrentMomentArtworkTintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

private extension EnvironmentValues {
    var currentMomentArtworkTint: Color? {
        get { self[CurrentMomentArtworkTintKey.self] }
        set { self[CurrentMomentArtworkTintKey.self] = newValue }
    }
}

/// Use the same cover sample as the artwork border, only for the current card.
private struct CurrentMomentArtworkTint: ViewModifier {
    let artworkURL: URL?
    @State private var sampledTint: Color?
    @State private var sampledURL: URL?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .environment(\.currentMomentArtworkTint, sampledURL == artworkURL ? sampledTint : nil)
            .task(id: artworkURL) {
                sampledTint = nil
                sampledURL = nil
                guard let requestedURL = artworkURL else { return }
                let tint = await DJConnectArtworkDataCache.shared.tint(for: requestedURL, fallback: Color(white: 0.22))
                guard !Task.isCancelled, requestedURL == artworkURL else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    sampledURL = requestedURL
                    sampledTint = tint
                }
            }
    }
}

private struct DJSessionGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    var currentMomentBorder = false
    @Environment(\.currentMomentArtworkTint) private var artworkTint
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled
    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let bordered = content.background {
            if currentMomentBorder, let artworkTint {
                shape.fill(LinearGradient(
                    colors: [artworkTint.opacity(reduceTransparency ? 0.85 : 0.38),
                             artworkTint.opacity(reduceTransparency ? 0.65 : 0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }.overlay {
            shape.stroke(currentMomentBorder ? AnyShapeStyle(DJConnectCardAppearance.searchFocusGradient) : AnyShapeStyle(Color.white.opacity(DJConnectCardAppearance.borderOpacity)),
                         lineWidth: DJConnectCardAppearance.borderWidth)
        }
        if !glassEnabled || reduceTransparency {
            bordered.background(DJConnectGlassAppearance.opaqueSurface, in: shape)
        } else if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, *) {
            if currentMomentBorder, let artworkTint {
                bordered.glassEffect(.regular.tint(artworkTint.opacity(0.22)), in: shape)
            } else {
                #if os(iOS)
                if currentMomentBorder && UIDevice.current.userInterfaceIdiom == .pad {
                    // Wide iPad bubbles need a visible frost tint over the page gradient.
                    bordered.glassEffect(.regular.tint(.white.opacity(0.12)), in: shape)
                } else { bordered.glassEffect(.regular, in: shape) }
                #else
                bordered.glassEffect(.regular, in: shape)
                #endif
            }
        } else { bordered.background(DJConnectMaterial(.ultraThin), in: shape) }
    }
}

/// Share the glass compositor across visible cards without merging separated bubbles.
struct DJSessionGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, *), glassEnabled && !reduceTransparency {
            GlassEffectContainer(spacing: 0) { content }
        } else {
            content
        }
    }
}

/// One native projection shared by Compact and Expanded Apple surfaces.
struct NativeSessionMomentsView: View {
    let session: DJConnectSessionRuntime
    let language: String
    var isRecovering = false
    var isLiveUnavailable = false
    var retryConnection: () -> Void = {}
    var artworkBaseURL: URL? = nil
    var playbackOutputName: String? = nil
    var playbackModel: DJConnectAppModel? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var artworkFeedback: ArtworkFeedback?
    @State private var artworkActionGeneration = UUID()
    @State private var artworkPausedOverride: Bool?
    @State private var artworkPlaybackConfirmationID = UUID()
    @State private var hidesArtworkPlayOnTouch = false
    @State private var artworkTouchID = UUID()
    @State private var hidesArtworkPlayDuringSkip = false
    @State private var artworkSkipSettleID = UUID()
    private struct ArtworkFeedback {
        let id = UUID()
        let command: String
        var symbol: String {
            switch command {
            case "next": "forward.end.fill"
            case "previous": "backward.end.fill"
            case "play": "play.fill"
            default: "pause.fill"
            }
        }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func text(_ key: String) -> String {
        DJConnectLocalization.localized(key: key, language: language)
    }

    private var stacksCurrentOnPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            let current = currentMoment(at: clock.date)
            VStack(alignment: .leading, spacing: 24) {
                SessionCurrentColumns(stacked: true) {
                    musicContext
                    currentCard(current)
                        .modifier(CurrentMomentArtworkTint(artworkURL: musicArtworkURL))
                        .accessibilityIdentifier("session-current-card")
                }
                .accessibilityElement(children: .contain)
                .id("native-session-current")
                .animation(djSessionReducedMotion(reduceMotion) ? nil : .easeInOut(duration: 0.2), value: current?.id)

            }
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: Binding(get: { playbackModel?.momentTrackInsightTarget != nil }, set: { if !$0 { playbackModel?.dismissMomentTrackInsight() } })) {
            if let model = playbackModel {
                #if os(macOS)
                TrackInsightView(model: model, explicitMoment: true).frame(minWidth: 640, minHeight: 600)
                #else
                TrackInsightView(model: model, explicitMoment: true)
                #endif
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { clearArtworkFeedback() }
        }
        .onChange(of: session.id) { _, _ in clearArtworkFeedback() }
        .onChange(of: session.broadcast.playback?.itemID) { _, _ in artworkPausedOverride = nil }
        .onChange(of: session.broadcast.playback?.state) { _, state in
            if let artworkPausedOverride,
               (state == "paused" && artworkPausedOverride) || (state == "playing" && !artworkPausedOverride) {
                self.artworkPausedOverride = nil
            }
        }
        .task(id: artworkPlaybackConfirmationID) {
            guard artworkPausedOverride != nil else { return }
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            artworkPausedOverride = nil
        }
        .task(id: artworkSkipSettleID) {
            guard hidesArtworkPlayDuringSkip else { return }
            let generation = artworkActionGeneration
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard artworkActionGeneration == generation else { return }
            hidesArtworkPlayDuringSkip = false
        }
        .task(id: artworkTouchID) {
            guard hidesArtworkPlayOnTouch else { return }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            hidesArtworkPlayOnTouch = false
        }
        .onDisappear { clearArtworkFeedback() }
        .accessibilityIdentifier("session-moment-content")
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            if ProcessInfo.processInfo.arguments.contains("--uitesting"), djSessionReducedMotion(reduceMotion) {
                Text("uitest-renderer-reduce-motion-on").font(.caption2).accessibilityIdentifier("uitest-renderer-reduce-motion-on")
            }
        }
        #endif
    }

    private func currentMoment(at date: Date) -> DJConnectMoment? { session.broadcast.nativeCurrentMoment(at: date, spotifyAttributionAvailable: spotifyAttributionLogo != nil) }

    private func kind(_ moment: DJConnectMoment) -> String {
        let mapped = ["track": "track_context", "artist": "artist_story", "album": "album_story", "genre": "genre_story", "session": "session_direction"][moment.type] ?? moment.type
        let key = "ui.session.moment.\(mapped)"
        let value = text(key)
        return value == key ? text("ui.session.moment.generic") : value
    }

    private func presentation(for moment: DJConnectMoment) -> DJConnectPresentation? {
        session.broadcast.presentations.last { $0.momentID == moment.id }
    }

    @ViewBuilder private func currentCard(_ moment: DJConnectMoment?) -> some View {
        if isLiveUnavailable {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("ui.session.live_unavailable")).font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Button(text("ui.retry"), action: retryConnection)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .djSessionFrostedSurface(currentMomentBorder: true)
        } else if isRecovering {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("ui.session.reconnecting")).font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .djSessionFrostedSurface(currentMomentBorder: true)
        } else if session.runtimeState == "active", session.broadcast.playback?.state == "paused" {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(text("ui.paused")).font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(text("ui.session.playback_paused_detail"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .djSessionFrostedSurface(currentMomentBorder: true)
            .accessibilityIdentifier("session-playback-paused")
        } else if let moment {
            MomentCard(moment: moment, kind: kind(moment), presentation: presentation(for: moment), language: language,
                navigationLabel: insightOffer(for: moment)?.label,
                openInsight: { if let offer = insightOffer(for: moment) { playbackModel?.openMomentTrackInsight(offer) } },
                artworkMedia: session.broadcast.sessionMedia.first { $0.sessionID == session.id && $0.target == .moment(moment.id) },
                artworkModel: playbackModel,
                speech: session.broadcast.sessionSpeech.first { $0.reference == .moment(sessionID: session.id, momentID: moment.id) })
                .id(moment.id)
                .transition(.opacity)
                .accessibilityIdentifier("session-current-moment")
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: DJConnectFeatureSymbols.djSession)
                    .font(.title).accessibilityHidden(true)
                Text(text("ui.session.quiet")).font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .djSessionFrostedSurface(currentMomentBorder: true)
        }
    }

    private func insightOffer(for moment: DJConnectMoment) -> DJConnectMomentInsightNavigation? {
        guard playbackModel?.sessionHistory.momentInsightAvailable == true,
              let offer = session.broadcast.nativeCurrentInsightNavigation(at: Date()), offer.reference.momentID == moment.id else { return nil }
        return offer
    }

    private var musicArtworkURL: URL? {
        guard playbackModel?.isDemoMode != true,
              let raw = session.broadcast.playback?.artworkURL,
              let candidate = URL(string: raw) else { return nil }
        if let playbackModel {
            return playbackModel.resolvedArtworkURL(candidate)
        }
        return DJConnectArtworkRoute.resolve(candidate, knownOrigins: artworkBaseURL.map { [$0] } ?? [],
                                             preferredOrigin: artworkBaseURL)
    }

    private var musicContext: some View {
        SessionCurrentColumns(stacked: stacksCurrentOnPhone) {
            ZStack {
                CachedArtworkImage(url: musicArtworkURL, mode: .fit, usesAlbumGlassFrame: true) {
                    AlbumArtworkPlaceholder(tint: djConnectAccent,
                        isPlaying: session.broadcast.playback?.state == "playing" && !artworkIsPaused)
                }
                    .aspectRatio(1, contentMode: .fit)
                artworkPlaybackOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(1)
                SessionArtworkTapSurface(action: handleArtworkTap, touchBegan: {
                    if artworkIsPaused, playbackModel?.canUsePlaybackFeatures == true {
                        hidesArtworkPlayOnTouch = true
                        artworkTouchID = UUID()
                    }
                }, touchCancelled: { hidesArtworkPlayOnTouch = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(2)
            }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: DJConnectAlbumArtworkLayout.maximumWidth(phone: stacksCurrentOnPhone))
                .contentShape(RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius, style: .continuous))
                .task(id: artworkFeedback?.id) {
                    guard let feedback = artworkFeedback else { return }
                    do { try await Task.sleep(for: feedback.command == "pause" ? .seconds(2) : .milliseconds(850)) } catch { return }
                    guard artworkFeedback?.id == feedback.id else { return }
                    withAnimation(.easeOut(duration: 0.2)) { artworkFeedback = nil }
                }
                .accessibilityAction { sendArtworkCommand(artworkIsPaused ? "play" : "pause") }
                .accessibilityAction(named: Text(text("ui.next.track"))) { sendArtworkCommand("next") }
                .accessibilityAction(named: Text(text("ui.previous.track"))) { sendArtworkCommand("previous") }
                .accessibilityAction(named: Text(text("ui.pause"))) { sendArtworkCommand("pause") }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("session-music-artwork")
                .sessionIntroductionTarget("artwork")
            musicDetails
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-music-context")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleArtworkTap(_ count: Int) {
        switch count {
        case 1: sendArtworkCommand(artworkIsPaused ? "play" : "pause")
        case 2: sendArtworkCommand("next")
        case 3: sendArtworkCommand("previous")
        default: break
        }
    }

    private func sendArtworkCommand(_ command: String) {
        // Global playback controls remain usable while artwork/progress projections catch up.
        guard scenePhase == .active, let playbackModel, playbackModel.canUsePlaybackFeatures,
              !playbackModel.djSessionIsRecovering, !playbackModel.djSessionLiveUnavailable,
              playbackModel.activeDJSession?.id == session.id,
              playbackModel.activeDJSession?.runtimeState == "active" else {
            hidesArtworkPlayOnTouch = false
            return
        }
        let isSkip = command == "next" || command == "previous"
        hidesArtworkPlayDuringSkip = isSkip
        // Keep the paused affordance out of the track-transition feedback.
        // Start the settle window only when the request finishes.
        let generation = UUID()
        artworkActionGeneration = generation
        let epoch = playbackModel.sessionHistory.responseEpoch
        // Acknowledge the gesture immediately. Resume hides Play while its request is pending.
        playArtworkHaptic(command)
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.8)) {
            hidesArtworkPlayOnTouch = false
            artworkFeedback = command == "play" ? nil : ArtworkFeedback(command: command)
            if command == "play" {
                artworkPausedOverride = false
                artworkPlaybackConfirmationID = UUID()
            }
        }
        playbackModel.recordPresentationState("artwork-gesture-feedback-\(command)")
        playbackModel.sendPlaybackCommand(command, onConfirmed: {
            playbackModel.recordPresentationState("artwork-callback-generation-\(artworkActionGeneration == generation)-epoch-\(playbackModel.sessionHistory.responseEpoch == epoch)-active-\(playbackModel.activeDJSession?.runtimeState == "active")")
            guard artworkActionGeneration == generation,
                  playbackModel.activeDJSession?.id == session.id,
                  playbackModel.activeDJSession?.runtimeState == "active",
                  playbackModel.sessionHistory.responseEpoch == epoch else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.8)) {
                artworkPausedOverride = command == "pause" ? true : command == "play" ? false : nil
                artworkPlaybackConfirmationID = UUID()
            }
            if isSkip { artworkSkipSettleID = UUID() }
            playbackModel.recordPresentationState("artwork-playback-confirmed-\(command)")
        }, onUnconfirmed: {
            guard artworkActionGeneration == generation,
                  playbackModel.activeDJSession?.id == session.id,
                  playbackModel.sessionHistory.responseEpoch == epoch else { return }
            artworkPausedOverride = nil
            if isSkip { artworkSkipSettleID = UUID() }
        })
    }

    private func playArtworkHaptic(_ command: String) {
        #if os(iOS)
        if command == "pause" { UISelectionFeedbackGenerator().selectionChanged() }
        else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }

    private func clearArtworkFeedback() {
        artworkActionGeneration = UUID()
        artworkFeedback = nil
        hidesArtworkPlayDuringSkip = false
        artworkSkipSettleID = UUID()
        artworkPausedOverride = nil
        hidesArtworkPlayOnTouch = false
        artworkTouchID = UUID()
        artworkPlaybackConfirmationID = UUID()
    }

    private var artworkIsPaused: Bool {
        if let artworkPausedOverride { return artworkPausedOverride }
        if let playbackModel, playbackModel.playback?.isPlaying != nil { return !playbackModel.isPlaying }
        return session.broadcast.playback?.state == "paused"
    }

    @ViewBuilder private var artworkPlaybackOverlay: some View {
        if let playbackModel {
            SessionArtworkPlaybackOverlay(model: playbackModel, session: session,
                                          feedbackSymbol: artworkFeedback?.symbol, feedbackID: artworkFeedback?.id,
                                          pausedOverride: artworkPausedOverride,
                                          hidesPlayOnTouch: hidesArtworkPlayOnTouch || hidesArtworkPlayDuringSkip)
        }
    }

    private var musicDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let playback = session.broadcast.playback {
                Text(playback.title ?? text("ui.nothing.playing")).font(.headline)
                if let artist = playback.artist { Text(artist).foregroundStyle(.secondary) }
                if let album = playback.album { Text(album).font(.caption).foregroundStyle(.secondary) }
                if let duration = playback.durationMS, duration > 0, let position = playbackModel?.displayedSessionPositionMS(session) ?? playback.positionMS {
                    let current = max(0, min(position, duration))
                    ProgressView(value: Double(current), total: Double(duration))
                        .accessibilityLabel(text("ui.session.music_progress"))
                    HStack(alignment: .center, spacing: 8) {
                        if let playbackModel, playbackModel.canToggleSessionFavorite(session) {
                            FavoriteTrackButton(model: playbackModel, identifier: "session-favorite-button", sessionContext: session)
                                .disabled(!playbackModel.canUsePlaybackFeatures || playbackModel.isRefreshing)
                        }
                        Spacer(minLength: 0)
                        Text("\(sessionPlaybackTime(current)) / \(sessionPlaybackTime(duration))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            .accessibilityLabel(text("ui.session.music_duration"))
                            .accessibilityValue("\(sessionPlaybackTime(current)) / \(sessionPlaybackTime(duration))")
                    }
                }
                if let playbackOutputName {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Label(playbackOutputName, systemImage: "hifispeaker.fill")
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(text("ui.output.device"))
                            .accessibilityValue(playbackOutputName)
                            .accessibilityIdentifier("session-playback-output")
                        Spacer(minLength: 0)
                        Group {
                            if playbackModel?.currentPlaybackUsesLocalBluetooth == true {
                                BluetoothOutputSymbol()
                                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                                    .frame(width: 12, height: 18)
                            } else if let volume = playbackModel?.currentPlaybackVolumePercent {
                                Label("\(volume)%", systemImage: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            } else {
                                Text("-")
                            }
                        }
                        .fixedSize()
                        .accessibilityLabel(text("watch.volume"))
                        .accessibilityValue(playbackModel?.currentPlaybackUsesLocalBluetooth == true ? "Bluetooth" : playbackModel?.currentPlaybackVolumePercent.map { "\($0)%" } ?? "-")
                        .accessibilityIdentifier("session-playback-volume")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-music-details")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if os(iOS)
/// Native failure dependencies arbitrate 1/2/3 taps without leaking a lower tap count.
private struct SessionArtworkTapSurface: UIViewRepresentable {
    var action: (Int) -> Void
    var touchBegan: () -> Void
    var touchCancelled: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeUIView(context: Context) -> UIView {
        let view = TouchView()
        view.touchBegan = touchBegan
        view.touchCancelled = touchCancelled
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isAccessibilityElement = false
        let recognizers = (1...3).map { count in
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
            tap.numberOfTapsRequired = count
            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
            return tap
        }
        recognizers[0].require(toFail: recognizers[1])
        recognizers[0].require(toFail: recognizers[2])
        recognizers[1].require(toFail: recognizers[2])
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.action = action
        if let view = view as? TouchView { view.touchBegan = touchBegan; view.touchCancelled = touchCancelled }
    }
    @MainActor final class TouchView: UIView {
        var touchBegan: (() -> Void)?
        var touchCancelled: (() -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            touchBegan?(); super.touchesBegan(touches, with: event)
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            touchCancelled?(); super.touchesCancelled(touches, with: event)
        }
    }
    @MainActor final class Coordinator: NSObject {
        var action: (Int) -> Void
        init(action: @escaping (Int) -> Void) { self.action = action }
        @objc func tapped(_ tap: UITapGestureRecognizer) {
            if tap.state == .ended { action(tap.numberOfTapsRequired) }
        }
    }
}
#elseif os(macOS)
private struct SessionArtworkTapSurface: NSViewRepresentable {
    var action: (Int) -> Void
    var touchBegan: () -> Void
    var touchCancelled: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        for count in 1...3 {
            let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.clicked(_:)))
            click.numberOfClicksRequired = count
            click.delegate = context.coordinator
            view.addGestureRecognizer(click)
        }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { context.coordinator.action = action }
    @MainActor final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var action: (Int) -> Void
        init(action: @escaping (Int) -> Void) { self.action = action }
        @objc func clicked(_ click: NSClickGestureRecognizer) {
            if click.state == .ended { action(click.numberOfClicksRequired) }
        }
        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                               shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
            guard let first = gestureRecognizer as? NSClickGestureRecognizer,
                  let other = otherGestureRecognizer as? NSClickGestureRecognizer else { return false }
            return first.numberOfClicksRequired < other.numberOfClicksRequired
        }
    }
}
#endif

/// Observe playback directly: the Session projection may arrive after the command's playback reply.
private struct SessionArtworkPlaybackOverlay: View {
    @ObservedObject var model: DJConnectAppModel
    let session: DJConnectSessionRuntime
    let feedbackSymbol: String?
    let feedbackID: UUID?
    let pausedOverride: Bool?
    let hidesPlayOnTouch: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var isPaused: Bool {
        if let pausedOverride { return pausedOverride }
        if model.playback?.isPlaying != nil { return !model.isPlaying }
        return session.broadcast.playback?.state == "paused"
    }
    var body: some View {
        ZStack {
            if let feedbackSymbol {
                symbol(feedbackSymbol)
                    .id(feedbackID)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
            } else if isPaused && !hidesPlayOnTouch {
                symbol("play.fill")
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 72, weight: .semibold))
            .foregroundStyle(.white.opacity(0.78))
            .frame(width: 124, height: 124)
            .background(.black.opacity(0.28), in: Circle())
            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
    }
}

/// Keeps music on the left even at compact widths and larger text sizes.
/// Each column measures its full text height, so the pinned header can scroll
/// vertically without changing the relationship between artwork and DJ content.
private struct SessionCurrentColumns: Layout {
    var stacked = false
    private func widths(_ proposal: ProposedViewSize) -> (CGFloat, CGFloat, CGFloat) {
        let width = max(0, proposal.width ?? 800)
        let gap: CGFloat = width < 600 ? 12 : 24
        let music = min(270, width * 0.375)
        return (music, max(0, width - music - gap), gap)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        if stacked {
            let width = max(0, proposal.width ?? 400)
            let top = subviews[0].sizeThatFits(.init(width: width, height: nil))
            let bottom = subviews[1].sizeThatFits(.init(width: width, height: nil))
            return CGSize(width: width, height: top.height + 16 + bottom.height)
        }
        let (music, card, gap) = widths(proposal)
        let left = subviews[0].sizeThatFits(.init(width: music, height: nil))
        let right = subviews[1].sizeThatFits(.init(width: card, height: nil))
        return CGSize(width: music + card + gap, height: max(left.height, right.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        if stacked {
            let top = subviews[0].sizeThatFits(.init(width: bounds.width, height: nil))
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .init(width: bounds.width, height: nil))
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + top.height + 16), anchor: .topLeading,
                              proposal: .init(width: bounds.width, height: nil))
            return
        }
        let (music, card, gap) = widths(.init(width: bounds.width, height: nil))
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .init(width: music, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.minX + music + gap, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: card, height: nil))
    }
}

struct MomentCard: View {
    let moment: DJConnectMoment
    let kind: String
    let presentation: DJConnectPresentation?
    let language: String
    var navigationLabel: String? = nil
    var openInsight: (() -> Void)? = nil
    var artworkMedia: DJConnectSessionMedia? = nil
    var artworkModel: DJConnectAppModel? = nil
    var speech: DJConnectSessionSpeech? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let media = artworkMedia, let model = artworkModel {
                SessionArtworkView(media: media, target: .moment(moment.id), audience: .current, language: language, model: model)
            }
            Text(kind).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if !moment.title.isEmpty { Text(moment.title).font(.title2.bold()).accessibilityAddTraits(.isHeader) }
            Text(moment.content).font(.title3).fixedSize(horizontal: false, vertical: true)
            if let speech = presentation?.speech {
                ForEach(speech.segments.filter { !(["dj", "primary_dj"].contains($0.speakerRole) && $0.text == moment.content) }.sorted { $0.ordinal < $1.ordinal }, id: \.ordinal) { segment in
                    Text(segment.text).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let label = navigationLabel, let openInsight {
                Button { DJConnectHaptics.selection(); openInsight() } label: { Label(label, systemImage: "waveform.path.ecg") }
                    .tint(djConnectAccent)
                    .accessibilityIdentifier("moment-open-track-insight")
            }
            if moment.sourceAttribution?["provider"] == "Spotify",
               let logo = spotifyAttributionLogo, let url = moment.nativeSourceURLs.first {
                Link(destination: url) {
                    logo.resizable().scaledToFit().frame(width: 70, height: 20)
                        .padding(10).frame(minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Spotify")
                .accessibilityValue(url.absoluteString)
                .accessibilityIdentifier("session-spotify-attribution")
            }
            ForEach(moment.nativeSourceURLs, id: \.absoluteString) { url in
                Link(moment.sourceAttribution?["provider"] ?? url.host ?? "", destination: url)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .accessibilityValue(url.absoluteString)
                    .accessibilityIdentifier("moment-source-" + url.absoluteString)
            }
            if let model = artworkModel { SharedDJSpeechActions(model: model, speech: speech, acceptedText: moment.content) }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .djSessionFrostedSurface(currentMomentBorder: true)
        .accessibilityElement(children: .contain)
    }
}

var spotifyAttributionLogo: Image? {
    #if os(iOS)
    UIImage(named: "SpotifyAttribution").map { Image(uiImage: $0) }
    #elseif os(macOS)
    NSImage(named: NSImage.Name("SpotifyAttribution")).map { Image(nsImage: $0) }
    #else
    nil
    #endif
}

func djSessionReducedMotion(_ systemPreference: Bool) -> Bool {
    #if DEBUG
    return systemPreference || ProcessInfo.processInfo.arguments.contains("--uitest-reduce-motion")
    #else
    return systemPreference
    #endif
}

func sessionPlaybackTime(_ milliseconds: Int) -> String {
    let seconds = max(0, milliseconds) / 1000
    return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}

// MARK: - One-time session navigation introduction

@MainActor final class SessionIntroductionAnchors: ObservableObject {
    @Published private(set) var frames: [String: CGRect] = [:]
    func record(_ name: String, frame: CGRect) {
        guard !frame.isEmpty, !frame.isInfinite, frames[name] != frame else { return }
        frames[name] = frame
    }
}

private struct SessionIntroductionAnchorsKey: EnvironmentKey {
    static let defaultValue: SessionIntroductionAnchors? = nil
}
extension EnvironmentValues {
    var sessionIntroductionAnchors: SessionIntroductionAnchors? {
        get { self[SessionIntroductionAnchorsKey.self] }
        set { self[SessionIntroductionAnchorsKey.self] = newValue }
    }
}
extension View {
    func sessionIntroductionTarget(_ name: String) -> some View {
        background(SessionIntroductionTargetReader(name: name))
    }
}

#if os(iOS)
private struct SessionIntroductionTargetReader: UIViewRepresentable {
    let name: String
    @Environment(\.sessionIntroductionAnchors) private var anchors
    func makeUIView(context: Context) -> Probe {
        let view = Probe(); view.isUserInteractionEnabled = false; return view
    }
    func updateUIView(_ view: Probe, context: Context) {
        view.name = name; view.anchors = anchors; view.publish()
    }
    final class Probe: UIView {
        var name = ""
        weak var anchors: SessionIntroductionAnchors?
        override func didMoveToWindow() { super.didMoveToWindow(); publish() }
        override func layoutSubviews() { super.layoutSubviews(); publish() }
        func publish() {
            guard let window, !bounds.isEmpty else { return }
            let rect = convert(bounds, to: window)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                self.anchors?.record(self.name, frame: rect)
                if self.name == "chat", let window = self.window {
                    func descendants(_ view: UIView) -> [UIView] {
                        view.subviews.flatMap { [$0] + descendants($0) }
                    }
                    if let bar = descendants(window).compactMap({ $0 as? UITabBar }).first(where: { !$0.isHidden }) {
                        let buttons = descendants(bar).filter { $0 is UIControl && !$0.isHidden && $0.bounds.width > 20 }
                        let frame = buttons.reduce(CGRect.null) { $0.union($1.convert($1.bounds, to: window)) }
                        if !frame.isNull { self.anchors?.record("navigation", frame: frame.insetBy(dx: -8, dy: -4)) }
                    }
                }
            }
        }
    }
}
#elseif os(macOS)
private struct SessionIntroductionTargetReader: NSViewRepresentable {
    let name: String
    @Environment(\.sessionIntroductionAnchors) private var anchors
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) {
        view.name = name; view.anchors = anchors; view.publish()
    }
    final class Probe: NSView {
        var name = ""
        weak var anchors: SessionIntroductionAnchors?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); publish() }
        override func layout() { super.layout(); publish() }
        func publish() {
            guard let content = window?.contentView, !bounds.isEmpty else { return }
            var rect = convert(bounds, to: content)
            if !content.isFlipped { rect.origin.y = content.bounds.height - rect.maxY }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                self.anchors?.record(self.name, frame: rect)
            }
        }
    }
}
#else
private struct SessionIntroductionTargetReader: View {
    let name: String
    var body: some View { Color.clear.allowsHitTesting(false) }
}
#endif

struct SessionIntroductionOverlay: View {
    @ObservedObject var anchors: SessionIntroductionAnchors
    let language: String
    let dismiss: () -> Void
    @State private var step = 0
    @AccessibilityFocusState private var titleFocused: Bool
    private let targets = ["toolbar", "chat", "artwork", "navigation"]
    private let symbols = ["slider.horizontal.3", "bubble.left.and.bubble.right", "hand.tap", "rectangle.bottomthird.inset.filled"]
    private func text(_ suffix: String) -> String {
        DJConnectLocalization.localized(key: "ui.session.intro." + suffix, language: language)
    }
    private var stepName: String {
        #if os(macOS)
        if step == 3 { return "sidebar" }
        #endif
        return targets[step]
    }
    private func target(in geometry: GeometryProxy) -> CGRect {
        let frame: CGRect
        if step == 0 {
            frame = anchors.frames.filter { $0.key.hasPrefix("toolbar-") }.values.reduce(CGRect.null) { $0.union($1) }
        } else { frame = anchors.frames[targets[step]] ?? .null }
        guard !frame.isNull else { return .zero }
        let origin = geometry.frame(in: .global).origin
        return frame.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -6, dy: -6)
            .intersection(CGRect(origin: .zero, size: geometry.size).insetBy(dx: 4, dy: 4))
    }
    var body: some View {
        GeometryReader { geometry in
            let highlight = target(in: geometry)
            let above = !highlight.isEmpty && highlight.midY > geometry.size.height / 2
            ZStack {
                Color.clear.contentShape(Rectangle()).onTapGesture { }
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    if !highlight.isEmpty { path.addRoundedRect(in: highlight, cornerSize: CGSize(width: 24, height: 24)) }
                }
                .fill(.black.opacity(0.66), style: FillStyle(eoFill: true))
                .allowsHitTesting(false).accessibilityHidden(true)
                if !highlight.isEmpty {
                    RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.95), lineWidth: 2)
                        .frame(width: highlight.width, height: highlight.height)
                        .position(x: highlight.midX, y: highlight.midY)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                VStack(spacing: 0) {
                    if above || highlight.isEmpty { Spacer(minLength: 16) }
                    else { Spacer().frame(height: min(highlight.maxY + 18, geometry.size.height * 0.42)) }
                    card
                        .id(step)
                        .transaction { $0.animation = nil }
                        .frame(maxWidth: 460)
                    if above { Spacer().frame(height: min(geometry.size.height - highlight.minY + 18, geometry.size.height * 0.42)) }
                    else { Spacer(minLength: 16) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("session-introduction")
        .onAppear { titleFocused = true }
        .onChange(of: step) { titleFocused = true }
    }
    private var card: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(step + 1) / 4").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(text("skip"), action: dismiss).frame(minHeight: 44)
                    .accessibilityIdentifier("session-introduction-skip")
            }
            Label(text(stepName + ".title"), systemImage: symbols[step])
                .font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
                .accessibilityIdentifier("session-introduction-title")
            Text(text(stepName + ".body"))
                .font(.body).fixedSize(horizontal: false, vertical: true)
            if step == 2 {
                ForEach(Array(["playpause.fill", "forward.end.fill", "backward.end.fill"].enumerated()), id: \.offset) { index, symbol in
                    Label(text("gesture.\(index + 1)"), systemImage: symbol)
                        .font(.callout.weight(.medium))
                }
            }
            HStack(spacing: 12) {
                if step > 0 {
                    Button(text("back")) { DJConnectHaptics.selection(); step -= 1 }
                        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .secondary, usesLiveGlass: false))
                }
                Spacer(minLength: 0)
                Button(text(step == 3 ? "done" : "next")) {
                    DJConnectHaptics.selection()
                    if step == 3 { dismiss() } else { step += 1 }
                }
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, usesLiveGlass: false))
                .accessibilityIdentifier("session-introduction-next")
            }
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(DJConnectMaterial(.regular), in: RoundedRectangle(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).stroke(DJConnectCardAppearance.searchFocusGradient, lineWidth: 1.25).allowsHitTesting(false) }
    }
}
