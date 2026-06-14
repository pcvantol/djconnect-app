import DJConnectCore
import Combine
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import Darwin
#endif

private func localized(_ language: String, _ english: String, _ dutch: String) -> String {
    language == "nl" ? dutch : english
}

private func localizedOutputName(_ outputName: String, language: String) -> String {
    switch outputName {
    case "Not selected", "No output selected":
        localized(language, "No output device selected", "Geen uitvoerapparaat geselecteerd")
    default:
        outputName
    }
}

private func screenTitle(_ language: String, _ english: String, _ dutch: String, isDemoMode: Bool) -> String {
    let title = localized(language, english, dutch)
    guard isDemoMode, title != localized(language, "More", "Meer") else {
        return title
    }
    return "\(title) (demo)"
}

private let djConnectAccent = Color(red: 0.84, green: 0.22, blue: 0.96)

private var djConnectListRowInsets: EdgeInsets {
    #if os(iOS)
    EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16)
    #else
    EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    #endif
}

private struct DJConnectTableRowBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.07, blue: 0.14).opacity(0.98),
                Color(red: 0.20, green: 0.09, blue: 0.32).opacity(0.96),
                Color(red: 0.10, green: 0.14, blue: 0.28).opacity(0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct DJConnectLilacButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(djConnectAccent)
            .accentColor(djConnectAccent)
            .foregroundStyle(djConnectAccent)
            .foregroundColor(djConnectAccent)
            .symbolRenderingMode(.monochrome)
    }
}

private extension View {
    func djConnectLilacButton() -> some View {
        modifier(DJConnectLilacButtonModifier())
    }
}

private enum DJConnectHaptics {
    @MainActor
    static func impact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    @MainActor
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    @MainActor
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

private extension View {
    @ViewBuilder
    func liquidGlassIfAvailable() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect()
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func scrollContentBackgroundIfAvailable(_ visibility: Visibility) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.scrollContentBackground(visibility)
        } else {
            self
        }
    }
}

private struct DJConnectCanvasBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.09),
                    Color(red: 0.07, green: 0.04, blue: 0.15),
                    Color(red: 0.03, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.43, blue: 0.98).opacity(0.42),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 880
            )
            RadialGradient(
                colors: [
                    Color(red: 0.64, green: 0.12, blue: 0.92).opacity(0.34),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 820
            )
            RadialGradient(
                colors: [
                    Color(red: 0.10, green: 0.18, blue: 0.52).opacity(0.26),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 720
            )
            LinearGradient(
                colors: [
                    .black.opacity(0.16),
                    .clear,
                    .black.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private enum DJConnectSection: Hashable {
    case nowPlaying
    case queue
    case playlists
    case games
    case settings
    case logs
    case about
    case legal
    case privacy
}

public struct DJConnectRootView: View {
    @ObservedObject private var model: DJConnectAppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSection = DJConnectSection.nowPlaying
    @State private var moreResetID = UUID()
    @State private var showingFeedback = false

    public init(model: DJConnectAppModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            Group {
                #if os(macOS)
                NavigationSplitView {
                    List {
                        SidebarItem(
                            title: localized(model.language, "Now Playing", "Speelt Nu"),
                            systemImage: "music.note",
                            isSelected: selectedSection == .nowPlaying
                        ) { selectedSection = .nowPlaying }
                        SidebarItem(
                            title: localized(model.language, "Queue", "Wachtrij"),
                            systemImage: "text.line.first.and.arrowtriangle.forward",
                            isSelected: selectedSection == .queue
                        ) { selectedSection = .queue }
                        SidebarItem(
                            title: localized(model.language, "Playlists", "Afspeellijsten"),
                            systemImage: "rectangle.stack",
                            isSelected: selectedSection == .playlists
                        ) { selectedSection = .playlists }
                        SidebarItem(
                            title: localized(model.language, "Games", "Games"),
                            systemImage: "gamecontroller",
                            isSelected: selectedSection == .games
                        ) { selectedSection = .games }
                        SidebarItem(
                            title: localized(model.language, "Settings", "Instellingen"),
                            systemImage: "gearshape",
                            isSelected: selectedSection == .settings
                        ) { selectedSection = .settings }
                        SidebarItem(
                            title: localized(model.language, "Logs", "Logs"),
                            systemImage: "doc.text.magnifyingglass",
                            isSelected: selectedSection == .logs
                        ) { selectedSection = .logs }
                        SidebarItem(
                            title: localized(model.language, "About", "Over"),
                            systemImage: "info.circle",
                            isSelected: selectedSection == .about
                        ) { selectedSection = .about }
                        SidebarItem(
                            title: localized(model.language, "Legal", "Juridisch"),
                            systemImage: "doc.text",
                            isSelected: selectedSection == .legal
                        ) { selectedSection = .legal }
                        SidebarItem(
                            title: localized(model.language, "Privacy", "Privacy"),
                            systemImage: "hand.raised",
                            isSelected: selectedSection == .privacy
                        ) { selectedSection = .privacy }
                        Button {
                            showingFeedback = true
                        } label: {
                            Label(localized(model.language, "Share Feedback", "Feedback delen"), systemImage: "bubble.left.and.bubble.right")
                        }
                        .buttonStyle(.plain)
                    }
                    .navigationTitle(screenTitle(model.language, "DJConnect", "DJConnect", isDemoMode: model.isDemoMode))
                    .scrollContentBackgroundIfAvailable(.hidden)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
                } detail: {
                    selectedView
                }
                .tint(Color(red: 0.74, green: 0.22, blue: 0.96))
                .accentColor(Color(red: 0.74, green: 0.22, blue: 0.96))
                #else
                TabView(selection: $selectedSection) {
                    NowPlayingView(model: model)
                        .tabItem {
                            Label(localized(model.language, "Now Playing", "Speelt Nu"), systemImage: "music.note")
                        }
                        .tag(DJConnectSection.nowPlaying)
                    QueueView(model: model)
                        .tabItem {
                            Label(localized(model.language, "Queue", "Wachtrij"), systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        .tag(DJConnectSection.queue)
                    PlaylistsView(model: model)
                        .tabItem {
                            Label(localized(model.language, "Playlists", "Afspeellijsten"), systemImage: "rectangle.stack")
                        }
                        .tag(DJConnectSection.playlists)
                    MoreView(model: model) {
                        selectedSection = .nowPlaying
                    }
                    .id(moreResetID)
                        .tabItem {
                            Label(localized(model.language, "More", "Meer"), systemImage: "ellipsis")
                        }
                        .tag(DJConnectSection.settings)
                }
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
                #endif
            }
            #if os(iOS)
            .background(.clear)
            #endif
        }
        .sheet(isPresented: $model.isShowingWelcome) {
            WelcomeView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        }
        .sheet(isPresented: $model.isShowingWhatsNew) {
            WhatsNewView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        }
        .sheet(isPresented: $model.isShowingCrashReportPrompt) {
            CrashReportPromptView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        }
        .sheet(isPresented: $model.isShowingKeychainAccessRequired) {
            KeychainAccessRequiredView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: Binding(
            get: { model.updateRequiredMessage != nil },
            set: { _ in }
        )) {
            UpdateRequiredView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: Binding(
            get: { model.shouldShowPairingScreen },
            set: { isPresented in
                if !isPresented {
                    model.completePairingScreen()
                }
            }
        )) {
            PairingSheetView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
                .interactiveDismissDisabled(true)
                .presentationBackground {
                    DJConnectCanvasBackground()
                }
        }
        .onChange(of: model.shouldShowPairingScreen) {
            if model.shouldShowPairingScreen {
                selectedSection = .nowPlaying
            }
        }
        .onChange(of: selectedSection) {
            if selectedSection == .settings {
                moreResetID = UUID()
            }
        }
        .sheet(isPresented: $model.isShowingWakeWordActivationPrompt) {
            WakeWordActivationPromptView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        }
        .sheet(isPresented: $showingFeedback) {
            FeedbackPromptView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                model.markActiveSession()
            case .inactive, .background:
                model.markInactiveSession()
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedSection {
        case .nowPlaying:
            NowPlayingView(model: model)
        case .queue:
            QueueView(model: model)
        case .playlists:
            PlaylistsView(model: model)
        case .games:
            GamesView(language: model.language, isDemoMode: model.isDemoMode)
        case .settings:
            SettingsView(model: model) {
                selectedSection = .nowPlaying
            }
        case .logs:
            LogsView(model: model)
        case .about:
            AboutView(model: model)
        case .legal:
            LegalNoticesView(language: model.language)
        case .privacy:
            PrivacyView(language: model.language)
        }
    }
}

#if os(macOS)
private struct SidebarItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
                .background {
                    selectionBackground
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            LinearGradient(
                colors: [
                    Color(red: 0.74, green: 0.22, blue: 0.96),
                    Color(red: 0.31, green: 0.28, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Color.clear
        }
    }
}
#endif

private struct PairingSheetView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(spacing: 22) {
            AboutBanner()
                .frame(maxWidth: 520)

            if model.isShowingPairingSuccess {
                pairingSuccess
            } else {
                pairingPending
            }
        }
        .padding(28)
        .frame(minWidth: 360, idealWidth: 560, maxWidth: 680)
        .background(DJConnectCanvasBackground())
        #if os(macOS)
        .frame(minHeight: 560)
        #endif
    }

    private var pairingPending: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(localized(model.language, "Pair DJConnect", "DJConnect koppelen"))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(localized(
                    model.language,
                    "Use these values in Home Assistant to pair this app.",
                    "Koppelgegevens voor Home Assistant:"
                ))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PairingValueCard(
                    title: localized(model.language, "Pair Code", "Koppelcode"),
                    value: model.pairingToken,
                    copyLabel: localized(model.language, "Copy Pair Code", "Koppelcode kopiëren"),
                    prominent: true
                )

                PairingValueCard(
                    title: "Client API url",
                    value: model.localDeviceAPIURL ?? localized(model.language, "Starting Client API...", "Client API wordt gestart..."),
                    copyLabel: localized(model.language, "Copy Client API url", "Client API url kopiëren"),
                    prominent: false
                )
            }

            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)
                    if let pairingMessage = model.pairingMessage {
                        Text(pairingMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Button {
                model.startDemoMode()
            } label: {
                Label(
                    localized(model.language, "Start Demo Mode", "Demo modus starten"),
                    systemImage: "play.circle"
                )
                .foregroundStyle(djConnectAccent)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .djConnectLilacButton()
            .controlSize(.large)

            #if os(macOS)
            Button {
                quitApplication()
            } label: {
                Label(
                    localized(model.language, "Quit App", "App afsluiten"),
                    systemImage: "power"
                )
                .foregroundStyle(djConnectAccent)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .djConnectLilacButton()
            .controlSize(.large)
            #endif
        }
    }

    #if os(macOS)
    private func quitApplication() {
        NSApp.sendAction(#selector(NSApplication.terminate(_:)), to: nil, from: nil)
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exit(EXIT_SUCCESS)
        }
    }
    #endif

    private var pairingSuccess: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 86, weight: .bold))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(localized(model.language, "Pairing successful", "Koppeling succesvol"))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(localized(
                    model.language,
                    "DJConnect is paired with Home Assistant.",
                    "DJConnect is gekoppeld met Home Assistant."
                ))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                model.completePairingScreen()
            } label: {
                Text(localized(model.language, "Let's Start!", "Start"))
                    .font(.headline)
                    .foregroundStyle(djConnectAccent)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .djConnectLilacButton()
            .controlSize(.large)
        }
    }

    private var statusTitle: String {
        if model.isDemoMode {
            return localized(model.language, "Demo Mode", "Demo modus")
        }
        return switch model.pairingStatus {
        case .pairing:
            localized(model.language, "Pairing in progress", "Pairing bezig")
        case .stale:
            localized(model.language, "Not connected to Home Assistant", "Niet gekoppeld aan Home Assistant")
        default:
            localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant")
        }
    }
}

private struct PairingValueCard: View {
    let title: String
    let value: String
    let copyLabel: String
    var prominent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(value)
                    .font(prominent ? .system(.title, design: .monospaced).weight(.semibold) : .system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    copyText(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(djConnectAccent)
                .tint(djConnectAccent)
                .help(copyLabel)
                .accessibilityLabel(copyLabel)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WakeWordActivationPromptView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 20) {
                AboutBanner()
                Text(localized(model.language, "Enable Voice Activation?", "Stemactivatie inschakelen?"))
                    .font(.title2.bold())
                Text(localized(
                    model.language,
                    "Start hands-free with \"Hey DJ\" while DJConnect is open. Microphone and speech recognition permission may be requested.",
                    "Start handsfree met \"Hey DJ\" terwijl DJConnect open is. Microfoon- en spraakherkenningstoestemming kunnen worden gevraagd."
                ))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Button {
                    model.activateWakeWordFromPrompt()
                } label: {
                    Label(localized(model.language, "Enable Voice Activation", "Stemactivatie inschakelen"), systemImage: "waveform")
                        .foregroundStyle(djConnectAccent)
                        .foregroundColor(djConnectAccent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .djConnectLilacButton()
                .controlSize(.large)
                Button {
                    model.dismissWakeWordActivationPrompt()
                } label: {
                    Text(localized(model.language, "Not Now", "Niet nu"))
                        .foregroundStyle(djConnectAccent)
                        .foregroundColor(djConnectAccent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .djConnectLilacButton()
                .controlSize(.large)
            }
            .padding(28)
        }
        .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
        #if os(macOS)
        .frame(minHeight: 420)
        #endif
    }
}

private struct UpdateRequiredView: View {
    @ObservedObject var model: DJConnectAppModel
    private let websiteURL = URL(string: "https://djconnect.dev/start")!

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized(model.language, "Update Required", "Update vereist"))
                        .font(.title2.bold())
                    Text(model.updateRequiredMessage ?? localized(
                        model.language,
                        "Update DJConnect before continuing.",
                        "Update DJConnect voordat je verdergaat."
                    ))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(localized(
                model.language,
                "Playback, queue, playlists, output selection and voice controls are blocked until the app and Home Assistant integration are compatible.",
                "Playback, wachtrij, afspeellijsten, uitvoerapparaat en stemfuncties zijn geblokkeerd totdat de app en Home Assistant-integratie compatibel zijn."
            ))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Link(destination: websiteURL) {
                Label(localized(model.language, "Open DJConnect Update Page", "Open DJConnect updatepagina"), systemImage: "safari")
                    .foregroundStyle(djConnectAccent)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .djConnectLilacButton()
            .controlSize(.large)
        }
        .padding(28)
        .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
    }
}

private struct CrashReportPromptView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 18) {
                AboutBanner()
                Label(localized(model.language, "The app may have crashed", "De app is mogelijk gecrasht"), systemImage: "exclamationmark.triangle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                Text(localized(
                    model.language,
                    "You can share redacted diagnostics by opening a GitHub issue. Nothing is uploaded automatically.",
                    "Je kunt geredigeerde diagnostiek delen via een GitHub issue. Er wordt niets automatisch geüpload."
                ))
                .foregroundStyle(.secondary)
                Text(localized(model.language, "GitHub issue target: pcvantol/djconnect", "GitHub issue doel: pcvantol/djconnect"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button {
                    copyText(model.crashIssueBody())
                } label: {
                    Label(localized(model.language, "Copy Logs", "Logs kopiëren"), systemImage: "doc.on.doc")
                        .foregroundStyle(djConnectAccent)
                        .foregroundColor(djConnectAccent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .djConnectLilacButton()
                Button {
                    if let url = model.crashIssueURL() {
                        openURL(url)
                    }
                    model.dismissCrashReportPrompt()
                } label: {
                    Label(localized(model.language, "Open GitHub Issue", "Open GitHub issue"), systemImage: "arrow.up.forward.app")
                        .foregroundStyle(djConnectAccent)
                        .foregroundColor(djConnectAccent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .djConnectLilacButton()
                Button {
                    model.dismissCrashReportPrompt()
                } label: {
                    Text(localized(model.language, "Not Now", "Niet nu"))
                        .foregroundStyle(djConnectAccent)
                        .foregroundColor(djConnectAccent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .djConnectLilacButton()
            }
            .padding(28)
        }
        .frame(minWidth: 380, idealWidth: 560, maxWidth: 640)
        #if os(macOS)
        .frame(minHeight: 500)
        #endif
    }
}

private struct WelcomeView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(spacing: 22) {
                AboutBanner()
                    .frame(maxWidth: 520)

                Text(.init(localized(
                    model.language,
                    "Please setup in Home Assistant via [djconnect.dev/start](https://djconnect.dev/start)",
                    "Configureer DJConnect in Home Assistant"
                )))
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

                Label(
                    localized(
                        model.language,
                        "A Spotify Premium account is required.",
                        "Een Spotify Premium account is benodigd."
                    ),
                    systemImage: "music.note"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button {
                    model.dismissWelcome()
                } label: {
                    Text(localized(model.language, "Continue", "Doorgaan"))
                        .foregroundStyle(djConnectAccent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .djConnectLilacButton()
                .controlSize(.large)
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
            #if os(macOS)
            .frame(minHeight: 430)
            #endif
        }
    }
}

private struct WhatsNewView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 20) {
                AboutBanner()
                    .frame(maxWidth: 560)

                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text(localized(model.language, "What's New", "Wat is er nieuw?"))
                        .font(.title.bold())
                }

                Text(model.whatsNewTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack(alignment: .topLeading) {
                    ScrollView {
                        Text(model.whatsNewBody)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                    #if os(macOS)
                    .frame(minHeight: 220)
                    #else
                    .frame(minHeight: 260)
                    #endif

                    if model.isLoadingWhatsNew {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(localized(model.language, "Loading release notes...", "Release notes laden..."))
                                .font(.callout)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }

                Button {
                    model.dismissWhatsNew()
                } label: {
                Text(localized(model.language, "Continue", "Doorgaan"))
                        .foregroundStyle(djConnectAccent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .djConnectLilacButton()
                .controlSize(.large)
            }
            .padding(28)
        }
        .frame(minWidth: 360, idealWidth: 560, maxWidth: 680)
        #if os(macOS)
        .frame(minHeight: 560)
        #endif
    }
}

private struct KeychainAccessRequiredView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(localized(model.language, "Keychain access required", "Sleutelhanger-toegang nodig"))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(localized(
                    model.language,
                    "DJConnect cannot work without access to the saved DJConnect token. Choose Allow in the Keychain prompt to continue.",
                    "DJConnect werkt niet zonder toegang tot het opgeslagen DJConnect-token. Kies Sta toe in de sleutelhanger-vraag om door te gaan."
                ))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                model.retryKeychainAccess()
            } label: {
                Label(
                    localized(model.language, "Open Keychain Prompt Again", "Open sleutelhanger-vraag opnieuw"),
                    systemImage: "key"
                )
                .foregroundStyle(djConnectAccent)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .djConnectLilacButton()
            .controlSize(.large)
        }
        .padding(28)
        .frame(minWidth: 360, idealWidth: 460, maxWidth: 560)
    }
}

struct NowPlayingView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        #if os(iOS)
        IOSNowPlayingView(model: model)
        #else
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AboutBanner()
                    VoiceResponseView(model: model)
                    TrackSummaryView(model: model)
                    SetupStatusView(model: model)
                    OutputSelectorView(model: model)
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(screenTitle(model.language, "DJConnect", "DJConnect", isDemoMode: model.isDemoMode))
            .toolbar {
                ToolbarItem {
                    RefreshButton(model: model)
                }
            }
            .task {
                if model.pairingStatus == .paired {
                    model.refresh()
                }
            }
            .djUserNoticeToast(model: model)
        }
        #endif
    }
}

