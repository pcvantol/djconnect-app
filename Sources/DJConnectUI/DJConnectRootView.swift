import DJConnectCore
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
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

private extension View {
    @ViewBuilder
    func liquidGlassIfAvailable() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect()
        } else {
            self
        }
    }
}

public struct DJConnectRootView: View {
    @ObservedObject private var model: DJConnectAppModel
    @Environment(\.scenePhase) private var scenePhase

    public init(model: DJConnectAppModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            #if os(macOS)
            NavigationSplitView {
                List {
                    NavigationLink {
                        NowPlayingView(model: model)
                    } label: {
                        Label(localized(model.language, "Now Playing", "Speelt Nu"), systemImage: "music.note")
                    }
                    NavigationLink {
                        QueueView(model: model)
                    } label: {
                        Label(localized(model.language, "Queue", "Wachtrij"), systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    NavigationLink {
                        PlaylistsView(model: model)
                    } label: {
                        Label(localized(model.language, "Playlists", "Afspeellijsten"), systemImage: "rectangle.stack")
                    }
                    NavigationLink {
                        SettingsView(model: model)
                    } label: {
                        Label(localized(model.language, "Settings", "Instellingen"), systemImage: "gearshape")
                    }
                    NavigationLink {
                        AboutView(model: model)
                    } label: {
                        Label(localized(model.language, "About", "Over"), systemImage: "info.circle")
                    }
                }
                .navigationTitle("DJConnect")
            } detail: {
                NowPlayingView(model: model)
            }
            #else
            TabView {
                NowPlayingView(model: model)
                    .tabItem {
                        Label(localized(model.language, "Now Playing", "Speelt Nu"), systemImage: "music.note")
                    }
                QueueView(model: model)
                    .tabItem {
                        Label(localized(model.language, "Queue", "Wachtrij"), systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                PlaylistsView(model: model)
                    .tabItem {
                        Label(localized(model.language, "Playlists", "Afspeellijsten"), systemImage: "rectangle.stack")
                    }
                SettingsView(model: model)
                    .tabItem {
                        Label(localized(model.language, "Settings", "Instellingen"), systemImage: "gearshape")
                    }
                AboutView(model: model)
                    .tabItem {
                        Label(localized(model.language, "About", "Over"), systemImage: "info.circle")
                    }
            }
            #endif
        }
        .sheet(isPresented: $model.isShowingWelcome) {
            WelcomeView(model: model)
        }
        .sheet(isPresented: $model.isShowingCrashReportPrompt) {
            CrashReportPromptView(model: model)
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
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $model.isShowingWakeWordActivationPrompt) {
            WakeWordActivationPromptView(model: model)
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                model.markActiveSession()
            case .inactive, .background:
                model.markCleanShutdown()
            @unknown default:
                break
            }
        }
    }
}

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
                    "Gebruik deze waarden in Home Assistant om deze app te koppelen."
                ))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PairingValueCard(
                    title: "Client API url",
                    value: model.localDeviceAPIURL ?? localized(model.language, "Starting Client API...", "Client API wordt gestart..."),
                    copyLabel: localized(model.language, "Copy Client API url", "Client API url kopiëren"),
                    prominent: false
                )

                PairingValueCard(
                    title: localized(model.language, "Pair Code", "Pairingcode"),
                    value: model.pairingToken,
                    copyLabel: localized(model.language, "Copy Pairing Code", "Pairingcode kopiëren"),
                    prominent: true
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
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var pairingSuccess: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 86, weight: .bold))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(localized(model.language, "Pairing successful", "Pairing succesvol"))
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
                Text("Let's Start!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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
            localized(model.language, "Pairing needs attention", "Pairing vraagt aandacht")
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized(model.language, "Wakeword activeren?", "Wakeword activeren?"))
                        .font(.title2.bold())
                    Text(localized(
                        model.language,
                        "DJConnect is gekoppeld. Wil je handsfree starten met \"Hey DJ\" terwijl de app open is?",
                        "DJConnect is gekoppeld. Wil je handsfree starten met \"Hey DJ\" terwijl de app open is?"
                    ))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Label(
                localized(
                    model.language,
                    "Microphone and Speech Recognition permission may be requested.",
                    "Microfoon- en spraakherkenningstoestemming kunnen worden gevraagd."
                ),
                systemImage: "mic"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Button(localized(model.language, "Not Now", "Niet nu")) {
                    model.dismissWakeWordActivationPrompt()
                }

                Spacer()

                Button {
                    model.activateWakeWordFromPrompt()
                } label: {
                    Label(localized(model.language, "Activate Wakeword", "Wakeword activeren"), systemImage: "waveform")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
        #if os(macOS)
        .frame(minHeight: 260)
        #endif
    }
}

