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

/// Keep the same artwork and controls mounted while resizing the native screen.
struct DJConnectPlaybackHeroLayout: Layout {
    var allowsSideBySide: Bool
    private let artworkWidth: CGFloat = 270
    private let gap: CGFloat = 24

    private func sideBySide(_ width: CGFloat?) -> Bool {
        allowsSideBySide && (width ?? 0) >= 700
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2, sideBySide(proposal.width), let width = proposal.width else {
            let layout = AnyLayout(VStackLayout(spacing: 16))
            var stackCache = layout.makeCache(subviews: subviews)
            return layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &stackCache)
        }
        let artwork = subviews[0].sizeThatFits(.init(width: artworkWidth, height: nil))
        let controls = subviews[1].sizeThatFits(.init(width: width - artworkWidth - gap, height: nil))
        return CGSize(width: width, height: max(artwork.height, controls.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2, sideBySide(bounds.width) else {
            let layout = AnyLayout(VStackLayout(spacing: 16))
            var stackCache = layout.makeCache(subviews: subviews)
            layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &stackCache)
            return
        }
        subviews[0].place(at: bounds.origin, anchor: .topLeading,
                          proposal: .init(width: artworkWidth, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.minX + artworkWidth + gap, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: bounds.width - artworkWidth - gap, height: nil))
    }
}

extension View {
    /// Inline pop-outs own a frosted card; native Mac presentations own their rim.
    /// Both respect the glass preference and stay live over scrolling pages.
    @ViewBuilder func djConnectGlassPopoutSurface(enabled: Bool = true, nativePresentation: Bool = false) -> some View {
        if enabled {
            #if os(macOS)
            if nativePresentation {
                // AppKit already owns the popover's glass, arrow, rim and radius.
                // A second 32pt card inside it creates intersecting corner arcs.
                self.djConnectPresentationSurface()
                    .environment(\.djConnectScrollingSurface, false)
            } else {
                self.djSessionFrostedSurface()
                    .environment(\.djConnectScrollingSurface, false)
            }
            #else
            self.djSessionFrostedSurface()
                .environment(\.djConnectScrollingSurface, false)
            #endif
        } else { self }
    }

    func djSessionFrostedSurface(cornerRadius: CGFloat = DJConnectCardAppearance.cornerRadius, currentMomentBorder: Bool = false, mood: String? = nil, surfaceTint: Color? = nil) -> some View {
        modifier(DJSessionGlassSurface(cornerRadius: cornerRadius, currentMomentBorder: currentMomentBorder, mood: mood, surfaceTint: surfaceTint))
    }

    func djAlbumArtworkGlassCard(artworkURL: URL? = nil) -> some View {
        modifier(DJAlbumArtworkGlassCard(artworkURL: artworkURL))
    }

    /// Player controls share the displayed cover's URL-fenced sample without artwork padding.
    func djPlaybackArtworkGlassCard(artworkURL: URL?) -> some View {
        modifier(DJAlbumArtworkGlassCard(artworkURL: artworkURL, playbackControls: true))
    }

    /// A protected image supplies its already admitted pixel sample, never a URL/cache lookup.
    func djAlbumArtworkGlassCard(tint: Color?) -> some View {
        modifier(DJAlbumArtworkGlassSurface(tint: tint))
    }

