import SwiftUI
import DJConnectCore

extension DJConnectSessionPersonaValue {
    var choiceGlyph: String {
        switch self {
        case .homeDJ: return "house"
        case .radioDJ: return "radio"
        case .clubDJ: return "opticaldisc"
        case .festivalDJ: return "music.mic"
        }
    }
}

/// Shared Session state; selection changes only after Core confirmation.
struct ActiveSessionPersonaToolbar: View {
    @ObservedObject var model: DJConnectAppModel
    let session: DJConnectSessionRuntime
    var requestPresentation: (() -> Void)? = nil
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    private struct Scope: Identifiable { let id = UUID(); let sessionID: String; let epoch: UUID }
    @State private var scope: Scope?
    #if os(macOS)
    @FocusState private var personaPopoverFocused: Bool
    #endif

    init(model: DJConnectAppModel, session: DJConnectSessionRuntime, requestPresentation: (() -> Void)? = nil) {
        self.model = model; self.session = session; self.requestPresentation = requestPresentation
        history = model.sessionHistory
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var confirmed: DJConnectSessionPersonaSnapshot? {
        guard model.activeDJSession?.id == session.id else { return nil }
        return model.activeDJSession?.confirmedPersona
    }
    var body: some View {
        Button {
            if let requestPresentation { requestPresentation(); return }
            if scope != nil { scope = nil }
            else { scope = Scope(sessionID: session.id, epoch: history.responseEpoch) }
        } label: {
            Image(systemName: confirmed?.selectedPersona.choiceGlyph ?? "person.crop.circle")
                .foregroundStyle(.white)
        }
        .accessibilityLabel(text("ui.session.persona.title"))
        .accessibilityValue(confirmed.map { text($0.selectedPersona.localizationKey) } ?? text("ui.session.persona.unavailable"))
        .accessibilityIdentifier("session-persona-toggle")
        .help(text("ui.session.persona.title"))
        .popover(item: $scope) { intent in
            ActiveSessionPersonaControl(model: model, sessionID: intent.sessionID, epoch: intent.epoch)
                .padding(16).frame(idealWidth: 360)
                #if os(macOS)
                .focusable().focusEffectDisabled().focused($personaPopoverFocused)
                .onAppear { personaPopoverFocused = true }
                .onDisappear { personaPopoverFocused = false }
                .onKeyPress(.escape) { scope = nil; return .handled }
                .onExitCommand { scope = nil }
                #endif
                .presentationCompactAdaptation(.popover)
                .djConnectPresentationSurface()
        }
        .task(id: scope?.id) {
            guard let captured = scope, scenePhase == .active, !Task.isCancelled else { return }
            await model.refreshActiveDJSession()
            guard !Task.isCancelled, scope?.id == captured.id,
                  captured.sessionID == model.activeDJSession?.id,
                  captured.epoch == history.responseEpoch, scenePhase == .active else { return }
            await model.refreshActiveMoodCapability()
        }
        .onChange(of: session.id) { scope = nil }
        .onChange(of: history.responseEpoch) { scope = nil }
        .onChange(of: scenePhase) { _, phase in if phase != .active { scope = nil } }
        .onDisappear { scope = nil }
    }
}

struct ActiveSessionPersonaControl: View {
    @ObservedObject var model: DJConnectAppModel
    let sessionID: String
    let epoch: UUID
    @Environment(\.scenePhase) private var scenePhase
    private let values = DJConnectSessionPersonaValue.allCases
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var confirmed: DJConnectSessionPersonaSnapshot? {
        guard model.activeDJSession?.id == sessionID else { return nil }
        return model.activeDJSession?.confirmedPersona
    }
    private var canChange: Bool {
        scenePhase == .active && epoch == model.sessionHistory.responseEpoch &&
        !model.isDemoMode && model.pairingStatus == .paired && model.sessionHistory.hasAuthorizedOwner &&
        model.activePersonaAvailable && !model.activePersonaPending &&
        model.activeDJSession?.runtimeState == "active" && confirmed != nil
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SessionGlassChoiceSelector(
                steps: values.enumerated().map { (text($0.element.localizationKey), $0.offset) },
                selectedIndex: confirmed.flatMap { values.firstIndex(of: $0.selectedPersona) } ?? -1,
                language: model.language,
                glyphs: values.map(\.choiceGlyph),
                titleKey: "ui.session.persona.title",
                accessibilityLabelKey: "ui.session.persona.title",
                optionIDs: values.map { "session-persona-" + $0.rawValue },
                preservesAppearanceWhileDisabled: true
            ) { index in
                guard canChange, values.indices.contains(index) else { return }
                Task { await model.changeActiveSessionPersona(values[index], expectedSessionID: sessionID, expectedEpoch: epoch) }
            }
            .disabled(!canChange || (model.profileDJSettings.negotiated && !model.profileDJSettings.canEdit))
            if let error = model.activePersonaError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            } else if !canChange && !model.activePersonaPending {
                Text(text("ui.session.persona.unavailable")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("active-session-persona")
    }
}
