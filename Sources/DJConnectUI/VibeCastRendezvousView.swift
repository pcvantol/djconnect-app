import DJConnectCore
import SwiftUI
#if os(iOS)
import AVFoundation
import UIKit
#endif

/// A nil callback belongs to the route/QR presentation that created its binding.
/// Shared by the product root and the isolated native qualification shell.
@MainActor
func rendezvousOwnedSheetBinding<Route: Equatable>(
    current: @escaping @MainActor () -> Route?, rendezvous: Route,
    dismissRendezvous: @escaping @MainActor () -> Bool,
    dismissOther: @escaping @MainActor (Route) -> Void
) -> Binding<Route?> {
    let presented = current()
    return Binding(get: current, set: { value in
        guard value == nil, let presented else { return }
        if presented == rendezvous { _ = dismissRendezvous() }
        else if presented == current() { dismissOther(presented) }
    })
}

/// Shared product presentation. It never displays the QR capability or owner
/// response payload. Destination preparation is distinct from display consent.
struct VibeCastRendezvousView: View {
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @State private var presentation: UUID
    init(model: DJConnectAppModel) {
        self.model = model; self.history = model.sessionHistory
        _presentation = State(initialValue: model.rendezvousPresentationID)
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var cameraDenied = false
    @State private var scanning = false
    @State private var selectedInstallation = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("VibeCast").font(.title.bold())
                    Text(rendezvousText(model.language, model.rendezvousStatusKey))
                        .accessibilityIdentifier("vibecast-rendezvous-status")
                    #if os(iOS)
                    Button(rendezvousText(model.language, "ui.rendezvous.scan")) {
                        Task { @MainActor in
                            let authorized: Bool
                            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { authorized = true }
                            else { authorized = await AVCaptureDevice.requestAccess(for: .video) }
                            if authorized { scanning = true }
                            else { cameraDenied = true }
                        }
                    }
                    .disabled(model.rendezvousBusy)
                    .accessibilityIdentifier("vibecast-rendezvous-scan")
                    #endif
                    PasteButton(payloadType: String.self) { values in
                        guard values.count == 1, let value = values.first else { return }
                        selectedInstallation = false
                        model.receiveRendezvousQR(value)
                    }
                    .disabled(model.rendezvousBusy)
                    .accessibilityIdentifier("vibecast-rendezvous-paste")
                    if model.rendezvousHasQR {
                        Toggle(rendezvousText(model.language, "ui.rendezvous.savedHA"), isOn: $selectedInstallation)
                            .disabled(model.rendezvousBusy)
                            .accessibilityIdentifier("vibecast-rendezvous-installation")
                        Button(rendezvousText(model.language, "ui.rendezvous.confirm")) {
                            Task { await model.prepareRendezvousDestination() }
                        }
                        .disabled(!selectedInstallation || model.rendezvousBusy || model.pairingStatus != .paired)
                        .accessibilityIdentifier("vibecast-rendezvous-confirm")
                    }
                    if model.rendezvousRepairOffered {
                        Button(rendezvousText(model.language, "ui.rendezvous.repair")) {
                            Task { await model.repairRendezvousKey() }
                        }
                        .disabled(model.rendezvousBusy || !RendezvousNativeAdmission.isAdmitted)
                        .accessibilityIdentifier("vibecast-rendezvous-repair")
                    }
                    if model.rendezvousBusy { ProgressView() }
                    Divider()
                    Text(rendezvousText(model.language, "ui.rendezvous.tv_code_help"))
                    Button(rendezvousText(model.language, "ui.rendezvous.tv_code")) {
                        model.openRendezvousDisplayConsent()
                    }
                    .disabled(!model.canResolveDisplayConsent || model.rendezvousBusy)
                    .accessibilityIdentifier("vibecast-rendezvous-tv-code")
                }.padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(rendezvousText(model.language, "ui.not.now.b1e535")) {
                        guard model.cancelRendezvousPresentation(presentation) else { return }
                        model.isShowingRendezvous = false; dismiss()
                    }
                    .accessibilityIdentifier("vibecast-rendezvous-close")
                }
            }
            #if os(iOS)
            .alert(rendezvousText(model.language, "ui.camera.access.is.disabled.enable.it.in.settings.to.scan"), isPresented:$cameraDenied) {
                Button(rendezvousText(model.language, "ui.open.settings")) {
                    if let settings = URL(string:UIApplication.openSettingsURLString) { openURL(settings) }
                }
                Button(rendezvousText(model.language, "ui.cancel"), role:.cancel) {}
            }
            .fullScreenCover(isPresented: $scanning) {
                PairingQRScannerView(language: model.language, instructionsKey: "ui.rendezvous.scan", confirmsDetection: false) { value in
                    scanning = false; selectedInstallation = false
                    model.receiveRendezvousQR(value)
                }.presentationBackground(.black)
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.cancelRendezvousPresentation(presentation)
                selectedInstallation = false
            }
        }
        .onDisappear {
            if !scanning { model.cancelRendezvousPresentation(presentation) }
        }
        .accessibilityIdentifier("vibecast-rendezvous")
    }
}

private func rendezvousText(_ language: String, _ key: String) -> String {
    DJConnectLocalization.localized(key: key, language: language)
}
