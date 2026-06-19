import DJConnectCore
import SwiftUI

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
    @EnvironmentObject private var model: DJConnectWatchModel

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

                    HStack(spacing: 10) {
                        commandButton("backward.fill", command: "previous")
                        commandButton(
                            model.playback?.isPlaying == true ? "pause.fill" : "play.fill",
                            command: model.playback?.isPlaying == true ? "pause" : "play"
                        )
                        commandButton("forward.fill", command: "next")
                    }

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

                    if !model.responseImages.isEmpty {
                        AskDJWatchImageStack(images: model.responseImages)
                    }

                    NavigationLink {
                        DJConnectWatchAskDJChatView()
                    } label: {
                        Label("Ask DJ Chat", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .primary))

                    if model.isDemoMode {
                        Button {
                            model.stopDemoMode()
                        } label: {
                            Label("Stop demo", systemImage: "xmark.circle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.74))
                    } else {
                        Button(role: .destructive) {
                            model.resetPairing()
                        } label: {
                            Label("Reset", systemImage: "xmark.circle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.74))
                    }
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
        VStack(spacing: 6) {
            HStack {
                Text("Mood")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text("\(model.askDJMoodLabel) \(model.askDJMoodInt)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(watchAccentBlue.opacity(0.92))
            }

            Slider(value: $model.askDJMood, in: 0...100, step: 1)
                .tint(watchAccentPurple)

            HStack {
                Text("Chill")
                Spacer()
                Text("Party")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.52))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(DJConnectWatchPanel(cornerRadius: 12))
    }

    private var nowPlaying: some View {
        VStack(spacing: 5) {
            Text(model.playback?.trackName ?? "Geen track")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Text(model.playback?.artistName ?? "DJConnect")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(2)
            if let volume = model.playback?.volumePercent {
                Label("\(volume)%", systemImage: "speaker.wave.2.fill")
                    .font(.caption2)
                    .foregroundStyle(watchAccentBlue.opacity(0.92))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(DJConnectWatchPanel())
    }

    private func pairingView(message: String?) -> some View {
        ZStack {
            DJConnectWatchCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    Text("Koppel met Home Assistant")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Code")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.66))
                        Text(model.pairingCode)
                            .font(.title2.monospacedDigit())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [watchAccentBlue, watchAccentPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

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

                    Button {
                        model.startDemoMode()
                    } label: {
                        Label("Demo modus", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(DJConnectWatchGradientButtonStyle(kind: .secondary))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
    }

    private func commandButton(_ icon: String, command: String) -> some View {
        Button {
            Task { await model.sendCommand(command) }
        } label: {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(DJConnectWatchRoundButtonStyle())
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
                .onChange(of: model.askDJMessages) {
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
            return "Praat"
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
