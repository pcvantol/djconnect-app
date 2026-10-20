import DJConnectCore
import SwiftUI
#if os(iOS)
import AVFoundation
#endif

/// Shared product presentation. It never displays the QR capability or owner
/// response payload. Destination preparation is distinct from display consent.
struct VibeCastRendezvousView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
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
                        }
                    }.accessibilityIdentifier("vibecast-rendezvous-scan")
                    #endif
                    if model.rendezvousHasQR {
                        Toggle(rendezvousText(model.language, "ui.rendezvous.savedHA"), isOn: $selectedInstallation)
                            .accessibilityIdentifier("vibecast-rendezvous-installation")
                        Button(rendezvousText(model.language, "ui.rendezvous.confirm")) {
                            Task { await model.prepareRendezvousDestination() }
                        }
                        .disabled(!selectedInstallation || model.rendezvousBusy || model.pairingStatus != .paired)
                        .accessibilityIdentifier("vibecast-rendezvous-confirm")
                    }
                    if model.rendezvousBusy { ProgressView() }
                }.padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(rendezvousText(model.language, "ui.not.now.b1e535")) {
                        model.cancelRendezvous(); model.isShowingRendezvous = false; dismiss()
                    }
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $scanning) {
                PairingQRScannerView(language: model.language, instructionsKey: "ui.rendezvous.scan", confirmsDetection: false) { value in
                    scanning = false; selectedInstallation = false
                    model.receiveRendezvousQR(value)
                }.presentationBackground(.black)
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.cancelRendezvous(); selectedInstallation = false }
        }
        .onDisappear { if !scanning { model.cancelRendezvous() } }
        .accessibilityIdentifier("vibecast-rendezvous")
    }
}

private func rendezvousText(_ language: String, _ key: String) -> String {
    DJConnectLocalization.localized(key: key, language: language)
}
