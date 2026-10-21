import SwiftUI
import DJConnectCore

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
    @State private var showsDynamics = false
    @State private var unavailable = false
    @State private var showsVoiceHelp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var owner: String? { model.sessionHistory.authorizedProfileID }
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
                    .onTapGesture { showsVoiceHelp = true }
            }
            if unavailable {
                Text(text("ui.vibescape.unavailable"))
                    .foregroundStyle(.white).padding(28).accessibilityIdentifier("vibescape-unavailable")
            }
            VStack {
                HStack(alignment: .top, spacing: 8) {
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        exitButton("ui.session.forecast.flow",forecast: false)
                        exitButton("ui.session.forecast.tab",forecast: true)
                        Text("VibeScape").font(.headline).padding(.horizontal,12).frame(minHeight:48)
                            .foregroundStyle(.white).accessibilityAddTraits(.isSelected)
                    }
                    .padding(4).djSessionFrostedSurface()
                    .frame(maxWidth: 520)
                    Spacer(minLength: 0)
                    Button { showsDynamics.toggle() } label: {
                        Image(systemName: "slider.horizontal.3").frame(width:44,height:44)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle())
                    .accessibilityLabel(text("ui.vibescape.dynamics"))
                    .accessibilityIdentifier("vibescape-settings")
                    .popover(isPresented: $showsDynamics) { dynamicsControl.padding(24).frame(minWidth:240) }
                }
                .padding(.horizontal,12).padding(.top,8)
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("VibeScape")
        .accessibilityAction(named: Text(text("ui.vibescape.voice.label"))) { showsVoiceHelp = true }
        .onAppear {
            guard admitted else { model.isShowingVibeScape = false; return }
            visit.enter(mood:model.activeDJSession?.selectedMood,occurrence:nil)
        }
        .onDisappear { visit.revoke() }
        .onChange(of: model.activeDJSession?.broadcast.playback?.itemID) { _, _ in
            if admitted { visit.enter(mood:model.activeDJSession?.selectedMood,occurrence:nil) }
        }
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
    private func close() { visit.revoke(); model.isShowingVibeScape = false }
    private func exitButton(_ key: String, forecast: Bool) -> some View {
        Button(text(key)) { model.vibeScapeReturnToForecast = forecast; close() }
            .font(.headline).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            .frame(minHeight:48)
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis:.secondary,shape:.segmented,usesLiveGlass:true))
            .accessibilityIdentifier(forecast ? "vibescape-exit-forecast" : "vibescape-exit-flow")
    }
    private var dynamicsControl: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(text("ui.vibescape.dynamics")).font(.headline)
            Slider(value: Binding(get:{ Double(visit.dynamics) },set:{ _ = visit.setDynamics(Float($0)) }),in:0...1)
                .accessibilityLabel(text("ui.vibescape.dynamics"))
                .accessibilityIdentifier("vibescape-dynamics")
            HStack {
                Text(text("ui.vibescape.calm")); Spacer(); Text(text("ui.vibescape.intense"))
            }.font(.caption)
            Button(text("ui.vibescape.follow")) { _ = visit.setDynamics(0.5) }
                .accessibilityIdentifier("vibescape-follow-dj")
        }
    }
}
