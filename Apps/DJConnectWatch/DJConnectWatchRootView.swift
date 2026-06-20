import DJConnectCore
import SwiftUI
import WatchKit

private let watchAccentBlue = Color(red: 0.16, green: 0.56, blue: 1.0)
private let watchAccentPurple = Color(red: 0.84, green: 0.18, blue: 1.0)
private let watchDeepNavy = Color(red: 0.02, green: 0.03, blue: 0.09)

private func watchAskDJTimestamp(_ date: Date, now: Date = Date()) -> String {
    let elapsed = max(0, now.timeIntervalSince(date))
    if elapsed < 3_600 {
        let minutes = max(1, Int(elapsed / 60))
        return "\(minutes) minuten geleden"
    }
    if Calendar.current.isDate(date, inSameDayAs: now) {
        return date.formatted(date: .omitted, time: .shortened)
    }
    let days = max(1, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 1)
    switch days {
    case 1:
        return "Gisteren"
    case 2...6:
        return "\(days) dagen geleden"
    case 7...13:
        return "Vorige week"
    case 14...30:
        return "\(max(2, days / 7)) weken geleden"
    case 31...61:
        return "Vorige maand"
    default:
        return "\(max(2, days / 30)) maanden geleden"
    }
}

struct DJConnectWatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var moodCrownValue = 0.0

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("DJConnect")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            Task { await model.refreshStatus() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .tint(watchAccentPurple)
                        .disabled(!model.canUseBackend)
                    }
                }
        }
        .tint(watchAccentPurple)
        .sheet(isPresented: $model.isShowingMicrophonePermissionExplanation) {
            DJConnectWatchMicrophonePermissionView(kind: .pushToTalk)
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isShowingVoiceActivationPermissionExplanation) {
            DJConnectWatchMicrophonePermissionView(kind: .voiceActivation)
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isShowingWelcome) {
            DJConnectWatchWelcomeView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { _, phase in
            model.handleAppForegroundChange(phase == .active)
        }
        .onAppear {
            model.handleAppForegroundChange(scenePhase == .active)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.connectionState {
        case .paired:
            if model.isShowingPairingSuccess {
                pairingSuccessView
            } else {
                pairedView
            }
        case .pairing:
            pairingView(message: "Wachten tot Home Assistant de code accepteert.")
        case let .failed(message):
            pairingView(message: message)
        case .unpaired:
            pairingView(message: nil)
        }
    }

    private var pairedView: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(spacing: 12) {
                    nowPlaying

                    HStack(spacing: 12) {
                        commandButton("backward.fill", command: "previous", accessibilityLabel: "Vorige track")
                        commandButton(
                            model.playback?.isPlaying == true ? "pause.fill" : "play.fill",
                            command: model.playback?.isPlaying == true ? "pause" : "play",
                            accessibilityLabel: model.playback?.isPlaying == true ? "Pauzeer" : "Speel af",
                            isPrimary: true
                        )
                        commandButton("forward.fill", command: "next", accessibilityLabel: "Volgende track")
                    }

                    volumeControl

                    NavigationLink {
                        DJConnectWatchOutputsView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(watchAccentBlue.opacity(0.94))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Uitvoer")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.62))
                                Text(model.selectedOutput)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.46))
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(DJConnectWatchPanel(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.toggleRecording()
                    } label: {
                        Label(voiceButtonTitle, systemImage: voiceButtonIcon)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: voiceButtonKind))

                    askDJMoodControl

                    Text(model.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)

                    if model.isDemoMode {
                        Button {
                            model.stopDemoMode()
                        } label: {
                            Label("Stop demo", systemImage: "xmark.circle")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                    }

                    if !model.responseImages.isEmpty {
                        AskDJWatchImageStack(images: model.responseImages)
                    }

                    NavigationLink {
                        DJConnectWatchQueueView()
                    } label: {
                        Label("Wachtrij", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchPlaylistsView()
                    } label: {
                        Label("Afspeellijsten", systemImage: "music.note.list")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchOutputsView()
                    } label: {
                        Label("Uitvoer", systemImage: "speaker.wave.2")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchGamesView()
                    } label: {
                        Label("Games", systemImage: "gamecontroller")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchSettingsView()
                    } label: {
                        Label("Instellingen", systemImage: "gearshape")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchLogsView()
                    } label: {
                        Label("Logs", systemImage: "doc.text.magnifyingglass")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchAboutView()
                    } label: {
                        Label("Over", systemImage: "info.circle")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchLegalView()
                    } label: {
                        Label("Juridisch", systemImage: "doc.text")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchPrivacyView()
                    } label: {
                        Label("Privacy", systemImage: "hand.raised")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                    NavigationLink {
                        DJConnectWatchFeedbackView()
                    } label: {
                        Label("Feedback delen", systemImage: "bubble.left.and.bubble.right")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .task {
            await model.refreshStatus()
        }
    }

    private var pairingSuccessView: some View {
        ZStack {
            DJConnectWatchCanvas()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [watchAccentBlue, watchAccentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Succesvol gekoppeld")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("DJConnect is verbonden met Home Assistant.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                Button {
                    model.dismissPairingSuccess()
                } label: {
                    Text("Doorgaan")
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
            }
            .padding(.horizontal, 10)
        }
    }

    private var askDJMoodControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Mood")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(model.askDJMoodLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(watchAccentBlue.opacity(0.92))
            }

            GeometryReader { proxy in
                let steps = model.askDJMoodSteps
                let selectedIndex = model.askDJMoodStepIndex
                let availableWidth = max(1, proxy.size.width - 26)
                let stepWidth = availableWidth / CGFloat(max(steps.count - 1, 1))
                let thumbX = 13 + stepWidth * CGFloat(selectedIndex)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 4)
                        .padding(.horizontal, 13)

                    ForEach(steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? watchAccentBlue : Color.white.opacity(0.42))
                            .frame(width: 7, height: 7)
                            .position(x: 13 + stepWidth * CGFloat(index), y: 16)
                    }

                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [watchAccentPurple, watchAccentBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: watchAccentPurple.opacity(0.34), radius: 8, y: 3)
                        .position(x: thumbX, y: 16)
                }
            }
            .frame(height: 32)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .background(DJConnectWatchPanel(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(watchAccentPurple.opacity(0.18), lineWidth: 1)
        )
        .focusable(true)
        .digitalCrownRotation(
            $moodCrownValue,
            from: 0,
            through: 3,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onAppear {
            moodCrownValue = Double(model.askDJMoodStepIndex)
        }
        .onChange(of: model.askDJMoodStepIndex) {
            moodCrownValue = Double(model.askDJMoodStepIndex)
        }
        .onChange(of: moodCrownValue) {
            updateMoodFromCrown()
        }
        .accessibilityLabel("Mood")
        .accessibilityValue(model.askDJMoodLabel)
    }

    private func updateMoodFromCrown() {
        let nextIndex = max(0, min(model.askDJMoodSteps.count - 1, Int(moodCrownValue.rounded())))
        guard nextIndex != model.askDJMoodStepIndex else {
            moodCrownValue = Double(nextIndex)
            return
        }
        model.setAskDJMoodStep(nextIndex)
        moodCrownValue = Double(nextIndex)
        WKInterfaceDevice.current().play(.click)
    }

    private var volumeControl: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(watchAccentBlue.opacity(0.92))
                Slider(value: $model.volume, in: 0...60, step: 1) { editing in
                    if !editing {
                        model.commitVolume()
                    }
                }
                .tint(watchAccentPurple)
                Text("\(Int(model.volume.rounded()))%")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(DJConnectWatchPanel(cornerRadius: 12))
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(model.volume.rounded())) procent")
    }

    private var nowPlaying: some View {
        HStack(spacing: 9) {
            DJConnectWatchArtwork(
                url: model.playback?.albumImageURL,
                fallbackSystemImage: "music.note"
            )
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.playback?.trackName ?? "Geen track")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text(model.playback?.artistName ?? "DJConnect")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if let volume = model.playback?.volumePercent {
                    Label("\(volume)%", systemImage: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundStyle(watchAccentBlue.opacity(0.92))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(DJConnectWatchPanel())
    }

    private func pairingView(message: String?) -> some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .center, spacing: 9) {
                        Image("LaunchIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: watchAccentPurple.opacity(0.26), radius: 8, y: 3)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("DJConnect koppelen")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text("Koppelgegevens voor Home Assistant")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Home Assistant URL")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                        TextField("Home Assistant URL", text: $model.haBaseURL)
                            .font(.caption2.monospaced())
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .accessibilityLabel("Home Assistant URL")
                            .accessibilityHint("Home Assistant URL voor deze Watch")
                        Text("WiFi is vereist. Gebruik hetzelfde lokale netwerk als Home Assistant.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.54))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(9)
                    .background(DJConnectWatchPanel(cornerRadius: 12))

                    if let networkRequirementMessage = model.networkRequirementMessage {
                        Label(networkRequirementMessage, systemImage: "wifi.exclamationmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.28))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(9)
                            .background(DJConnectWatchPanel(cornerRadius: 12))
                    }

                    pairingValueCard(
                        title: "Koppelcode",
                        value: model.pairingCode,
                        systemImage: "number",
                        prominent: true
                    )

                    pairingValueCard(
                        title: "Client adres",
                        value: model.localDeviceAPIURL ?? "Client adres wordt gestart...",
                        systemImage: "network",
                        prominent: false
                    )

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.58))
                    }

                    Button {
                        Task { await model.pair() }
                    } label: {
                        Label("Wacht op koppeling", systemImage: "antenna.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
                    .disabled(!model.isWiFiAvailable)

                    Button {
                        model.startDemoMode()
                    } label: {
                        Label("Demo modus", systemImage: "play.circle")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
    }

    private func pairingValueCard(
        title: String,
        value: String,
        systemImage: String,
        prominent: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                Text(value)
                    .font(prominent ? .title3.monospacedDigit().weight(.bold) : .caption2.monospaced())
                    .foregroundStyle(prominent ? .white : .white.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: systemImage)
                .font(.system(size: prominent ? 16 : 13, weight: .semibold))
                .foregroundStyle(watchAccentPurple.opacity(0.92))
        }
        .padding(9)
        .background(DJConnectWatchPanel(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func commandButton(
        _ icon: String,
        command: String,
        accessibilityLabel: String,
        isPrimary: Bool = false
    ) -> some View {
        Button {
            Task { await model.sendCommand(command) }
        } label: {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 24 : 19, weight: .semibold))
                .frame(width: isPrimary ? 54 : 44, height: isPrimary ? 54 : 44)
        }
        .buttonStyle(DJConnectWatchRoundButtonStyle())
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
    }

    private var voiceButtonTitle: String {
        switch model.voiceState {
        case .idle:
            return "Ask DJ"
        case .recording:
            return "Stop"
        case .processing:
            return "Bezig"
        case .failed:
            return "Opnieuw"
        }
    }

    private var voiceButtonIcon: String {
        switch model.voiceState {
        case .recording:
            return "stop.fill"
        case .processing:
            return "hourglass"
        case .idle, .failed:
            return "mic.fill"
        }
    }

    private var voiceButtonKind: DJConnectWatchGradientButtonStyle.Kind {
        switch model.voiceState {
        case .recording:
            return .recording
        case .processing:
            return .processing
        case .idle, .failed:
            return .primary
        }
    }
}

private struct DJConnectWatchWelcomeView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(spacing: 11) {
                    Image("LaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: watchAccentPurple.opacity(0.28), radius: 10, y: 4)
                        .accessibilityHidden(true)

                    Text("Welkom bij DJConnect")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Configureer DJConnect in Home Assistant en koppel daarna deze Watch.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Label("Spotify Premium is benodigd.", systemImage: "music.note")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)

                    Button {
                        model.dismissWelcome()
                    } label: {
                        Text("Doorgaan")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
        }
    }
}

private struct DJConnectWatchMicrophonePermissionView: View {
    enum Kind {
        case pushToTalk
        case voiceActivation
    }

    @EnvironmentObject private var model: DJConnectWatchModel
    let kind: Kind

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            VStack(spacing: 10) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [watchAccentBlue, watchAccentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Microfoon")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(bodyText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(secondaryText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.56))
                    .multilineTextAlignment(.center)

                Button {
                    switch kind {
                    case .pushToTalk:
                        model.continueAfterMicrophonePermissionExplanation()
                    case .voiceActivation:
                        model.continueAfterVoiceActivationPermissionExplanation()
                    }
                } label: {
                    Text("Doorgaan")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))

                Button {
                    switch kind {
                    case .pushToTalk:
                        model.cancelMicrophonePermissionExplanation()
                    case .voiceActivation:
                        model.cancelVoiceActivationPermissionExplanation()
                    }
                } label: {
                    Text("Niet nu")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
            }
            .padding(.horizontal, 8)
        }
    }

    private var bodyText: String {
        switch kind {
        case .pushToTalk:
            return "DJConnect gebruikt de microfoon alleen wanneer je zelf een stemverzoek aan Ask DJ start."
        case .voiceActivation:
            return "Stemactivatie luistert alleen naar Hey DJ zolang de Watch app zichtbaar en open is."
        }
    }

    private var secondaryText: String {
        switch kind {
        case .pushToTalk:
            return "Hierna vraagt Apple om toestemming."
        case .voiceActivation:
            return "Geen wake word buiten de app. Hierna vraagt Apple om microfoon- en spraakherkenningstoestemming."
        }
    }
}

