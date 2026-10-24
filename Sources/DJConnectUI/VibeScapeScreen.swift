import SwiftUI
import DJConnectCore
#if os(iOS)
import UIKit
#endif

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
        #if DEBUG || DJCONNECT_VIBESCAPE_PREVIEW
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
    @StateObject private var displayWakeLock = VibeScapeDisplayWakeLock()
    @StateObject private var voice = VibeScapeVoiceControl()
    @State private var controlsVisible = true
    @State private var controlsGeneration = UUID()
    @State private var adjustingDynamics = false
    @State private var hoveringControls = false
    @State private var canvasBounds = CGRect.zero
    @State private var modeBounds = CGRect.zero
    @State private var sliderBounds = CGRect.zero
    @State private var lastStrokePoint: CGPoint?
    @State private var lastStrokeTime: TimeInterval = 0
    @State private var lastInteractionHaptic: TimeInterval?
    @State private var unavailable = false
    @State private var visualHelp: DJConnectVisualHelp?
    @State private var helpLoading = false
    @State private var helpFailed = false
    @State private var helpGeneration = UUID()
    @State private var showsHelp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var owner: String? { model.sessionHistory.authorizedProfileID }
    private var automaticIntensity: Float? {
        VibeScapeTrackIntensity.resolve(insight: model.currentTrackInsight,
                                       playback: model.activeDJSession?.broadcast.playback)
    }
    // Voice obtains its occurrence from the dedicated server context route,
    // never from history IDs or polling timestamps.
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

            }
            }
            GeometryReader { geometry in
                VStack {
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Button { toggleVisualVoice() } label: {
                                Group {
                                    if voice.busy && !voice.recording { ProgressView().tint(.white) }
                                    else { Image(systemName: voice.recording ? "stop.fill" : "mic.fill") }
                                }.frame(width: 44, height: 44)
                            }
                            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: voice.recording ? .destructive : .secondary, shape: .icon))
                            .disabled((voice.busy && !voice.recording) || !admitted || unavailable || model.isDemoMode || !model.voiceEnabled || model.isRecordingVoice || model.voiceStatus == .processing)
                            .accessibilityLabel(text(voice.recording ? "ui.vibescape.voice.stop" : "ui.vibescape.voice.label"))
                            .accessibilityIdentifier("vibescape-microphone")
                            Button {
                                DJConnectHaptics.selection()
                                showControls(); showsHelp = true
                            } label: {
                                Image(systemName: "questionmark").frame(width: 44, height: 44)
                            }
                            .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                            .accessibilityLabel(text("ui.vibescape.help.title"))
                            .accessibilityIdentifier("vibescape-help")
                            .popover(isPresented: $showsHelp) {
                                VibeScapeHelpContent(language: model.language, help: visualHelp,
                                    loading: helpLoading, failed: helpFailed,
                                    retry: { Task { await loadVisualHelp() } }, close: { showsHelp = false })
                                    .task { await loadVisualHelp() }
                                    .presentationCompactAdaptation(.popover)
                            }
                        }
                        if let key = voice.statusKey {
                            Text(text(key)).font(.callout).foregroundStyle(.white)
                                .multilineTextAlignment(.center).accessibilityIdentifier("vibescape-voice-status")
                        }
                        dynamicsControl
                    }
                        .frame(width: min(480, max(0, geometry.size.width - 32)))
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sliderBounds = $0 }
                }
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .opacity(controlsVisible ? 1 : 0)
            .allowsHitTesting(controlsVisible)
            .accessibilityHidden(!controlsVisible)
        }
        #if os(macOS)
        .onContinuousHover(coordinateSpace: .global) { phase in
            switch phase {
            case .active(let location): updateControlHover(isControlArea(location))
            case .ended: updateControlHover(false)
            }
        }
        #endif
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: controlsVisible)
        .task(id: controlsGeneration) {
            guard controlsVisible, !adjustingDynamics, !hoveringControls, !showsHelp, !voice.busy else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled, !adjustingDynamics, !hoveringControls, !showsHelp, !voice.busy else { return }
            controlsVisible = false
        }
        .onChange(of: showsHelp) { _, open in
            showControls()
            if !open { helpGeneration = UUID(); visualHelp = nil; helpLoading = false; helpFailed = false }
        }
        .onChange(of: voice.busy) { _, _ in showControls() }
        .onChange(of: unavailable) { _, failed in if failed { voice.cancel() } }
        .accessibilityAction(named: Text(text("ui.vibescape.dynamics"))) { showControls() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("VibeScape")
        .accessibilityAction(named: Text(text("ui.vibescape.voice.label"))) { toggleVisualVoice() }
        .onAppear {
            guard admitted else { model.isShowingVibeScape = false; return }
            displayWakeLock.setActive(scenePhase == .active)
            visit.enter(mood:model.activeDJSession?.selectedMood,occurrence:nil)
            updateAutomaticIntensity()
        }
        .onDisappear { voice.cancel(); displayWakeLock.setActive(false); visit.revoke() }
        .onChange(of: model.activeDJSession?.broadcast.playback?.itemID) { _, _ in
            if admitted {
                voice.cancel()
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
        .onChange(of: scenePhase) { _, value in
            if value == .active, admitted { displayWakeLock.setActive(true) }
            else if value == .inactive, voice.awaitingPermission { displayWakeLock.setActive(false) }
            else { close() }
        }
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
    private func close() {
        voice.cancel()
        displayWakeLock.setActive(false)
        visit.revoke(); model.isShowingVibeScape = false
    }
    private func toggleVisualVoice() {
        guard admitted, !unavailable, !model.isDemoMode else { return }
        showControls(); DJConnectHaptics.selection()
        voice.toggle(model: model, visit: visit)
    }
    private func loadVisualHelp() async {
        let generation = UUID(), epoch = model.sessionHistory.responseEpoch
        let owner = self.owner, sessionID = model.activeDJSession?.id
        helpGeneration = generation; visualHelp = nil; helpFailed = false; helpLoading = true
        guard admitted, !model.isDemoMode, model.canRefreshSessionHistory else {
            helpLoading = false; helpFailed = true; return
        }
        defer { if helpGeneration == generation { helpLoading = false } }
        do {
            let help = try await model.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                try await $0.visualDirectorHelp(language: model.language)
            }
            guard !Task.isCancelled, showsHelp, model.isShowingVibeScape, helpGeneration == generation, self.owner == owner,
                  model.sessionHistory.responseEpoch == epoch, model.activeDJSession?.id == sessionID else { return }
            visualHelp = help
        } catch {
            guard !Task.isCancelled, showsHelp, model.isShowingVibeScape, helpGeneration == generation, self.owner == owner,
                  model.sessionHistory.responseEpoch == epoch else { return }
            helpFailed = true
        }
    }
    private func updateAutomaticIntensity() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            visit.updateTrackIntensity(automaticIntensity)
        }
    }
    private func isControlArea(_ point: CGPoint) -> Bool {
        (!modeBounds.isEmpty && modeBounds.insetBy(dx: -12, dy: -12).contains(point))
            || (!sliderBounds.isEmpty && sliderBounds.insetBy(dx: -12, dy: -12).contains(point))
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
    private func updateControlHover(_ inside: Bool) {
        guard inside != hoveringControls else { return }
        hoveringControls = inside
        if inside { showControls() }
        else { controlsGeneration = UUID() }
    }
    private func toggleControls() {
        DJConnectHaptics.selection()
        controlsVisible.toggle(); controlsGeneration = UUID()
    }
    private func dynamicsEditingChanged(_ editing: Bool) {
        if editing { DJConnectHaptics.selection() }
        adjustingDynamics = editing; controlsGeneration = UUID()
    }
    private var dynamicsControl: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill").foregroundStyle(.white)
                .accessibilityHidden(true)
            VStack(spacing: 2) {
                Text(Double(visit.dynamics), format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit()).foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text(text(visit.followsTrackIntensity ? "ui.vibescape.dynamics.auto" : "ui.vibescape.dynamics.manual"))
                    .font(.caption2).foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            #if os(macOS)
            VibeScapeMacDynamicsSlider(
                value: Binding(get: { Double(visit.dynamics) }, set: { _ = visit.setDynamics(Float($0)) }),
                editingChanged: dynamicsEditingChanged)
                .frame(maxWidth: .infinity).frame(height: 44)
                .accessibilityLabel(text("ui.vibescape.dynamics"))
                .accessibilityIdentifier("vibescape-dynamics")
            #else
            Slider(value: Binding(get: { Double(visit.dynamics) }, set: { _ = visit.setDynamics(Float($0)) }),
                   in: 0...1, onEditingChanged: dynamicsEditingChanged)
                .tint(.white)
                .frame(maxWidth: .infinity).frame(height: 44)
                .accessibilityLabel(text("ui.vibescape.dynamics"))
                .accessibilityIdentifier("vibescape-dynamics")
            #endif
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
        .padding(.vertical, 8).padding(.horizontal, 12)
        .djSessionFrostedSurface()
    }
}