private struct RefreshButton: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        Button {
            model.refresh()
        } label: {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(model.isDemoMode || model.pairingStatus != .paired || model.isRefreshing)
        .help(localized(model.language, "Refresh", "Vernieuwen"))
        .accessibilityLabel(localized(model.language, "Refresh", "Vernieuwen"))
    }
}

private struct DJConnectPressedTintButtonStyle: ButtonStyle {
    enum ShapeKind {
        case circle
        case capsule
    }

    var pressedColor: Color = .purple
    var shape: ShapeKind = .capsule

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    switch shape {
                    case .circle:
                        Circle().fill(pressedColor.opacity(0.34))
                    case .capsule:
                        Capsule().fill(pressedColor.opacity(0.34))
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct AnimatedAlbumArtworkView: View {
    let playback: DJConnectPlayback?
    let isDemoMode: Bool
    let maxWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trackKey: String {
        nowPlayingTrackKey(for: playback)
    }

    var body: some View {
        ZStack {
            artworkContent
                .id(trackKey)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                    removal: .scale(scale: 1.04).combined(with: .opacity)
                ))
        }
        .animation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.42, dampingFraction: 0.82), value: trackKey)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .djArtworkStyle(cornerRadius: 8)
    }

    @ViewBuilder
    private var artworkContent: some View {
        CachedArtworkImage(url: playback?.albumImageURL, mode: .fit) {
            artworkPlaceholder
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.22))
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    artworkTintColor(for: playback).opacity(0.52),
                    Color(red: 0.02, green: 0.03, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if isDemoMode {
                VStack {
                    DJConnectAppIconView()
                        .frame(width: 132, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: Color.black.opacity(0.34), radius: 18, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
            }
        }
    }
}

private enum CachedArtworkImageMode {
    case fit
    case fill
}

private struct CachedArtworkImage<Placeholder: View>: View {
    let url: URL?
    let mode: CachedArtworkImageMode
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var loadedImage: Image?
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let loadedImage, loadedURL == url {
                loadedImage
                    .resizable()
                    .cachedArtworkContentMode(mode)
            } else {
                placeholder()
            }
        }
        .task(id: url?.absoluteString) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let url else {
            loadedURL = nil
            loadedImage = nil
            return
        }
        if loadedURL == url, loadedImage != nil {
            return
        }
        do {
            let data = try await DJConnectArtworkDataCache.shared.data(for: url)
            guard let image = makeArtworkImage(from: data) else {
                loadedURL = nil
                loadedImage = nil
                return
            }
            loadedURL = url
            loadedImage = image
        } catch {
            loadedURL = nil
            loadedImage = nil
        }
    }
}

private extension Image {
    @ViewBuilder
    func cachedArtworkContentMode(_ mode: CachedArtworkImageMode) -> some View {
        switch mode {
        case .fit:
            self.scaledToFit()
        case .fill:
            self.scaledToFill()
        }
    }
}

@MainActor
private func makeArtworkImage(from data: Data) -> Image? {
    #if os(iOS)
    guard let image = UIImage(data: data) else {
        return nil
    }
    return Image(uiImage: image)
    #elseif os(macOS)
    guard let image = NSImage(data: data) else {
        return nil
    }
    return Image(nsImage: image)
    #else
    return nil
    #endif
}