private struct CrashReportPromptView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized(model.language, "The app may have crashed", "De app is mogelijk gecrasht"))
                        .font(.title2.bold())
                    Text(localized(
                        model.language,
                        "You can share redacted diagnostics by opening a GitHub issue. Nothing is uploaded automatically.",
                        "Je kunt geredigeerde diagnostiek delen via een GitHub issue. Er wordt niets automatisch geüpload."
                    ))
                    .foregroundStyle(.secondary)
                }
            }

            Text(localized(
                model.language,
                "GitHub issue target: pcvantol/djconnect",
                "GitHub issue doel: pcvantol/djconnect"
            ))
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Button {
                    copyText(model.crashIssueBody())
                } label: {
                    Label(localized(model.language, "Copy Logs", "Logs kopiëren"), systemImage: "doc.on.doc")
                }

                Spacer()

                Button(localized(model.language, "Not Now", "Niet nu")) {
                    model.dismissCrashReportPrompt()
                }

                Button {
                    if let url = model.crashIssueURL() {
                        openURL(url)
                    }
                    model.dismissCrashReportPrompt()
                } label: {
                    Label(localized(model.language, "Open GitHub Issue", "Open GitHub issue"), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 380, idealWidth: 560, maxWidth: 640)
        #if os(macOS)
        .frame(minHeight: 280)
        #endif
    }
}

private struct WelcomeView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(spacing: 22) {
            AboutBanner()
                .frame(maxWidth: 520)

