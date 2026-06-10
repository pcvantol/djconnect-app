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
                    OutputSelectorView(model: model)
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
                    IOSConnectionCard(model: model)
                    IOSTrackHero(model: model)
                    OutputSelectorView(model: model)
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
                Text(playback?.artistName ?? playback?.device?.name ?? localized(model.language, "Select an output device", "Kies een uitvoerapparaat"))
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
    private var isPaired: Bool { model.pairingStatus == .paired }

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
                .disabled(!isPaired)
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
                .tint(model.playback?.shuffle == true ? .accentColor : .secondary)
                .disabled(!isPaired)

                RepeatModeButton(model: model)
                    .disabled(!isPaired)
            }
        }
        .disabled(!isPaired)
        .opacity(isPaired ? 1 : 0.55)
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
        .disabled(!isPaired)
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
            .disabled(!model.voiceEnabled || model.pairingStatus != .paired)
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
                Text(playback?.artistName ?? playback?.device?.name ?? localized(language, "Select an output device", "Kies een uitvoerapparaat"))
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
    private var isPaired: Bool { model.pairingStatus == .paired }

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
                .disabled(!isPaired)

                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help(model.isPlaying ? localized(model.language, "Pause", "Pauze") : localized(model.language, "Play", "Afspelen"))
                .disabled(!isPaired)

                Button {
                    model.sendPlaybackCommand("next")
                } label: {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.bordered)
                .help(localized(model.language, "Next", "Volgende"))
                .disabled(!isPaired)
            }

            HStack {
                Image(systemName: "speaker.wave.1")
                Slider(value: $model.volume, in: 0...60, step: 1) { editing in
                    if !editing {
                        model.commitVolumeChange()
                    }
                }
                .disabled(!isPaired)
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
                .tint(model.playback?.shuffle == true ? .accentColor : .secondary)
                .disabled(!isPaired)

                RepeatModeButton(model: model)
                    .disabled(!isPaired)
            }
        }
        .opacity(isPaired ? 1 : 0.55)
    }
}

private struct QueueItemRow: View {
    let item: DJConnectQueueItem

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
            if item.uri?.isEmpty == false {
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
    private var isPaired: Bool { model.pairingStatus == .paired }

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
                }
                .buttonStyle(.borderless)
                .disabled(!isPaired)
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
                .disabled(!isPaired)
            }
        }
        .opacity(isPaired ? 1 : 0.55)
        .task {
            if model.pairingStatus == .paired, model.availableOutputs.isEmpty {
                model.loadOutputs()
            }
        }
        #if os(iOS)
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
        #endif
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
                .disabled(!model.voiceEnabled || model.pairingStatus != .paired)
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
    private var isPaired: Bool { model.pairingStatus == .paired }

    var body: some View {
        NavigationStack {
            List {
                Section(localized(model.language, "Queue", "Wachtrij")) {
                    if model.queueItems.isEmpty {
                        ContentUnavailableView(localized(model.language, "No Queue", "Geen wachtrij"), systemImage: "music.note.list")
                    } else {
                        ForEach(model.queueItems) { item in
                            Button {
                                model.startQueueItem(item)
                            } label: {
                                QueueItemRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isPaired || item.uri?.isEmpty != false)
                            .accessibilityLabel(item.displayTitle)
                        }
                    }
                    Button {
                        model.loadQueue()
                    } label: {
                        Label(localized(model.language, "Reload Queue", "Wachtrij herladen"), systemImage: "arrow.clockwise")
                    }
                    .disabled(!isPaired)
                }
            }
            .navigationTitle(localized(model.language, "Queue", "Wachtrij"))
            .task {
                guard model.pairingStatus == .paired else {
                    return
                }
                model.loadQueue()
            }
        }
    }
}

struct PlaylistsView: View {
    @ObservedObject var model: DJConnectAppModel
    private var isPaired: Bool { model.pairingStatus == .paired }

    var body: some View {
        NavigationStack {
            List {
                Section(localized(model.language, "Liked Songs", "Gelikete nummers")) {
                    Button {
                        model.startLikedProxy()
                    } label: {
                        Label(localized(model.language, "Start Liked Songs", "Gelikete nummers starten"), systemImage: "heart.fill")
                    }
                    .disabled(!isPaired)
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
                            .disabled(!isPaired)
                        }
                    }
                    Button {
                        model.loadPlaylists()
                    } label: {
                        Label(localized(model.language, "Reload Playlists", "Afspeellijsten herladen"), systemImage: "arrow.clockwise")
                    }
                    .disabled(!isPaired)
                }
            }
            .navigationTitle(localized(model.language, "Playlists", "Afspeellijsten"))
            .task {
                guard model.pairingStatus == .paired else {
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
                            copyLabel: localized(model.language, "Copy Pairing Code", "Pairingcode kopieren"),
                            prominent: true
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
                        LabeledContent(localized(model.language, "Local API", "Lokale API")) {
                            CopyableValue(
                                text: localDeviceAPIURL,
                                copyLabel: localized(model.language, "Copy Local API URL", "Lokale API URL kopieren")
                            )
                        }
                    }
                }

                Section(localized(model.language, "App", "App")) {
                    NavigationLink {
                        AboutView(model: model)
                    } label: {
                        Label(localized(model.language, "About DJConnect", "Over DJConnect"), systemImage: "info.circle")
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
                }

                Section(localized(model.language, "Logs", "Logs")) {
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
                            Label(localized(model.language, "Copy Logs Export", "Logs-export kopieren"), systemImage: "doc.on.doc")
                        }
                    }
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
                        Text("DJConnect. Jouw persoonlijke muziek DJ")
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
