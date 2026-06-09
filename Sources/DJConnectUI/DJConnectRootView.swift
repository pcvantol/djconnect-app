import DJConnectCore
import SwiftUI

#if os(iOS)
import UIKit
#endif

private func localized(_ language: String, _ english: String, _ dutch: String) -> String {
    language == "nl" ? dutch : english
}

private func localizedOutputName(_ outputName: String, language: String) -> String {
    switch outputName {
    case "Not selected", "No output selected":
        localized(language, "No output selected", "Geen output geselecteerd")
    default:
        outputName
    }
}

public struct DJConnectRootView: View {
    @ObservedObject private var model: DJConnectAppModel

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
                        SettingsView(model: model)
                    } label: {
                        Label(localized(model.language, "Settings", "Instellingen"), systemImage: "gearshape")
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
                SettingsView(model: model)
                    .tabItem {
                        Label(localized(model.language, "Settings", "Instellingen"), systemImage: "gearshape")
                    }
            }
            #endif
        }
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
                    SetupStatusView(model: model)
                    TrackSummaryView(playback: model.playback, language: model.language)
                    PlaybackControlsView(model: model)
                    VoiceResponseView(model: model)
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("DJConnect")
        }
        #endif
    }
}

#if os(iOS)
private struct IOSNowPlayingView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    IOSConnectionCard(model: model)
                    IOSTrackHero(model: model)
                    IOSPlaybackSurface(model: model)
                    IOSVoiceCard(model: model)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("DJConnect")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.pairingStatus != .paired)
                    .accessibilityLabel(localized(model.language, "Refresh", "Vernieuwen"))
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
                    Text(model.pairingToken)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .textSelection(.enabled)
                    Spacer()
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
    }

    private var statusTitle: String {
        switch model.pairingStatus {
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
        switch model.pairingStatus {
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
        switch model.pairingStatus {
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
        switch model.pairingStatus {
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
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(playback?.trackName ?? localized(model.language, "Nothing Playing", "Niets speelt af"))
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                Text(playback?.artistName ?? playback?.device?.name ?? localized(model.language, "Select a playback output", "Kies een playback-output"))
                    .font(.subheadline)
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
    }
}

private struct IOSPlaybackSurface: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 30) {
                playbackButton("backward.fill", size: 46) {
                    model.sendPlaybackCommand("previous")
                }

                playbackButton(model.isPlaying ? "pause.fill" : "play.fill", size: 62, prominent: true) {
                    model.togglePlayback()
                }

                playbackButton("forward.fill", size: 46) {
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
                Text("\(Int(model.volume))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { model.playback?.shuffle ?? false },
                    set: { value in
                        var updated = model.playback ?? DJConnectPlayback()
                        updated.shuffle = value
                        model.playback = updated
                        model.setShuffle(value)
                    }
                )) {
                    Image(systemName: "shuffle")
                }
                .toggleStyle(.button)

                Picker(localized(model.language, "Repeat", "Herhaal"), selection: Binding(
                    get: { model.playback?.repeatState ?? .off },
                    set: { value in
                        var updated = model.playback ?? DJConnectPlayback()
                        updated.repeatState = value
                        model.playback = updated
                        model.setRepeat(value)
                    }
                )) {
                    Text(localized(model.language, "Off", "Uit")).tag(DJConnectRepeatState.off)
                    Text(localized(model.language, "Track", "Track")).tag(DJConnectRepeatState.track)
                    Text("Context").tag(DJConnectRepeatState.context)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
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
    }
}

private struct IOSVoiceCard: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(.purple)
                .frame(width: 34, height: 34)
                .background(Color.purple.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(model.language, "DJ Response", "DJ Reactie"))
                    .font(.headline)
                Text(model.djResponseText.isEmpty ? localized(model.language, "Ready for voice response", "Klaar voor voice response") : model.djResponseText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
            } label: {
                Image(systemName: "mic.fill")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .disabled(!model.voiceEnabled)
            .accessibilityLabel(localized(model.language, "Push to talk", "Push-to-talk"))
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}
#endif

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
        switch model.pairingStatus {
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
        switch model.pairingStatus {
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
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(playback?.trackName ?? localized(language, "Nothing playing", "Niets speelt af"))
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(playback?.artistName ?? playback?.device?.name ?? localized(language, "Select a playback output", "Kies een playback-output"))
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

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 28) {
                Button {
                    model.sendPlaybackCommand("previous")
                } label: {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.bordered)
                .help(localized(model.language, "Previous", "Vorige"))

                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help(model.isPlaying ? localized(model.language, "Pause", "Pauze") : localized(model.language, "Play", "Afspelen"))

                Button {
                    model.sendPlaybackCommand("next")
                } label: {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.bordered)
                .help(localized(model.language, "Next", "Volgende"))
            }

            HStack {
                Image(systemName: "speaker.wave.1")
                Slider(value: $model.volume, in: 0...60, step: 1) { editing in
                    if !editing {
                        model.commitVolumeChange()
                    }
                }
                Text("\(Int(model.volume))")
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }

            HStack {
                Toggle(isOn: Binding(
                    get: { model.playback?.shuffle ?? false },
                    set: { value in
                        var updated = model.playback ?? DJConnectPlayback()
                        updated.shuffle = value
                        model.playback = updated
                        model.setShuffle(value)
                    }
                )) {
                    Label(localized(model.language, "Shuffle", "Shuffle"), systemImage: "shuffle")
                }

                Picker(localized(model.language, "Repeat", "Herhaal"), selection: Binding(
                    get: { model.playback?.repeatState ?? .off },
                    set: { value in
                        var updated = model.playback ?? DJConnectPlayback()
                        updated.repeatState = value
                        model.playback = updated
                        model.setRepeat(value)
                    }
                )) {
                    Text(localized(model.language, "Off", "Uit")).tag(DJConnectRepeatState.off)
                    Text(localized(model.language, "Track", "Track")).tag(DJConnectRepeatState.track)
                    Text("Context").tag(DJConnectRepeatState.context)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

struct VoiceResponseView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(localized(model.language, "DJ", "DJ"), systemImage: "waveform")
                Spacer()
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!model.voiceEnabled)
                .help(localized(model.language, "Push to talk", "Push-to-talk"))
            }

            Text(model.djResponseText.isEmpty ? localized(model.language, "Ready for a DJ response.", "Klaar voor een DJ-reactie.") : model.djResponseText)
                .foregroundStyle(model.djResponseText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct QueueView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        NavigationStack {
            List {
                Section(localized(model.language, "Output", "Output")) {
                    Label(localizedOutputName(model.selectedOutput, language: model.language), systemImage: "speaker.wave.2")
                }
                Section(localized(model.language, "Queue", "Wachtrij")) {
                    if model.queue.isEmpty {
                        ContentUnavailableView(localized(model.language, "No Queue", "Geen wachtrij"), systemImage: "music.note.list")
                    } else {
                        ForEach(model.queue, id: \.self) { item in
                            Text(item)
                        }
                    }
                }
                Section(localized(model.language, "Playlists", "Playlists")) {
                    if model.playlists.isEmpty {
                        ContentUnavailableView(localized(model.language, "No Playlists", "Geen playlists"), systemImage: "rectangle.stack")
                    } else {
                        ForEach(model.playlists, id: \.self) { playlist in
                            Label(playlist, systemImage: "play.square")
                        }
                    }
                }
            }
            .navigationTitle(localized(model.language, "Queue", "Wachtrij"))
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

struct SettingsView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Home Assistant") {
                    TextField(localized(model.language, "URL", "URL"), text: $model.homeAssistantURL)
                        .textContentType(.URL)
                    LabeledContent(localized(model.language, "Pairing Code", "Pairingcode")) {
                        Text(model.pairingToken)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .textSelection(.enabled)
                    }
                    if model.isPairing {
                        ProgressView(localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant"))
                    }
                    HStack {
                        Button(localized(model.language, "New Code", "Nieuwe code")) {
                            model.rotatePairingTokenAndWait()
                        }
                        .disabled(model.pairingStatus == .paired)
                        Button(localized(model.language, "Reset Pairing", "Reset pairing"), role: .destructive) {
                            model.resetPairing()
                        }
                    }
                    LabeledContent(localized(model.language, "Device ID", "Device ID"), value: model.identity.deviceID)
                    LabeledContent(localized(model.language, "Client", "Client"), value: model.identity.clientType.rawValue)
                    if let localDeviceURL = model.localDeviceURL {
                        LabeledContent(localized(model.language, "Local API", "Lokale API"), value: localDeviceURL)
                    }
                }

                Section(localized(model.language, "App", "App")) {
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
                    Toggle(localized(model.language, "Voice", "Voice"), isOn: $model.voiceEnabled)
                    Toggle(localized(model.language, "Local Response Audio", "Lokale response-audio"), isOn: $model.localResponseAudioEnabled)
                }

                Section {
                    if model.diagnosticLogLines.isEmpty {
                        ContentUnavailableView(
                            localized(model.language, "No Logs", "Geen logs"),
                            systemImage: "doc.text.magnifyingglass"
                        )
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(model.diagnosticLogLines) { line in
                                    Text(line.text)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(minHeight: 140, maxHeight: 260)
                    }

                    Button(localized(model.language, "Clear Logs", "Logs wissen")) {
                        model.clearDiagnosticLog()
                    }
                    .disabled(model.diagnosticLogLines.isEmpty)
                } header: {
                    Text(localized(model.language, "Diagnostics", "Diagnostiek"))
                }
            }
            .navigationTitle(localized(model.language, "Settings", "Instellingen"))
            .task {
                model.startPairingWait()
            }
            .onChange(of: model.homeAssistantURL) {
                model.schedulePairingWait()
            }
        }
    }
}