            VStack(spacing: 10) {
                Text("DJConnect")
                    .font(.largeTitle.bold())
                Text(localized(model.language, "Jouw persoonlijke muziek DJ", "Jouw persoonlijke muziek DJ"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(.init("Please setup in Home Assistant via [pcvantol/djconnect](https://github.com/pcvantol/djconnect)"))
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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
        #if os(macOS)
        .frame(minHeight: 430)
        #endif
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
                    SetupStatusView(model: model)
                    TrackSummaryView(playback: model.playback, language: model.language)
                    PlaybackControlsView(model: model)
                    OutputSelectorView(model: model)
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("DJConnect")
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
        .disabled(model.pairingStatus != .paired || model.isRefreshing)
        .help(localized(model.language, "Refresh", "Vernieuwen"))
        .accessibilityLabel(localized(model.language, "Refresh", "Vernieuwen"))
    }
}

#if os(iOS)
private struct IOSNowPlayingView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AboutBanner()
                    IOSVoiceCard(model: model)
                    IOSConnectionCard(model: model)
                    IOSTrackHero(model: model)
                    IOSPlaybackSurface(model: model)
                    OutputSelectorView(model: model)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("DJConnect")
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
                    Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            if model.pairingStatus != .paired {
                HStack {
                    Text(localized(model.language, "Code", "Code"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    CopyableValue(
                        text: model.pairingToken,
                        copyLabel: localized(model.language, "Copy Pairing Code", "Pairingcode kopieren"),
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
                Label(localized(model.language, "Playback backend unavailable", "Playback-backend niet beschikbaar"), systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if let pairingMessage = model.pairingMessage {
                Text(pairingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .liquidGlassIfAvailable()
    }

    private var statusTitle: String {
        return switch model.pairingStatus {
        case .paired:
            localized(model.language, "Connected", "Verbonden")
        case .pairing:
            localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant")
        case .stale:
            localized(model.language, "Setup Needs Attention", "Setup vraagt aandacht")
        case .unpaired:
            localized(model.language, "Ready to Pair", "Klaar om te koppelen")
        }
    }

    private var statusSubtitle: String {
        if model.isDemoMode {
            return localized(model.language, "App Store preview without Home Assistant", "App Store preview zonder Home Assistant")
        }
        return switch model.pairingStatus {
        case .paired:
            model.selectedOutput == "Not selected" ? localized(model.language, "DJConnect is paired", "DJConnect is gekoppeld") : localizedOutputName(model.selectedOutput, language: model.language)
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
            .green
        case .pairing:
            .blue
        case .stale:
            .orange
        case .unpaired:
            .secondary
        }
    }
}

private struct IOSTrackHero: View {
    @ObservedObject var model: DJConnectAppModel

    private var playback: DJConnectPlayback? {
        model.playback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AsyncImage(url: playback?.albumImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.10, blue: 0.30),
                            Color(red: 0.02, green: 0.18, blue: 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(playback?.trackName ?? localized(model.language, "Nothing Playing", "Niets speelt af"))
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                Text(playback?.artistName ?? playback?.device?.name ?? localized(model.language, "Select an output device", "Kies een uitvoerapparaat"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ProgressView(
                value: Double(playback?.progressMS ?? 0),
                total: Double(max(playback?.durationMS ?? 1, 1))
            )
            .tint(.purple)
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .liquidGlassIfAvailable()
    }
}

private struct IOSPlaybackSurface: View {
    @ObservedObject var model: DJConnectAppModel
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 30) {
                playbackButton("backward.end.fill", size: 46) {
                    model.sendPlaybackCommand("previous")
                }

                playbackButton(model.isPlaying ? "pause.fill" : "play.fill", size: 62, prominent: true) {
                    model.togglePlayback()
                }

                playbackButton("forward.end.fill", size: 46) {
                    model.sendPlaybackCommand("next")
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.1.fill")
                    .foregroundStyle(.secondary)
                Slider(value: $model.volume, in: 0...60, step: 1) { editing in
                    if !editing {
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
        .liquidGlassIfAvailable()
    }

    private func playbackButton(
        _ systemImage: String,
        size: CGFloat,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: prominent ? 24 : 18, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(prominent ? .white : .primary)
                .background(prominent ? Color.purple : Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canUsePlayback)
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
            return localized(model.language, "DJ announcement is currently unavailable", "DJ aankondiging momenteel niet beschikbaar")
        case .idle:
            if !model.djResponseText.isEmpty {
                return model.djResponseText
            }
            if !model.backendAvailable {
                return localized(model.language, "DJ announcement is currently unavailable", "DJ aankondiging momenteel niet beschikbaar")
            }
            return localized(model.language, "Ready for voice response", "Klaar voor voice response")
        }
    }

    private var announcementColor: Color {
        switch model.voiceStatus {
        case .listening:
            .purple
        case .processing:
            .blue
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
                Text(localized(model.language, "DJ Announcement", "DJ aankondiging"))
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
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .liquidGlassIfAvailable()
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
                        model.startVoiceRecording()
                    }
                    .onEnded { _ in
                        guard isPressing else {
                            return
                        }
                        isPressing = false
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
                model.toggleVoiceRecording()
            }
    }
}

struct SetupStatusView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(statusTitle, systemImage: statusIcon)
                Spacer()
                Circle()
                    .fill(model.isConnected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel(model.isConnected ? localized(model.language, "Connected", "Verbonden") : localized(model.language, "Disconnected", "Niet verbonden"))
            }

            if let updateRequiredMessage = model.updateRequiredMessage {
                Label(updateRequiredMessage, systemImage: "arrow.down.app")
                    .foregroundStyle(.orange)
            } else if !model.backendAvailable {
                Label(localized(model.language, "Playback backend unavailable", "Playback-backend niet beschikbaar"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if let pairingMessage = model.pairingMessage {
                Text(pairingMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
    var playback: DJConnectPlayback?
    var language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AsyncImage(url: playback?.albumImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(playback?.trackName ?? localized(language, "Nothing playing", "Niets speelt af"))
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(playback?.artistName ?? playback?.device?.name ?? localized(language, "Select an output device", "Kies een uitvoerapparaat"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ProgressView(
                value: Double(playback?.progressMS ?? 0),
                total: Double(max(playback?.durationMS ?? 1, 1))
            )
        }
    }
}

struct PlaybackControlsView: View {
    @ObservedObject var model: DJConnectAppModel
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 28) {
                Button {
                    model.sendPlaybackCommand("previous")
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(.bordered)
                .help(localized(model.language, "Previous", "Vorige"))
                .disabled(!canUsePlayback)

                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help(model.isPlaying ? localized(model.language, "Pause", "Pauze") : localized(model.language, "Play", "Afspelen"))
                .disabled(!canUsePlayback)

                Button {
                    model.sendPlaybackCommand("next")
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(.bordered)
                .help(localized(model.language, "Next", "Volgende"))
                .disabled(!canUsePlayback)
            }

            HStack {
                Image(systemName: "speaker.wave.1")
                Slider(value: $model.volume, in: 0...60, step: 1) { editing in
                    if !editing {
                        model.commitVolumeChange()
                    }
                }
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
                    .controlSize(.small)
            } else if item.uri?.isEmpty == false {
                Image(systemName: "play.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct QueueArtworkView: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.14))
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct OutputSelectorView: View {
    @ObservedObject var model: DJConnectAppModel
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(localized(model.language, "Output Device", "Uitvoerapparaat"), systemImage: "speaker.wave.2")
                    .font(.headline)
                Spacer()
                Button {
                    model.loadOutputs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderless)
                .tint(.white)
                .disabled(!canUsePlayback)
                .help(localized(model.language, "Reload Output Devices", "Uitvoerapparaten herladen"))
                .accessibilityLabel(localized(model.language, "Reload Output Devices", "Uitvoerapparaten herladen"))
            }

            if model.availableOutputs.isEmpty {
                Text(localizedOutputName(model.selectedOutput, language: model.language))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Picker(localized(model.language, "Output Device", "Uitvoerapparaat"), selection: Binding(
                    get: { model.selectedOutput },
                    set: { selected in
                        if let output = model.availableOutputs.first(where: { $0.name == selected || $0.id == selected }) {
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
                .disabled(!canUsePlayback)
            }
        }
        .opacity(canUsePlayback ? 1 : 0.55)
        .task {
            if model.canUsePlaybackFeatures, model.availableOutputs.isEmpty {
                model.loadOutputs()
            }
        }
        #if os(iOS)
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .liquidGlassIfAvailable()
        #endif
    }
}

private struct ShuffleModeButton: View {
    @ObservedObject var model: DJConnectAppModel

    private var isShuffling: Bool {
        model.playback?.shuffle == true
    }

    var body: some View {
        Button {
            let nextValue = !isShuffling
            var updated = model.playback ?? DJConnectPlayback()
            updated.shuffle = nextValue
            model.playback = updated
            model.setShuffle(nextValue)
        } label: {
            Image(systemName: "shuffle")
                .symbolVariant(isShuffling ? .fill : .none)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .tint(isShuffling ? .accentColor : .secondary)
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
            let nextState = repeatState.next
            var updated = model.playback ?? DJConnectPlayback()
            updated.repeatState = nextState
            model.playback = updated
            model.setRepeat(nextState)
        } label: {
            Image(systemName: repeatState.systemImage)
                .symbolVariant(repeatState == .off ? .none : .fill)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .tint(repeatState == .off ? .secondary : .accentColor)
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
            return localized(model.language, "DJ announcement is currently unavailable", "DJ aankondiging momenteel niet beschikbaar")
        case .idle:
            if !model.djResponseText.isEmpty {
                return model.djResponseText
            }
            if !model.backendAvailable {
                return localized(model.language, "DJ announcement is currently unavailable", "DJ aankondiging momenteel niet beschikbaar")
            }
            return localized(model.language, "Ready for a DJ response.", "Klaar voor een DJ-reactie.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(localized(model.language, "DJ", "DJ"), systemImage: "waveform")
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
    }
}

struct QueueView: View {
    @ObservedObject var model: DJConnectAppModel
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        NavigationStack {
            List {
                if model.queueItems.isEmpty {
                    ContentUnavailableView(localized(model.language, "No Queue", "Geen wachtrij"), systemImage: "music.note.list")
                } else {
                    ForEach(Array(model.queueItems.enumerated()), id: \.offset) { index, item in
                        Button {
                            model.startQueueItem(item, at: index)
                        } label: {
                            QueueItemRow(item: item, isLoading: model.loadingQueueItemIndex == index)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canUsePlayback || model.loadingQueueItemIndex != nil || !model.canStartQueueItem(item))
                        .accessibilityLabel(item.displayTitle)
                    }
                }
            }
            .refreshable {
                guard canUsePlayback else {
                    return
                }
                await model.refreshQueue()
            }
            .navigationTitle(localized(model.language, "Queue", "Wachtrij"))
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
                    .disabled(!canUsePlayback || model.isLoadingQueue)
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
        }
    }
}

struct PlaylistsView: View {
    @ObservedObject var model: DJConnectAppModel
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

    var body: some View {
        NavigationStack {
            List {
                Section(localized(model.language, "Default playlist", "Standaard playlist")) {
                    Button {
                        model.startLikedProxy()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.purple)
                                .frame(width: 22)
                            Text(localized(model.language, "Liked Songs", "Gelikete nummers"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "play.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canUsePlayback)
                }

                Section(localized(model.language, "Playlists", "Afspeellijsten")) {
                    if model.playlistItems.isEmpty {
                        ContentUnavailableView(localized(model.language, "No Playlists", "Geen afspeellijsten"), systemImage: "rectangle.stack")
                    } else {
                        ForEach(model.playlistItems) { playlist in
                            Button {
                                model.startPlaylist(playlist)
                            } label: {
                                PlaylistRow(playlist: playlist)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canUsePlayback)
                        }
                    }
                }
            }
            .refreshable {
                guard canUsePlayback else {
                    return
                }
                await model.refreshPlaylists()
            }
            .navigationTitle(localized(model.language, "Playlists", "Afspeellijsten"))
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
                    .disabled(!canUsePlayback || model.isLoadingPlaylists)
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
        }
    }
}

private struct PlaylistRow: View {
    let playlist: DJConnectPlaylist

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.square.fill")
                .foregroundStyle(.purple)
                .frame(width: 22)
            Text(playlist.name)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
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

struct SettingsView: View {
    @ObservedObject var model: DJConnectAppModel
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
                    LabeledContent(localized(model.language, "Pairing Code", "Pairingcode")) {
                        CopyableValue(
                            text: model.pairingToken,
                            copyLabel: localized(model.language, "Copy Pairing Code", "Pairingcode kopieren")
                        )
                    }
                    if model.isPairing {
                        LabeledContent(localized(model.language, "Status", "Status")) {
                            ProgressView(localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant"))
                        }
                    }
                    LabeledContent(localized(model.language, "Actions", "Acties")) {
                        if model.hasStoredPairingToken {
                            Button(localized(model.language, "Reset Pairing", "Pairing resetten"), role: .destructive) {
                                showingResetPairingConfirmation = true
                            }
                        } else {
                            Button(localized(model.language, "New Code", "Nieuwe code")) {
                                model.rotatePairingTokenAndWait()
                            }
                        }
                    }
                    LabeledContent(localized(model.language, "Device ID", "Device ID")) {
                        SelectableValue(model.identity.deviceID)
                    }
                    LabeledContent(localized(model.language, "Client", "Client")) {
                        SelectableValue(model.identity.clientType.rawValue)
                    }
                    if !model.haLocalURL.isEmpty {
                        LabeledContent(localized(model.language, "Local URL", "Lokale URL")) {
                            SelectableValue(model.haLocalURL)
                        }
                    }
                    if let localDeviceAPIURL = model.localDeviceAPIURL, !localDeviceAPIURL.isEmpty {
                        LabeledContent("Client API url") {
                            CopyableValue(
                                text: localDeviceAPIURL,
                                copyLabel: localized(model.language, "Copy Client API url", "Client API url kopiëren")
                            )
                        }
                    }
                }

                Section(localized(model.language, "App", "App")) {
                    if model.isDemoMode {
                        LabeledContent(localized(model.language, "Demo Mode", "Demo modus")) {
                            Button(localized(model.language, "Stop Demo Mode", "Demo modus stoppen"), role: .destructive) {
                                model.stopDemoMode()
                            }
                        }
                    }
                    Picker(localized(model.language, "Language", "Taal"), selection: $model.language) {
                        Text("Nederlands").tag("nl")
                        Text("English").tag("en")
                    }
                    Picker(localized(model.language, "Log Level", "Logniveau"), selection: $model.logLevel) {
                        Text("Info").tag("info")
                        Text("Debug").tag("debug")
                        Text(localized(model.language, "Warning", "Waarschuwing")).tag("warning")
                        Text(localized(model.language, "Error", "Fout")).tag("error")
                    }
                    Toggle(localized(model.language, "Voice", "Spraak"), isOn: $model.voiceEnabled)
                    Toggle(localized(model.language, "Local Response Audio", "Lokale antwoord-audio"), isOn: $model.localResponseAudioEnabled)
                    Toggle(localized(model.language, "Wakeword", "Wakeword"), isOn: $model.wakeWordEnabled)
                    wakeWordPhraseField(model)
                    LabeledContent(localized(model.language, "Wakeword status", "Wakeword-status")) {
                        Text(wakeWordStatusText(model))
                            .foregroundStyle(.secondary)
                    }
                }

                Section(localized(model.language, "Permissions", "Toestemmingen")) {
                    PermissionStatusRow(
                        title: localized(model.language, "Microphone", "Microfoon"),
                        detail: localized(
                            model.language,
                            "Needed for push-to-talk voice requests.",
                            "Nodig voor push-to-talk voice requests."
                        ),
                        status: model.microphonePermissionStatus,
                        language: model.language
                    )
                    PermissionStatusRow(
                        title: localized(model.language, "Speech Recognition", "Spraakherkenning"),
                        detail: localized(
                            model.language,
                            "Needed for the foreground wake phrase.",
                            "Nodig voor de foreground wake-zin."
                        ),
                        status: model.speechPermissionStatus,
                        language: model.language
                    )
                    PermissionStatusRow(
                        title: localized(model.language, "Local Network", "Lokaal netwerk"),
                        detail: localized(
                            model.language,
                            "Needed to reach Home Assistant and expose the Client API url.",
                            "Nodig om Home Assistant te bereiken en de Client API url aan te bieden."
                        ),
                        status: model.localNetworkPermissionStatus,
                        language: model.language
                    )
                    Button {
                        model.requestAppPermissions()
                    } label: {
                        if model.isRequestingPermissions {
                            ProgressView()
                        } else {
                            Label(
                                localized(model.language, "Request Permissions", "Toestemmingen vragen"),
                                systemImage: "checkmark.shield"
                            )
                        }
                    }
                    .disabled(model.isRequestingPermissions)
                }

                Section(localized(model.language, "Logs", "Logs")) {
                    if model.diagnosticLogLines.isEmpty {
                        ContentUnavailableView(
                            localized(model.language, "No Logs", "Geen logs"),
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .frame(minHeight: 120)
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
                                .padding(.vertical, 4)
                            }
                            .frame(minHeight: 140, maxHeight: 260)
                            .onAppear {
                                scrollLogsToBottom(proxy)
                            }
                            .onChange(of: model.diagnosticLogLines.last?.id) {
                                scrollLogsToBottom(proxy)
                            }
                        }
                    }

                    Button {
                        copyText(model.diagnosticExportText())
                    } label: {
                        Label(localized(model.language, "Copy Logs", "Logs kopiëren"), systemImage: "doc.on.doc")
                    }
                    .disabled(model.diagnosticLogLines.isEmpty)

                    Button(localized(model.language, "Clear Logs", "Logs wissen"), role: .destructive) {
                        model.clearDiagnosticLog()
                    }
                    .disabled(model.diagnosticLogLines.isEmpty)
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle(localized(model.language, "Settings", "Instellingen"))
            .task {
                model.startPairingWait()
            }
            .onChange(of: model.homeAssistantURL) {
                model.schedulePairingWait()
            }
            .alert(
                localized(model.language, "Reset Pairing?", "Pairing resetten?"),
                isPresented: $showingResetPairingConfirmation
            ) {
                Button(localized(model.language, "Reset Pairing", "Pairing resetten"), role: .destructive) {
                    model.resetPairing()
                }
                Button(localized(model.language, "Cancel", "Annuleren"), role: .cancel) {}
            } message: {
                Text(localized(
                    model.language,
                    "This removes the Home Assistant pairing token from this app and disables playback controls until you pair again.",
                    "Dit verwijdert de Home Assistant pairing-token uit deze app en schakelt playback-bediening uit tot je opnieuw koppelt."
                ))
            }
        }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                AboutBanner()

                SettingsSection(title: localized(model.language, "App", "App")) {
                    AboutStackedRow(label: localized(model.language, "Version", "Versie")) {
                        SelectableValue(model.version)
                    }
                    AboutStackedRow(label: localized(model.language, "Client", "Client")) {
                        SelectableValue(model.identity.clientType.rawValue)
                    }
                    AboutStackedRow(label: localized(model.language, "Platform", "Platform")) {
                        SelectableValue(model.identity.platform.rawValue)
                    }
                    AboutStackedRow(label: localized(model.language, "Device Name", "Apparaatnaam")) {
                        SelectableValue(model.identity.deviceName)
                    }
                    AboutStackedRow(label: localized(model.language, "Website", "Website")) {
                        CopyableValue(
                            text: "https://djconnect.pages.dev",
                            copyLabel: localized(model.language, "Copy Website", "Website kopiëren"),
                            monospaced: false
                        )
                    }
                    AboutStackedRow(label: localized(model.language, "Device ID", "Device ID")) {
                        CopyableValue(
                            text: model.identity.deviceID,
                            copyLabel: localized(model.language, "Copy Device ID", "Device ID kopieren"),
                            monospaced: false
                        )
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
                    AboutStackedRow(label: localized(model.language, "App", "App")) {
                        SelectableValue("Proprietary")
                    }
                    AboutStackedRow(label: "Spotify") {
                        SelectableValue("Trademark Spotify AB")
                    }
                    AboutStackedRow(label: "Notice") {
                        SelectableValue(localized(model.language, "Not affiliated", "Niet gelieerd"))
                    }
                    AboutStackedRow(label: "OSS") {
                        SelectableValue(localized(model.language, "See notices", "Zie notices"))
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .navigationTitle(localized(model.language, "About", "Over"))
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
                Text("Jouw persoonlijke muziek DJ")
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
        .liquidGlassIfAvailable()
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
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SelectableValue: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .textSelection(.enabled)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CopyableValue: View {
    let text: String
    let copyLabel: String
    var prominent = false
    var monospaced = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .font(valueFont)
                .textSelection(.enabled)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                copyText(text)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help(copyLabel)
            .accessibilityLabel(copyLabel)
        }
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
        LabeledContent {
            VStack(alignment: .trailing, spacing: 2) {
                Label(permissionStatusText(status, language: language), systemImage: permissionStatusIcon(status))
                    .foregroundStyle(permissionStatusColor(status))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        } label: {
            Text(title)
        }
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
    TextField(localized(model.language, "Wake phrase", "Wake-zin"), text: phrase)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    #else
    TextField(localized(model.language, "Wake phrase", "Wake-zin"), text: phrase)
    #endif
}

@MainActor
private func wakeWordStatusText(_ model: DJConnectAppModel) -> String {
    switch model.wakeWordStatus {
    case .idle:
        return localized(model.language, "Idle", "Inactief")
    case .listening:
        return localized(model.language, "Listening for wake phrase", "Luistert naar wake-zin")
    case .detected:
        return localized(model.language, "Wake phrase detected", "Wake-zin herkend")
    case .unavailable:
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