    @ViewBuilder func djSessionNavigationTitleStyle() -> some View {
        #if os(iOS)
        // The session has no title; reserve only the toolbar on both iPhone and iPad.
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

/// Sample only the displayed cover, sharing the player's artwork cache.
/// URL-bound state prevents a late previous-cover download from tinting the next cover.
private struct DJAlbumArtworkGlassCard: ViewModifier {
    let artworkURL: URL?
    let playbackControls: Bool
    @State private var sampledTint: Color?
    @State private var sampledURL: URL?

    init(artworkURL: URL?, playbackControls: Bool = false) {
        self.artworkURL = artworkURL
        self.playbackControls = playbackControls
        let cached = artworkURL.flatMap { DJConnectArtworkTintCache.shared.value(for: $0) }
        _sampledTint = State(initialValue: cached?.color)
        _sampledURL = State(initialValue: cached == nil ? nil : artworkURL)
    }

    func body(content: Content) -> some View {
        content
            .modifier(DJArtworkSampledSurface(tint: sampledURL == artworkURL ? sampledTint : nil,
                                               playbackControls: playbackControls))
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

private struct DJArtworkSampledSurface: ViewModifier {
    let tint: Color?
    let playbackControls: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if playbackControls {
            content.modifier(DJSessionGlassSurface(cornerRadius: DJConnectCardAppearance.cornerRadius,
                                                   surfaceTint: tint))
        } else {
            content.djAlbumArtworkGlassCard(tint: tint)
        }
    }
}

/// Identical glass treatment for public player covers and ephemeral admitted artwork.
private struct DJAlbumArtworkGlassSurface: ViewModifier {
    let tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled

    func body(content: Content) -> some View {
        let inset: CGFloat = 8
        let shape = RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius, style: .continuous)
        content
            .clipShape(RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius - inset, style: .continuous))
            .padding(inset)
            .background { shape.fill(tint?.opacity(reduceTransparency || !glassEnabled ? 1 : 0.72) ?? .clear) }
            // Isolate the background from the Session's shared glass compositor;
            // otherwise it can cover the pixels and later gesture feedback.
            .background {
                GlassEffectContainer(spacing: 0) {
                    Color.clear.djSessionFrostedSurface()
                }
            }
            .overlay {
                if let tint {
                    shape.stroke(tint.opacity(0.8), lineWidth: DJConnectCardAppearance.borderWidth)
                        .allowsHitTesting(false)
                }
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
    var mood: String? = nil
    var surfaceTint: Color? = nil
    @Environment(\.currentMomentArtworkTint) private var artworkTint
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled
    @Environment(\.djConnectScrollingSurface) private var scrollingSurface
    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let tint = surfaceTint ?? (currentMomentBorder ? artworkTint : nil)
        let moodColors = DJConnectSessionMoodTheme(sessionMood: mood).colorValues.map { value in
            Color(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
        }
        let borderGradient = LinearGradient(colors: moodColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        let bordered = content.background {
            if let tint {
                shape.fill(LinearGradient(
                    colors: [tint.opacity(reduceTransparency ? 0.85 : 0.38),
                             tint.opacity(reduceTransparency ? 0.65 : 0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }.overlay {
            shape.stroke(currentMomentBorder ? AnyShapeStyle(borderGradient) : AnyShapeStyle(Color.white.opacity(DJConnectCardAppearance.borderOpacity)),
                         lineWidth: DJConnectCardAppearance.borderWidth + (currentMomentBorder ? 1 : 0))
                .allowsHitTesting(false)
        }
        if !glassEnabled || reduceTransparency {
            bordered.background(DJConnectGlassAppearance.opaqueSurface, in: shape)
        } else if scrollingSurface {
            bordered.background(DJConnectMaterial(.ultraThin), in: shape)
        } else if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, *) {
            // One native glass node keeps its content (especially the avatar's
            // interaction/focus state) mounted when the card changes emphasis.
            #if os(iOS)
            let glassTint = tint?.opacity(0.22) ??
                (currentMomentBorder && UIDevice.current.userInterfaceIdiom == .pad ? Color.white.opacity(0.12) : nil)
            #else
            let glassTint = tint?.opacity(0.22)
            #endif
            bordered.glassEffect(.regular.tint(glassTint), in: shape)
        } else { bordered.background(DJConnectMaterial(.ultraThin), in: shape) }
    }
}

/// Share the glass compositor across visible cards without merging separated bubbles.
struct DJSessionGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.djConnectGlassEffectsEnabled) private var glassEnabled
    @Environment(\.djConnectScrollingSurface) private var scrollingSurface
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if #available(iOS 26, macOS 26, watchOS 26, tvOS 26, *), glassEnabled && !reduceTransparency && !scrollingSurface {
            GlassEffectContainer(spacing: 0) { content }
        } else {
            content
        }
    }
}

/// Only geometry is retained across incomplete delivery. Content admission stays
/// exclusively in nativeCurrentMoment and the existing local withdrawal guard.
enum SessionCurrentDJCardState: Equatable {
    case compact, expanded, unresolved

    static func resolve(session: DJConnectSessionRuntime, moment: DJConnectMoment?,
                        recovering: Bool, unavailable: Bool, withdrawn: Bool = false, at now: Date) -> Self {
        guard !recovering, !unavailable, session.runtimeState == "active",
              session.broadcast.playback?.state == "playing", moment == nil else { return .expanded }
        let broadcast = session.broadcast
        guard broadcast.session.runtimeState == "active",
              let authority = broadcast.nativeDelivery, authority.schemaVersion == 1,
              authority.sessionID == session.id, broadcast.session.sessionID == session.id,
              authority.revocationScope == "session", !authority.revision.isEmpty else { return .unresolved }
        if let id = authority.currentMomentID {
            guard authority.currentSilenceMomentID == nil else { return .unresolved }
            if withdrawn { return .compact }
            // A known existing presentation deadline may end the display before
            // the next snapshot clears currentMomentID. Never invent a timer.
            let admissions = authority.admissions.filter { $0.momentID == id }
            guard broadcast.djMoments.contains(where: { $0.id == id && $0.sessionID == session.id }),
                  admissions.count == 1, let admission = admissions.first,
                  admission.qualification == "qualified",
                  let displayDeadline = admission.displayExpiresAt.flatMap(DJConnectHistoryEntry.date) else { return .unresolved }
            let sourceDeadline = admission.sourceExpiresAt.flatMap(DJConnectHistoryEntry.date)
            guard admission.sourceExpiresAt == nil || sourceDeadline != nil else { return .unresolved }
            return !admission.currentDisplayAllowed || displayDeadline <= now || sourceDeadline.map({ $0 <= now }) == true ? .compact : .unresolved
        }
        guard authority.currentSilenceMomentID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != true else { return .unresolved }
        return .compact
    }
}

/// Finite numeric geometry avoids animating a nil/infinite frame, which can
/// briefly clip the avatar to zero and expose detail outside the glass. Detail
/// is measured at its final width throughout the transition, never reflowed.
struct SessionCurrentDJCardLayout: Layout {
    let sessionID: String
    var expansion: CGFloat
    let hasDetail: Bool
    let heldSize: CGSize?
    var animatableData: CGFloat { get { expansion } set { expansion = newValue } }
    struct Cache {
        var sessionID: String
        var fullWidth: CGFloat = 640
        var expandedHeight: CGFloat = DJConnectCardAppearance.currentDJAvatarSize + 2 * DJConnectCardAppearance.currentDJInset
    }
    func makeCache(subviews: Subviews) -> Cache { Cache(sessionID: sessionID) }
    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        // Default cache rebuilding on 2→1 children would lose the measured
        // expanded height during collapse. Keep only sizes, never a detail view.
        if cache.sessionID != sessionID { cache = Cache(sessionID: sessionID) }
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        if cache.sessionID != sessionID { cache = Cache(sessionID: sessionID) }
        let avatar = DJConnectCardAppearance.currentDJAvatarSize
        let inset = DJConnectCardAppearance.currentDJInset
        let side = avatar + 2 * inset
        if let width = proposal.width, width.isFinite { cache.fullWidth = max(side, width) }
        if hasDetail, subviews.count > 1 {
            let detail = subviews[1].sizeThatFits(.init(width: max(0, cache.fullWidth - avatar - 16 - 2 * inset), height: nil))
            if detail.height.isFinite { cache.expandedHeight = max(avatar, detail.height) + 2 * inset }
        }
        let fraction = expansion.isFinite ? max(0, min(1, expansion)) : 0
        return CGSize(width: heldSize.map { min(cache.fullWidth, $0.width) } ?? side + (cache.fullWidth - side) * fraction,
                      height: heldSize?.height ?? side + (cache.expandedHeight - side) * fraction)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard let avatar = subviews.first else { return }
        let inset = DJConnectCardAppearance.currentDJInset
        let side = DJConnectCardAppearance.currentDJAvatarSize
        avatar.place(at: CGPoint(x: bounds.minX + inset, y: bounds.minY + inset), anchor: .topLeading,
                     proposal: .init(width: side, height: side))
        if subviews.count > 1 {
            subviews[1].place(at: CGPoint(x: bounds.minX + inset + side + 16, y: bounds.minY + inset), anchor: .topLeading,
                             proposal: .init(width: max(0, cache.fullWidth - side - 16 - 2 * inset), height: nil))
        }
    }
}

/// The same avatar stays at the same structural position in both formats. Only
/// confirmed geometry (never text, admission or audio state) survives a partial read.
struct SessionCurrentDJCard<Avatar: View, Detail: View>: View {
    let sessionID: String
    let state: SessionCurrentDJCardState
    let mood: String?
    @ViewBuilder let avatar: () -> Avatar
    @ViewBuilder let detail: () -> Detail
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private struct Observation: Equatable { let sessionID: String; let state: SessionCurrentDJCardState; let visible: Bool? }
    private struct GeometryMemory { var sessionID: String?; var compact = false; var size: CGSize = .zero }
    @State private var remembered = GeometryMemory()
    @State private var visible: Bool?
    private var mayResize: Bool { visible != false || remembered.sessionID != sessionID }
    private var compact: Bool {
        if !mayResize { return remembered.compact }
        return switch state {
        case .compact: true
        case .expanded: false
        case .unresolved: remembered.sessionID == sessionID && remembered.compact
        }
    }
    var body: some View {
        SessionCurrentDJCardLayout(sessionID: sessionID, expansion: compact ? 0 : 1,
            hasDetail: state == .expanded && !compact,
            heldSize: (state == .unresolved || !mayResize) && remembered.sessionID == sessionID && remembered.size.height > 0 ? remembered.size : nil) {
            avatar()
            if state == .expanded && !compact { detail().transition(.identity) }
        }
        // An offscreen height change makes native lazy scrolling re-estimate
        // rows above the reader. Freeze only geometry until this card returns;
        // never cache a moment or issue a scroll request. Clip before the glass
        // so offscreen replacement text cannot spill into retained Flow rows.
        .clipShape(DJConnectCardAppearance.shape)
        .djSessionFrostedSurface(currentMomentBorder: !compact, mood: mood)
        .accessibilityElement(children: .contain)
        .onScrollVisibilityChange(threshold: 0.01) { visible = $0 }
        .onChange(of: Observation(sessionID: sessionID, state: state, visible: visible), initial: true) { _, observation in
            var next = remembered
            if next.sessionID != observation.sessionID { next = GeometryMemory(sessionID: observation.sessionID) }
            if observation.state != .unresolved && observation.visible != false { next.compact = observation.state == .compact }
            remembered = next
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            if state != .unresolved && mayResize { remembered = GeometryMemory(sessionID: sessionID, compact: state == .compact, size: size) }
        }
        .animation(djSessionReducedMotion(reduceMotion) ? nil : .easeInOut(duration: 0.2), value: compact)
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
    var onPlaybackOutputQuestion: () -> Void = {}
    var onContributionQuestion: () -> Void = {}
    var contributionQuestion: String? = nil
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
        VStack(alignment: .leading, spacing: 24) {
            SessionCurrentColumns(stacked: true) {
                // Keep the artwork's asynchronous crossfade outside the timeline's
                // clock-driven rendering and the current DJ card's animation.
                musicContext
                TimelineView(.periodic(from: .now, by: 1)) { clock in
                    let current = currentMoment(at: clock.date)
                    currentCard(current, at: clock.date)
                        .modifier(CurrentMomentArtworkTint(artworkURL: musicArtworkURL))
                        .accessibilityIdentifier("session-current-card")
                        .animation(djSessionReducedMotion(reduceMotion) ? nil : .easeInOut(duration: 0.2), value: current?.id)
                }
            }
            .accessibilityElement(children: .contain)
            .id("native-session-current")
        }
        .frame(maxWidth: 1000, alignment: .leading)
        .frame(maxWidth: .infinity)
        .djConnectPopup(isPresented: Binding(get: { playbackModel?.momentTrackInsightTarget != nil }, set: { if !$0 { playbackModel?.dismissMomentTrackInsight() } })) {
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

    private func currentMoment(at date: Date) -> DJConnectMoment? {
        guard let moment = session.broadcast.nativeCurrentMoment(at: date, spotifyAttributionAvailable: spotifyAttributionLogo != nil),
              playbackModel?.sessionHistory.contentMomentWasWithdrawn(sessionID: session.id, momentID: moment.id) != true else { return nil }
        return moment
    }

    private func kind(_ moment: DJConnectMoment) -> String {
        let mapped = ["track": "track_context", "artist": "artist_story", "album": "album_story", "genre": "genre_story", "session": "session_direction"][moment.type] ?? moment.type
        let key = "ui.session.moment.\(mapped)"
        let value = text(key)
        return value == key ? text("ui.session.moment.generic") : value
    }

    private func presentation(for moment: DJConnectMoment) -> DJConnectPresentation? {
        session.broadcast.presentations.last { $0.momentID == moment.id }
    }

    func currentCard(_ moment: DJConnectMoment?, at now: Date = Date()) -> some View {
        let withdrawn = session.broadcast.nativeDelivery?.currentMomentID.map {
            playbackModel?.sessionHistory.contentMomentWasWithdrawn(sessionID: session.id, momentID: $0) == true
        } ?? false
        let state = SessionCurrentDJCardState.resolve(session: session, moment: moment,
            recovering: isRecovering, unavailable: isLiveUnavailable, withdrawn: withdrawn, at: now)
        let evidence = playbackModel?.personaEvidence(for: session, admittedMoment: moment, at: now) ?? .init()
        return SessionCurrentDJCard(sessionID: session.id, state: state,
            mood: isLiveUnavailable || isRecovering ? nil : session.selectedMood) {
            let avatar = DJPersonaAvatarView(confirmedMood: isLiveUnavailable || isRecovering ? nil : session.selectedMood, language: language,
                                            activity: DJPersonaActivity.resolve(evidence), speechIsPlaying: evidence.speaking)
                .frame(width: DJConnectCardAppearance.currentDJAvatarSize, height: DJConnectCardAppearance.currentDJAvatarSize).fixedSize()
            if let playbackModel { PersonaReactionAvatar(model: playbackModel, avatar: avatar) }
            else { avatar }
        } detail: {
            currentCardContent(moment)
        }
    }

    @ViewBuilder private func currentCardContent(_ moment: DJConnectMoment?) -> some View {
        if isLiveUnavailable {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("ui.session.live_unavailable")).font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Button(text("ui.retry"), action: retryConnection)
            }
        } else if isRecovering {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("ui.session.reconnecting")).font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
        } else if session.runtimeState == "active", session.broadcast.playback?.state == "paused",
                  moment?.isSettingsConfirmation != true {
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
            .accessibilityIdentifier("session-playback-paused")
        } else if let moment {
            let actionEpoch = playbackModel?.sessionHistory.responseEpoch
            MomentCard(moment: moment, kind: kind(moment), presentation: presentation(for: moment), language: language,
                navigationLabel: insightOffer(for: moment)?.label,
                openInsight: { if let offer = insightOffer(for: moment) { playbackModel?.openMomentTrackInsight(offer) } },
                artworkMedia: session.broadcast.sessionMedia.first { $0.sessionID == session.id && $0.target == .moment(moment.id) },
                artworkModel: playbackModel,
                speech: session.broadcast.sessionSpeech.first { $0.reference == .moment(sessionID: session.id, momentID: moment.id) },
                contributionQuestion: contributionQuestion,
                contributionAction: {
                    guard let model = playbackModel, let actionEpoch,
                          model.sessionHistory.exploreContribution(moment, expectedEpoch: actionEpoch) else { return }
                    DJConnectHaptics.selection(); onContributionQuestion()
                })
                .id(moment.id)
                .djContentDeletion(model: playbackModel, target: .init(kind: "moment", sessionID: session.id, targetID: moment.id))
                .accessibilityIdentifier("session-current-moment")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(text("ui.session.start_here.title"))
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                if session.broadcast.playback?.state != "playing" {
                    Text(text("ui.session.start_here.detail"))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
            CachedArtworkImage(url: musicArtworkURL, mode: .fit, usesAlbumGlassFrame: true, animatesArtworkChanges: true) {
                AlbumArtworkPlaceholder(tint: djConnectAccent,
                    isPlaying: session.broadcast.playback?.state == "playing" && !artworkIsPaused)
            }
                .aspectRatio(1, contentMode: .fit)
                // The base cover determines geometry. Neither the native hit
                // surface nor an initially empty feedback view participates in sizing.
                .overlay {
                    SessionArtworkTapSurface(action: handleArtworkTap, touchBegan: {
                        if artworkIsPaused, playbackModel?.canUsePlaybackFeatures == true {
                            hidesArtworkPlayOnTouch = true
                            artworkTouchID = UUID()
                        }
                    }, touchCancelled: { hidesArtworkPlayOnTouch = false })
                }
                // Paint feedback last, above the native touch plane and the
                // complete glass/crossfade subtree; it never intercepts taps.
                .overlay(alignment: .center) {
                    artworkPlaybackOverlay
                        .allowsHitTesting(false)
                }
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
        if ["play", "pause"].contains(command), playbackModel.needsSessionPlaybackOutputSelection {
            hidesArtworkPlayOnTouch = false
            if playbackModel.sessionHistory.requestSessionSpeakerChoice(sessionID: session.id) {
                onPlaybackOutputQuestion()
            }
            return
        }
        let isSkip = command == "next" || command == "previous"
        hidesArtworkPlayDuringSkip = isSkip
        // Keep the paused affordance out of the track-transition feedback.
        // Start the settle window only when the request finishes.
        let generation = UUID()
        artworkActionGeneration = generation
        let epoch = playbackModel.sessionHistory.responseEpoch
        // Acknowledge every gesture immediately, including resuming playback.
        playArtworkHaptic(command)
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.8)) {
            hidesArtworkPlayOnTouch = false
            artworkFeedback = ArtworkFeedback(command: command)
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

    private var usesLargePlaybackTypography: Bool {
        #if os(macOS)
        true
        #elseif os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    private var musicDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let playback = session.broadcast.playback {
                if let title = playback.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(title).font(usesLargePlaybackTypography ? .title.bold() : .headline)
                }
                if let artist = playback.artist {
                    Text(artist).font(usesLargePlaybackTypography ? .title2 : .body).foregroundStyle(.secondary)
                }
                if let album = playback.album {
                    Text(album).font(usesLargePlaybackTypography ? .body : .caption).foregroundStyle(.secondary)
                }
                if usesLargePlaybackTypography { Spacer(minLength: 0) }
                if let duration = playback.durationMS, duration > 0, let position = playbackModel?.displayedSessionPositionMS(session) ?? playback.positionMS {
                    let current = max(0, min(position, duration))
                    if let model = playbackModel {
                        SessionPlaybackCardButton(model: model, session: session, position: current, duration: duration)
                            .id(session.id)
                    } else {
                        SessionMusicProgress(position: current, duration: duration, isPlaying: playback.state == "playing")
                            .accessibilityLabel(text("ui.session.music_progress"))
                    }
                    HStack(alignment: .center, spacing: 8) {
                        if let playbackModel, playbackModel.canToggleSessionFavorite(session) {
                            FavoriteTrackButton(model: playbackModel, identifier: "session-favorite-button", sessionContext: session)
                                .disabled(!playbackModel.canUsePlaybackFeatures || playbackModel.isRefreshing)
                        }
                        Spacer(minLength: 0)
                        Text("\(sessionPlaybackTime(current)) / \(sessionPlaybackTime(duration))")
                            .font((usesLargePlaybackTypography ? Font.body : .caption).monospacedDigit()).foregroundStyle(.secondary)
                            .accessibilityLabel(text("ui.session.music_duration"))
                            .accessibilityValue("\(sessionPlaybackTime(current)) / \(sessionPlaybackTime(duration))")
                    }
                }
                if let playbackOutputName {
                    HStack(alignment: .center, spacing: 8) {
                        if let model = playbackModel {
                            SessionPlaybackOutputButton(model: model, name: playbackOutputName)
                                .id(session.id)
                        } else {
                            Label(playbackOutputName, systemImage: "hifispeaker.fill")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if let model = playbackModel {
                            SessionPlaybackVolumeButton(model: model).id(session.id)
                        } else { Text("-").fixedSize() }
                    }
                    .font(usesLargePlaybackTypography ? .callout : .caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-music-details")
        .frame(maxWidth: .infinity, maxHeight: usesLargePlaybackTypography ? .infinity : nil, alignment: .topLeading)
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
        // Give the details the full cover-row height so their progress/output
        // group aligns with the bottom of the artwork. Natural text height still
        // wins in sizeThatFits when long text or accessibility sizes need more room.
        subviews[1].place(at: CGPoint(x: bounds.minX + music + gap, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: card, height: bounds.height))
    }
}

/// Anchored to the current speaker; uses the same backend inventory and command
/// path as Now Playing, including pending/confirmed output selection.
struct SessionPlaybackOutputButton: View {
    @ObservedObject var model: DJConnectAppModel
    let name: String
    @State private var showsOutputs = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Button { showsOutputs.toggle() } label: {
            Label(name, systemImage: "hifispeaker.fill")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .djConnectPlainButtonStyle()
        .disabled(!model.canUsePlaybackFeatures)
        .accessibilityLabel(DJConnectLocalization.localized(key: "ui.output.device", language: model.language))
        .accessibilityValue(name)
        .accessibilityIdentifier("session-playback-output")
        .popover(isPresented: $showsOutputs) {
            OutputSelectorView(scrollsOutputs: true, model: model)
                .padding(16)
                .frame(minWidth: 280, idealWidth: 360, maxWidth: 400)
                .environment(\.djConnectScrollingSurface, false)
                #if os(macOS)
                // AppKit owns the glass, arrow and rounded rim. No inner card.
                .djConnectPresentationSurface()
                #else
                .djConnectGlassPopoutSurface()
                .djConnectPresentationSurface()
                #endif
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: model.canUsePlaybackFeatures) { _, available in
            if !available { showsOutputs = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { showsOutputs = false }
        }
    }
}

struct SessionPlaybackVolumeButton: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var showsVolume = false
    @Environment(\.scenePhase) private var scenePhase
    var canPresentVolume: Bool {
        model.canUsePlaybackFeatures && model.canControlPlaybackVolume &&
            model.playback?.device?.active != false && model.volumeOutputKey != nil &&
            model.pendingOutputSelectionID == nil
    }
    var body: some View {
        Button { showsVolume.toggle() } label: {
            Group {
                if model.currentPlaybackUsesLocalBluetooth {
                    BluetoothOutputSymbol()
                        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 12, height: 18)
                } else if let volume = model.currentPlaybackVolumePercent {
                    Label("\(volume)%", systemImage: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                } else { Text("-") }
            }
            .fixedSize().frame(minHeight: 44).contentShape(Rectangle())
        }
        .djConnectPlainButtonStyle()
        .disabled(!canPresentVolume)
        .accessibilityLabel(DJConnectLocalization.localized(key: "watch.volume", language: model.language))
        .accessibilityValue(model.currentPlaybackUsesLocalBluetooth ? "Bluetooth" : model.currentPlaybackVolumePercent.map { "\($0)%" } ?? "-")
        .accessibilityIdentifier("session-playback-volume")
        .popover(isPresented: $showsVolume) {
            SessionPlaybackVolumePanel(model: model)
                .padding(20).frame(width: 320)
                .environment(\.djConnectScrollingSurface, false)
                #if os(macOS)
                .djConnectPresentationSurface()
                #else
                .djConnectGlassPopoutSurface().djConnectPresentationSurface()
                #endif
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: canPresentVolume) { _, allowed in if !allowed { showsVolume = false } }
        .onChange(of: model.volumeOutputKey) { _, _ in showsVolume = false }
        .onChange(of: scenePhase) { _, phase in if phase != .active { showsVolume = false } }
    }
}

struct SessionPlaybackVolumePanel: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var draft: Double?
    @State private var editingOutput: String?
    private var allowed: Bool { SessionPlaybackVolumeButton(model: model).canPresentVolume }
    private var value: Double { draft ?? Double(model.currentPlaybackVolumePercent ?? Int(model.volume)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(DJConnectLocalization.localized(key: "watch.volume", language: model.language))
                .font(.headline).accessibilityAddTraits(.isHeader)
            if let name = model.playback?.device?.name { Text(name).font(.callout).foregroundStyle(.secondary) }
            HStack(spacing: 12) {
                Image(systemName: value == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                Slider(value: Binding(get: { value }, set: { draft = $0 }), in: 0...100) { editing in
                    if editing { editingOutput = model.volumeOutputKey }
                    else {
                        defer { draft = nil; editingOutput = nil }
                        guard allowed, let editingOutput, editingOutput == model.volumeOutputKey else { return }
                        model.volume = value
                        DJConnectHaptics.selection()
                        model.commitVolumeChange()
                    }
                }
                .tint(djConnectAccent).disabled(!allowed)
                .accessibilityLabel(DJConnectLocalization.localized(key: "watch.volume", language: model.language))
                .accessibilityIdentifier("session-volume-slider")
                Text("\(Int(value.rounded()))%").monospacedDigit().frame(minWidth: 44, alignment: .trailing)
            }
        }
        .onChange(of: model.volumeOutputKey) { _, _ in draft = nil; editingOutput = nil }
    }
}

/// The decorative meter has its own clock so it never re-renders the Session timeline.
private struct SessionMusicProgress: View {
    let position: Int
    let duration: Int
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 8) {
            SessionPlaybackEqualizer(isPlaying: isPlaying)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            ProgressView(value: Double(position), total: Double(max(duration, 1)))
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SessionPlaybackEqualizer: View {
    let isPlaying: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !isPlaying || scenePhase != .active || reduceMotion)) { clock in
            Canvas { context, size in
                let time = clock.date.timeIntervalSinceReferenceDate
                let animated = isPlaying && scenePhase == .active && !reduceMotion
                let resting: [Double] = isPlaying ? [0.85, 0.35, 0.62, 0.25] : [0.16, 0.16, 0.16, 0.16]
                for index in 0..<4 {
                    let phase = Double(index) * 1.7
                    let level = animated ? 0.18 + 0.82 * (0.5 + 0.5 * sin(time * (4.2 + Double(index) * 0.7) + phase)) : resting[index]
                    let height = max(3, size.height * level)
                    let bar = CGRect(x: Double(index) * 5, y: size.height - height, width: 3, height: height)
                    context.fill(Path(roundedRect: bar, cornerRadius: 0.75), with: .color(djConnectAccent))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SessionPlaybackCardButton: View {
    @ObservedObject var model: DJConnectAppModel
    let session: DJConnectSessionRuntime
    let position: Int
    let duration: Int
    @State private var showsPlayback = false
    @Environment(\.scenePhase) private var scenePhase
    var canOpenPlayback: Bool { model.canToggleSessionFavorite(session) }
    private var context: [String?] {
        [session.id, session.broadcast.playback?.itemID, session.broadcast.playback?.sourceURL,
         session.broadcast.playback?.title, session.broadcast.playback?.artist]
    }
    var body: some View {
        Button { showsPlayback.toggle() } label: {
            SessionMusicProgress(position: position, duration: duration,
                                 isPlaying: model.playback?.isPlaying ?? (session.broadcast.playback?.state == "playing"))
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .djConnectPlainButtonStyle()
        .disabled(!canOpenPlayback)
        .accessibilityLabel(DJConnectLocalization.localized(key: "ui.playback", language: model.language))
        .accessibilityValue("\(sessionPlaybackTime(position)) / \(sessionPlaybackTime(duration))")
        .accessibilityIdentifier("session-playback-card-open")
        .popover(isPresented: $showsPlayback) {
            ScrollView {
                NowPlayingPlaybackCardContent(model: model).padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(minWidth: 280, idealWidth: 380, maxWidth: 440, maxHeight: 460)
            .environment(\.djConnectScrollingSurface, false)
            #if os(macOS)
            // Let AppKit draw the single native glass rim and corner radius.
            .djConnectPresentationSurface()
            #else
            .djConnectGlassPopoutSurface().djConnectPresentationSurface()
            #endif
            .presentationCompactAdaptation(.popover)
        }
        .onChange(of: context) { _, _ in showsPlayback = false }
        .onChange(of: canOpenPlayback) { _, allowed in if !allowed { showsPlayback = false } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { showsPlayback = false } }
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
    var contributionQuestion: String? = nil
    var contributionAction: (() -> Void)? = nil
    private var spotifyURLs: [URL] { moment.nativeSourceURLs.filter(SessionSourceLinks.isSpotify) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let media = artworkMedia, let model = artworkModel {
                SessionArtworkView(media: media, target: .moment(moment.id), audience: .current, language: language, model: model,
                    showsAttribution: spotifyURLs.isEmpty)
            }
            if moment.isBulletinV1 {
                Label(kind, systemImage: "newspaper").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
            } else { Text(kind).font(.caption.weight(.bold)).foregroundStyle(.secondary) }
            if !moment.isBulletinV1 && !moment.title.isEmpty { Text(moment.title).font(.title2.bold()).accessibilityAddTraits(.isHeader) }
            Text(moment.content).font(.title3).fixedSize(horizontal: false, vertical: true)
                .modifier(ContributionContentAction(question: contributionQuestion, action: contributionAction))
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
            HStack(alignment: .center, spacing: 12) {
                SessionSpotifyAttributionLinks(urls: spotifyURLs)
                if let model = artworkModel { SharedDJSpeechActions(model: model, speech: speech, acceptedText: moment.content) }
            }
            ForEach(moment.nativeSourceURLs.filter { !SessionSourceLinks.isSpotify($0) }, id: \.absoluteString) { url in
                let source = moment.isBulletinV1 ? moment.sources.first { $0.destination == url } : nil
                let label = source?.attributionLabel ?? moment.sourceAttribution?["provider"] ?? url.host ?? ""
                Link(label, destination: url)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .accessibilityLabel(source?.accessibilityLabel ?? label)
                    .accessibilityValue(url.absoluteString)
                    .accessibilityIdentifier("moment-source-" + url.absoluteString)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// One branded credit, with every distinct Spotify destination still reachable.
struct SessionSpotifyAttributionLinks: View {
    let urls: [URL]
    var body: some View {
        if let logo = spotifyAttributionLogo, let first = urls.first {
            let mark = logo.resizable().scaledToFit().frame(width: 70, height: 20)
                .padding(10).frame(minHeight: 44).contentShape(Rectangle())
            Group {
                if urls.count == 1 {
                    Link(destination: first) { mark }
                        .accessibilityValue(first.absoluteString)
                } else {
                    Menu {
                        ForEach(urls, id: \.absoluteString) { url in
                            Link(SessionSourceLinks.destinationLabel(url), destination: url)
                                .accessibilityValue(url.absoluteString)
                        }
                    } label: { mark }
                    .menuIndicator(.hidden)
                    #if os(macOS)
                    .menuStyle(.borderlessButton)
                    #endif
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Spotify")
            .accessibilityIdentifier("session-spotify-attribution")
        }
    }
}

var spotifyAttributionLogo: Image? {
    #if os(iOS)
    UIImage(named: "SpotifyAttribution").map { Image(uiImage: $0) }
    #elseif os(macOS)
    // Native Menu labels use NSImage's logical size before SwiftUI layout.
    // Size a copy so the asset cache and its original pixels remain untouched.
    if let logo = NSImage(named: NSImage.Name("SpotifyAttribution"))?.copy() as? NSImage,
       logo.size.width > 0, logo.size.height > 0 {
        let scale = min(70 / logo.size.width, 20 / logo.size.height)
        logo.size = NSSize(width: logo.size.width * scale, height: logo.size.height * scale)
        return Image(nsImage: logo)
    }
    return nil
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
    @Published var highlightsToolbar = false
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
    @ViewBuilder
    func sessionIntroductionTarget(_ name: String) -> some View {
        #if os(macOS)
        if name.hasPrefix("toolbar-") {
            modifier(SessionIntroductionMacToolbarTarget())
        } else {
            background(SessionIntroductionTargetReader(name: name))
        }
        #else
        background(SessionIntroductionTargetReader(name: name))
        #endif
    }
}

#if os(macOS)
private struct SessionIntroductionMacToolbarTarget: ViewModifier {
    @Environment(\.sessionIntroductionAnchors) private var anchors

    func body(content: Content) -> some View {
        content.overlay {
            if let anchors {
                SessionIntroductionToolbarRing(anchors: anchors)
            }
        }
    }
}

private struct SessionIntroductionToolbarRing: View {
    @ObservedObject var anchors: SessionIntroductionAnchors

    var body: some View {
        if anchors.highlightsToolbar {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.95), lineWidth: 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
#endif

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
        #if os(macOS)
        guard let origin = anchors.frames["overlay"]?.origin else { return .zero }
        #else
        let origin = geometry.frame(in: .global).origin
        #endif
        return frame.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -6, dy: -6)
            .intersection(CGRect(origin: .zero, size: geometry.size).insetBy(dx: 4, dy: 4))
    }
    var body: some View {
        GeometryReader { geometry in
            let highlight = target(in: geometry)
            let above = !highlight.isEmpty && highlight.midY > geometry.size.height / 2
            #if os(macOS)
            let toolbarStep = step == 0
            #else
            let toolbarStep = false
            #endif
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
                    if toolbarStep { Spacer().frame(height: 16) }
                    else if above || highlight.isEmpty { Spacer(minLength: 16) }
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
        #if os(macOS)
        .background(SessionIntroductionTargetReader(name: "overlay")
            .environment(\.sessionIntroductionAnchors, anchors))
        .onChange(of: step, initial: true) { _, step in anchors.highlightsToolbar = step == 0 }
        .onDisappear { anchors.highlightsToolbar = false }
        #endif
        .onAppear { titleFocused = true }
        .onChange(of: step) { titleFocused = true }
    }
    private var card: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(step + 1) / 4").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(text("skip"), action: dismiss).frame(minHeight: 44)
                    .buttonStyle(.plain)
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
                        .buttonStyle(.glass)
                        .controlSize(.large)
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
        .djSessionFrostedSurface(cornerRadius: 26)
        .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(DJConnectCardAppearance.searchFocusGradient, lineWidth: 1.25).allowsHitTesting(false) }
    }
}