private actor DJConnectArtworkDataCache {
    static let shared = DJConnectArtworkDataCache()

    private struct Entry {
        var data: Data
        var tint: Color?
        var expiresAt: Date
    }

    private var entries: [URL: Entry] = [:]
    private let ttl: TimeInterval = 24 * 60 * 60
    private let maxEntries = 180

    func data(for url: URL) async throws -> Data {
        let now = Date()
        if let entry = entries[url], entry.expiresAt > now {
            return entry.data
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        entries[url] = Entry(data: data, tint: nil, expiresAt: now.addingTimeInterval(ttl))
        trimIfNeeded()
        return data
    }

    func tint(for url: URL, fallback: Color) async -> Color {
        let now = Date()
        if let entry = entries[url], entry.expiresAt > now, let tint = entry.tint {
            return tint
        }

        do {
            let data = try await data(for: url)
            let tint = averageArtworkColor(from: data) ?? fallback
            if var entry = entries[url] {
                entry.tint = tint
                entries[url] = entry
            }
            return tint
        } catch {
            return fallback
        }
    }

    private func trimIfNeeded() {
        guard entries.count > maxEntries else {
            return
        }
        let overflow = entries.count - maxEntries
        let expiredOrOldest = entries
            .sorted { $0.value.expiresAt < $1.value.expiresAt }
            .prefix(overflow)
            .map(\.key)
        for key in expiredOrOldest {
            entries.removeValue(forKey: key)
        }
    }
}

private func nowPlayingCardBackground(tint: Color) -> LinearGradient {
    return LinearGradient(
        colors: [
            tint.opacity(0.70),
            tint.opacity(0.36),
            Color.black.opacity(0.76),
            tint.opacity(0.30)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private func artworkTintColor(for playback: DJConnectPlayback?) -> Color {
    let key = nowPlayingTrackKey(for: playback)
    let palette: [Color] = [
        Color(red: 0.22, green: 0.52, blue: 0.92),
        Color(red: 0.58, green: 0.20, blue: 0.88),
        Color(red: 0.08, green: 0.56, blue: 0.62),
        Color(red: 0.78, green: 0.22, blue: 0.62),
        Color(red: 0.38, green: 0.42, blue: 0.96),
        Color(red: 0.86, green: 0.42, blue: 0.18)
    ]
    let value = key.unicodeScalars.reduce(0) { (($0 &* 31) &+ Int($1.value)) & 0x7fffffff }
    return palette[value % palette.count]
}

private func nowPlayingTrackKey(for playback: DJConnectPlayback?) -> String {
    [
        playback?.albumImageURL?.absoluteString,
        playback?.trackName,
        playback?.artistName,
        playback?.contextURI
    ]
    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty }
    .joined(separator: "|")
}

private func sampledArtworkTint(for playback: DJConnectPlayback?) async -> Color {
    let fallback = artworkTintColor(for: playback)
    guard let url = playback?.albumImageURL else {
        return fallback
    }
    return await DJConnectArtworkDataCache.shared.tint(for: url, fallback: fallback)
}

private func averageArtworkColor(from data: Data) -> Color? {
    #if os(iOS)
    guard let image = UIImage(data: data), let cgImage = image.cgImage else {
        return nil
    }
    #elseif os(macOS)
    guard let image = NSImage(data: data) else {
        return nil
    }
    var rect = NSRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        return nil
    }
    #endif

    var pixel = [UInt8](repeating: 0, count: 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixel,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }
    context.interpolationQuality = .medium
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return Color(
        red: Double(pixel[0]) / 255.0,
        green: Double(pixel[1]) / 255.0,
        blue: Double(pixel[2]) / 255.0
    )
}

#if os(iOS)
private struct IOSNowPlayingView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        AboutBanner()
                        IOSVoiceCard(model: model)
                        IOSTrackHero(model: model)
                        if !model.isDemoMode {
                            IOSConnectionCard(model: model)
                        }
                        OutputSelectorView(model: model)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.clear)
                .refreshable {
                    model.refresh()
                }
            }
            .navigationTitle(screenTitle(model.language, "DJConnect", "DJConnect", isDemoMode: model.isDemoMode))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    RefreshButton(model: model)
                }
            }
            .task {
                if model.pairingStatus == .paired {
                    model.refresh()
                }
            }
            .djUserNoticeToast(model: model)
        }
    }
}