private struct DJConnectWatchAboutView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(spacing: 10) {
                    Image("LaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: watchAccentPurple.opacity(0.28), radius: 10, y: 4)
                        .accessibilityHidden(true)

                    Text("DJConnect")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Muziekbediening met karakter.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 7) {
                        aboutRow("Versie", appVersion)
                        aboutRow("Platform", "watchOS")
                        aboutRow("Status", model.isDemoMode ? "Demo modus" : model.statusMessage)
                        aboutRow("Website", "djconnect.dev")
                    }
                    .padding(10)
                    .background(DJConnectWatchPanel(cornerRadius: 12))

                    Text("Home Assistant beheert pairing, playback en Ask DJ. De Watch bewaart alleen het DJConnect device-token lokaal.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
            }
        }
        .navigationTitle("Over")
    }

    private func aboutRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
            Spacer(minLength: 8)
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

private struct DJConnectWatchLegalView: View {
    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DJConnectWatchLegalSection(title: "Juridisch") {
                        Text("DJConnect is niet gelieerd aan, goedgekeurd door of gesponsord door Spotify AB, Apple of Home Assistant.")
                        Text("Spotify is een handelsmerk van Spotify AB. Home Assistant is een handelsmerk van de Open Home Foundation.")
                    }

                    DJConnectWatchLegalSection(title: "OSS") {
                        Text("DJConnect gebruikt Apple platform-frameworks en Swift Package Manager.")
                        Text("Third-party notices worden in de repository gedocumenteerd wanneer dependencies worden toegevoegd.")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.76))
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Juridisch")
    }
}

