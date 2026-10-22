import SwiftUI
import DJConnectCore

/// Whole-track server analysis only; this is not a beat or live-audio signal.
/// Current Core has no qualified numeric analysis basis. A finite legacy/demo
/// scalar and matching metadata cannot establish that qualification.
enum VibeScapeTrackIntensity {
    static func resolve(insight: TrackInsight?, playback: DJConnectSessionPlayback?, numericBasisQualified: Bool = false) -> Float? {
        guard numericBasisQualified,
              let insight, let playback, let item = playback.itemID, !item.isEmpty,
              playback.state == "playing" || playback.state == "paused",
              !insight.hasUnavailableAnalysis, insight.verifiedCredit == nil,
              insight.analysisBasis != "qualified_credit_and_interpretation_v1",
              let value = insight.intensity, value.isFinite, (0...1).contains(value),
              let title = normalized(playback.title), let artist = normalized(playback.artist),
              title == normalized(insight.title), artist == normalized(insight.artist) else { return nil }
        if let album = normalized(playback.album), let analysisAlbum = normalized(insight.album), album != analysisAlbum { return nil }
        if let milliseconds = playback.durationMS, let duration = insight.duration {
            guard milliseconds > 0, duration.isFinite, duration > 0,
                  abs(Double(milliseconds)/1000-duration) <= 1.5 else { return nil }
        }
        return Float(value)
    }
    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

enum VibeScapeAvailability {
    static var previewEnabled: Bool {
        #if DJCONNECT_VIBESCAPE_PREVIEW
        true
        #else
        false
        #endif
    }
}

/// Entire visual visit is mounted at root, above navigation/tab chrome. Existing
/// Flow and Forecast views remain mounted behind it, preserving their positions.
struct VibeScapeScreen: View {
    @ObservedObject var model: DJConnectAppModel
    @StateObject private var visit = VisualDirectorVisit()
    @State private var controlsVisible = true
    @State private var controlsGeneration = UUID()
    @State private var adjustingDynamics = false
    @State private var canvasBounds = CGRect.zero
    @State private var modeBounds = CGRect.zero
    @State private var sliderBounds = CGRect.zero
    @State private var lastStrokePoint: CGPoint?
    @State private var lastStrokeTime: TimeInterval = 0
    @State private var lastInteractionHaptic: TimeInterval?
    @State private var unavailable = false
    @State private var showsVoiceHelp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var owner: String? { model.sessionHistory.authorizedProfileID }
    private var automaticIntensity: Float? {
        VibeScapeTrackIntensity.resolve(insight: model.currentTrackInsight,
                                       playback: model.activeDJSession?.broadcast.playback)
    }
    // Core has not yet delivered an authoritative playback occurrence. Neither
    // history IDs nor polling timestamps can grant current-track voice scope.
    // The preview resets on a changed item; live voice remains unavailable.
    private var admitted: Bool {
        model.isDemoMode || (model.pairingStatus == .paired && owner != nil && model.activeDJSession?.runtimeState == "active")
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key,language: model.language) }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !unavailable {
                VibeScapeMetalView(visit: visit,reduceMotion: reduceMotion,unavailable: { unavailable = true })
                    .ignoresSafeArea().accessibilityHidden(true)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { canvasBounds = $0 }
                    .gesture(canvasInteraction)
            }
            if unavailable {
                Text(text("ui.vibescape.unavailable"))
                    .foregroundStyle(.white).padding(28).accessibilityIdentifier("vibescape-unavailable")
            }
            GeometryReader { geometry in
            VStack {
                SessionModeToggleButtons(showsForecast: Binding(get: { false }, set: { forecast in
                    model.vibeScapeReturnToForecast = forecast; close()
                }), language: model.language, openVibeScape: { toggleControls() }, isVibeScape: true, mood: model.activeDJSession?.selectedMood)
                    .padding(.horizontal, 20)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { modeBounds = $0 }
                    .padding(.top, pickerTop(in: geometry))
                    .opacity(controlsVisible ? 1 : 0)
                    .allowsHitTesting(controlsVisible)
                    .accessibilityHidden(!controlsVisible)
                Spacer()
                if showsVoiceHelp {
                    Label(text("ui.vibescape.voice.unavailable"),systemImage:"mic.slash")
                        .font(.callout).padding(16).djSessionFrostedSurface()
                        .padding(24).transition(.opacity)
                        .accessibilityIdentifier("vibescape-voice-unavailable")
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            guard !Task.isCancelled else { return }
                            withAnimation(reduceMotion ? nil : .easeOut(duration:0.25)) { showsVoiceHelp = false }
                        }
                }
            }
            }
            GeometryReader { geometry in
                HStack {
                    Spacer(minLength: 0)
                    dynamicsControl(length: min(240, max(100, geometry.size.height - 180)))
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sliderBounds = $0 }
                }
                .padding(.trailing, 12)
                .frame(maxHeight: .infinity)
            }
            .opacity(controlsVisible ? 1 : 0)
            .allowsHitTesting(controlsVisible)
            .accessibilityHidden(!controlsVisible)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: controlsVisible)
        .task(id: controlsGeneration) {
            guard controlsVisible, !adjustingDynamics else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled, !adjustingDynamics else { return }
            controlsVisible = false
        }
        .accessibilityAction(named: Text(text("ui.vibescape.dynamics"))) { showControls() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("VibeScape")
        .accessibilityAction(named: Text(text("ui.vibescape.voice.label"))) { showsVoiceHelp = true }
        .onAppear {
            guard admitted else { model.isShowingVibeScape = false; return }
            visit.enter(mood:model.activeDJSession?.selectedMood,occurrence:nil)
            updateAutomaticIntensity()
        }
        .onDisappear { visit.revoke() }
        .onChange(of: model.activeDJSession?.broadcast.playback?.itemID) { _, _ in
            if admitted {
                let manual = visit.followsTrackIntensity ? nil : visit.dynamics
                visit.enter(mood:model.activeDJSession?.selectedMood,occurrence:nil)
                updateAutomaticIntensity()
                if let manual { _ = visit.setDynamics(manual) }
            }
        }
        .onChange(of: automaticIntensity) { _, _ in updateAutomaticIntensity() }
        .onChange(of: model.activeDJSession?.selectedMood) { _, mood in visit.moodChanged(mood) }
        .onChange(of: owner) { _, _ in close() }
        .onChange(of: model.sessionHistory.responseEpoch) { _, _ in close() }
        .onChange(of: model.activeDJSession?.id) { _, _ in close() }
        .onChange(of: model.activeDJSession?.runtimeState) { _, _ in close() }
        .onChange(of: model.pairingStatus) { _, _ in close() }
        .onChange(of: scenePhase) { _, value in if value != .active { close() } }
        .task {
            // Bound a visit even when a static Reduce Motion frame is paused.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if !visit.isCurrent { close(); return }
            }
        }
        .onKeyPress(.escape) { close(); return .handled }
        .accessibilityIdentifier("screen-vibescape")
    }
    private func pickerTop(in geometry: GeometryProxy) -> CGFloat {
        let source = model.vibeScapeModePickerFrame
        guard source.height > 0 else { return 64 }
        // Capture the actual visible inline picker position when switching.
        return min(max(4, source.minY - geometry.frame(in: .global).minY), max(4, geometry.size.height - source.height - 12))
    }
    private func close() { visit.revoke(); model.isShowingVibeScape = false }
    private func updateAutomaticIntensity() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            visit.updateTrackIntensity(automaticIntensity)
        }
    }
    private func isControlArea(_ point: CGPoint) -> Bool {
        modeBounds.insetBy(dx: -12, dy: -12).contains(point)
            || sliderBounds.insetBy(dx: -12, dy: -12).contains(point)
    }
    private func nudge(at location: CGPoint, strength: Float) {
        guard canvasBounds.width > 0, canvasBounds.height > 0 else { return }
        let point = SIMD2(Float((location.x-canvasBounds.minX)/canvasBounds.width),
                          Float((location.y-canvasBounds.minY)/canvasBounds.height))
        guard visit.nudge(at: point, aspect: Float(canvasBounds.width/canvasBounds.height), strength: strength) else { return }
        let time = ProcessInfo.processInfo.systemUptime
        if strength > 1 {
            DJConnectHaptics.impact()
            lastInteractionHaptic = time
        } else if lastInteractionHaptic.map({ time-$0 >= 0.18 }) ?? true {
            // A resting finger produces no repeated feedback; moving strokes
            // get at most one lighter selection pulse every 180 ms.
            DJConnectHaptics.selection()
            lastInteractionHaptic = time
        }
    }
    private var canvasInteraction: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { drag in
                // A stroke starting on a control belongs to that control, even
                // while hidden. Crossing its region never reveals the chrome.
                guard !isControlArea(drag.startLocation), !isControlArea(drag.location) else { return }
                let time = ProcessInfo.processInfo.systemUptime
                if let prior = lastStrokePoint {
                    guard time-lastStrokeTime >= 1.0/30,
                          hypot(drag.location.x-prior.x, drag.location.y-prior.y) >= 8 else { return }
                }
                nudge(at: drag.location, strength: 0.8)
                lastStrokePoint = drag.location; lastStrokeTime = time
            }
            .onEnded { drag in
                if !isControlArea(drag.startLocation), !isControlArea(drag.location) {
                    nudge(at: drag.location, strength: 0.8)
                }
                lastStrokePoint = nil; lastStrokeTime = 0
            }
            .exclusively(before: SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
                if isControlArea(tap.location) { toggleControls() }
                else { nudge(at: tap.location, strength: 2.4) }
            })
    }
    private func showControls() {
        controlsVisible = true; controlsGeneration = UUID()
    }
    private func toggleControls() {
        DJConnectHaptics.selection()
        controlsVisible.toggle(); controlsGeneration = UUID()
    }
    private func dynamicsControl(length: CGFloat) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.fill").foregroundStyle(.white)
                .accessibilityHidden(true)
            Text(Double(visit.dynamics), format: .percent.precision(.fractionLength(0)))
                .font(.caption.monospacedDigit()).foregroundStyle(.white)
                .accessibilityHidden(true)
            Text(text(visit.followsTrackIntensity ? "ui.vibescape.dynamics.auto" : "ui.vibescape.dynamics.manual"))
                .font(.caption2).foregroundStyle(.white.opacity(0.8))
            Slider(value: Binding(get: { Double(visit.dynamics) }, set: { _ = visit.setDynamics(Float($0)) }),
                   in: 0...1, onEditingChanged: { editing in
                       if editing { DJConnectHaptics.selection() }
                       adjustingDynamics = editing; controlsGeneration = UUID()
                   })
                .tint(.white)
                .frame(width: length, height: 44)
                .rotationEffect(.degrees(-90))
                .frame(width: 44, height: length)
                .accessibilityLabel(text("ui.vibescape.dynamics"))
                .accessibilityIdentifier("vibescape-dynamics")
            Button {
                DJConnectHaptics.selection()
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                    visit.followTrackIntensity()
                }
                showControls()
            } label: {
                Image(systemName: "arrow.uturn.backward").foregroundStyle(.white).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text("ui.vibescape.dynamics.follow"))
            .accessibilityIdentifier("vibescape-follow-dj")
        }
        .padding(.vertical, 12).padding(.horizontal, 4)
        .djSessionFrostedSurface()
    }
}
