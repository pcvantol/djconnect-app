import SwiftUI
import DJConnectCore

/// Shared Session state. A choice stays unselected until Core confirms its CAS revision.
struct ActiveSessionPersonaToolbar: View {
    @ObservedObject var model: DJConnectAppModel
    let session: DJConnectSessionRuntime
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    private struct Scope: Identifiable { let id = UUID(); let sessionID: String; let epoch: UUID }
    @State private var scope: Scope?

    init(model: DJConnectAppModel, session: DJConnectSessionRuntime) {
        self.model = model; self.session = session; history = model.sessionHistory
    }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: model.language) }
    private var confirmed: DJConnectSessionPersonaSnapshot? {
        guard model.activeDJSession?.id == session.id else { return nil }
        return model.activeDJSession?.confirmedPersona
    }
    private var canChange: Bool {
        scenePhase == .active && !model.isDemoMode && model.pairingStatus == .paired &&
        history.hasAuthorizedOwner && model.activePersonaAvailable && !model.activePersonaPending &&
        model.activeDJSession?.runtimeState == "active" && confirmed != nil
    }
    var body: some View {
        Button { scope = Scope(sessionID: session.id, epoch: history.responseEpoch) } label: {
            Label(text("ui.session.persona.title"), systemImage: "person.crop.circle")
        }
        .foregroundStyle(.white)
        .accessibilityLabel(text("ui.session.persona.title"))
        .accessibilityValue(confirmed.map { text($0.selectedPersona.localizationKey) } ?? text("ui.session.persona.unavailable"))
        .accessibilityIdentifier("session-persona-toggle")
        .popover(item: $scope) { intent in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(text("ui.session.persona.title")).font(.headline).accessibilityAddTraits(.isHeader)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    ForEach(DJConnectSessionPersonaValue.allCases, id: \.self) { value in
                        Button {
                            guard canChange else { return }
                            Task { await model.changeActiveSessionPersona(value, expectedSessionID: intent.sessionID, expectedEpoch: intent.epoch) }
                        } label: {
                            HStack {
                                Text(text(value.localizationKey)).fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if confirmed?.selectedPersona == value { Image(systemName: "checkmark") }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .disabled(!canChange)
                        .accessibilityValue(confirmed?.selectedPersona == value ? text("ui.session.persona.confirmed") : "")
                        .accessibilityIdentifier("session-persona-" + value.rawValue)
                    }
                    if model.activePersonaPending {
                        ProgressView(text("ui.session.persona.pending"))
                    } else if let error = model.activePersonaError {
                        Text(error).fixedSize(horizontal: false, vertical: true)
                    } else if !canChange {
                        Text(text("ui.session.persona.unavailable")).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(16)
            }
            .frame(idealWidth: 340, maxHeight: 500)
            .presentationCompactAdaptation(.popover)
            .task {
                _ = await model.refreshActiveDJSession()
                await model.refreshActiveMoodCapability()
            }
        }
        .onChange(of: session.id) { scope = nil }
        .onChange(of: history.responseEpoch) { scope = nil }
        .onChange(of: scenePhase) { _, phase in if phase != .active { scope = nil } }
    }
}