private struct DJConnectWatchLegalSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 7) {
                content
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchPrivacyView: View {
    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DJConnectWatchLegalSection(title: "Privacy") {
                        Text("DJConnect verzamelt, verkoopt of verwerkt zelf geen persoonsgegevens in de app.")
                        Text("Device-tokens worden lokaal in de private app-opslag bewaard.")
                        Text("Pushnotificaties worden alleen gebruikt voor DJConnect-meldingen, zoals Ask DJ-reacties. DJConnect bewaart hiervoor een Apple push-token lokaal en deelt dit met je eigen Home Assistant DJConnect-integratie zodat notificaties via Apple Push Notification service kunnen worden bezorgd. Push-tokens worden niet gebruikt voor tracking, advertenties of verkoop.")
                        Text("Diagnostiek wordt alleen gedeeld wanneer je die zelf kopieert of een GitHub issue opent.")
                        Text("Muziek, playback en stemverzoeken lopen via je eigen Home Assistant DJConnect-integratie.")
                        Text("AI- en Assist-antwoorden kunnen onjuist zijn en hangen af van je eigen Home Assistant- en Assist-configuratie.")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.76))
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Privacy")
    }
}

private struct DJConnectWatchFeedbackView: View {
    @Environment(\.openURL) private var openURL

    private var feedbackURL: URL {
        var components = URLComponents(string: "https://github.com/pcvantol/djconnect/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "DJConnect watchOS feedback"),
            URLQueryItem(name: "body", value: """
            ## DJConnect watchOS feedback

            Please describe your feedback or feature request:


            ```text
            client_type: watchos
            ```
            """)
        ]
        return components?.url ?? URL(string: "https://github.com/pcvantol/djconnect/issues/new")!
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [watchAccentBlue, watchAccentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Feedback delen")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Open een GitHub issue met app-context. Er wordt niets automatisch geüpload.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        openURL(feedbackURL)
                    } label: {
                        Label("Open GitHub issue", systemImage: "arrow.up.right.square")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Werkt openen niet op de Watch?")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Gebruik dan deze link op iPhone of Mac:")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                        Text("github.com/pcvantol/djconnect/issues/new")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(watchAccentBlue.opacity(0.92))
                            .lineLimit(3)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(DJConnectWatchPanel(cornerRadius: 12))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
            }
        }
        .navigationTitle("Feedback")
    }
}