private struct IOSConnectionCard: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                    .frame(width: 28, height: 28)
                    .background(statusColor.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)
                    if let statusSubtitle {
                        Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    }
                }
                Spacer()
                if model.pairingStatus == .paired, !model.isDemoMode {
                    playbackAvailabilityDot
                }
            }

            if model.pairingStatus != .paired {
                HStack {
                    Text(localized(model.language, "Code", "Code"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    CopyableValue(
                        text: model.pairingToken,
                        copyLabel: localized(model.language, "Copy Pair Code", "Koppelcode kopiëren"),
                        prominent: true
                    )
                    if model.isPairing {
                        ProgressView()
                    }
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            if let updateRequiredMessage = model.updateRequiredMessage {
                Label(updateRequiredMessage, systemImage: "arrow.down.app")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if !model.backendAvailable {
                Label(
                    localized(
                            model.language,
                            "Playback is unavailable\nCheck the Spotify authorization in Home Assistant",
                            "Afspelen niet beschikbaar\nControleer de Spotify autorisatie in Home Assistant"
                        ),
                    systemImage: "exclamationmark.triangle"
                )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else if let pairingMessage = model.pairingMessage {
                Text(pairingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .background {
            DJConnectTableRowBackground()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private var playbackAvailabilityDot: some View {
        if model.backendAvailable {
            GlowingStatusDot()
                .frame(width: 22, height: 22)
                .accessibilityLabel(localized(model.language, "Playback available", "Afspelen beschikbaar"))
        } else {
            Circle()
                .fill(Color.red)
                .frame(width: 11, height: 11)
                .shadow(color: Color.red.opacity(0.75), radius: 8)
                .frame(width: 22, height: 22)
                .accessibilityLabel(localized(model.language, "Playback unavailable", "Afspelen niet beschikbaar"))
        }
    }

    private var statusTitle: String {
        return switch model.pairingStatus {
        case .paired:
            localized(model.language, "Paired", "Gekoppeld")
        case .pairing:
            localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant")
        case .stale:
            localized(model.language, "Not connected to Home Assistant", "Niet gekoppeld aan Home Assistant")
        case .unpaired:
            localized(model.language, "Ready to Pair", "Klaar om te koppelen")
        }
    }

    private var statusSubtitle: String? {
        if model.isDemoMode {
            return localized(model.language, "App Store preview without Home Assistant", "App Store preview zonder Home Assistant")
        }
        return switch model.pairingStatus {
        case .paired:
            nil
        case .pairing:
            localized(model.language, "Enter this code in the DJConnect Home Assistant integration", "Vul deze code in bij de DJConnect Home Assistant integratie")
        case .stale:
            localized(model.language, "Open Settings to reset or recover pairing", "Open Instellingen om pairing te herstellen of resetten")
        case .unpaired:
            localized(model.language, "Add your Home Assistant URL in Settings", "Vul je Home Assistant URL in bij Instellingen")
        }
    }

    private var statusIcon: String {
        if model.isDemoMode {
            return "play.circle.fill"
        }
        return switch model.pairingStatus {
        case .paired:
            "checkmark.seal.fill"
        case .pairing:
            "link"
        case .stale:
            "exclamationmark.lock.fill"
        case .unpaired:
            "lock.open.fill"
        }
    }

    private var statusColor: Color {
        if model.isDemoMode {
            return .purple
        }
        return switch model.pairingStatus {
        case .paired:
            model.backendAvailable ? .green : .red
        case .pairing:
            djConnectAccent
        case .stale:
            .orange
        case .unpaired:
            .secondary
        }
    }
}

private struct IOSTrackHero: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var cardTint = Color(red: 0.22, green: 0.52, blue: 0.92)

    private var playback: DJConnectPlayback? {
        model.playback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnimatedAlbumArtworkView(playback: playback, isDemoMode: model.isDemoMode, maxWidth: 300)

            VStack(alignment: .leading, spacing: 5) {
                Text(playback?.trackName ?? localized(model.language, "Nothing Playing", "Niets speelt af"))
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                Text(playback?.artistName ?? playback?.device?.name ?? localized(model.language, "Select an output device", "Kies een uitvoerapparaat"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ProgressScrubberView(model: model)

            SeekControlsView(model: model)
            IOSPlaybackSurface(model: model)
        }
        .padding(14)
        .background(nowPlayingCardBackground(tint: cardTint), in: RoundedRectangle(cornerRadius: 8))
        .task(id: nowPlayingTrackKey(for: playback)) {
            cardTint = await sampledArtworkTint(for: playback)
        }
    }
}

private struct IOSPlaybackSurface: View {
    @ObservedObject var model: DJConnectAppModel
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 30) {
                playbackButton(
                    "backward.end.fill",
                    size: 54,
                    accessibilityLabel: localized(model.language, "Previous Track", "Vorig nummer")
                ) {
                    model.sendPlaybackCommand("previous")
                }

                playbackButton(
                    model.isPlaying ? "pause.fill" : "play.fill",
                    size: 66,
                    prominent: true,
                    accessibilityLabel: model.isPlaying ? localized(model.language, "Pause", "Pauze") : localized(model.language, "Play", "Afspelen")
                ) {
                    model.togglePlayback()
                }

                playbackButton(
                    "forward.end.fill",
                    size: 54,
                    accessibilityLabel: localized(model.language, "Next Track", "Volgend nummer")
                ) {
                    model.sendPlaybackCommand("next")
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.1.fill")
                    .foregroundStyle(.secondary)
                Slider(value: $model.volume, in: 0...60, step: 1) { editing in
                    if !editing {
                        DJConnectHaptics.selection()
                        model.commitVolumeChange()
                    }
                }
                .disabled(!canUsePlayback)
                Text("\(Int(model.volume))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }

            HStack(spacing: 12) {
                ShuffleModeButton(model: model)
                    .disabled(!canUsePlayback)

                RepeatModeButton(model: model)
                    .disabled(!canUsePlayback)
            }
        }
        .disabled(!canUsePlayback)
        .opacity(canUsePlayback ? 1 : 0.55)
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func playbackButton(
        _ systemImage: String,
        size: CGFloat,
        prominent: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            DJConnectHaptics.impact()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: prominent ? 24 : 18, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(prominent ? .white : .primary)
                .background(prominent ? Color.purple : Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(DJConnectPressedTintButtonStyle(pressedColor: djConnectAccent, shape: .circle))
        .disabled(!canUsePlayback)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct IOSVoiceCard: View {
    @ObservedObject var model: DJConnectAppModel
    private var isVoiceAvailable: Bool {
        model.voiceEnabled && model.canUsePlaybackFeatures && model.voiceStatus != .processing
    }

    private var announcementText: String {
        switch model.voiceStatus {
        case .listening:
            return localized(model.language, "Listening...", "Luistert...")
        case .processing:
            return localized(model.language, "Processing...", "Verwerken...")
        case .unavailable:
            if !model.djResponseText.isEmpty {
                return model.djResponseText
            }
            return localized(model.language, "DJ request is currently unavailable", "DJ verzoek momenteel niet beschikbaar")
        case .idle:
            if !model.djResponseText.isEmpty {
                return model.djResponseText
            }
            if !model.backendAvailable {
                return localized(model.language, "DJ request is currently unavailable", "DJ verzoek momenteel niet beschikbaar")
            }
            return localized(
                model.language,
                "Hold the microphone to request music",
                "Houd de microfoon ingedrukt om muziek aan te vragen"
            )
        }
    }

    private var announcementColor: Color {
        switch model.voiceStatus {
        case .listening:
            djConnectAccent
        case .processing:
            djConnectAccent.opacity(0.82)
        case .unavailable:
            .secondary
        case .idle:
            .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(isVoiceAvailable ? .purple : .secondary)
                .frame(width: 34, height: 34)
                .background((isVoiceAvailable ? Color.purple : Color.secondary).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(model.language, "DJ Request", "DJ verzoek"))
                    .font(.headline)
                Text(announcementText)
                    .font(.subheadline)
                    .foregroundStyle(announcementColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            PushToTalkButton(model: model, isEnabled: isVoiceAvailable, size: 46)
        }
        .padding(14)
        .background {
            DJConnectTableRowBackground()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onChange(of: model.djResponseText) { _, newValue in
            if !newValue.isEmpty {
                DJConnectHaptics.success()
            }
        }
    }
}
#endif

private struct PushToTalkButton: View {
    @ObservedObject var model: DJConnectAppModel
    let isEnabled: Bool
    var size: CGFloat = 42
    @State private var isPressing = false

    var body: some View {
        Image(systemName: model.isRecordingVoice ? "stop.fill" : "mic.fill")
            .font(.title2.weight(.semibold))
            .foregroundStyle(isEnabled ? .purple : .secondary)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressing else {
                            return
                        }
                        isPressing = true
                        DJConnectHaptics.impact()
                        model.startVoiceRecording()
                    }
                    .onEnded { _ in
                        guard isPressing else {
                            return
                        }
                        isPressing = false
                        DJConnectHaptics.selection()
                        model.stopVoiceRecordingAndUpload()
                    }
            )
            .onDisappear {
                if isPressing {
                    isPressing = false
                    model.stopVoiceRecordingAndUpload()
                }
            }
            .accessibilityLabel(localized(model.language, "Push to talk", "Push-to-talk"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                DJConnectHaptics.impact()
                model.toggleVoiceRecording()
            }
    }
}

struct SetupStatusView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        if !model.isDemoMode {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text(statusTitle)
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: statusIcon)
                            .foregroundStyle(pairingIconColor)
                    }
                    Spacer()
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: statusDotColor.opacity(0.75), radius: 8)
                        .accessibilityLabel(statusDotLabel)
                }

                if let updateRequiredMessage = model.updateRequiredMessage {
                    Label(updateRequiredMessage, systemImage: "arrow.down.app")
                        .foregroundStyle(.orange)
                } else if !model.backendAvailable {
                    Label(
                        localized(
                            model.language,
                            "Playback is unavailable\nCheck the Spotify authorization in Home Assistant",
                            "Afspelen niet beschikbaar\nControleer de Spotify autorisatie in Home Assistant"
                        ),
                        systemImage: "exclamationmark.triangle"
                    )
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }

                if let pairingMessage = model.pairingMessage {
                    Text(pairingMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusIcon: String {
        if model.isDemoMode {
            return "play.circle"
        }
        return switch model.pairingStatus {
        case .paired:
            "checkmark.seal"
        case .pairing:
            "link"
        case .stale:
            "exclamationmark.lock"
        case .unpaired:
            "lock.open"
        }
    }

    private var statusDotColor: Color {
        guard model.isConnected else {
            return .orange
        }
        return model.backendAvailable ? .green : .red
    }

    private var pairingIconColor: Color {
        if model.isDemoMode {
            return djConnectAccent
        }
        return switch model.pairingStatus {
        case .paired:
            .green
        case .pairing:
            djConnectAccent
        case .stale:
            .orange
        case .unpaired:
            .secondary
        }
    }

    private var statusDotLabel: String {
        guard model.isConnected else {
            return localized(model.language, "Disconnected", "Niet verbonden")
        }
        guard model.backendAvailable else {
            return localized(model.language, "Playback unavailable", "Afspelen niet beschikbaar")
        }
        return localized(model.language, "Connected", "Verbonden")
    }

    private var statusTitle: String {
        if model.isDemoMode {
            return localized(model.language, "Demo Mode", "Demo modus")
        }
        return switch model.pairingStatus {
        case .paired:
            localized(model.language, "Paired", "Gekoppeld")
        case .pairing:
            localized(model.language, "Pairing", "Koppelen")
        case .stale:
            localized(model.language, "Stale", "Verlopen")
        case .unpaired:
            localized(model.language, "Unpaired", "Niet gekoppeld")
        }
    }
}

struct TrackSummaryView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var cardTint = Color(red: 0.22, green: 0.52, blue: 0.92)

    private var playback: DJConnectPlayback? {
        model.playback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AnimatedAlbumArtworkView(playback: playback, isDemoMode: model.isDemoMode, maxWidth: 320)

            VStack(alignment: .leading, spacing: 6) {
                Text(playback?.trackName ?? localized(model.language, "Nothing playing", "Niets speelt af"))
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(playback?.artistName ?? playback?.device?.name ?? localized(model.language, "Select an output device", "Kies een uitvoerapparaat"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ProgressScrubberView(model: model)

            SeekControlsView(model: model)
            PlaybackControlsView(model: model)
        }
        .padding(16)
        .background(nowPlayingCardBackground(tint: cardTint), in: RoundedRectangle(cornerRadius: 8))
        .task(id: nowPlayingTrackKey(for: playback)) {
            cardTint = await sampledArtworkTint(for: playback)
        }
    }
}

private struct ProgressScrubberView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var seekTargetMS: Int?

    private var durationMS: Int {
        max(model.playback?.durationMS ?? 0, 0)
    }

    private var currentMS: Int {
        min(max(seekTargetMS ?? model.playback?.progressMS ?? 0, 0), max(durationMS, 0))
    }

    private var canSeek: Bool {
        model.canUsePlaybackFeatures && model.playback?.hasPlayback == true && durationMS > 0
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Slider(
                value: Binding(
                    get: { Double(currentMS) },
                    set: { newValue in
                        seekTargetMS = min(max(Int(newValue.rounded()), 0), durationMS)
                    }
                ),
                in: 0...Double(max(durationMS, 1)),
                onEditingChanged: { isEditing in
                    if !isEditing {
                        let target = seekTargetMS ?? currentMS
                        seekTargetMS = nil
                        guard abs(target - (model.playback?.progressMS ?? 0)) >= 500 else {
                            return
                        }
                        DJConnectHaptics.selection()
                        model.commitSeek(to: target)
                    }
                }
            )
            .tint(djConnectAccent)
            .disabled(!canSeek)
            .opacity(canSeek ? 1 : 0.55)
            .accessibilityLabel(localized(model.language, "Playback position", "Afspeelpositie"))

            Text("\(formatPlaybackTime(currentMS)) / \(formatPlaybackTime(durationMS))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(durationMS <= 0)
                .opacity(durationMS > 0 ? 1 : 0)
        }
    }

    private func formatPlaybackTime(_ milliseconds: Int) -> String {
        let totalSeconds = max(milliseconds, 0) / 1_000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}

private struct SeekControlsView: View {
    @ObservedObject var model: DJConnectAppModel
    private let seekStepMS = 15_000

    private var canSeek: Bool {
        model.canUsePlaybackFeatures && model.playback?.hasPlayback == true
    }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                DJConnectHaptics.impact()
                model.seekRelative(milliseconds: -seekStepMS)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 48, height: 44)
                    .foregroundStyle(.white)
            }
            .help(localized(model.language, "Back 15 seconds", "15 seconden terug"))
            .accessibilityLabel(localized(model.language, "Back 15 seconds", "15 seconden terug"))

            Button {
                DJConnectHaptics.impact()
                model.seekRelative(milliseconds: seekStepMS)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 48, height: 44)
                    .foregroundStyle(.white)
            }
            .help(localized(model.language, "Forward 15 seconds", "15 seconden vooruit"))
            .accessibilityLabel(localized(model.language, "Forward 15 seconds", "15 seconden vooruit"))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.white)
        .disabled(!canSeek)
        .opacity(canSeek ? 1 : 0.45)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct PlaybackControlsView: View {
    @ObservedObject var model: DJConnectAppModel
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 28) {
                Button {
                    DJConnectHaptics.impact()
                    model.sendPlaybackCommand("previous")
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 44, height: 40)
                }
                .buttonStyle(.bordered)
                .buttonStyle(DJConnectPressedTintButtonStyle(pressedColor: djConnectAccent))
                .help(localized(model.language, "Previous", "Vorige"))
                .accessibilityLabel(localized(model.language, "Previous Track", "Vorig nummer"))
                .disabled(!canUsePlayback)

                Button {
                    DJConnectHaptics.impact()
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 50, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(djConnectAccent)
                .help(model.isPlaying ? localized(model.language, "Pause", "Pauze") : localized(model.language, "Play", "Afspelen"))
                .accessibilityLabel(model.isPlaying ? localized(model.language, "Pause", "Pauze") : localized(model.language, "Play", "Afspelen"))
                .disabled(!canUsePlayback)

                Button {
                    DJConnectHaptics.impact()
                    model.sendPlaybackCommand("next")
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 44, height: 40)
                }
                .buttonStyle(.bordered)
                .buttonStyle(DJConnectPressedTintButtonStyle(pressedColor: djConnectAccent))
                .help(localized(model.language, "Next", "Volgende"))
                .accessibilityLabel(localized(model.language, "Next Track", "Volgend nummer"))
                .disabled(!canUsePlayback)
            }

            HStack {
                Image(systemName: "speaker.wave.1")
                Slider(value: $model.volume, in: 0...60, step: 1) { editing in
                    if !editing {
                        DJConnectHaptics.selection()
                        model.commitVolumeChange()
                    }
                }
                .tint(djConnectAccent)
                .disabled(!canUsePlayback)
                Text("\(Int(model.volume))")
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }

            HStack {
                ShuffleModeButton(model: model)
                    .disabled(!canUsePlayback)

                RepeatModeButton(model: model)
                    .disabled(!canUsePlayback)
            }
        }
        .opacity(canUsePlayback ? 1 : 0.55)
    }
}

private struct QueueItemRow: View {
    let item: DJConnectQueueItem
    var isLoading = false

    var body: some View {
        HStack(spacing: 12) {
            QueueArtworkView(url: item.albumImageURL)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if let artist = item.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 30, height: 30)
            } else if item.uri?.isEmpty == false {
                RowPlayIndicator()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.72),
                    Color(red: 0.20, green: 0.08, blue: 0.32).opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(djConnectAccent.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct RowPlayIndicator: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.84, green: 0.18, blue: 1.0),
                        Color(red: 0.16, green: 0.56, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: Color(red: 0.84, green: 0.18, blue: 1.0).opacity(0.28), radius: 8, y: 3)
            .accessibilityHidden(true)
    }
}

private struct QueueArtworkView: View {
    let url: URL?
    var fallbackSystemImage = "music.note"

    var body: some View {
        GeometryReader { proxy in
            CachedArtworkImage(url: url, mode: .fill) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.14))
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .djArtworkStyle(cornerRadius: 6)
    }
}

private struct DJConnectArtworkStyle: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private extension View {
    func djArtworkStyle(cornerRadius: CGFloat) -> some View {
        modifier(DJConnectArtworkStyle(cornerRadius: cornerRadius))
    }
}

private struct OutputSelectorView: View {
    @ObservedObject var model: DJConnectAppModel
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized(model.language, "Output Device", "Uitvoerapparaat"))
                    .font(.headline)
                Spacer()
                Button {
                    model.loadOutputs()
                } label: {
                    if model.isLoadingOutputs {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.borderless)
                .tint(.white)
                .disabled(model.isDemoMode || !canUsePlayback || model.isLoadingOutputs)
                .help(localized(model.language, "Reload Output Devices", "Uitvoerapparaten herladen"))
                .accessibilityLabel(localized(model.language, "Reload Output Devices", "Uitvoerapparaten herladen"))
            }

            if model.availableOutputs.isEmpty {
                Text(localizedOutputName(model.selectedOutput, language: model.language))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Picker("", selection: Binding(
                    get: { model.selectedOutput },
                    set: { selected in
                        if let output = model.availableOutputs.first(where: { $0.name == selected || $0.id == selected }) {
                            DJConnectHaptics.selection()
                            model.selectOutput(output)
                        }
                    }
                )) {
                    ForEach(model.availableOutputs) { output in
                        Label(output.name, systemImage: output.active == true ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .tag(output.name)
                    }
                }
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
                .labelsHidden()
                .tint(djConnectAccent)
                .foregroundStyle(djConnectAccent)
                .disabled(!canUsePlayback)
            }
        }
        .opacity(canUsePlayback ? 1 : 0.55)
        .tint(djConnectAccent)
        .task {
            if model.canUsePlaybackFeatures, model.availableOutputs.isEmpty {
                model.loadOutputs()
            }
        }
        #if os(iOS)
        .padding(14)
        .background {
            DJConnectTableRowBackground()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        #endif
    }
}

private struct GlowingStatusDot: View {
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 12, height: 12)
            .shadow(color: Color.green.opacity(0.8), radius: 9)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .accessibilityLabel(Text("Connected"))
    }
}

private struct ShuffleModeButton: View {
    @ObservedObject var model: DJConnectAppModel

    private var isShuffling: Bool {
        model.playback?.shuffle == true
    }

    var body: some View {
        Button {
            DJConnectHaptics.impact()
            let nextValue = !isShuffling
            var updated = model.playback ?? DJConnectPlayback()
            updated.shuffle = nextValue
            model.playback = updated
            model.setShuffle(nextValue)
        } label: {
            Image(systemName: "shuffle")
                .symbolVariant(isShuffling ? .fill : .none)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 40)
        }
        .buttonStyle(.bordered)
        .tint(isShuffling ? djConnectAccent : .secondary)
        .help(localized(model.language, "Shuffle", "Shuffle"))
        .accessibilityLabel(localized(model.language, "Shuffle", "Shuffle"))
        .accessibilityValue(isShuffling ? localized(model.language, "On", "Aan") : localized(model.language, "Off", "Uit"))
    }
}

private struct RepeatModeButton: View {
    @ObservedObject var model: DJConnectAppModel

    private var repeatState: DJConnectRepeatState {
        model.playback?.repeatState ?? .off
    }

    var body: some View {
        Button {
            DJConnectHaptics.impact()
            let nextState = repeatState.next
            var updated = model.playback ?? DJConnectPlayback()
            updated.repeatState = nextState
            model.playback = updated
            model.setRepeat(nextState)
        } label: {
            Image(systemName: repeatState.systemImage)
                .symbolVariant(repeatState == .off ? .none : .fill)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 40)
        }
        .buttonStyle(.bordered)
        .tint(repeatState == .off ? .secondary : djConnectAccent)
        .help(repeatHelpText)
        .accessibilityLabel(localized(model.language, "Repeat", "Herhaal"))
        .accessibilityValue(repeatState.localizedName(language: model.language))
    }

    private var repeatHelpText: String {
        let state = repeatState.localizedName(language: model.language)
        let next = repeatState.next.localizedName(language: model.language)
        return localized(
            model.language,
            "Repeat: \(state). Click for \(next).",
            "Herhaal: \(state). Klik voor \(next)."
        )
    }
}

