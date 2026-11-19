import Foundation
import SwiftUI
import DJConnectCore
@testable import DJConnectUI
/// Disposable local counters, not server authority or a reaction result.
@MainActor final class NativePersonaReactionProbeState: ObservableObject {
    let language = "en"
    @Published var presentsPersonaReactionControl = true
    @Published var canStartPersonaReaction = true
    @Published var revision = 0
    @Published var requests: [String] = []
    var personaAvatarFrame = CGRect.zero
    func requestPersonaReaction(_ kind: DJConnectPersonaReactionKind) {
        guard presentsPersonaReactionControl && canStartPersonaReaction else { return }
        requests.append(kind.rawValue)
    }
}
@main struct NativePersonaReactionHost: App {
    @StateObject private var model = NativePersonaReactionProbeState()
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 30) {
                Text("Production presentation component — synthetic authority; no AppModel, HTTP or audio")
                Text("revision:\(model.revision)").accessibilityIdentifier("revision")
                Group {
                    if model.presentsPersonaReactionControl {
                        PersonaReactionAvatarInteraction(avatar: Image(systemName: "headphones").resizable().scaledToFit().frame(width: 120,height: 120),
                            language: model.language, canStart: model.canStartPersonaReaction,
                            request: { model.requestPersonaReaction($0) })
                    } else { Image(systemName: "headphones").resizable().scaledToFit().frame(width: 120,height: 120) }
                }
                    .accessibilityIdentifier("avatar-control")
                Text("requests:" + model.requests.joined(separator: ",")).accessibilityIdentifier("requests")
                Button("Clear") { model.requests = [] }.accessibilityIdentifier("clear")
                Button("Toggle busy") { model.canStartPersonaReaction.toggle() }.accessibilityIdentifier("busy")
                Button("Withdraw") { model.presentsPersonaReactionControl = false }.accessibilityIdentifier("withdraw")
            }.padding(24)
            .task { for n in 1...900 { try? await Task.sleep(for: .milliseconds(100)); if Task.isCancelled { return }; model.revision = n } }
        }
    }
}