private enum DJConnectWatchGameMode: String, CaseIterable, Identifiable {
    case pong
    case fly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pong:
            return "Paddle Rally"
        case .fly:
            return "Fly"
        }
    }

    var icon: String {
        switch self {
        case .pong:
            return "circle.grid.cross"
        case .fly:
            return "paperplane.fill"
        }
    }
}

private struct DJConnectWatchGamesView: View {
    @State private var activeGame: DJConnectWatchGameMode?

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(DJConnectWatchGameMode.allCases) { game in
                        Button {
                            activeGame = game
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: game.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(watchAccentBlue)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle()
                                            .fill(watchAccentBlue.opacity(0.16))
                                    )

                                Text(game.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Spacer(minLength: 4)

                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [watchAccentPurple, watchAccentBlue],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                            }
                            .padding(9)
                            .background(DJConnectWatchPanel(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Speel \(game.title)")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Games")
        .fullScreenCover(item: $activeGame) { game in
            DJConnectWatchFullscreenGameView(game: game) {
                activeGame = nil
            }
        }
    }
}

private struct DJConnectWatchFullscreenGameView: View {
    let game: DJConnectWatchGameMode
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            DJConnectWatchCanvas()
            DJConnectWatchGameSurface(game: game, isFullscreen: true)
                .id(game)
                .padding(.top, 30)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

            Button {
                close()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.32))
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .padding(.top, 2)
            .accessibilityLabel("Terug naar game selectie")
        }
    }
}

private struct DJConnectWatchGameSurface: View {
    let game: DJConnectWatchGameMode
    var isFullscreen = false

    @AppStorage("djconnect.watch.game.pong.high") private var pongHighScore = 0
    @AppStorage("djconnect.watch.game.fly.high") private var flyHighScore = 0
    @State private var isPlaying = false
    @State private var score = 0
    @State private var crownValue = 0.5
    @State private var paddleY: CGFloat = 0.5
    @State private var ballX: CGFloat = 0.55
    @State private var ballY: CGFloat = 0.48
    @State private var ballVX: CGFloat = 0.012
    @State private var ballVY: CGFloat = 0.010
    @State private var planeY: CGFloat = 0.5
    @State private var obstacleX: CGFloat = 1.05
    @State private var obstacleY: CGFloat = 0.45
    @State private var shotX: CGFloat = 0.0
    @State private var shotActive = false
    @State private var lastTick = Date()

    private var highScore: Int {
        switch game {
        case .pong:
            return pongHighScore
        case .fly:
            return flyHighScore
        }
    }