private struct VibeScapeHelpContent: View {
    let language: String
    let help: DJConnectVisualHelp?
    let loading: Bool
    let failed: Bool
    let retry: () -> Void
    let close: () -> Void
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(text("ui.vibescape.help.title")).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                        .accessibilityLabel(text("ui.close"))
                }
                Label(text("ui.vibescape.help.touch"), systemImage: "hand.tap")
                Label(text("ui.vibescape.help.intensity"), systemImage: "slider.horizontal.3")
                Label(text("ui.vibescape.help.controls"), systemImage: "cursorarrow")
                Divider()
                Text(text("ui.vibescape.help.voice")).font(.headline).accessibilityAddTraits(.isHeader)
                if loading { ProgressView().accessibilityLabel(text("ui.vibescape.help.loading")) }
                else if let help {
                    ForEach(help.examples) { example in Text("• " + example.text) }
                    ForEach(help.scopes) { scope in Text(scope.text).font(.callout).foregroundStyle(.secondary) }
                } else if failed {
                    Text(text("ui.vibescape.help.unavailable"))
                    Button(text("ui.retry"), action: retry).djConnectButtonStyle(DJConnectButtonStyle())
                }
            }
            .font(.body).fixedSize(horizontal: false, vertical: true).padding(24)
        }
        .frame(idealWidth: 380, maxWidth: 440, idealHeight: 400, maxHeight: 560)
        .djSessionFrostedSurface()
        .accessibilityIdentifier("vibescape-help-content")
    }
}