private extension DJConnectRepeatState {
    var next: DJConnectRepeatState {
        switch self {
        case .off:
            .track
        case .track:
            .context
        case .context:
            .off
        }
    }

    var systemImage: String {
        switch self {
        case .off, .context:
            "repeat"
        case .track:
            "repeat.1"
        }
    }

    func localizedName(language: String) -> String {
        switch self {
        case .off:
            localized(language, "Off", "Uit")
        case .track:
            localized(language, "Track", "Nummer")
        case .context:
            localized(language, "Context", "Context")
        }
    }
}

struct VoiceResponseView: View {
    @ObservedObject var model: DJConnectAppModel
    private var isVoiceAvailable: Bool {
        model.voiceEnabled && model.canUsePlaybackFeatures && model.voiceStatus != .processing
    }

    private var announcementText: String {
        switch model.voiceStatus {
        case .listening:
            return localized(model.language, "Listening...", "Luistert...")
        case .processing:
            return localized(model.language, "Processing...", "Verwerken...")
        case .unavailable:
            if !model.djResponseText.isEmpty {
                return model.djResponseText
            }
            return localized(model.language, "DJ request is currently unavailable", "DJ verzoek momenteel niet beschikbaar")
        case .idle:
            if !model.djResponseText.isEmpty {
                return model.djResponseText
            }
            if !model.backendAvailable {
                return localized(model.language, "DJ request is currently unavailable", "DJ verzoek momenteel niet beschikbaar")
            }
            return localized(
                model.language,
                "Hold the microphone to request music",
                "Houd de microfoon ingedrukt om muziek aan te vragen"
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(localized(model.language, "DJ Request", "DJ verzoek"), systemImage: "waveform")
                    .foregroundStyle(isVoiceAvailable ? .primary : .secondary)
                Spacer()
                PushToTalkButton(model: model, isEnabled: isVoiceAvailable)
                    .help(localized(model.language, "Push to talk", "Push-to-talk"))
            }

            if model.isRecordingVoice {
                Label(localized(model.language, "Recording", "Neemt op"), systemImage: "record.circle")
                    .foregroundStyle(.red)
            }
            Text(announcementText)
                .foregroundStyle(model.djResponseText.isEmpty || !model.backendAvailable || model.voiceStatus != .idle ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: model.djResponseText) { _, newValue in
            if !newValue.isEmpty {
                DJConnectHaptics.success()
            }
        }
    }
}

struct QueueView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var statusToast: String?
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        NavigationStack {
            List {
                if model.queueItems.isEmpty {
                    DJConnectEmptyState(
                        title: localized(model.language, "No Queue", "Geen wachtrij"),
                        systemImage: "music.note.list"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(Array(model.queueItems.enumerated()), id: \.offset) { index, item in
                        Button {
                            DJConnectHaptics.impact()
                            showStatusToast(localized(model.language, "Selected track is starting...", "Gekozen nummer wordt gestart..."))
                            model.startQueueItem(item, at: index)
                        } label: {
                            QueueItemRow(item: item, isLoading: model.loadingQueueItemIndex == index)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(djConnectListRowInsets)
                        .disabled(!canUsePlayback || model.loadingQueueItemIndex != nil || !model.canStartQueueItem(item))
                        .accessibilityLabel(item.displayTitle)
                    }
                }
            }
            .refreshable {
                guard !model.isDemoMode, canUsePlayback else {
                    return
                }
                await model.refreshQueue()
            }
            .navigationTitle(screenTitle(model.language, "Queue", "Wachtrij", isDemoMode: model.isDemoMode))
            .scrollContentBackgroundIfAvailable(.hidden)
            .background(DJConnectCanvasBackground())
            .overlay(alignment: .top) {
                if let statusToast {
                    StatusToast(text: statusToast)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        model.loadQueue()
                    } label: {
                        if model.isLoadingQueue {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isDemoMode || !canUsePlayback || model.isLoadingQueue)
                    .help(localized(model.language, "Reload Queue", "Wachtrij herladen"))
                    .accessibilityLabel(localized(model.language, "Reload Queue", "Wachtrij herladen"))
                }
            }
            .task {
                guard model.canUsePlaybackFeatures else {
                    return
                }
                model.loadQueue()
            }
            .onChange(of: model.userNotice?.id) { _, _ in
                if let text = model.userNotice?.text {
                    showStatusToast(text)
                }
            }
        }
        .background(DJConnectCanvasBackground())
    }

    private func showStatusToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = text
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast == text else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }
}

struct PlaylistsView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var statusToast: String?
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        NavigationStack {
            List {
                if model.playlistItems.isEmpty {
                    DJConnectEmptyState(
                        title: localized(model.language, "No Playlists", "Geen afspeellijsten"),
                        systemImage: "rectangle.stack"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(model.playlistItems) { playlist in
                        Button {
                            DJConnectHaptics.impact()
                            showStatusToast(localized(model.language, "Selected playlist is starting...", "Gekozen playlist wordt gestart..."))
                            model.startPlaylist(playlist)
                        } label: {
                            PlaylistRow(playlist: playlist, isLoading: model.loadingPlaylistID == playlist.id)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(djConnectListRowInsets)
                        .disabled(!canUsePlayback || model.loadingPlaylistID != nil)
                    }
                }
            }
            .refreshable {
                guard !model.isDemoMode, canUsePlayback else {
                    return
                }
                await model.refreshPlaylists()
            }
            .navigationTitle(screenTitle(model.language, "Playlists", "Afspeellijsten", isDemoMode: model.isDemoMode))
            .scrollContentBackgroundIfAvailable(.hidden)
            .background(DJConnectCanvasBackground())
            .overlay(alignment: .top) {
                if let statusToast {
                    StatusToast(text: statusToast)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        model.loadPlaylists()
                    } label: {
                        if model.isLoadingPlaylists {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isDemoMode || !canUsePlayback || model.isLoadingPlaylists)
                    .help(localized(model.language, "Reload Playlists", "Afspeellijsten herladen"))
                    .accessibilityLabel(localized(model.language, "Reload Playlists", "Afspeellijsten herladen"))
                }
            }
            .task {
                guard model.canUsePlaybackFeatures else {
                    return
                }
                model.loadPlaylists()
            }
            .onChange(of: model.userNotice?.id) { _, _ in
                if let text = model.userNotice?.text {
                    showStatusToast(text)
                }
            }
        }
    }

    private func showStatusToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = text
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast == text else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }
}

private struct DJConnectEmptyState: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.8))
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }
}

private struct StatusToast: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "play.fill")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.36, blue: 0.0).opacity(0.96),
                        Color(red: 0.82, green: 0.12, blue: 1.0).opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.42), lineWidth: 1.2)
            }
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Color(red: 1.0, green: 0.36, blue: 0.0).opacity(0.34), radius: 16, y: 8)
            .accessibilityAddTraits(.isStaticText)
    }
}

private struct DJConnectUserNoticeToastModifier: ViewModifier {
    @ObservedObject var model: DJConnectAppModel
    @State private var toast: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    StatusToast(text: toast)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: model.userNotice?.id) { _, _ in
                guard let text = model.userNotice?.text else {
                    return
                }
                show(text)
            }
    }

    private func show(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            toast = text
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard toast == text else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                toast = nil
            }
        }
    }
}

private extension View {
    func djUserNoticeToast(model: DJConnectAppModel) -> some View {
        modifier(DJConnectUserNoticeToastModifier(model: model))
    }
}

private struct PlaylistRow: View {
    let playlist: DJConnectPlaylist
    var isLoading = false

    var body: some View {
        HStack(spacing: 12) {
            QueueArtworkView(url: playlist.imageURL, fallbackSystemImage: "music.note.list")
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 30, height: 30)
            } else {
                RowPlayIndicator()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.72),
                    Color(red: 0.20, green: 0.08, blue: 0.32).opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(djConnectAccent.opacity(0.12), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

private enum LocalGameMode: String, CaseIterable, Identifiable {
    case pong
    case asteroids
    case fly
    case pacman

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pong:
            "Paddle Rally"
        case .asteroids:
            "Meteor Run"
        case .fly:
            "Sky Dash"
        case .pacman:
            "Maze Chase"
        }
    }

    var tint: Color {
        switch self {
        case .pong:
            .orange
        case .asteroids:
            djConnectAccent.opacity(0.92)
        case .fly:
            .cyan
        case .pacman:
            .yellow
        }
    }

    var highScoreKey: String {
        "djconnect.app.game.\(rawValue).high"
    }
}

private struct GamesView: View {
    let language: String
    let isDemoMode: Bool
    @State private var selectedGame = LocalGameMode.pong

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("", selection: $selectedGame) {
                        ForEach(LocalGameMode.allCases) { game in
                            Text(game.title).tag(game)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .tint(djConnectAccent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .frame(maxWidth: 540)

                    LocalGameSurface(game: selectedGame, language: language)
                }
                .padding(24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(DJConnectCanvasBackground())
            .navigationTitle(localized(language, "Games", "Games"))
        }
        .id("games-\(isDemoMode)-\(language)")
    }
}

private struct LocalGameSurface: View {
    let game: LocalGameMode
    let language: String
    @AppStorage("djconnect.app.game.pong.high") private var pongHighScore = 0
    @AppStorage("djconnect.app.game.asteroids.high") private var asteroidsHighScore = 0
    @AppStorage("djconnect.app.game.fly.high") private var flyHighScore = 0
    @AppStorage("djconnect.app.game.pacman.high") private var pacmanHighScore = 0
    @State private var score = 0
    @State private var paddleY: CGFloat = 86
    @State private var ballX: CGFloat = 160
    @State private var ballY: CGFloat = 86
    @State private var ballVX: CGFloat = 3
    @State private var ballVY: CGFloat = 2
    @State private var shipX: CGFloat = 160
    @State private var asteroidX: CGFloat = 80
    @State private var asteroidY: CGFloat = 48
    @State private var asteroidVX: CGFloat = 2
    @State private var asteroidBulletY: CGFloat = 120
    @State private var asteroidBulletActive = false
    @State private var planeY: CGFloat = 86
    @State private var obstacleX: CGFloat = 300
    @State private var obstacleY: CGFloat = 90
    @State private var flyShotX: CGFloat = 58
    @State private var flyShotActive = false
    @State private var pacmanX: CGFloat = 46
    @State private var pacmanY: CGFloat = 86
    @State private var pacmanDX: CGFloat = 1
    @State private var pacmanDY: CGFloat = 0
    @State private var ghostX: CGFloat = 250
    @State private var ghostY: CGFloat = 86
    @State private var pellets: Set<Int> = Set(0..<24)
    @State private var flashUntil = Date.distantPast
    @State private var isPlaying = false
    @FocusState private var isGameFocused: Bool
    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var highScore: Int {
        switch game {
        case .pong:
            pongHighScore
        case .asteroids:
            asteroidsHighScore
        case .fly:
            flyHighScore
        case .pacman:
            pacmanHighScore
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(game.title, systemImage: gameIcon)
                    .font(.title2.bold())
                    .foregroundStyle(game.tint)
                Spacer()
                Text("\(localized(language, "Score", "Score")) \(score)")
                    .monospacedDigit()
                Text("\(localized(language, "High", "High")) \(highScore)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size)
                    context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(Color.black.opacity(0.62)))
                    context.stroke(Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 8), with: .color(.white.opacity(0.10)), lineWidth: 1)
                    drawGame(in: &context, size: size, isPlaying: isPlaying)
                    if Date() < flashUntil {
                        context.stroke(Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 8), with: .color(.red), lineWidth: 3)
                    }
                }