    var body: some View {
        VStack(spacing: isFullscreen ? 5 : 7) {
            HStack(spacing: 8) {
                Text("\(game.title)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(score)")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(watchAccentBlue)
                Text("HI \(highScore)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.horizontal, isFullscreen ? 6 : 8)

            gameCanvas

            HStack(spacing: 7) {
                Button {
                    reset()
                    isPlaying = true
                } label: {
                    Label(isPlaying ? "Reset" : "Start", systemImage: isPlaying ? "arrow.clockwise" : "play.fill")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))

                if game == .fly {
                    Button {
                        fire()
                    } label: {
                        Label("Schiet", systemImage: "sparkle")
                            .labelStyle(.iconOnly)
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: isFullscreen ? .infinity : nil)
        .padding(.vertical, isFullscreen ? 0 : 8)
        .background {
            if !isFullscreen {
                DJConnectWatchPanel(cornerRadius: 12)
            }
        }
        .onAppear {
            reset()
        }
    }

    private var gameCanvas: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(maxWidth: .infinity, maxHeight: isFullscreen ? .infinity : nil)
            .aspectRatio(isFullscreen ? nil : 1.28, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.34))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .focusable(true)
            .digitalCrownRotation(
                $crownValue,
                from: 0,
                through: 1,
                by: 0.01,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
            .onChange(of: crownValue) {
                handleCrownChange()
            }
            .onChange(of: timeline.date) {
                update(now: timeline.date)
            }
        }
    }

    private func handleCrownChange() {
        let clamped = min(max(crownValue, 0.08), 0.92)
        crownValue = clamped
        switch game {
        case .pong:
            paddleY = clamped
        case .fly:
            planeY = clamped
        }
    }

    private func update(now: Date) {
        guard isPlaying else {
            lastTick = now
            return
        }
        let elapsed = min(0.05, max(0.0, now.timeIntervalSince(lastTick)))
        lastTick = now
        let scale = CGFloat(elapsed / (1.0 / 30.0))
        switch game {
        case .pong:
            updatePong(scale: scale)
        case .fly:
            updateFly(scale: scale)
        }
    }

    private func updatePong(scale: CGFloat) {
        ballX += ballVX * scale
        ballY += ballVY * scale
        if ballY < 0.12 || ballY > 0.88 {
            ballVY *= -1
            ballY = min(max(ballY, 0.12), 0.88)
        }
        if ballX > 0.94 {
            ballVX = -abs(ballVX)
        }
        if ballX < 0.12 {
            if abs(ballY - paddleY) < 0.16 {
                ballVX = abs(ballVX) * 1.035
                ballVY += (ballY - paddleY) * 0.018
                score += 1
                pongHighScore = max(pongHighScore, score)
            } else {
                score = 0
                resetBall()
            }
        }
    }

    private func updateFly(scale: CGFloat) {
        obstacleX -= (0.014 + CGFloat(min(score, 18)) * 0.0008) * scale
        if shotActive {
            shotX += 0.045 * scale
            if shotX > 1.05 {
                shotActive = false
            }
            if abs(shotX - obstacleX) < 0.07 && abs(planeY - obstacleY) < 0.14 {
                shotActive = false
                score += 2
                flyHighScore = max(flyHighScore, score)
                resetObstacle()
            }
        }
        if obstacleX < 0.10 {
            score += 1
            flyHighScore = max(flyHighScore, score)
            resetObstacle()
        }
        if obstacleX < 0.28 && obstacleX > 0.13 && abs(planeY - obstacleY) < 0.15 {
            score = 0
            resetObstacle()
        }
    }

    private func fire() {
        guard game == .fly else {
            return
        }
        if !isPlaying {
            isPlaying = true
        }
        guard !shotActive else {
            return
        }
        shotActive = true
        shotX = 0.26
    }

    private func reset() {
        score = 0
        crownValue = 0.5
        paddleY = 0.5
        planeY = 0.5
        shotActive = false
        resetBall()
        resetObstacle()
        lastTick = Date()
    }

    private func resetBall() {
        ballX = 0.56
        ballY = 0.50
        ballVX = Bool.random() ? -0.012 : 0.012
        ballVY = Bool.random() ? 0.010 : -0.010
    }

    private func resetObstacle() {
        obstacleX = 1.05
        obstacleY = CGFloat.random(in: 0.22...0.80)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .linearGradient(
            Gradient(colors: [watchDeepNavy, Color(red: 0.12, green: 0.05, blue: 0.18)]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: size.height)
        ))
        switch game {
        case .pong:
            drawPong(in: &context, size: size)
        case .fly:
            drawFly(in: &context, size: size)
        }
        if !isPlaying {
            context.draw(
                Text("Tik start")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.82)),
                at: CGPoint(x: size.width / 2, y: size.height / 2),
                anchor: .center
            )
        }
    }

    private func drawPong(in context: inout GraphicsContext, size: CGSize) {
        let paddleHeight = size.height * 0.26
        let paddleRect = CGRect(
            x: size.width * 0.10,
            y: size.height * paddleY - paddleHeight / 2,
            width: 7,
            height: paddleHeight
        )
        context.fill(Path(roundedRect: paddleRect, cornerRadius: 3), with: .color(watchAccentPurple))
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * ballX - 4, y: size.height * ballY - 4, width: 8, height: 8)),
            with: .color(watchAccentBlue)
        )
        var mid = Path()
        mid.move(to: CGPoint(x: size.width / 2, y: size.height * 0.12))
        mid.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.88))
        context.stroke(mid, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
    }

    private func drawFly(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<8 {
            let x = size.width * CGFloat(index) / 7
            let y = size.height * (0.18 + CGFloat((index * 37) % 62) / 100)
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.42)))
        }
        var plane = Path()
        plane.move(to: CGPoint(x: size.width * 0.25, y: size.height * planeY))
        plane.addLine(to: CGPoint(x: size.width * 0.12, y: size.height * planeY - 10))
        plane.addLine(to: CGPoint(x: size.width * 0.12, y: size.height * planeY + 10))
        plane.closeSubpath()
        context.fill(plane, with: .color(watchAccentBlue))

        let obstacleRect = CGRect(x: size.width * obstacleX - 8, y: size.height * obstacleY - 16, width: 16, height: 32)
        context.fill(Path(roundedRect: obstacleRect, cornerRadius: 5), with: .color(watchAccentPurple))

        if shotActive {
            context.fill(
                Path(roundedRect: CGRect(x: size.width * shotX, y: size.height * planeY - 2, width: 16, height: 4), cornerRadius: 2),
                with: .color(.white.opacity(0.92))
            )
        }
    }
}