/// Keep the display awake only for an active, visible VibeScape visit.
/// iOS shares its app-wide idle timer across windows; Mac activities are scoped
/// independently and do not alter a user's system sleep preferences.
@MainActor final class VibeScapeDisplayWakeLock: ObservableObject {
    private var active = false
    #if os(iOS)
    private let leaseID = UUID()
    private static var leases = Set<UUID>()
    private static var previousIdleTimerDisabled = false
    #elseif os(macOS)
    private var activity: NSObjectProtocol?
    #endif

    func setActive(_ requested: Bool) {
        guard active != requested else { return }
        active = requested
        #if os(iOS)
        if requested {
            if Self.leases.isEmpty { Self.previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled }
            Self.leases.insert(leaseID)
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            Self.leases.remove(leaseID)
            if Self.leases.isEmpty { UIApplication.shared.isIdleTimerDisabled = Self.previousIdleTimerDisabled }
        }
        #elseif os(macOS)
        if requested {
            activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled],
                                                             reason: "VibeScape is visible")
        } else if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        #endif
    }
}

#if os(macOS)
import AppKit

/// Native horizontal layout aligns pointer hit testing with the visible track.
struct VibeScapeMacDynamicsSlider: NSViewRepresentable {
    @Binding var value: Double
    var editingChanged: (Bool) -> Void
    func makeNSView(context: Context) -> TrackingSlider {
        let slider = TrackingSlider(value: value, minValue: 0, maxValue: 1,
                                    target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        slider.isVertical = false
        slider.isContinuous = true
        slider.trackFillColor = .white
        slider.editingChanged = editingChanged
        return slider
    }
    func updateNSView(_ slider: TrackingSlider, context: Context) {
        context.coordinator.parent = self
        slider.editingChanged = editingChanged
        if slider.doubleValue != value { slider.doubleValue = value }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    @MainActor final class Coordinator: NSObject {
        var parent: VibeScapeMacDynamicsSlider
        init(_ parent: VibeScapeMacDynamicsSlider) { self.parent = parent }
        @objc func changed(_ slider: NSSlider) { parent.value = slider.doubleValue }
    }
    final class TrackingSlider: NSSlider {
        var editingChanged: ((Bool) -> Void)?
        override func mouseDown(with event: NSEvent) {
            editingChanged?(true)
            defer { editingChanged?(false) }
            super.mouseDown(with: event)
        }
    }
}
#endif

#if canImport(AVFoundation) && canImport(Speech) && (os(iOS) || os(macOS))
import AVFoundation
@preconcurrency import Speech

/// Speech may invoke its legacy completion on any queue. Explicit Sendable
/// prevents this callback from inheriting the caller's MainActor isolation.
@MainActor enum VibeScapeSpeechAuthorization {
    static func request(
        using request: (@escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) -> Void = SFSpeechRecognizer.requestAuthorization
    ) async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            request { @Sendable status in
                continuation.resume(returning: status)
            }
        }
    }
}