                if !isPlaying {
                    Button {
                        startGame()
                    } label: {
                        Label(localized(language, "Tap to play", "Tik om te spelen"), systemImage: "play.fill")
                            .font(.headline)
                            .frame(minWidth: 180)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .djConnectLilacButton()
                    .controlSize(.large)
                }
            }
            .aspectRatio(320.0 / 170.0, contentMode: .fit)
            .frame(maxWidth: 640)
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(value.location)
                    }
                    .onEnded { _ in
                        fire()
                    }
            )
            .onReceive(tick) { _ in
                guard isPlaying else {
                    return
                }
                update()
            }
            .onChange(of: game) {
                reset()
                isPlaying = false
            }

            HStack(spacing: 10) {
                Button {
                    DJConnectHaptics.impact()
                    move(-1)
                } label: {
                    Label(primaryMoveLabel, systemImage: primaryMoveIcon)
                        .labelStyle(.iconOnly)
                }
                .help(primaryMoveLabel)

                Button {
                    DJConnectHaptics.impact()
                    move(1)
                } label: {
                    Label(secondaryMoveLabel, systemImage: secondaryMoveIcon)
                        .labelStyle(.iconOnly)
                }
                .help(secondaryMoveLabel)

                if game != .pong && game != .pacman {
                    Button {
                        DJConnectHaptics.impact()
                        fire()
                    } label: {
                        Label(localized(language, "Fire", "Schiet"), systemImage: "sparkle")
                            .labelStyle(.iconOnly)
                    }
                    .help(localized(language, "Fire", "Schiet"))
                }

                Button {
                    DJConnectHaptics.selection()
                    reset()
                } label: {
                    Label(localized(language, "Reset", "Reset"), systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .help(localized(language, "Reset", "Reset"))
            }
            .buttonStyle(.bordered)
            .djConnectLilacButton()
            .controlSize(.large)

            Text(helpText)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .focusable(true)
        .focused($isGameFocused)
        .onKeyPress(.upArrow) {
            handleArrowKey(.up)
        }
        .onKeyPress(.downArrow) {
            handleArrowKey(.down)
        }
        .onKeyPress(.leftArrow) {
            handleArrowKey(.left)
        }
        .onKeyPress(.rightArrow) {
            handleArrowKey(.right)
        }
        .onKeyPress(.space) {
            fire()
            return .handled
        }
        .onAppear {
            reset()
        }
        .onDisappear {
            isPlaying = false
            isGameFocused = false
            reset()
        }
    }

    private var gameIcon: String {
        switch game {
        case .pong:
            "circle.grid.cross"
        case .asteroids:
            "paperplane"
        case .fly:
            "airplane"
        case .pacman:
            "circle.circle"
        }
    }

    private var primaryMoveLabel: String {
        game == .asteroids ? localized(language, "Left", "Links") : localized(language, "Up", "Omhoog")
    }

    private var secondaryMoveLabel: String {
        game == .asteroids ? localized(language, "Right", "Rechts") : localized(language, "Down", "Omlaag")
    }

    private var primaryMoveIcon: String {
        game == .asteroids ? "chevron.left" : "chevron.up"
    }

    private var secondaryMoveIcon: String {
        game == .asteroids ? "chevron.right" : "chevron.down"
    }

    private var helpText: String {
        switch game {
        case .pong:
            localized(language, "Move the paddle and keep the ball alive.", "Beweeg het batje en houd de bal in het spel.")
        case .asteroids:
            localized(language, "Move left and right. Fire to clear asteroids.", "Beweeg links en rechts. Schiet om asteroids te raken.")
        case .fly:
            localized(language, "Fly through the gaps. Fire clears an obstacle.", "Vlieg door de openingen. Schieten ruimt een obstakel op.")
        case .pacman:
            localized(language, "Eat dots and dodge the ghost.", "Eet bolletjes en ontwijk de geest.")
        }
    }

    private func drawGame(in context: inout GraphicsContext, size: CGSize, isPlaying: Bool) {
        let scaleX = size.width / 320
        let scaleY = size.height / 170

        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: x * scaleX, y: y * scaleY, width: width * scaleX, height: height * scaleY)
        }

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scaleX, y: y * scaleY)
        }

        context.draw(Text(game.title).font(.headline).foregroundColor(game.tint), at: point(12, 18), anchor: .leading)

        switch game {
        case .pong:
            var centerLine = Path()
            centerLine.move(to: point(160, 22))
            centerLine.addLine(to: point(160, 148))
            context.stroke(centerLine, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 7]))
            context.fill(Path(roundedRect: rect(18, paddleY - 17, 8, 34), cornerRadius: 3), with: .color(.orange))
            if isPlaying {
                context.fill(Path(ellipseIn: rect(ballX - 4, ballY - 4, 8, 8)), with: .color(.green))
            }
        case .asteroids:
            var ship = Path()
            ship.move(to: point(shipX, 128))
            ship.addLine(to: point(shipX - 9, 146))
            ship.addLine(to: point(shipX + 9, 146))
            ship.closeSubpath()
            context.stroke(ship, with: .color(djConnectAccent), lineWidth: 2)
            context.stroke(Path(ellipseIn: rect(asteroidX - 10, asteroidY - 10, 20, 20)), with: .color(.pink), lineWidth: 2)
            if asteroidBulletActive {
                context.fill(Path(roundedRect: rect(shipX - 2, asteroidBulletY, 4, 10), cornerRadius: 2), with: .color(.cyan))
            }
        case .fly:
            var plane = Path()
            plane.move(to: point(62, planeY))
            plane.addLine(to: point(30, planeY - 12))
            plane.addLine(to: point(30, planeY + 12))
            plane.closeSubpath()
            context.fill(plane, with: .color(.cyan))
            context.fill(Path(roundedRect: rect(obstacleX - 8, obstacleY - 18, 16, 36), cornerRadius: 3), with: .color(.brown))
            if flyShotActive {
                context.fill(Path(roundedRect: rect(flyShotX, planeY - 2, 14, 4), cornerRadius: 2), with: .color(.cyan))
            }
        case .pacman:
            for pellet in pellets {
                let column = pellet % 8
                let row = pellet / 8
                context.fill(
                    Path(ellipseIn: rect(CGFloat(48 + column * 28) - 2, CGFloat(52 + row * 28) - 2, 4, 4)),
                    with: .color(.white.opacity(0.82))
                )
            }
            context.fill(Path(ellipseIn: rect(pacmanX - 8, pacmanY - 8, 16, 16)), with: .color(.yellow))
            drawPacmanMouth(in: &context, at: point(pacmanX, pacmanY), scaleX: scaleX, scaleY: scaleY)
            drawGhost(in: &context, at: point(ghostX, ghostY), scaleX: scaleX, scaleY: scaleY)
        }
    }

    private func drawPacmanMouth(in context: inout GraphicsContext, at center: CGPoint, scaleX: CGFloat, scaleY: CGFloat) {
        let radius = 8 * min(scaleX, scaleY)
        let mouthAngle: CGFloat
        if abs(pacmanDX) >= abs(pacmanDY) {
            mouthAngle = pacmanDX < 0 ? .pi : 0
        } else {
            mouthAngle = pacmanDY < 0 ? -.pi / 2 : .pi / 2
        }
        let spread = CGFloat.pi / 5
        var mouth = Path()
        mouth.move(to: center)
        mouth.addArc(
            center: center,
            radius: radius + 1,
            startAngle: .radians(Double(mouthAngle - spread)),
            endAngle: .radians(Double(mouthAngle + spread)),
            clockwise: false
        )
        mouth.closeSubpath()
        context.fill(mouth, with: .color(.black.opacity(0.82)))
    }

    private func drawGhost(in context: inout GraphicsContext, at center: CGPoint, scaleX: CGFloat, scaleY: CGFloat) {
        let width = 18 * scaleX
        let height = 18 * scaleY
        let left = center.x - width / 2
        let right = center.x + width / 2
        let top = center.y - height / 2
        let bottom = center.y + height / 2
        let midY = center.y - 1 * scaleY

        var ghost = Path()
        ghost.move(to: CGPoint(x: left, y: bottom))
        ghost.addLine(to: CGPoint(x: left, y: midY))
        ghost.addQuadCurve(to: CGPoint(x: center.x, y: top), control: CGPoint(x: left, y: top))
        ghost.addQuadCurve(to: CGPoint(x: right, y: midY), control: CGPoint(x: right, y: top))
        ghost.addLine(to: CGPoint(x: right, y: bottom))
        ghost.addLine(to: CGPoint(x: center.x + width * 0.22, y: bottom - height * 0.18))
        ghost.addLine(to: CGPoint(x: center.x, y: bottom))
        ghost.addLine(to: CGPoint(x: center.x - width * 0.22, y: bottom - height * 0.18))
        ghost.closeSubpath()
        context.fill(ghost, with: .color(.pink))

        let eyeSize = 4.3 * min(scaleX, scaleY)
        let pupilSize = 1.8 * min(scaleX, scaleY)
        for offset in [-3.4 * scaleX, 3.4 * scaleX] {
            let eyeCenter = CGPoint(x: center.x + offset, y: center.y - 2.2 * scaleY)
            context.fill(
                Path(ellipseIn: CGRect(x: eyeCenter.x - eyeSize / 2, y: eyeCenter.y - eyeSize / 2, width: eyeSize, height: eyeSize)),
                with: .color(.white)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: eyeCenter.x - pupilSize / 2, y: eyeCenter.y - pupilSize / 2, width: pupilSize, height: pupilSize)),
                with: .color(djConnectAccent)
            )
        }
    }

    private func move(_ direction: CGFloat) {
        if !isPlaying {
            startGame()
        }
        switch game {
        case .pong:
            paddleY = min(max(paddleY + direction * 12, 42), 126)
        case .asteroids:
            shipX = min(max(shipX + direction * 14, 24), 296)
        case .fly:
            planeY = min(max(planeY + direction * 12, 52), 138)
        case .pacman:
            pacmanDY = direction
            pacmanDX = 0
        }
    }

    private enum ArrowKey {
        case up
        case down
        case left
        case right
    }

    private func handleArrowKey(_ key: ArrowKey) -> KeyPress.Result {
        switch (game, key) {
        case (.pong, .up), (.fly, .up), (.asteroids, .left), (.pacman, .up):
            move(-1)
        case (.pong, .down), (.fly, .down), (.asteroids, .right), (.pacman, .down):
            move(1)
        case (.pacman, .left):
            pacmanDX = -1
            pacmanDY = 0
        case (.pacman, .right):
            pacmanDX = 1
            pacmanDY = 0
        default:
            break
        }
        return .handled
    }

    private func handleDrag(_ location: CGPoint) {
        if !isPlaying {
            startGame()
        }
        switch game {
        case .pong:
            paddleY = min(max(location.y / 1.0, 42), 126)
        case .asteroids:
            shipX = min(max(location.x / 1.0, 24), 296)
        case .fly:
            planeY = min(max(location.y / 1.0, 52), 138)
        case .pacman:
            let dx = location.x - pacmanX
            let dy = location.y - pacmanY
            if abs(dx) > abs(dy) {
                pacmanDX = dx < 0 ? -1 : 1
                pacmanDY = 0
            } else {
                pacmanDX = 0
                pacmanDY = dy < 0 ? -1 : 1
            }
        }
    }

    private func fire() {
        if !isPlaying {
            startGame()
            return
        }
        switch game {
        case .pong:
            break
        case .asteroids:
            if !asteroidBulletActive {
                asteroidBulletActive = true
                asteroidBulletY = 120
            }
        case .fly:
            if !flyShotActive {
                flyShotActive = true
                flyShotX = 58
            }
        case .pacman:
            break
        }
    }

    private func startGame() {
        DJConnectHaptics.selection()
        isPlaying = true
        isGameFocused = true
    }

    private func update() {
        switch game {
        case .pong:
            ballX += ballVX
            ballY += ballVY
            if ballY <= 42 || ballY >= 156 {
                ballVY *= -1
            }
            if ballX >= 306 {
                ballVX = -abs(ballVX)
            }
            if ballX <= 30 {
                if ballY >= paddleY - 20 && ballY <= paddleY + 20 {
                    ballVX = abs(ballVX)
                    setScore(score + 1)
                } else {
                    flash()
                    setScore(0)
                    ballX = 160
                    ballY = 86
                    ballVX = 3
                    ballVY = Bool.random() ? 2 : -2
                }
            }
        case .asteroids:
            asteroidX += asteroidVX
            asteroidY += 2 + CGFloat(min(score / 5, 3))
            if asteroidX < 24 || asteroidX > 296 {
                asteroidVX *= -1
            }
            if asteroidBulletActive {
                asteroidBulletY -= 8
                if asteroidBulletY < 36 {
                    asteroidBulletActive = false
                } else if abs(asteroidX - shipX) < 16 && abs(asteroidY - asteroidBulletY) < 16 {
                    asteroidBulletActive = false
                    setScore(score + 1)
                    resetAsteroid()
                }
            }
            if asteroidY > 150 {
                flash()
                setScore(0)
                resetAsteroid()
            }
        case .fly:
            obstacleX -= 4 + CGFloat(min(score / 6, 4))
            if flyShotActive {
                flyShotX += 9
                if flyShotX > 310 {
                    flyShotActive = false
                } else if abs(flyShotX - obstacleX) < 16 && abs(planeY - obstacleY) < 24 {
                    flyShotActive = false
                    setScore(score + 1)
                    resetObstacle()
                }
            }
            if obstacleX < 24 {
                setScore(score + 1)
                resetObstacle()
            }
            if obstacleX < 66 && obstacleX > 28 && abs(planeY - obstacleY) < 28 {
                flash()
                setScore(0)
                resetObstacle()
            }
        case .pacman:
            pacmanX = min(max(pacmanX + pacmanDX * 4, 28), 292)
            pacmanY = min(max(pacmanY + pacmanDY * 4, 44), 140)
            let ghostStep: CGFloat = 1.25 + CGFloat(min(score / 10, 3)) * 0.35
            if abs(ghostX - pacmanX) > 2 {
                ghostX += ghostX < pacmanX ? ghostStep : -ghostStep
            }
            if abs(ghostY - pacmanY) > 2 {
                ghostY += ghostY < pacmanY ? ghostStep : -ghostStep
            }
            for pellet in pellets {
                let column = pellet % 8
                let row = pellet / 8
                let pelletX = CGFloat(48 + column * 28)
                let pelletY = CGFloat(52 + row * 28)
                if abs(pelletX - pacmanX) < 10 && abs(pelletY - pacmanY) < 10 {
                    pellets.remove(pellet)
                    setScore(score + 1)
                    break
                }
            }
            if pellets.isEmpty {
                pellets = Set(0..<24)
                ghostX = 250
                ghostY = 86
            }
            if abs(ghostX - pacmanX) < 14 && abs(ghostY - pacmanY) < 14 {
                flash()
                setScore(0)
                resetPacman()
            }
        }
    }

    private func reset() {
        score = 0
        paddleY = 86
        ballX = 160
        ballY = 86
        ballVX = 3
        ballVY = 2
        shipX = 160
        asteroidBulletActive = false
        planeY = 86
        flyShotActive = false
        resetPacman()
        resetAsteroid()
        resetObstacle()
    }

    private func resetPacman() {
        pacmanX = 46
        pacmanY = 86
        pacmanDX = 1
        pacmanDY = 0
        ghostX = 250
        ghostY = 86
        pellets = Set(0..<24)
    }

    private func resetAsteroid() {
        asteroidX = CGFloat.random(in: 40...280)
        asteroidY = 46
        asteroidVX = Bool.random() ? 2 : -2
    }

    private func resetObstacle() {
        obstacleX = 310
        obstacleY = CGFloat.random(in: 52...138)
    }

    private func flash() {
        flashUntil = Date().addingTimeInterval(0.35)
    }

    private func setScore(_ newScore: Int) {
        score = newScore
        switch game {
        case .pong:
            pongHighScore = max(pongHighScore, newScore)
        case .asteroids:
            asteroidsHighScore = max(asteroidsHighScore, newScore)
        case .fly:
            flyHighScore = max(flyHighScore, newScore)
        case .pacman:
            pacmanHighScore = max(pacmanHighScore, newScore)
        }
    }
}