private struct DJConnectWatchSettingsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var isShowingResetPairingConfirmation = false

    private var selectedLogLevel: DJConnectWatchLogLevel {
        DJConnectWatchLogLevel(rawValue: model.watchLogLevel) ?? .info
    }

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    DJConnectWatchSettingsSection(title: "Modus") {
                        Text(model.isDemoMode ? "Demo modus actief" : "Normale modus")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.72))
                        if model.isDemoMode {
                            Button {
                                model.stopDemoMode()
                            } label: {
                                Label("Stop demo", systemImage: "xmark.circle")
                                    .font(.caption2.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                        }
                    }

                    if !model.isDemoMode {
                        DJConnectWatchSettingsSection(title: "Koppeling") {
                            Text("Reset de Watch-koppeling en koppel opnieuw via Home Assistant.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                            Button(role: .destructive) {
                                isShowingResetPairingConfirmation = true
                            } label: {
                                Label("Opnieuw koppelen", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption2.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                        }
                    }

                    DJConnectWatchSettingsSection(title: "Stemactivatie") {
                        Toggle(isOn: Binding(
                            get: { model.isVoiceActivationEnabled },
                            set: { model.setVoiceActivationEnabled($0) }
                        )) {
                            Label("Hey DJ", systemImage: "waveform")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .tint(watchAccentPurple)

                        HStack(spacing: 7) {
                            Image(systemName: voiceActivationIcon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(voiceActivationColor)
                            Text(model.voiceActivationStatusText)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }

                        Text(model.voiceActivationDetailText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Stop automatisch bij achtergrond of slapen.")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    DJConnectWatchSettingsSection(title: "Logs") {
                        VStack(spacing: 6) {
                            ForEach(DJConnectWatchLogLevel.allCases) { level in
                                Button {
                                    model.setWatchLogLevel(level)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: selectedLogLevel == level ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(selectedLogLevel == level ? watchAccentPurple : .white.opacity(0.46))
                                        Text(level.title)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 28)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Instellingen")
        .alert("Opnieuw koppelen?", isPresented: $isShowingResetPairingConfirmation) {
            Button("Annuleer", role: .cancel) {}
            Button("Opnieuw koppelen", role: .destructive) {
                model.resetPairing()
            }
        } message: {
            Text("Dit wist de lokale Watch-koppeling en opent het koppelscherm opnieuw.")
        }
    }

    private var voiceActivationIcon: String {
        switch model.voiceActivationStatus {
        case .listening:
            return "waveform.circle.fill"
        case .paused:
            return "pause.circle"
        case .microphoneRequired:
            return "mic.badge.xmark"
        case .unavailable:
            return "exclamationmark.triangle"
        }
    }

    private var voiceActivationColor: Color {
        switch model.voiceActivationStatus {
        case .listening:
            return .green
        case .paused:
            return .white.opacity(0.58)
        case .microphoneRequired, .unavailable:
            return Color(red: 1.0, green: 0.62, blue: 0.28)
        }
    }
}

private struct DJConnectWatchSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchLogsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            VStack(spacing: 8) {
                if model.diagnosticLogLines.isEmpty {
                    Spacer(minLength: 10)
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [watchAccentBlue, watchAccentPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Geen logs")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Nieuwe acties op de Watch verschijnen hier.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.66))
                            .multilineTextAlignment(.center)
                    }
                    .padding(10)
                    Spacer(minLength: 10)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 5) {
                                ForEach(Array(model.diagnosticLogLines.enumerated()), id: \.element.id) { index, line in
                                    HStack(alignment: .top, spacing: 5) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.42))
                                            .frame(width: 18, alignment: .trailing)
                                        Text(line.text)
                                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.76))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .id(line.id)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .frame(maxHeight: .infinity)
                        .onAppear {
                            scrollToBottom(proxy)
                        }
                        .onChange(of: model.diagnosticLogLines.last?.id) {
                            scrollToBottom(proxy)
                        }
                    }
                }

                Button(role: .destructive) {
                    model.clearDiagnosticLog()
                } label: {
                    Label("Wis logs", systemImage: "trash")
                        .font(.caption2.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                .disabled(model.diagnosticLogLines.isEmpty)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Logs")
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = model.diagnosticLogLines.last?.id else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct DJConnectWatchOutputsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.isLoadingOutputs && model.availableOutputs.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 18)
                    } else if model.availableOutputs.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "speaker.slash")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [watchAccentBlue, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Geen uitvoerapparaten gevonden.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)
                    } else {
                        ForEach(model.availableOutputs) { output in
                            Button {
                                Task { await model.selectOutput(output) }
                            } label: {
                                DJConnectWatchOutputRow(
                                    output: output,
                                    isLoading: model.loadingOutputID == output.id
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isLoadingOutputs || model.loadingOutputID != nil)
                        }
                    }

                    Button {
                        Task { await model.loadOutputs() }
                    } label: {
                        Label(model.isLoadingOutputs ? "Ververs..." : "Ververs", systemImage: "arrow.clockwise")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                    .disabled(model.isLoadingOutputs)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Uitvoer")
        .task {
            if model.availableOutputs.isEmpty {
                await model.loadOutputs()
            }
        }
    }
}

private struct DJConnectWatchOutputRow: View {
    let output: DJConnectOutputDevice
    let isLoading: Bool

    private var isActive: Bool {
        output.active == true
    }

    private var iconName: String {
        switch output.type?.lowercased() {
        case "computer", "tv":
            return "display"
        case "headphones":
            return "headphones"
        case "phone":
            return "iphone"
        default:
            return isActive ? "speaker.wave.2.fill" : "speaker.wave.2"
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? watchAccentBlue : .white.opacity(0.68))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isActive ? watchAccentBlue.opacity(0.18) : Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(output.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    if isActive {
                        Text("Actief")
                    } else if let volume = output.volumePercent {
                        Text("\(volume)%")
                    } else {
                        Text(output.type ?? "Uitvoer")
                    }
                }
                .font(.caption2)
                .foregroundStyle(isActive ? watchAccentBlue.opacity(0.92) : .white.opacity(0.56))
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(watchAccentPurple)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchPlaylistsView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.isLoadingPlaylists && model.playlistItems.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 18)
                    } else if model.playlistItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [watchAccentBlue, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Geen afspeellijsten gevonden.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)
                    } else {
                        ForEach(model.playlistItems) { playlist in
                            Button {
                                Task { await model.startPlaylist(playlist) }
                            } label: {
                                DJConnectWatchPlaylistRow(
                                    playlist: playlist,
                                    isLoading: model.loadingPlaylistID == playlist.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        Task { await model.loadPlaylists() }
                    } label: {
                        Label(model.isLoadingPlaylists ? "Ververs..." : "Ververs", systemImage: "arrow.clockwise")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                    .disabled(model.isLoadingPlaylists)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Afspeellijsten")
        .task {
            if model.playlistItems.isEmpty {
                await model.loadPlaylists()
            }
        }
    }
}

private struct DJConnectWatchQueueView: View {
    @EnvironmentObject private var model: DJConnectWatchModel

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.isLoadingQueue && model.queueItems.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 18)
                    } else if model.queueItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [watchAccentBlue, watchAccentPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Geen wachtrij gevonden.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)
                    } else {
                        ForEach(Array(model.queueItems.enumerated()), id: \.offset) { index, item in
                            Button {
                                Task { await model.startQueueItem(item, at: index) }
                            } label: {
                                DJConnectWatchQueueRow(
                                    item: item,
                                    isLoading: model.loadingQueueItemIndex == index
                                )
                                .opacity(model.canStartQueueItem(item) ? 1 : 0.45)
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isLoadingQueue || model.loadingQueueItemIndex != nil || !model.canStartQueueItem(item))
                        }
                    }

                    Button {
                        Task { await model.loadQueue() }
                    } label: {
                        Label(model.isLoadingQueue ? "Ververs..." : "Ververs", systemImage: "arrow.clockwise")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                    .disabled(model.isLoadingQueue)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Wachtrij")
        .task {
            if model.queueItems.isEmpty {
                await model.loadQueue()
            }
        }
    }
}

