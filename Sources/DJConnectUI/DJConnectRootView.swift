import DJConnectCore
import SwiftUI

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
                        Label("Now Playing", systemImage: "music.note")
                    }
                    NavigationLink {
                        QueueView(model: model)
                    } label: {
                        Label("Queue", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    NavigationLink {
                        SettingsView(model: model)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
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
                        Label("Now Playing", systemImage: "music.note")
                    }
                QueueView(model: model)
                    .tabItem {
                        Label("Queue", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                SettingsView(model: model)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            #endif
        }
    }
}

struct NowPlayingView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SetupStatusView(model: model)
                    TrackSummaryView(playback: model.playback)
                    PlaybackControlsView(model: model)
                    VoiceResponseView(model: model)
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("DJConnect")
        }
    }
}

struct SetupStatusView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(model.pairingStatus.rawValue.capitalized, systemImage: statusIcon)
                Spacer()
                Circle()
                    .fill(model.isConnected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel(model.isConnected ? "Connected" : "Disconnected")
            }

            if let updateRequiredMessage = model.updateRequiredMessage {
                Label(updateRequiredMessage, systemImage: "arrow.down.app")
                    .foregroundStyle(.orange)
            } else if !model.backendAvailable {
                Label("Playback backend unavailable", systemImage: "exclamationmark.triangle")
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
}

struct TrackSummaryView: View {
    var playback: DJConnectPlayback?

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
                Text(playback?.trackName ?? "Nothing playing")
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(playback?.artistName ?? playback?.device?.name ?? "Select a playback output")
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
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.bordered)
                .help("Previous")

                Button(action: {}) {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help(model.isPlaying ? "Pause" : "Play")

                Button(action: {}) {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.bordered)
                .help("Next")
            }

            HStack {
                Image(systemName: "speaker.wave.1")
                Slider(value: $model.volume, in: 0...60, step: 1)
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
                    }
                )) {
                    Label("Shuffle", systemImage: "shuffle")
                }

                Picker("Repeat", selection: Binding(
                    get: { model.playback?.repeatState ?? .off },
                    set: { value in
                        var updated = model.playback ?? DJConnectPlayback()
                        updated.repeatState = value
                        model.playback = updated
                    }
                )) {
                    Text("Off").tag(DJConnectRepeatState.off)
                    Text("Track").tag(DJConnectRepeatState.track)
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
                Label("DJ", systemImage: "waveform")
                Spacer()
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!model.voiceEnabled)
                .help("Push to talk")
            }

            Text(model.djResponseText.isEmpty ? "Ready for a DJ response." : model.djResponseText)
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
                Section("Output") {
                    Label(model.selectedOutput, systemImage: "speaker.wave.2")
                }
                Section("Queue") {
                    if model.queue.isEmpty {
                        ContentUnavailableView("No Queue", systemImage: "music.note.list")
                    } else {
                        ForEach(model.queue, id: \.self) { item in
                            Text(item)
                        }
                    }
                }
                Section("Playlists") {
                    if model.playlists.isEmpty {
                        ContentUnavailableView("No Playlists", systemImage: "rectangle.stack")
                    } else {
                        ForEach(model.playlists, id: \.self) { playlist in
                            Label(playlist, systemImage: "play.square")
                        }
                    }
                }
            }
            .navigationTitle("Queue")
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
                    TextField("URL", text: $model.homeAssistantURL)
                        .textContentType(.URL)
                    SecureField("Pairing token", text: $model.pairingToken)
                    HStack {
                        Button(model.isPairing ? "Pairing..." : "Pair") {
                            Task {
                                await model.pair()
                            }
                        }
                        .disabled(model.isPairing)
                        Button("Reset Pairing", role: .destructive) {
                            model.resetPairing()
                        }
                    }
                    LabeledContent("Device ID", value: model.identity.deviceID)
                    LabeledContent("Client", value: model.identity.clientType.rawValue)
                }

                Section("App") {
                    Picker("Language", selection: $model.language) {
                        Text("Nederlands").tag("nl")
                        Text("English").tag("en")
                    }
                    Picker("Log Level", selection: $model.logLevel) {
                        Text("Info").tag("info")
                        Text("Debug").tag("debug")
                        Text("Warning").tag("warning")
                    }
                    Toggle("Voice", isOn: $model.voiceEnabled)
                    Toggle("Local Response Audio", isOn: $model.localResponseAudioEnabled)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
