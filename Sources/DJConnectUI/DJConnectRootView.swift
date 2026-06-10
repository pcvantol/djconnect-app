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
            .toolbar {
                ToolbarItem {
                    Button {
                        model.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.pairingStatus != .paired)
                    .help(localized(model.language, "Refresh", "Vernieuwen"))
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
                    Text(localized(model.language, "Context", "Context")).tag(DJConnectRepeatState.context)
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
                model.toggleVoiceRecording()
            } label: {
                Image(systemName: model.isRecordingVoice ? "stop.fill" : "mic.fill")
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
                    Text(localized(model.language, "Context", "Context")).tag(DJConnectRepeatState.context)
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
                Button {
                    model.toggleVoiceRecording()
                } label: {
                    Image(systemName: model.isRecordingVoice ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!model.voiceEnabled)
                .help(localized(model.language, "Push to talk", "Push-to-talk"))
            }

            if model.isRecordingVoice {
                Label(localized(model.language, "Recording", "Neemt op"), systemImage: "record.circle")
                    .foregroundStyle(.red)
            }
            if let voiceErrorMessage = model.voiceErrorMessage {
                Text(voiceErrorMessage)
                    .font(.callout)
                    .foregroundStyle(.orange)
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
                Section(localized(model.language, "Output", "Uitvoer")) {
                    if model.availableOutputs.isEmpty {
                        Label(localizedOutputName(model.selectedOutput, language: model.language), systemImage: "speaker.wave.2")
                    } else {
                        Picker(localized(model.language, "Output", "Uitvoer"), selection: Binding(
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
                    }
                    Button {
                        model.loadOutputs()
                    } label: {
                        Label(localized(model.language, "Reload Outputs", "Uitvoer herladen"), systemImage: "arrow.clockwise")
                    }
                }
                Section(localized(model.language, "Queue", "Wachtrij")) {
                    if model.queueItems.isEmpty {
                        ContentUnavailableView(localized(model.language, "No Queue", "Geen wachtrij"), systemImage: "music.note.list")
                    } else {
                        ForEach(model.queueItems) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                if let artist = item.artist {
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button {
                        model.loadQueue()
                    } label: {
                        Label(localized(model.language, "Reload Queue", "Wachtrij herladen"), systemImage: "arrow.clockwise")
                    }
                }
                Section(localized(model.language, "Playlists", "Afspeellijsten")) {
                    Button {
                        model.startLikedProxy()
                    } label: {
                        Label(localized(model.language, "Start Liked Songs", "Gelikete nummers starten"), systemImage: "heart.fill")
                    }
                    if model.playlistItems.isEmpty {
                        ContentUnavailableView(localized(model.language, "No Playlists", "Geen afspeellijsten"), systemImage: "rectangle.stack")
                    } else {
                        ForEach(model.playlistItems) { playlist in
                            Button {
                                model.startPlaylist(playlist)
                            } label: {
                                Label(playlist.name, systemImage: "play.square")
                            }
                        }
                    }
                    Button {
                        model.loadPlaylists()
                    } label: {
                        Label(localized(model.language, "Reload Playlists", "Afspeellijsten herladen"), systemImage: "arrow.clockwise")
                    }
                }
            }
            .navigationTitle(localized(model.language, "Queue", "Wachtrij"))
            .task {
                guard model.pairingStatus == .paired else {
                    return
                }
                model.loadOutputs()
                model.loadQueue()
                model.loadPlaylists()
            }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    SettingsSection(title: "Home Assistant") {
                        SettingsRow(label: localized(model.language, "URL", "URL")) {
                            TextField(localized(model.language, "URL", "URL"), text: $model.homeAssistantURL)
                                .textContentType(.URL)
                        }
                        SettingsRow(label: localized(model.language, "Pairing Code", "Pairingcode")) {
                            CopyableValue(
                                text: model.pairingToken,
                                copyLabel: localized(model.language, "Copy Pairing Code", "Pairingcode kopieren"),
                                prominent: true
                            )
                        }
                        if model.isPairing {
                            SettingsRow(label: localized(model.language, "Status", "Status")) {
                                ProgressView(localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant"))
                            }
                        }
                        SettingsRow(label: localized(model.language, "Actions", "Acties")) {
                            HStack(spacing: 10) {
                                Button(localized(model.language, "New Code", "Nieuwe code")) {
                                    model.rotatePairingTokenAndWait()
                                }
                                .disabled(model.pairingStatus == .paired)
                                Button(localized(model.language, "Reset Pairing", "Pairing resetten"), role: .destructive) {
                                    model.resetPairing()
                                }
                            }
                        }
                        SettingsRow(label: localized(model.language, "Device ID", "Device ID")) {
                            SelectableValue(model.identity.deviceID)
                        }
                        SettingsRow(label: localized(model.language, "Client", "Client")) {
                            SelectableValue(model.identity.clientType.rawValue)
                        }
                        if !model.haLocalURL.isEmpty {
                            SettingsRow(label: localized(model.language, "Local URL", "Lokale URL")) {
                                SelectableValue(model.haLocalURL)
                            }
                        }
                        if let localDeviceAPIURL = model.localDeviceAPIURL, !localDeviceAPIURL.isEmpty {
                            SettingsRow(label: localized(model.language, "Local API", "Lokale API")) {
                                CopyableValue(
                                    text: localDeviceAPIURL,
                                    copyLabel: localized(model.language, "Copy Local API URL", "Lokale API URL kopieren")
                                )
                            }
                        }
                    }

                    SettingsSection(title: localized(model.language, "App", "App")) {
                        NavigationLink {
                            AboutView(model: model)
                        } label: {
                            Label(localized(model.language, "About DJConnect", "Over DJConnect"), systemImage: "info.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        SettingsRow(label: localized(model.language, "Language", "Taal")) {
                            Picker("", selection: $model.language) {
                                Text("Nederlands").tag("nl")
                                Text("English").tag("en")
                            }
                            .labelsHidden()
                            .frame(maxWidth: 260, alignment: .leading)
                        }
                        SettingsRow(label: localized(model.language, "Log Level", "Logniveau")) {
                            Picker("", selection: $model.logLevel) {
                                Text("Info").tag("info")
                                Text("Debug").tag("debug")
                                Text(localized(model.language, "Warning", "Waarschuwing")).tag("warning")
                                Text(localized(model.language, "Error", "Fout")).tag("error")
                            }
                            .labelsHidden()
                            .frame(maxWidth: 260, alignment: .leading)
                        }
                        SettingsRow(label: localized(model.language, "Voice", "Spraak")) {
                            Toggle("", isOn: $model.voiceEnabled)
                                .labelsHidden()
                        }
                        SettingsRow(label: localized(model.language, "Local Response Audio", "Lokale antwoord-audio")) {
                            Toggle("", isOn: $model.localResponseAudioEnabled)
                                .labelsHidden()
                        }
                    }

                    SettingsSection(title: localized(model.language, "Diagnostics", "Diagnostiek")) {
                        if model.diagnosticLogLines.isEmpty {
                            ContentUnavailableView(
                                localized(model.language, "No Logs", "Geen logs"),
                                systemImage: "doc.text.magnifyingglass"
                            )
                            .frame(minHeight: 120)
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

                        HStack(spacing: 10) {
                            Button(localized(model.language, "Clear Logs", "Logs wissen")) {
                                model.clearDiagnosticLog()
                            }
                            .disabled(model.diagnosticLogLines.isEmpty)
                            Button {
                                copyText(model.diagnosticExportText())
                            } label: {
                                Label(localized(model.language, "Copy Diagnostics Export", "Diagnostics-export kopieren"), systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
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

private struct AboutView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                    DJConnectAppIconView()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.20), radius: 14, y: 8)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DJConnect")
                            .font(.system(.largeTitle, design: .default).weight(.bold))
                        Text(localized(model.language, "Apple client for Home Assistant and Spotify DJ control.", "Apple-client voor Home Assistant en Spotify DJ-bediening."))
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsSection(title: localized(model.language, "App", "App")) {
                    SettingsRow(label: localized(model.language, "Version", "Versie")) {
                        SelectableValue(model.version)
                    }
                    SettingsRow(label: localized(model.language, "Client", "Client")) {
                        SelectableValue(model.identity.clientType.rawValue)
                    }
                    SettingsRow(label: localized(model.language, "Platform", "Platform")) {
                        SelectableValue(model.identity.platform.rawValue)
                    }
                    SettingsRow(label: localized(model.language, "Device Name", "Apparaatnaam")) {
                        SelectableValue(model.identity.deviceName)
                    }
                    SettingsRow(label: localized(model.language, "Device ID", "Device ID")) {
                        CopyableValue(
                            text: model.identity.deviceID,
                            copyLabel: localized(model.language, "Copy Device ID", "Device ID kopieren")
                        )
                    }
                }

                SettingsSection(title: localized(model.language, "Connection", "Verbinding")) {
                    SettingsRow(label: localized(model.language, "Pairing", "Koppeling")) {
                        SelectableValue(model.pairingStatus.rawValue)
                    }
                    if let localDeviceAPIURL = model.localDeviceAPIURL, !localDeviceAPIURL.isEmpty {
                        SettingsRow(label: localized(model.language, "Local API", "Lokale API")) {
                            CopyableValue(
                                text: localDeviceAPIURL,
                                copyLabel: localized(model.language, "Copy Local API URL", "Lokale API URL kopieren")
                            )
                        }
                    }
                    if !model.haLocalURL.isEmpty {
                        SettingsRow(label: localized(model.language, "Home Assistant", "Home Assistant")) {
                            SelectableValue(model.haLocalURL)
                        }
                    }
                }

                Text(localized(
                    model.language,
                    "No Spotify, Home Assistant, or device tokens are shown here.",
                    "Spotify-, Home Assistant- en device-tokens worden hier niet getoond."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .navigationTitle(localized(model.language, "About", "Over"))
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .font(prominent ? .system(.title3, design: .monospaced).weight(.semibold) : .system(.body, design: .monospaced))
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
}

private func copyText(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}