private struct DJConnectWatchQueueRow: View {
    let item: DJConnectQueueItem
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            DJConnectWatchArtwork(url: item.albumImageURL, fallbackSystemImage: "music.note")
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let artist = item.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [watchAccentPurple, watchAccentBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchPlaylistRow: View {
    let playlist: DJConnectPlaylist
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            DJConnectWatchArtwork(url: playlist.imageURL, fallbackSystemImage: "music.note.list")
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle = playlist.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [watchAccentPurple, watchAccentBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchArtwork: View {
    let url: URL?
    let fallbackSystemImage: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.10))

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var fallback: some View {
        Image(systemName: fallbackSystemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(watchAccentBlue.opacity(0.88))
    }
}

private struct DJConnectWatchAskDJChatView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    @State private var toast: String?

    var body: some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if model.isCheckingAskDJHistoryState {
                            ProgressView()
                                .tint(.white)
                                .padding(.vertical, 18)
                        } else if model.askDJMessages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [watchAccentBlue, watchAccentPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Vraag iets over de muziek of geef je DJ een opdracht.")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .multilineTextAlignment(.center)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Waarom dit nummer?")
                                    Text("Verras me met nieuwe muziek")
                                    Text("Speel iets voor koken")
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.84))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.white.opacity(0.09))
                                }
                                Text("Ask DJ kan muziek aanpassen als je daarom vraagt.")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.48))
                                    .multilineTextAlignment(.center)
                                if model.isRequestingAskDJIdleSuggestion {
                                    HStack(spacing: 5) {
                                        ProgressView()
                                            .controlSize(.mini)
                                            .tint(.white)
                                        Text("Iets zoeken...")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.58))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(model.askDJMessages) { message in
                                DJConnectWatchAskDJBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        Button {
                            model.toggleRecording()
                        } label: {
                            Label(voiceButtonTitle, systemImage: voiceButtonIcon)
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .buttonStyle(DJConnectWatchGradientButtonStyle(kind: voiceButtonKind))
                        .disabled(!model.canUseBackend)

                        Button(role: .destructive) {
                            Task { await model.clearAskDJHistory() }
                        } label: {
                            Label(model.isClearingAskDJHistory ? "Wissen..." : "Wis chat", systemImage: "trash")
                                .font(.caption2)
                        }
                        .disabled(model.askDJMessages.isEmpty || model.isClearingAskDJHistory)
                        .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .onChange(of: model.askDJScrollRequestID) {
                    guard let lastID = model.askDJMessages.last?.id else {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
            if let toast {
                VStack {
                    Spacer()
                    Label(toast, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [watchAccentBlue.opacity(0.96), watchAccentPurple.opacity(0.92)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Ask DJ")
        .task {
            await model.runAskDJHistorySyncLoop()
        }
        .onChange(of: model.askDJToast?.id) { _, _ in
            guard let text = model.askDJToast?.text else {
                return
            }
            showToast(text)
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            toast = text
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard toast == text else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                toast = nil
            }
        }
    }

    private var voiceButtonTitle: String {
        switch model.voiceState {
        case .idle:
            return "DJ verzoek"
        case .recording:
            return "Stop"
        case .processing:
            return "Bezig"
        case .failed:
            return "Opnieuw"
        }
    }

    private var voiceButtonIcon: String {
        switch model.voiceState {
        case .recording:
            return "stop.fill"
        case .processing:
            return "hourglass"
        case .idle, .failed:
            return "mic.fill"
        }
    }

    private var voiceButtonKind: DJConnectWatchGradientButtonStyle.Kind {
        switch model.voiceState {
        case .recording:
            return .recording
        case .processing:
            return .processing
        case .idle, .failed:
            return .primary
        }
    }
}

private struct DJConnectWatchAskDJBubble: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    let message: DJConnectWatchAskDJMessage

    private var isUser: Bool {
        message.role == .user
    }

    private var isSystemMessage: Bool {
        !isUser && message.messageKind == .system
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 18)
            }
            VStack(alignment: .leading, spacing: 6) {
                if isSystemMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text(message.origin == "spotify_playback_context" ? "DJ feitje" : "DJ notitie")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !message.images.isEmpty {
                    AskDJWatchImageStack(images: message.images)
                }
                if !message.links.isEmpty {
                    AskDJWatchLinkStack(links: message.links)
                }
                if !isUser, !message.playbackActions.isEmpty {
                    AskDJWatchPlaybackActionStack(
                        actions: message.playbackActions,
                        playingActionID: model.playingAskDJActionID,
                        playAction: { action in
                            Task { await model.playAskDJRecommendation(action) }
                        }
                    )
                }
                if !isUser, message.audioURL != nil {
                    Button {
                        if model.isPlayingAskDJAudio(message.audioURL) {
                            model.stopAskDJAudio()
                        } else {
                            model.replayAskDJAudio(message.audioURL)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if model.isLoadingAskDJAudio(message.audioURL) {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                            } else {
                                Image(systemName: model.isPlayingAskDJAudio(message.audioURL) ? "stop.fill" : "play.fill")
                            }
                            Text(model.isPlayingAskDJAudio(message.audioURL) ? "Stop audio" : "Speel audio")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isLoadingAskDJAudio(message.audioURL))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.white.opacity(0.13))
                    }
                }
                Text(watchAskDJTimestamp(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background {
                if isUser {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(watchAccentBlue)
                } else if isSystemMessage {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    watchAccentBlue.opacity(0.34),
                                    watchAccentPurple.opacity(0.24),
                                    .white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [watchAccentBlue, watchAccentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            if !isUser {
                Spacer(minLength: 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct AskDJWatchPlaybackActionStack: View {
    let actions: [DJConnectAskDJPlaybackAction]
    let playingActionID: String?
    let playAction: (DJConnectAskDJPlaybackAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(actions) { action in
                Button {
                    playAction(action)
                } label: {
                    HStack(spacing: 7) {
                        if let imageURL = action.imageURL {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    fallbackIcon
                                }
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        } else {
                            fallbackIcon
                                .frame(width: 28, height: 28)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.title)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            if let subtitle = action.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.66))
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 4)
                        if playingActionID == action.id {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.caption2.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.white.opacity(0.13))
                    }
                }
                .buttonStyle(.plain)
                .disabled(playingActionID != nil)
            }
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white.opacity(0.14))
            Image(systemName: "music.note")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

private struct AskDJWatchLinkStack: View {
    let links: [DJConnectResponseLink]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(links) { link in
                Link(destination: link.url) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption2.weight(.bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(link.title?.isEmpty == false ? link.title! : link.url.host ?? link.url.absoluteString)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(2)
                            if let subtitle = link.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.66))
                                    .lineLimit(2)
                            }
                        }
                        Image(systemName: "arrow.up.forward")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.white.opacity(0.13))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AskDJWatchImageStack: View {
    let images: [DJConnectResponseImage]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(images) { image in
                AskDJWatchImageCard(image: image)
            }
        }
    }
}

private struct AskDJWatchImageCard: View {
    let image: DJConnectResponseImage

    private var displayURL: URL {
        image.thumbnailURL ?? image.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            AsyncImage(url: displayURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    Color.white.opacity(0.12)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let title = image.title, !title.isEmpty {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            if let subtitle = image.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }
        }
        .padding(7)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }
}

private struct DJConnectWatchCanvas: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    watchDeepNavy,
                    Color(red: 0.07, green: 0.04, blue: 0.15),
                    Color(red: 0.03, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(watchAccentBlue.opacity(0.34))
                .frame(width: 116, height: 116)
                .blur(radius: 26)
                .offset(x: -70, y: -64)
            Circle()
                .fill(watchAccentPurple.opacity(0.32))
                .frame(width: 126, height: 126)
                .blur(radius: 30)
                .offset(x: 78, y: 72)
        }
        .ignoresSafeArea()
    }
}

private struct DJConnectWatchPanel: View {
    var cornerRadius: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color(red: 0.20, green: 0.09, blue: 0.32).opacity(0.42),
                        Color(red: 0.06, green: 0.10, blue: 0.22).opacity(0.54)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct DJConnectWatchRoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                watchAccentPurple.opacity(configuration.isPressed ? 0.72 : 0.92),
                                watchAccentBlue.opacity(configuration.isPressed ? 0.66 : 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: watchAccentPurple.opacity(0.28), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
    }
}

private struct DJConnectWatchGradientButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case recording
        case processing
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(Capsule())
            .shadow(color: shadowColor.opacity(0.34), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }

    private func background(isPressed: Bool) -> LinearGradient {
        let opacity = isPressed ? 0.78 : 1.0
        return LinearGradient(
            colors: colors.map { $0.opacity(opacity) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var colors: [Color] {
        switch kind {
        case .primary:
            return [watchAccentBlue, watchAccentPurple]
        case .secondary:
            return [watchAccentBlue.opacity(0.42), watchAccentPurple.opacity(0.56)]
        case .recording:
            return [Color(red: 1.0, green: 0.18, blue: 0.38), watchAccentPurple]
        case .processing:
            return [Color(red: 1.0, green: 0.48, blue: 0.16), watchAccentPurple]
        }
    }

    private var shadowColor: Color {
        switch kind {
        case .primary, .secondary:
            return watchAccentBlue
        case .recording:
            return Color(red: 1.0, green: 0.18, blue: 0.38)
        case .processing:
            return Color(red: 1.0, green: 0.48, blue: 0.16)
        }
    }
}