public struct DJConnectSettingsView: View {
    @ObservedObject private var model: DJConnectAppModel

    public init(model: DJConnectAppModel) {
        self.model = model
    }

    public var body: some View {
        SettingsView(model: model)
    }
}

private struct MoreView: View {
    @ObservedObject var model: DJConnectAppModel
    var returnToNowPlaying: () -> Void
    @State private var showingFeedback = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MoreNavigationRow(
                        title: localized(model.language, "Games", "Games"),
                        systemImage: "gamecontroller"
                    ) {
                        GamesView(language: model.language, isDemoMode: model.isDemoMode)
                    }
                    MoreNavigationRow(
                        title: localized(model.language, "Settings", "Instellingen"),
                        systemImage: "gearshape"
                    ) {
                        SettingsView(model: model, returnToNowPlaying: returnToNowPlaying)
                    }
                    MoreNavigationRow(
                        title: localized(model.language, "Logs", "Logs"),
                        systemImage: "doc.text.magnifyingglass"
                    ) {
                        LogsView(model: model)
                    }
                    MoreNavigationRow(
                        title: localized(model.language, "About", "Over"),
                        systemImage: "info.circle"
                    ) {
                        AboutView(model: model)
                    }
                    MoreNavigationRow(
                        title: localized(model.language, "Legal", "Juridisch"),
                        systemImage: "doc.text"
                    ) {
                        LegalNoticesView(language: model.language)
                    }
                    MoreNavigationRow(
                        title: localized(model.language, "Privacy", "Privacy"),
                        systemImage: "hand.raised"
                    ) {
                        PrivacyView(language: model.language)
                    }
                    Button {
                        showingFeedback = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.title3)
                                .frame(width: 30)
                            Text(localized(model.language, "Share Feedback", "Feedback delen"))
                                .font(.body)
                            Spacer()
                        }
                        .foregroundStyle(djConnectAccent)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background {
                    DJConnectTableRowBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .background(DJConnectCanvasBackground())
            .navigationTitle(screenTitle(model.language, "More", "Meer", isDemoMode: model.isDemoMode))
        }
        .background(DJConnectCanvasBackground())
        .sheet(isPresented: $showingFeedback) {
            FeedbackPromptView(model: model)
        }
    }
}

private struct MoreNavigationRow<Destination: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(djConnectAccent)
                    .frame(width: 30)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(djConnectAccent)
    }
}

struct SettingsView: View {
    @ObservedObject var model: DJConnectAppModel
    var returnToNowPlaying: () -> Void = {}
    @State private var showingResetPairingConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Home Assistant") {
                    LabeledContent(localized(model.language, "URL", "URL")) {
                        TextField(localized(model.language, "URL", "URL"), text: $model.homeAssistantURL)
                            .textContentType(.URL)
                            .multilineTextAlignment(.trailing)
                    }
                    if !model.isDemoMode {
                        LabeledContent(localized(model.language, "Pairing Code", "Koppelcode")) {
                            CopyableValue(
                                text: model.pairingToken,
                                copyLabel: localized(model.language, "Copy Pair Code", "Koppelcode kopiëren"),
                                alignment: .trailing
                            )
                        }
                        if model.isPairing {
                            LabeledContent(localized(model.language, "Status", "Status")) {
                                ProgressView(localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant"))
                            }
                        }
                        LabeledContent(localized(model.language, "Actions", "Acties")) {
                            if model.hasStoredPairingToken {
                                Button(localized(model.language, "Reconnect", "Opnieuw koppelen"), role: .destructive) {
                                    showingResetPairingConfirmation = true
                                }
                            } else {
                                Button {
                                    model.rotatePairingTokenAndWait()
                                } label: {
                                    Text(localized(model.language, "New Code", "Nieuwe code"))
                                        .foregroundStyle(djConnectAccent)
                                }
                            }
                        }
                    }
                    LabeledContent(localized(model.language, "Device ID", "Device ID")) {
                        SelectableValue(model.identity.deviceID, alignment: .trailing)
                    }
                    if let localDeviceAPIURL = model.localDeviceAPIURL, !localDeviceAPIURL.isEmpty {
                        LabeledContent("Client API url") {
                            CopyableValue(
                                text: localDeviceAPIURL,
                                copyLabel: localized(model.language, "Copy Client API url", "Client API url kopiëren"),
                                alignment: .trailing
                            )
                        }
                    }
                }
                .listRowBackground(DJConnectTableRowBackground())

                Section(localized(model.language, "App", "App")) {
                    if model.isDemoMode {
                        LabeledContent(localized(model.language, "Demo Mode", "Demo modus")) {
                            Button(localized(model.language, "Stop Demo Mode", "Demo modus stoppen"), role: .destructive) {
                                returnToNowPlaying()
                                model.stopDemoMode()
                            }
                        }
                    }
                    Picker(localized(model.language, "Language", "Taal"), selection: $model.language) {
                        Text("Nederlands").tag("nl")
                        Text("English").tag("en")
                    }
                    Picker(localized(model.language, "Log Level", "Logniveau"), selection: $model.logLevel) {
                        Text("Debug").tag("debug")
                        Text("Info").tag("info")
                        Text(localized(model.language, "Warning", "Waarschuwing")).tag("warning")
                        Text(localized(model.language, "Error", "Fout")).tag("error")
                    }
                    LabeledContent(localized(model.language, "Wakeword", "Stemactivatie")) {
                        if model.wakeWordEnabled {
                            Button {
                                model.wakeWordEnabled = false
                            } label: {
                                Text(localized(model.language, "Disable Voice Activation", "Stemactivatie uitschakelen"))
                                    .foregroundStyle(djConnectAccent)
                            }
                            .foregroundStyle(djConnectAccent)
                            .tint(djConnectAccent)
                        } else {
                            Button {
                                model.wakeWordEnabled = true
                            } label: {
                                Text(localized(model.language, "Enable Voice Activation", "Stemactivatie inschakelen"))
                                    .foregroundStyle(djConnectAccent)
                            }
                            .foregroundStyle(djConnectAccent)
                            .tint(djConnectAccent)
                        }
                    }
                    wakeWordPhraseField(model)
                    LabeledContent(localized(model.language, "Wakeword status", "Stemactivatie-status")) {
                        Text(wakeWordStatusText(model))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(DJConnectTableRowBackground())

                Section(localized(model.language, "Permissions", "Toestemmingen")) {
                    PermissionStatusRow(
                        title: localized(model.language, "Microphone", "Microfoon"),
                        detail: localized(
                            model.language,
                            "Needed for push-to-talk voice requests.",
                            "Nodig voor push-to-talk muziekverzoeken."
                        ),
                        status: model.microphonePermissionStatus,
                        language: model.language
                    )
                    PermissionStatusRow(
                        title: localized(model.language, "Speech Recognition", "Spraakherkenning"),
                        detail: localized(
                            model.language,
                            "Needed for the foreground wake phrase.",
                            "Nodig voor stemactivatie."
                        ),
                        status: model.speechPermissionStatus,
                        language: model.language
                    )
                    Button {
                        model.requestAppPermissions()
                    } label: {
                        if model.isRequestingPermissions {
                            ProgressView()
                                .tint(djConnectAccent)
                        } else {
                            Label(
                                localized(model.language, "Request Permissions", "Toestemmingen vragen"),
                                systemImage: "checkmark.shield"
                            )
                            .foregroundStyle(djConnectAccent)
                        }
                    }
                    .foregroundStyle(djConnectAccent)
                    .tint(djConnectAccent)
                    .disabled(model.isRequestingPermissions)
                }
                .listRowBackground(DJConnectTableRowBackground())

            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .scrollContentBackgroundIfAvailable(.hidden)
            .background(.clear)
            .navigationTitle(localized(model.language, "Settings", "Instellingen"))
            .task {
                model.startPairingWait()
            }
            .onChange(of: model.homeAssistantURL) {
                model.schedulePairingWait()
            }
            .alert(
                localized(model.language, "Reconnect?", "Opnieuw koppelen?"),
                isPresented: $showingResetPairingConfirmation
            ) {
                Button(localized(model.language, "Reconnect", "Opnieuw koppelen"), role: .destructive) {
                    model.resetPairing()
                    returnToNowPlaying()
                }
                Button(localized(model.language, "Cancel", "Annuleren"), role: .cancel) {}
            } message: {
                Text(localized(
                    model.language,
                    "This removes the Home Assistant pairing from this app and disables playback controls until you pair again.",
                    "Dit verwijdert de Home Assistant koppeling uit deze app en schakelt playback-bediening uit tot je opnieuw koppelt."
                ))
            }
        }
        .background(DJConnectCanvasBackground())
    }
}