/// Separate visual-only capture. No transcript/audio enters Ask DJ or history.
@MainActor final class VibeScapeVoiceControl: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var recording = false
    private(set) var awaitingPermission = false
    @Published private(set) var statusKey: String?
    private var task: Task<Void, Never>?
    private var operation = UUID()
    private var deadlineTask: Task<Void, Never>?
    private var recorder: AVAudioRecorder?
    private var audioURL: URL?
    private let transcriber = DJConnectAppleSpeechTranscriber()
    private var fence: VisualDirectorTurnFence?
    private var revoke: (() -> Void)?
    private var audioSessionActive = false

    func toggle(model: DJConnectAppModel, visit: VisualDirectorVisit) {
        if recording { recorder?.stop(); recording = false; return }
        guard !busy, model.voiceEnabled, !model.isRecordingVoice, model.voiceStatus != .processing,
              let owner = model.sessionHistory.authorizedProfileID,
              let sessionID = model.activeDJSession?.id, let visitID = visit.ticket?.visit else { return }
        let epoch = model.sessionHistory.responseEpoch, language = model.language
        let origin = model.homeAssistantURL
        let token = UUID(); operation = token; busy = true; statusKey = nil
        func current() -> Bool {
            operation == token && !Task.isCancelled && model.voiceEnabled && model.isShowingVibeScape && model.canRefreshSessionHistory &&
            model.sessionHistory.authorizedProfileID == owner && model.sessionHistory.responseEpoch == epoch &&
            model.activeDJSession?.id == sessionID && model.activeDJSession?.runtimeState == "active" &&
            visit.isCurrent && visit.ticket?.visit == visitID
        }
        if fence == nil { fence = VisualDirectorTurnFence(visit: visit) }
        task = Task { [weak self] in
            guard let self else { return }
            defer { if operation == token { cleanupCapture(); busy = false; task = nil } }
            do {
                _ = try await model.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                    try await $0.visualDirectorHelp(language: language)
                }
                guard current() else { throw CancellationError() }
                awaitingPermission = true
                let microphone = await AVCaptureDevice.requestAccess(for: .audio)
                guard !Task.isCancelled, microphone else { throw DJConnectDeviceSTTError.permission }
                let speech = await VibeScapeSpeechAuthorization.request() == .authorized
                let locale = DJConnectLocalization.bcp47LocaleIdentifier(for: language)
                // Native permission panels briefly inactivate the scene. Wait
                // for foreground again before any capture or private context read.
                for _ in 0..<20 where !model.canRefreshSessionHistory {
                    try await Task.sleep(for: .milliseconds(100))
                }
                awaitingPermission = false
                guard current(), speech, DJConnectAppleSpeechTranscriber.isAvailable(language: locale) else { throw DJConnectDeviceSTTError.unavailable }
                revoke = { [weak model] in
                    guard let model, model.sessionHistory.authorizedProfileID == owner,
                          model.sessionHistory.responseEpoch == epoch, model.homeAssistantURL == origin else { return }
                    Task {
                        _ = try? await model.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                            guard model.sessionHistory.responseEpoch == epoch, model.homeAssistantURL == origin else { throw CancellationError() }
                            return try await $0.revokeVisualVisit(sessionID: sessionID, visitID: visitID)
                        }
                    }
                }
                let started = visit.now()
                let context = try await model.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                    guard current() else { throw CancellationError() }
                    return try await $0.visualDirectorContext(sessionID: sessionID, visitID: visitID)
                }
                guard current(), context.success, context.schema_version == 1,
                      UUID(uuidString: context.visit_id) == visitID,
                      !context.context_lease_id.isEmpty, context.context_lease_id.utf8.count <= 256,
                      !context.observed_occurrence_id.isEmpty, context.observed_occurrence_id.utf8.count <= 256,
                      (1...15000).contains(context.lease_duration_ms),
                      let expiry = DJConnectHistoryEntry.date(context.expires_at) else { throw DJConnectError.invalidResponse }
                let deadline = min(started + Double(context.lease_duration_ms) / 1000,
                                   visit.now() + expiry.timeIntervalSinceNow)

                visit.trackChanged(mood: model.activeDJSession?.selectedMood, occurrence: context.observed_occurrence_id)
                guard current(), deadline - visit.now() > 2, let scene = visit.scene,
                      let turn = fence?.begin(originalSourceDeadline: deadline, isCurrent: current) else { throw DJConnectError.invalidResponse }
                deadlineTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(max(0, deadline - visit.now()))) } catch { return }
                    guard let self, self.operation == token else { return }
                    self.cancel(); self.statusKey = "ui.vibescape.voice.failed"
                }
                #if os(iOS)
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
                try AVAudioSession.sharedInstance().setActive(true)
                audioSessionActive = true
                #endif
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("djc-visual-\(UUID().uuidString).wav")
                audioURL = url
                let capture = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16])
                recorder = capture
                guard capture.prepareToRecord(), capture.record(forDuration: min(8, deadline - visit.now() - 1)) else { throw DJConnectDeviceSTTError.failed }
                recording = true; statusKey = "ui.vibescape.voice.recording"
                while recording && capture.isRecording {
                    try await Task.sleep(for: .milliseconds(100))
                    guard current(), visit.ticket == turn.scene, visit.now() < deadline else { throw CancellationError() }
                }
                capture.stop(); recording = false; statusKey = "ui.processing.voice.request"
                let transcript = try await transcriber.transcribe(url: url, language: locale)
                guard current(), visit.ticket == turn.scene, visit.now() < deadline,
                      !transcript.isEmpty, transcript.utf8.count <= 1024 else { throw CancellationError() }
                let values = DJConnectVisualSceneValues(palette: [scene.palette.x, scene.palette.y, scene.palette.z],
                    motion: scene.motion, depth: scene.depth, roughness: scene.roughness, deformation: scene.deformation)
                let response = try await model.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) { client in
                    guard current(), visit.ticket == turn.scene, visit.now() < deadline else { throw CancellationError() }
                    return try await client.interpretVisualDirection(.init(deviceID: client.identity.deviceID,
                        clientType: client.identity.clientType.rawValue, sessionID: sessionID, visitID: visitID, turnID: turn.id,
                        lease: context.context_lease_id, occurrence: context.observed_occurrence_id, revision: turn.scene.revision,
                        text: transcript, scene: values, dynamics: visit.dynamics))
                }
                guard current(), response.success, response.schema_version == 1, response.status == "interpreted",
                      UUID(uuidString: response.visit_id) == visitID, UUID(uuidString: response.client_turn_id) == turn.id,
                      response.base_scene_revision == turn.scene.revision,
                      response.context_lease_id == context.context_lease_id,
                      response.observed_occurrence_id == context.observed_occurrence_id,
                      response.expires_at == context.expires_at, visit.now() < deadline else { throw DJConnectError.invalidResponse }
                let applied = fence?.complete(turn) {
                    switch response.directive.kind {
                    case "patch":
                        guard let p = response.directive.patch,
                              response.directive.scope == "current_track" || response.directive.scope == "while_in_vibescape",
                              p.palette == nil || p.palette?.count == 3 else { return false }
                        let palette = p.palette.map { SIMD3<Float>($0[0], $0[1], $0[2]) }
                        return visit.apply(.init(palette: palette, motion: p.motion, depth: p.depth,
                            roughness: p.roughness, deformation: p.deformation,
                            scope: response.directive.scope == "while_in_vibescape" ? .continuousVisit : .currentTrack), expected: turn.scene)
                    case "undo": return visit.undoLast(expected: turn.scene)
                    case "reset": return visit.resetToDJ(expected: turn.scene)
                    case "hold": return visit.holdExplicitStyle(expected: turn.scene)
                    case "variant": return visit.varyComposition(expected: turn.scene)
                    default: return false
                    }
                } ?? false
                statusKey = applied ? "ui.vibescape.voice.applied" : "ui.vibescape.voice.failed"
            } catch {
                if operation == token {
                    fence?.cancel()
                    if !Task.isCancelled { statusKey = "ui.vibescape.voice.failed" }
                }
            }
        }
    }
    func cancel() {
        operation = UUID(); task?.cancel(); task = nil; fence?.cancel()
        transcriber.cancel(); cleanupCapture(); busy = false; statusKey = nil
        let action = revoke; revoke = nil; action?()
    }
    private func cleanupCapture() {
        awaitingPermission = false
        deadlineTask?.cancel(); deadlineTask = nil
        recorder?.stop(); recorder = nil; recording = false
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        audioURL = nil
        #if os(iOS)
        if audioSessionActive { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        #endif
        audioSessionActive = false
    }
}
#else
@MainActor final class VibeScapeVoiceControl: ObservableObject {
    let busy = false, recording = false, awaitingPermission = false
    let statusKey: String? = "ui.vibescape.voice.unavailable"
    func toggle(model: DJConnectAppModel, visit: VisualDirectorVisit) {}
    func cancel() {}
}
#endif