private struct LogsView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button {
                        copyText(model.diagnosticExportText())
                    } label: {
                        Label(localized(model.language, "Copy Logs", "Logs kopiëren"), systemImage: "doc.on.doc")
                            .foregroundStyle(djConnectAccent)
                    }
                    .tint(djConnectAccent)
                    .foregroundStyle(djConnectAccent)
                    .disabled(model.diagnosticLogLines.isEmpty)

                    Spacer()

                    Button {
                        showingClearConfirmation = true
                    } label: {
                        Text(localized(model.language, "Clear Logs", "Logs wissen"))
                            .foregroundStyle(djConnectAccent)
                    }
                    .tint(djConnectAccent)
                    .foregroundStyle(djConnectAccent)
                    .disabled(model.diagnosticLogLines.isEmpty)
                }
                .padding(.horizontal, 20)

                if model.diagnosticLogLines.isEmpty {
                    HStack {
                        Spacer()
                        ContentUnavailableView(
                            localized(model.language, "No Logs", "Geen logs"),
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .frame(maxWidth: 420)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(model.diagnosticLogLines) { line in
                                    Text(line.text)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(line.id)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        }
                        .scrollIndicators(.visible)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        #if os(macOS)
                        .focusable()
                        #endif
                        .onAppear {
                            scrollLogsToBottom(proxy)
                        }
                        .onChange(of: model.diagnosticLogLines.last?.id) {
                            scrollLogsToBottom(proxy)
                        }
                    }
                }
            }
            .padding(.top, 12)
            .background(DJConnectCanvasBackground())
            .navigationTitle(localized(model.language, "Logs", "Logs"))
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(localized(model.language, "Logs", "Logs"))
                        .font(.headline.weight(.semibold))
                }
            }
            #endif
            .alert(localized(model.language, "Clear Logs?", "Logs wissen?"), isPresented: $showingClearConfirmation) {
                Button(localized(model.language, "Clear Logs", "Logs wissen"), role: .destructive) {
                    model.clearDiagnosticLog()
                }
                Button(localized(model.language, "Cancel", "Annuleren"), role: .cancel) {}
            } message: {
                Text(localized(
                    model.language,
                    "This removes the visible and persisted diagnostic logs.",
                    "Dit verwijdert de zichtbare en opgeslagen diagnostische logs."
                ))
            }
        }
        .background(DJConnectCanvasBackground())
    }

    private func scrollLogsToBottom(_ proxy: ScrollViewProxy) {
        guard let lastLogID = model.diagnosticLogLines.last?.id else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastLogID, anchor: .bottom)
            }
        }
    }
}

private struct AboutView: View {
    @ObservedObject var model: DJConnectAppModel
    private let websiteURL = URL(string: "https://djconnect.dev")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                AboutBanner()

                SettingsSection(title: localized(model.language, "App", "App")) {
                    AboutStackedRow(label: localized(model.language, "Version", "Versie")) {
                        SelectableValue(model.version)
                    }
                    AboutStackedRow(label: localized(model.language, "Device Name", "Apparaatnaam")) {
                        SelectableValue(model.identity.deviceName)
                    }
                    AboutStackedRow(label: localized(model.language, "Website", "Website")) {
                        Link(destination: websiteURL) {
                            HStack(spacing: 8) {
                                Text("https://djconnect.dev")
                                    .font(.body)
                                    .foregroundStyle(djConnectAccent)
                                    .foregroundColor(djConnectAccent)
                                    .textSelection(.enabled)
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(djConnectAccent)
                                    .foregroundColor(djConnectAccent)
                            }
                        }
                        .djConnectLilacButton()
                    }
                    AboutStackedRow(label: localized(model.language, "Device ID", "Device ID")) {
                        SelectableValue(model.identity.deviceID)
                    }
                }

                SettingsSection(title: localized(model.language, "Connection", "Verbinding")) {
                    AboutStackedRow(label: localized(model.language, "Pairing", "Koppeling")) {
                        SelectableValue(model.pairingStatus.rawValue)
                    }
                    AboutStackedRow(label: localized(model.language, "Music", "Muziek")) {
                        SelectableValue(model.backendAvailable ? localized(model.language, "Connected", "Verbonden") : localized(model.language, "Unavailable", "Niet beschikbaar"))
                    }
                    if let localDeviceAPIURL = model.localDeviceAPIURL, !localDeviceAPIURL.isEmpty {
                        AboutStackedRow(label: "Client API url") {
                            CopyableValue(
                                text: localDeviceAPIURL,
                                copyLabel: localized(model.language, "Copy Client API url", "Client API url kopiëren"),
                                monospaced: false
                            )
                        }
                    }
                    if !model.haLocalURL.isEmpty {
                        AboutStackedRow(label: localized(model.language, "Home Assistant", "Home Assistant")) {
                            SelectableValue(model.haLocalURL)
                        }
                    }
                }

                SettingsSection(title: localized(model.language, "Notices", "Notices")) {
                    AboutStackedRow(label: "Copyright") {
                        SelectableValue("2026 Peter van Tol")
                    }
                    AboutStackedRow(label: "Spotify") {
                        SelectableValue("Trademark Spotify AB")
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .navigationTitle(localized(model.language, "About", "Over"))
        .background(DJConnectCanvasBackground())
    }
}

private struct LegalNoticesView: View {
    let language: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsSection(title: localized(language, "Legal", "Juridisch")) {
                        SelectableValue(localized(
                            language,
                            "DJConnect is not affiliated with, endorsed by, or sponsored by Spotify AB, Apple, or Home Assistant.",
                            "DJConnect is niet gelieerd aan, goedgekeurd door of gesponsord door Spotify AB, Apple of Home Assistant."
                        ))
                        SelectableValue(localized(
                            language,
                            "Spotify is a trademark of Spotify AB. Home Assistant is a trademark of the Open Home Foundation.",
                            "Spotify is een handelsmerk van Spotify AB. Home Assistant is een handelsmerk van de Open Home Foundation."
                        ))
                    }

                    SettingsSection(title: "OSS") {
                        SelectableValue(localized(
                            language,
                            "DJConnect uses Apple platform frameworks and Swift Package Manager. Third-party notices are documented in the repository when dependencies are added.",
                            "DJConnect gebruikt Apple platform-frameworks en Swift Package Manager. Third-party notices worden in de repository gedocumenteerd wanneer dependencies worden toegevoegd."
                        ))
                    }
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
            }
            .navigationTitle(localized(language, "Legal", "Juridisch"))
            .background(DJConnectCanvasBackground())
        }
        .background(DJConnectCanvasBackground())
    }
}

private struct PrivacyView: View {
    let language: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AboutBanner()
                SettingsSection(title: localized(language, "Privacy", "Privacy")) {
                    SelectableValue(localized(
                        language,
                        "DJConnect does not collect, sell, or process personal data in the app.",
                        "DJConnect verzamelt, verkoopt of verwerkt zelf geen persoonsgegevens in de app."
                    ))
                    SelectableValue(localized(
                        language,
                        "Device tokens are stored locally in the platform Keychain. Diagnostics are only shared when you copy them or open a GitHub issue yourself.",
                        "Device-tokens worden lokaal in de platform-sleutelhanger bewaard. Diagnostiek wordt alleen gedeeld wanneer je die zelf kopieert of een GitHub issue opent."
                    ))
                    SelectableValue(localized(
                        language,
                        "Music, playback, and voice requests are handled through your own Home Assistant DJConnect integration.",
                        "Muziek, playback en stemverzoeken lopen via je eigen Home Assistant DJConnect-integratie."
                    ))
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .navigationTitle(localized(language, "Privacy", "Privacy"))
        .background(DJConnectCanvasBackground())
    }
}

private struct FeedbackPromptView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 22) {
                AboutBanner()
                VStack(alignment: .leading, spacing: 10) {
                    Text(localized(model.language, "Share Feedback", "Feedback delen"))
                        .font(.title.bold())
                    Text(localized(
                        model.language,
                        "Open a GitHub issue with redacted app context. Nothing is uploaded automatically.",
                        "Open een GitHub issue met geredigeerde app-context. Er wordt niets automatisch geüpload."
                    ))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button {
                        if let url = model.feedbackIssueURL() {
                            openURL(url)
                        }
                        dismiss()
                    } label: {
                        Label(localized(model.language, "Open GitHub Issue", "Open GitHub issue"), systemImage: "arrow.up.right.square")
                            .foregroundStyle(djConnectAccent)
                            .foregroundColor(djConnectAccent)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .djConnectLilacButton()
                    .controlSize(.large)

                    Button {
                        dismiss()
                    } label: {
                        Text(localized(model.language, "Not Now", "Niet nu"))
                            .foregroundStyle(djConnectAccent)
                            .foregroundColor(djConnectAccent)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .djConnectLilacButton()
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
        }
    }
}

private struct AboutBanner: View {
    var body: some View {
        HStack(spacing: 18) {
            DJConnectAppIconView()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
            VStack(alignment: .leading, spacing: 6) {
                Text("DJConnect")
                    .font(.system(.largeTitle, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("Muziekbediening met karakter")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.09, green: 0.07, blue: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            Divider()
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AboutStackedRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        #if os(macOS)
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        #else
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        #endif
    }
}

private struct SelectableValue: View {
    let text: String
    var alignment: Alignment = .leading

    init(_ text: String, alignment: Alignment = .leading) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .textSelection(.enabled)
            .lineLimit(nil)
            .foregroundStyle(.primary)
            .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private struct CopyableValue: View {
    let text: String
    let copyLabel: String
    var prominent = false
    var monospaced = true
    var alignment: Alignment = .leading

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .font(valueFont)
                .textSelection(.enabled)
                .lineLimit(nil)
                .foregroundStyle(.primary)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: alignment)
            Button {
                copyText(text)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .tint(djConnectAccent)
            .foregroundStyle(djConnectAccent)
            .help(copyLabel)
            .accessibilityLabel(copyLabel)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var valueFont: Font {
        if prominent {
            return monospaced ? .system(.title3, design: .monospaced).weight(.semibold) : .title3.weight(.semibold)
        }
        return monospaced ? .system(.body, design: .monospaced) : .body
    }
}

private func copyText(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}

private struct PermissionStatusRow: View {
    let title: String
    let detail: String
    let status: DJConnectPermissionStatus
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 12)
                Label(permissionStatusText(status, language: language), systemImage: permissionStatusIcon(status))
                    .foregroundStyle(permissionStatusColor(status))
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

@ViewBuilder
@MainActor
private func wakeWordPhraseField(_ model: DJConnectAppModel) -> some View {
    let phrase = Binding(
        get: { model.wakeWordPhrase },
        set: { model.wakeWordPhrase = $0 }
    )
    #if os(iOS)
    LabeledContent(localized(model.language, "Wake word", "Wake word")) {
        TextField(localized(model.language, "Wake word", "Wake word"), text: phrase)
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
    #else
    LabeledContent(localized(model.language, "Wake word", "Wake word")) {
        TextField(localized(model.language, "Wake word", "Wake word"), text: phrase)
            .multilineTextAlignment(.trailing)
    }
    #endif
}

@MainActor
private func wakeWordStatusText(_ model: DJConnectAppModel) -> String {
    switch model.wakeWordStatus {
    case .idle:
        return localized(model.language, "Idle", "Inactief")
    case .listening:
            return localized(model.language, "Listening for wake word", "Luistert naar wake word")
        case .detected:
            return localized(model.language, "Wake word detected", "Wake word herkend")
    case .unavailable:
        if model.isDemoMode {
            return localized(model.language, "Not available in Demo Mode", "Niet beschikbaar in demo modus")
        }
        return localized(model.language, "Not available", "Niet beschikbaar")
    }
}

private func permissionStatusText(_ status: DJConnectPermissionStatus, language: String) -> String {
    switch status {
    case .unknown:
        localized(language, "Ask when needed", "Vragen wanneer nodig")
    case .granted:
        localized(language, "Allowed", "Toegestaan")
    case .denied:
        localized(language, "Denied", "Geweigerd")
    case .restricted:
        localized(language, "Restricted", "Beperkt")
    case .unavailable:
        localized(language, "Not available", "Niet beschikbaar")
    }
}

private func permissionStatusIcon(_ status: DJConnectPermissionStatus) -> String {
    switch status {
    case .granted:
        "checkmark.circle.fill"
    case .denied, .restricted:
        "xmark.circle.fill"
    case .unknown:
        "questionmark.circle"
    case .unavailable:
        "slash.circle"
    }
}

private func permissionStatusColor(_ status: DJConnectPermissionStatus) -> Color {
    switch status {
    case .granted:
        .green
    case .denied, .restricted:
        .red
    case .unknown:
        .secondary
    case .unavailable:
        .orange
    }
}
