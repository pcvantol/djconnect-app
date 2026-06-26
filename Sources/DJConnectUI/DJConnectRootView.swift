import DJConnectCore
import Combine
import SwiftUI

#if canImport(AVFoundation)
import AVFoundation
import UniformTypeIdentifiers
#endif
#if canImport(WebKit)
import WebKit
#endif
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

private func askDJTimestamp(_ date: Date, language: String, now: Date = Date()) -> String {
    let elapsed = max(0, now.timeIntervalSince(date))
    if elapsed < 3_600 {
        let minutes = max(1, Int(elapsed / 60))
        return localized(language, "\(minutes) min ago", "\(minutes) minuten geleden")
    }
    if Calendar.current.isDate(date, inSameDayAs: now) {
        return date.formatted(date: .omitted, time: .shortened)
    }
    let days = max(1, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 1)
    switch days {
    case 1:
        return localized(language, "Yesterday", "Gisteren")
    case 2...6:
        return localized(language, "\(days) days ago", "\(days) dagen geleden")
    case 7...13:
        return localized(language, "Last week", "Vorige week")
    case 14...30:
        let weeks = max(2, days / 7)
        return localized(language, "\(weeks) weeks ago", "\(weeks) weken geleden")
    case 31...61:
        return localized(language, "Last month", "Vorige maand")
    default:
        let months = max(2, days / 30)
        return localized(language, "\(months) months ago", "\(months) maanden geleden")
    }
}

private func localizedPairingStatus(_ status: DJConnectPairingStatus, language: String) -> String {
    switch status {
    case .paired:
        localized(language, "Paired", "Gekoppeld")
    case .pairing:
        localized(language, "Pairing", "Koppelen")
    case .stale:
        localized(language, "Stale", "Verlopen")
    case .unpaired:
        localized(language, "Unpaired", "Niet gekoppeld")
    }
}

private let djConnectAccent = Color(red: 0.84, green: 0.22, blue: 0.96)
private let djConnectButtonBlue = Color(red: 0.16, green: 0.56, blue: 1.0)
private let djConnectButtonPurple = Color(red: 0.84, green: 0.18, blue: 1.0)
private let djConnectScreenHorizontalPadding: CGFloat = 16
private let djConnectScreenVerticalPadding: CGFloat = 12
private let djConnectContentMaxWidth: CGFloat = 760
private let djConnectCompactContentMaxWidth: CGFloat = 640
private let djConnectMacDetailHorizontalPadding: CGFloat = djConnectScreenHorizontalPadding
private let djConnectMacDetailVerticalPadding: CGFloat = djConnectScreenVerticalPadding

private var djConnectListRowInsets: EdgeInsets {
    #if os(iOS)
    EdgeInsets(top: 5, leading: djConnectScreenHorizontalPadding, bottom: 5, trailing: djConnectScreenHorizontalPadding)
    #else
    EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
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

private struct DJConnectGradientCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 12
    var strokeOpacity: Double = 0.16

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.03, blue: 0.13).opacity(0.96),
                        Color(red: 0.11, green: 0.05, blue: 0.24).opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(strokeOpacity), lineWidth: 1.5)
            }
    }
}

private extension View {
    func djConnectGradientCard(cornerRadius: CGFloat = 12, strokeOpacity: Double = 0.16) -> some View {
        modifier(DJConnectGradientCardStyle(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AskDJBottomPreferenceKey: PreferenceKey {
    static let defaultValue = CGFloat.greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AskDJViewportHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DJConnectLilacButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(.white)
            .accentColor(.white)
            .foregroundStyle(.white)
            .foregroundColor(.white)
            .symbolRenderingMode(.monochrome)
    }
}

private extension View {
    func djConnectScreenPadding() -> some View {
        padding(.horizontal, djConnectScreenHorizontalPadding)
            .padding(.vertical, djConnectScreenVerticalPadding)
    }

    func djConnectLilacButton() -> some View {
        modifier(DJConnectLilacButtonModifier())
    }

    @ViewBuilder
    func djConnectMacDetailContent(maxWidth: CGFloat = djConnectContentMaxWidth, alignment: Alignment = .top) -> some View {
        #if os(macOS)
        self
            .frame(maxWidth: maxWidth, alignment: alignment)
            .padding(.horizontal, djConnectMacDetailHorizontalPadding)
            .padding(.vertical, djConnectMacDetailVerticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        #else
        self
        #endif
    }

    @ViewBuilder
    func djSettingsListRowBackground() -> some View {
        #if os(iOS)
        self.listRowBackground(DJConnectTableRowBackground())
        #else
        self.listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
        #endif
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

    @MainActor
    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    @MainActor
    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

private enum DJConnectGameSoundEffect: Hashable {
    case start
    case move
    case fire
    case bounce
    case hit
    case collect
    case power
    case explosion
    case crash
    case gameOver
}

@MainActor
private enum DJConnectGameSounds {
    #if canImport(AVFoundation)
    private static var players: [DJConnectGameSoundEffect: AVAudioPlayer] = [:]
    #endif

    static func play(_ effect: DJConnectGameSoundEffect) {
        #if canImport(AVFoundation)
        do {
            let player: AVAudioPlayer
            if let cached = players[effect] {
                player = cached
            } else {
                let data = wavData(for: effect)
                let created = try AVAudioPlayer(data: data)
                created.prepareToPlay()
                created.volume = 0.24
                players[effect] = created
                player = created
            }
            player.currentTime = 0
            player.play()
        } catch {
            #if os(iOS)
            DJConnectHaptics.impact()
            #endif
        }
        #else
        _ = effect
        #endif
    }

    #if canImport(AVFoundation)
    private static func wavData(for effect: DJConnectGameSoundEffect) -> Data {
        let notes: [(Double, Double)] = switch effect {
        case .start:
            [(523, 0.05), (784, 0.07)]
        case .move:
            [(392, 0.035)]
        case .fire:
            [(880, 0.045), (660, 0.035)]
        case .bounce:
            [(330, 0.04)]
        case .hit:
            [(660, 0.035), (880, 0.045)]
        case .collect:
            [(740, 0.035)]
        case .power:
            [(523, 0.04), (659, 0.04), (784, 0.06)]
        case .explosion:
            [(160, 0.04), (110, 0.04), (82, 0.06)]
        case .crash:
            [(196, 0.04), (130, 0.05), (92, 0.08)]
        case .gameOver:
            [(330, 0.06), (247, 0.07), (165, 0.10)]
        }
        return makeSquareWaveWAV(notes: notes)
    }

    private static func makeSquareWaveWAV(notes: [(frequency: Double, duration: Double)]) -> Data {
        let sampleRate = 22_050
        var samples: [Int16] = []
        for note in notes {
            let count = max(1, Int(note.duration * Double(sampleRate)))
            for index in 0..<count {
                let phase = (Double(index) * note.frequency / Double(sampleRate)).truncatingRemainder(dividingBy: 1)
                let envelope = min(1, Double(count - index) / Double(max(1, count / 4)))
                let amplitude = Int16(8_500 * envelope)
                samples.append(phase < 0.5 ? amplitude : -amplitude)
            }
            samples.append(contentsOf: Array(repeating: 0, count: sampleRate / 200))
        }

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(36 + samples.count * 2))
        data.append("WAVEfmt ".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.append("data".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(samples.count * 2))
        for sample in samples {
            data.appendLittleEndian(UInt16(bitPattern: sample))
        }
        return data
    }
    #endif
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
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
    case askDJ
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
                            title: "Ask DJ",
                            systemImage: "bubble.left.and.bubble.right.fill",
                            isSelected: selectedSection == .askDJ
                        ) { selectedSection = .askDJ }
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
                    .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
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
                    AskDJView(model: model)
                        .tabItem {
                            Label("Ask DJ", systemImage: "bubble.left.and.bubble.right.fill")
                        }
                        .tag(DJConnectSection.askDJ)
                    QueueView(model: model)
                        .tabItem {
                            Label(localized(model.language, "Queue", "Wachtrij"), systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        .tag(DJConnectSection.queue)
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
                model.refreshPermissionStatuses()
                model.markActiveSession()
                model.recoverPairingClientAPIIfNeeded()
            case .inactive, .background:
                model.markInactiveSession()
            @unknown default:
                break
            }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.isShowingPermissionExplanation) {
            PermissionExplanationView(model: model)
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedSection {
        case .nowPlaying:
            NowPlayingView(model: model)
        case .askDJ:
            AskDJView(model: model)
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

private struct PermissionExplanationView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()

            VStack(spacing: 18) {
                Image(systemName: "bell.badge.circle.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [djConnectAccent, Color(red: 0.12, green: 0.55, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Text(localized(model.language, "App permissions", "App-toestemmingen"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(localized(
                        model.language,
                        "DJConnect asks for microphone access for voice requests and notifications for Ask DJ responses.",
                        "DJConnect vraagt microfoontoegang voor stemverzoeken en meldingen voor Ask DJ-antwoorden."
                    ))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    Text(localized(
                        model.language,
                        "Server push notifications use Apple APNs and contain only a small wake-up message; the app syncs the real Ask DJ history after opening.",
                        "Server-pushmeldingen gebruiken Apple APNs en bevatten alleen een korte melding; de app synchroniseert de echte Ask DJ-geschiedenis na openen."
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    Text(localized(
                        model.language,
                        "After this screen, Apple will ask for permission. You can change this later in Settings.",
                        "Na dit scherm vraagt Apple om toestemming. Je kunt dit later aanpassen in Instellingen."
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button {
                        model.cancelPermissionExplanation()
                    } label: {
                        Text(localized(model.language, "Not now", "Niet nu"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())

                    Button {
                        model.continueAfterPermissionExplanation()
                    } label: {
                        Text(localized(model.language, "Continue", "Doorgaan"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                }
            }
            .padding(24)
            .frame(minWidth: 320, idealWidth: 420, maxWidth: 460)
            .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        ScrollView(.vertical) {
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
            #if !os(macOS)
            .padding(.bottom, 18)
            #endif
            .frame(minWidth: 360, idealWidth: 560, maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(DJConnectCanvasBackground())
        #if os(macOS)
        .frame(minHeight: 560)
        #endif
        .task {
            model.recoverPairingClientAPIIfNeeded()
        }
        .onChange(of: model.homeAssistantURL) {
            model.schedulePairingWait()
        }
    }

    private var pairingPending: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(localized(model.language, "Pair DJConnect", "DJConnect koppelen"))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(localized(
                    model.language,
                    "Enter or scan the code shown by Home Assistant while this device is on the same local network.",
                    "Vul of scan de code uit Home Assistant terwijl dit apparaat op hetzelfde lokale netwerk zit."
                ))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PairingNetworkNotice(
                    language: model.language,
                    warning: model.localNetworkRequirementMessage
                )

                PairingEditableURLCard(
                    title: localized(model.language, "Home Assistant URL", "Home Assistant URL"),
                    language: model.language,
                    text: $model.homeAssistantURL
                ) {
                    model.confirmPairingHomeAssistantURL()
                }

                PairingValueCard(
                    title: localized(model.language, "Pair Code", "Koppelcode"),
                    language: model.language,
                    value: model.pairingToken,
                    copyLabel: localized(model.language, "Copy Pair Code", "Koppelcode kopiëren"),
                    prominent: true
                )
            }

            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    if let pairingMessage = model.pairingMessage {
                        Text(pairingMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
            }
            .padding(14)
            .djConnectGradientCard()

            Button {
                model.startDemoMode()
            } label: {
                Label(
                    localized(model.language, "Start Demo Mode", "Demo modus starten"),
                    systemImage: "play.circle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)

            #if os(macOS)
            Button {
                quitApplication()
            } label: {
                Label(
                    localized(model.language, "Quit App", "App afsluiten"),
                    systemImage: "power"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
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
                Text("Let's Rock!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)
        }
    }

    private var statusTitle: String {
        if model.isDemoMode {
            return localized(model.language, "Demo Mode", "Demo modus")
        }
        return switch model.pairingStatus {
        case .pairing:
            localized(model.language, "Pairing in progress", "Wacht op koppeling in Home Assistant")
        case .stale:
            localized(model.language, "Not connected to Home Assistant", "Niet gekoppeld aan Home Assistant")
        default:
            localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant")
        }
    }
}

private struct PairingNetworkNotice: View {
    let language: String
    let warning: String?

    var body: some View {
        Label {
            Text(warning ?? localized(
                    language,
                    "DJConnect works on the local network where Home Assistant is running. Keep this device and Home Assistant on the same Wi-Fi/LAN while pairing.",
                    "DJConnect werkt op het lokale netwerk waar Home Assistant draait. Houd dit apparaat en Home Assistant tijdens koppelen op hetzelfde WiFi/LAN-netwerk."
                ))
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: warning == nil ? "network" : "wifi.exclamationmark")
                .foregroundStyle(warning == nil ? djConnectAccent : .orange)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct PairingEditableURLCard: View {
    let title: String
    let language: String
    @Binding var text: String
    let onConfirm: () -> Void
    @FocusState private var isURLFocused: Bool
    @State private var didConfirm = false

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        DJConnectAppModel.normalizedHomeAssistantURL(from: trimmedText) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            HStack(spacing: 8) {
                TextField(title, text: $text)
                    .font(.system(.body, design: .monospaced))
                    .textContentType(.URL)
                    .focused($isURLFocused)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    #endif
                    .textFieldStyle(.plain)
                    .onSubmit {
                        confirmURL()
                    }

                if !text.isEmpty {
                    Button {
                        text = ""
                        didConfirm = false
                        isURLFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localized(language, "Clear Home Assistant URL", "Home Assistant URL wissen"))
                }

                Button {
                    confirmURL()
                } label: {
                    Image(systemName: didConfirm ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isValid ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
                .accessibilityLabel(localized(language, "Confirm Home Assistant URL", "Home Assistant URL bevestigen"))
            }
            if !trimmedText.isEmpty, !isValid {
                Label(
                    localized(
                        language,
                        "Enter a valid Home Assistant URL, for example http://homeassistant.local:8123.",
                        "Vul een geldige Home Assistant URL in, bijvoorbeeld http://homeassistant.local:8123."
                    ),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else if didConfirm {
                Label(
                    localized(
                        language,
                        "Open the DJConnect integration in Home Assistant to pair the app.",
                        "Open de DJConnect integratie in Home Assistant om de app te koppelen"
                    ),
                    systemImage: "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.green)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .djConnectGradientCard(strokeOpacity: !trimmedText.isEmpty && !isValid ? 0.0 : 0.16)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(!trimmedText.isEmpty && !isValid ? .orange.opacity(0.75) : .clear, lineWidth: 1)
        }
        .task {
            isURLFocused = false
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else {
                return
            }
            isURLFocused = false
        }
        .onChange(of: text) {
            didConfirm = false
        }
    }

    private func confirmURL() {
        guard isValid else {
            didConfirm = false
            return
        }
        didConfirm = true
        isURLFocused = false
        onConfirm()
    }
}

private struct PairingValueCard: View {
    let title: String
    let language: String
    let value: String
    let copyLabel: String
    var prominent = false
    @State private var didCopy = false
    @State private var copyFeedbackToken = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(value)
                    .font(prominent ? .system(.title, design: .monospaced).weight(.semibold) : .system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    copyText(value)
                    showCopiedFeedback()
                } label: {
                    Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(didCopy ? .green : djConnectAccent)
                .tint(djConnectAccent)
                .help(copyLabel)
                .accessibilityLabel(copyLabel)
            }
            if didCopy {
                Label(
                    localized(language, "Copied to clipboard", "Gekopieerd naar klembord"),
                    systemImage: "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.green)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .djConnectGradientCard()
    }

    private func showCopiedFeedback() {
        let token = UUID()
        copyFeedbackToken = token
        withAnimation(.easeOut(duration: 0.16)) {
            didCopy = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_100))
            guard copyFeedbackToken == token else {
                return
            }
            withAnimation(.easeOut(duration: 0.18)) {
                didCopy = false
            }
        }
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
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                .controlSize(.large)
                Button {
                    model.dismissWakeWordActivationPrompt()
                } label: {
                    Text(localized(model.language, "Not Now", "Niet nu"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
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
                Text(localized(model.language, "Version", "Versie") + " \(DJConnectVersionInfo.displayVersion)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button {
                    copyText(model.crashIssueBody())
                } label: {
                    Label(localized(model.language, "Copy Logs", "Logs kopiëren"), systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                Button {
                    if let url = model.crashIssueURL() {
                        openURL(url)
                    }
                    model.dismissCrashReportPrompt()
                } label: {
                    Label(localized(model.language, "Open GitHub Issue", "Open GitHub issue"), systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                Button {
                    model.dismissCrashReportPrompt()
                } label: {
                    Text(localized(model.language, "Not Now", "Niet nu"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
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
    @State private var selectedStepIndex = 0
    private let startURL = URL(string: "https://djconnect.dev/start")!
    private var steps: [WelcomeTourStep] { WelcomeTourStep.steps(language: model.language) }
    private var selectedStep: WelcomeTourStep { steps[selectedStepIndex] }
    private var isLastStep: Bool { selectedStepIndex == steps.count - 1 }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(spacing: 20) {
                AboutBanner()
                    .frame(maxWidth: 520)

                WelcomeTourPreview(
                    steps: steps,
                    selectedStep: selectedStep,
                    language: model.language,
                    selectStep: selectWelcomeTourStep
                )

                VStack(spacing: 10) {
                    Label(selectedStep.title, systemImage: selectedStep.systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text(selectedStep.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 52)
                }

                WelcomeTourProgress(count: steps.count, selectedIndex: selectedStepIndex)

                VStack(spacing: 8) {
                    Text(localized(
                        model.language,
                        "Setup runs through Home Assistant. Spotify playback requires Spotify Premium.",
                        "Installatie loopt via Home Assistant. Spotify-weergave vereist Spotify Premium."
                    ))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                    Link("djconnect.dev/start", destination: startURL)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(djConnectAccent)
                }

                Button {
                    model.dismissWelcome()
                } label: {
                    Text(localized(model.language, "Skip", "Overslaan"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                .controlSize(.large)

                HStack(spacing: 12) {
                    Button {
                        moveWelcomeTour(by: -1)
                    } label: {
                        Label(localized(model.language, "Previous", "Vorige"), systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                    .disabled(selectedStepIndex == 0)
                    .opacity(selectedStepIndex == 0 ? 0.46 : 1)

                    Button {
                        if isLastStep {
                            model.dismissWelcome()
                        } else {
                            moveWelcomeTour(by: 1)
                        }
                    } label: {
                        Label(
                            isLastStep
                                ? localized(model.language, "Let's Start!", "Aan de slag!")
                                : localized(model.language, "Next", "Volgende"),
                            systemImage: isLastStep ? "checkmark.circle.fill" : "chevron.right"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 580, maxWidth: 680)
            #if os(macOS)
            .frame(minHeight: 620)
            #endif
        }
    }

    private func moveWelcomeTour(by offset: Int) {
        DJConnectHaptics.selection()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            selectedStepIndex = max(0, min(steps.count - 1, selectedStepIndex + offset))
        }
    }

    private func selectWelcomeTourStep(_ step: WelcomeTourStep) {
        guard let index = steps.firstIndex(of: step), index != selectedStepIndex else {
            return
        }
        DJConnectHaptics.selection()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            selectedStepIndex = index
        }
    }
}

private struct WelcomeTourStep: Identifiable, Equatable {
    let id: DJConnectSection
    let title: String
    let body: String
    let systemImage: String

    static func steps(language: String) -> [WelcomeTourStep] {
        [
            WelcomeTourStep(
                id: .nowPlaying,
                title: localized(language, "Now Playing", "Speelt Nu"),
                body: localized(
                    language,
                    "Control playback, volume and the active output from the main screen.",
                    "Bedien playback, volume en het actieve uitvoerapparaat vanaf het hoofdscherm."
                ),
                systemImage: "music.note"
            ),
            WelcomeTourStep(
                id: .askDJ,
                title: "Ask DJ",
                body: localized(
                    language,
                    "Ask for music, context or a voice reply. DJConnect keeps the chat history in sync through Home Assistant.",
                    "Vraag om muziek, context of een gesproken antwoord. DJConnect synchroniseert de chatgeschiedenis via Home Assistant."
                ),
                systemImage: "bubble.left.and.bubble.right.fill"
            ),
            WelcomeTourStep(
                id: .queue,
                title: localized(language, "Queue", "Wachtrij"),
                body: localized(
                    language,
                    "See what is coming up next and start queue items when Home Assistant returns playable actions.",
                    "Bekijk wat hierna komt en start wachtrij-items wanneer Home Assistant afspeelacties teruggeeft."
                ),
                systemImage: "text.line.first.and.arrowtriangle.forward"
            ),
            WelcomeTourStep(
                id: .settings,
                title: localized(language, "More and Settings", "Meer en Instellingen"),
                body: localized(
                    language,
                    "Open playlists, local games, settings, logs, legal information and privacy controls.",
                    "Open afspeellijsten, lokale games, instellingen, logs, juridische info en privacyopties."
                ),
                systemImage: "ellipsis.circle.fill"
            ),
            WelcomeTourStep(
                id: .games,
                title: localized(language, "Mini-games", "Mini-games"),
                body: localized(
                    language,
                    "Play local mini-games while keeping DJConnect ready for your music setup.",
                    "Speel lokale mini-games terwijl DJConnect klaar blijft voor je muziekopstelling."
                ),
                systemImage: "gamecontroller.fill"
            )
        ]
    }
}

private struct WelcomeTourPreview: View {
    let steps: [WelcomeTourStep]
    let selectedStep: WelcomeTourStep
    let language: String
    let selectStep: (WelcomeTourStep) -> Void
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 14) {
            #if os(macOS)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(steps) { step in
                        WelcomeTourButton(
                            step: step,
                            isSelected: step == selectedStep,
                            isPulsing: isPulsing,
                            action: { selectStep(step) }
                        )
                    }
                }
                .frame(width: 190)

                WelcomeTourPanel(step: selectedStep, language: language)
                    .frame(maxWidth: .infinity)
            }
            #else
            WelcomeTourPanel(step: selectedStep, language: language)
            HStack(spacing: 8) {
                ForEach(steps) { step in
                    WelcomeTourButton(
                        step: step,
                        isSelected: step == selectedStep,
                        isPulsing: isPulsing,
                        action: { selectStep(step) }
                    )
                }
            }
            #endif
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct WelcomeTourPanel: View {
    let step: WelcomeTourStep
    let language: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(djConnectAccent.opacity(0.88))
                    .frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 90, height: 8)
                Spacer()
            }
            .padding(.horizontal, 6)

            Image(systemName: step.systemImage)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [djConnectButtonBlue, djConnectButtonPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 58)

            Text(step.title)
                .font(.headline.weight(.bold))
                .lineLimit(1)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(djConnectAccent.opacity(0.32))
                .frame(width: 64, height: 6)
        }
        .padding(18)
        .frame(minHeight: 184)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct WelcomeTourButton: View {
    let step: WelcomeTourStep
    let isSelected: Bool
    let isPulsing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(step.title, systemImage: step.systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 48, height: 42)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? djConnectAccent.opacity(0.28) : Color.white.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? djConnectAccent.opacity(0.92) : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                }
                .shadow(color: isSelected ? djConnectAccent.opacity(isPulsing ? 0.60 : 0.24) : .clear, radius: isPulsing ? 16 : 6)
                .scaleEffect(isSelected && isPulsing ? 1.06 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(step.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct WelcomeTourProgress: View {
    let count: Int
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? djConnectAccent : Color.white.opacity(0.22))
                    .frame(width: index == selectedIndex ? 26 : 8, height: 8)
            }
        }
        .animation(.easeOut(duration: 0.18), value: selectedIndex)
        .accessibilityLabel("\(selectedIndex + 1) / \(count)")
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
                        WhatsNewMarkdownBody(text: model.whatsNewBody, clientType: model.identity.clientType)
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
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
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

private struct WhatsNewMarkdownBody: View {
    let text: String
    let clientType: DJConnectClientType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case let .heading(value):
                    Text(value)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                case let .bullet(value):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body.weight(.semibold))
                        formattedText(value)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .foregroundStyle(.primary)
                case let .paragraph(value):
                    formattedText(value)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                case .separator:
                    Divider()
                        .overlay(.white.opacity(0.35))
                        .padding(.vertical, 4)
                }
            }
        }
        .tint(djConnectAccent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blocks: [Block] {
        text
            .components(separatedBy: .newlines)
            .compactMap { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty else {
                    return nil
                }
                if line == "---" {
                    return .separator
                }
                if line.hasPrefix("### ") {
                    return .heading(String(line.dropFirst(4)))
                }
                if line.hasPrefix("- ") {
                    return .bullet(String(line.dropFirst(2)))
                }
                return .paragraph(line)
            }
    }

    private func formattedText(_ value: String) -> Text {
        var attributed = (try? AttributedString(markdown: value)) ?? AttributedString(value)
        if let websiteURL = DJConnectAppModel.publicDownloadsURL(clientType: clientType),
           let range = attributed.range(of: "https://djconnect.dev") {
            attributed[range].link = websiteURL
        }
        return Text(attributed)
    }

    private enum Block {
        case heading(String)
        case bullet(String)
        case paragraph(String)
        case separator
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
                    TrackSummaryView(model: model)
                    OutputSelectorView(model: model)
                    SetupStatusView(model: model)
                }
                .djConnectScreenPadding()
                .disabled(model.isRefreshing)
                .allowsHitTesting(!model.isRefreshing)
                .frame(maxWidth: djConnectContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(screenTitle(model.language, "Now Playing", "Speelt nu", isDemoMode: model.isDemoMode))
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

private struct DJConnectLilacPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .foregroundColor(.white)
            .tint(.white)
            .accentColor(.white)
            .symbolRenderingMode(.monochrome)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        djConnectButtonBlue.opacity(configuration.isPressed ? 0.82 : 1.0),
                        djConnectButtonPurple.opacity(configuration.isPressed ? 0.82 : 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(.white.opacity(configuration.isPressed ? 0.18 : 0.12), lineWidth: 1)
            }
            .shadow(color: djConnectButtonPurple.opacity(0.26), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct DJConnectFloatingCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                djConnectButtonBlue.opacity(configuration.isPressed ? 0.86 : 1.0),
                                djConnectButtonPurple.opacity(configuration.isPressed ? 0.86 : 1.0),
                                Color(red: 1.0, green: 0.56, blue: 0.22).opacity(configuration.isPressed ? 0.78 : 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                Circle()
                    .stroke(.white.opacity(configuration.isPressed ? 0.24 : 0.18), lineWidth: 1)
            }
            .shadow(color: djConnectButtonPurple.opacity(0.38), radius: 14, y: 6)
            .shadow(color: Color.black.opacity(0.26), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
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
    private var failedUntil: [URL: Date] = [:]
    private let ttl: TimeInterval = 24 * 60 * 60
    private let failureTTL: TimeInterval = 60
    private let maxEntries = 180

    func data(for url: URL) async throws -> Data {
        let now = Date()
        if let entry = entries[url], entry.expiresAt > now {
            return entry.data
        }
        if let retryAt = failedUntil[url], retryAt > now {
            throw URLError(.cannotConnectToHost)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                failedUntil[url] = now.addingTimeInterval(failureTTL)
                throw URLError(.badServerResponse)
            }
            entries[url] = Entry(data: data, tint: nil, expiresAt: now.addingTimeInterval(ttl))
            failedUntil.removeValue(forKey: url)
            trimIfNeeded()
            return data
        } catch {
            failedUntil[url] = now.addingTimeInterval(failureTTL)
            throw error
        }
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
        let now = Date()
        failedUntil = failedUntil.filter { $0.value > now }
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
                        IOSTrackHero(model: model)
                        OutputSelectorView(model: model)
                        if !model.isDemoMode {
                            IOSConnectionCard(model: model)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .disabled(model.isRefreshing)
                    .allowsHitTesting(!model.isRefreshing)
                }
                .background(.clear)
                .refreshable {
                    model.refresh()
                }
            }
            .navigationTitle(screenTitle(model.language, "Now Playing", "Speelt nu", isDemoMode: model.isDemoMode))
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
                        .fixedSize(horizontal: false, vertical: true)
                    if let statusSubtitle {
                        Text(statusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
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
                .djConnectGradientCard(cornerRadius: 10)
            }

            if let updateRequiredMessage = model.updateRequiredMessage {
                Label(updateRequiredMessage, systemImage: "arrow.down.app")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let pairingMessage = model.pairingMessage {
                Text(pairingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
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
                .fill(Color.secondary.opacity(0.75))
                .frame(width: 11, height: 11)
                .shadow(color: Color.secondary.opacity(0.35), radius: 8)
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
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures && !model.isRefreshing }

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
                Slider(value: $model.volume, in: 0...100, step: 1) { editing in
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

                FavoriteTrackButton(model: model)
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
            DJConnectGameSounds.play(.move)
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

#endif

struct SetupStatusView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        if !model.isDemoMode {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text(statusTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: statusIcon)
                            .foregroundStyle(pairingIconColor)
                    }
                    .layoutPriority(1)
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
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
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
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let pairingMessage = model.pairingMessage {
                    Text(pairingMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
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
            return .red
        }
        return model.backendAvailable ? .green : .secondary
    }

    private var pairingIconColor: Color {
        if model.isDemoMode {
            return djConnectAccent
        }
        return switch model.pairingStatus {
        case .paired:
            model.isConnected && model.backendAvailable ? .green : .red
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
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures && !model.isRefreshing }

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
                Slider(value: $model.volume, in: 0...100, step: 1) { editing in
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

                FavoriteTrackButton(model: model)
                    .disabled(!canUsePlayback)

                RepeatModeButton(model: model)
                    .disabled(!canUsePlayback)
            }
        }
        .opacity(canUsePlayback ? 1 : 0.55)
    }
}

private struct FavoriteTrackButton: View {
    @ObservedObject var model: DJConnectAppModel

    private var isFavorite: Bool {
        model.playback?.currentTrackFavoriteStatus == true
    }

    private var label: String {
        isFavorite
            ? localized(model.language, "Remove from favorites", "Haal uit favorieten")
            : localized(model.language, "Add to favorites", "Zet in favorieten")
    }

    var body: some View {
        Button {
            DJConnectHaptics.selection()
            model.toggleCurrentTrackFavorite()
        } label: {
            if model.isSavingCurrentTrack {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
            }
        }
        .buttonStyle(.bordered)
        .tint(isFavorite ? .pink : nil)
        .help(label)
        .accessibilityLabel(label)
        .disabled(model.isSavingCurrentTrack)
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

private struct AskDJView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var showingClearConfirmation = false
    @State private var selectedWebLink: DJConnectResponseLink?
    @State private var feedbackMessage: DJConnectAskDJMessage?
    @State private var toast: String?
    @State private var isSearchVisible = false
    @State private var isMoodVisible = false
    @State private var askDJSearchText = ""
    @State private var selectedSearchResultIndex = 0
    @State private var isAskDJAtBottom = true
    @State private var askDJViewportHeight: CGFloat = 0
    @State private var didScrollAskDJToInitialBottom = false
    @FocusState private var isInputFocused: Bool
    @FocusState private var isSearchFocused: Bool

    private var searchResultIDs: [UUID] {
        let query = askDJSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }
        return model.askDJMessages.compactMap { message in
            message.text.localizedCaseInsensitiveContains(query) ? message.id : nil
        }
    }

    private var activeSearchResultID: UUID? {
        guard searchResultIDs.indices.contains(selectedSearchResultIndex) else {
            return nil
        }
        return searchResultIDs[selectedSearchResultIndex]
    }

    private var askDJTimelineMessages: [DJConnectAskDJMessage] {
        var messages = model.askDJMessages
        if let transientMessage = model.transientAskDJListeningMessage {
            messages.append(transientMessage)
        }
        if let transientMessage = model.transientAskDJMoodMessage {
            messages.append(transientMessage)
        }
        return messages.sorted(by: askDJTimelineMessagePrecedes)
    }

    private func askDJTimelineMessagePrecedes(_ lhs: DJConnectAskDJMessage, _ rhs: DJConnectAskDJMessage) -> Bool {
        if let lhsExchangeID = lhs.exchangeID,
           let rhsExchangeID = rhs.exchangeID,
           lhsExchangeID == rhsExchangeID {
            let lhsOrder = lhs.exchangeOrder ?? askDJRoleFallbackExchangeOrder(lhs)
            let rhsOrder = rhs.exchangeOrder ?? askDJRoleFallbackExchangeOrder(rhs)
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            if lhs.role != rhs.role {
                return lhs.role == .user
            }
        }
        if let lhsClientID = lhs.clientMessageID,
           let rhsClientID = rhs.clientMessageID,
           !lhsClientID.isEmpty,
           lhsClientID == rhsClientID,
           lhs.role != rhs.role {
            return lhs.role == .user
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func askDJRoleFallbackExchangeOrder(_ message: DJConnectAskDJMessage) -> Int {
        message.role == .user ? 0 : 1
    }

    private func isTransientAskDJMessage(_ message: DJConnectAskDJMessage) -> Bool {
        message.id == model.transientAskDJListeningMessage?.id
            || message.id == model.transientAskDJMoodMessage?.id
    }

    private var canSend: Bool {
        !model.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.isSendingAskDJText
            && model.canUsePlaybackFeatures
    }

    private var canUseVoiceInput: Bool {
        model.voiceEnabled
            && model.canUsePlaybackFeatures
            && !model.isRefreshing
            && !model.isSendingAskDJText
            && model.voiceStatus != .processing
    }

    private var isAskDJHistoryStale: Bool {
        !model.isDemoMode && !model.canUsePlaybackFeatures
    }

    private var chatTopPadding: CGFloat {
        16
            + (isSearchVisible ? 56 : 0)
    }

    private var shouldShowAskDJScrollToBottomButton: Bool {
        model.askDJMessages.count > 8 && !isAskDJAtBottom
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ZStack(alignment: .top) {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if isAskDJHistoryStale {
                                    AskDJOfflineNotice(language: model.language)
                                        .padding(.top, 12)
                                }
                                if model.isCheckingAskDJHistoryState {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.top, 56)
                                } else if model.askDJMessages.isEmpty && model.transientAskDJListeningMessage == nil && model.transientAskDJMoodMessage == nil {
                                    AskDJEmptyState(
                                        language: model.language,
                                        isRequestingIdleSuggestion: model.isRequestingAskDJIdleSuggestion,
                                        selectExample: { example in
                                            model.askDJDraft = example
                                            isInputFocused = true
                                        }
                                    )
                                    .padding(.top, 48)
                                } else {
                                    ForEach(askDJTimelineMessages) { message in
                                        let isTransientMessage = isTransientAskDJMessage(message)
                                        AskDJMessageBubble(
                                            message: message,
                                            language: model.language,
                                            isStaleHistory: isAskDJHistoryStale && !isTransientMessage,
                                            isAudioLoading: isTransientMessage ? false : model.isLoadingAskDJAudio(message.audioURL),
                                            isAudioPlaying: isTransientMessage ? false : model.isPlayingAskDJAudio(message.audioURL),
                                            isRetryDisabled: isTransientMessage || isAskDJHistoryStale || model.isSendingAskDJText,
                                            playingActionID: model.playingAskDJActionID,
                                            isSearchResult: searchResultIDs.contains(message.id),
                                            isActiveSearchResult: activeSearchResultID == message.id,
                                            searchText: askDJSearchText,
                                            retryAction: {
                                                guard !isTransientMessage, !isAskDJHistoryStale else { return }
                                                model.retryAskDJMessage(message)
                                            },
                                            playAction: {
                                                guard !isTransientMessage, !isAskDJHistoryStale else { return }
                                                model.playAskDJRecommendation($0)
                                            },
                                            audioAction: {
                                                guard !isTransientMessage, !isAskDJHistoryStale else { return }
                                                if model.isPlayingAskDJAudio(message.audioURL) {
                                                    model.stopAskDJAudio()
                                                } else {
                                                    model.replayAskDJAudio(message.audioURL)
                                                }
                                            },
                                            openLink: { selectedWebLink = $0 },
                                            feedbackAction: { feedbackMessage = $0 },
                                            setPromptAction: { text in
                                                guard !isAskDJHistoryStale else { return }
                                                model.askDJDraft = text
                                                isInputFocused = true
                                            }
                                        )
                                        .id(message.id)
                                    }
                                }
                                Color.clear
                                    .frame(height: 1)
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear.preference(
                                                key: AskDJBottomPreferenceKey.self,
                                                value: geometry.frame(in: .named("askDJScroll")).maxY
                                            )
                                        }
                                    )
                            }
                            .padding(.horizontal, djConnectScreenHorizontalPadding)
                            .padding(.top, chatTopPadding)
                            .padding(.bottom, 16)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isInputFocused = false
                                isSearchFocused = false
                            }
                        }
                        .coordinateSpace(name: "askDJScroll")
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: AskDJViewportHeightPreferenceKey.self,
                                    value: geometry.size.height
                                )
                            }
                        )
                        .onPreferenceChange(AskDJViewportHeightPreferenceKey.self) { height in
                            askDJViewportHeight = height
                        }
                        .onPreferenceChange(AskDJBottomPreferenceKey.self) { bottomMaxY in
                            isAskDJAtBottom = bottomMaxY <= askDJViewportHeight + 140
                        }
                        .refreshable {
                            isInputFocused = false
                            isSearchFocused = false
                            await model.refreshAskDJHistory()
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8).onChanged { _ in
                                isInputFocused = false
                            }
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if shouldShowAskDJScrollToBottomButton, let lastID = model.askDJMessages.last?.id {
                                Button {
                                    isInputFocused = false
                                    isSearchFocused = false
                                    withAnimation(.easeOut(duration: 0.22)) {
                                        isAskDJAtBottom = true
                                        proxy.scrollTo(lastID, anchor: .bottom)
                                    }
                                } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 48, height: 48)
                                }
                                .buttonStyle(DJConnectFloatingCircleButtonStyle())
                                .padding(.trailing, djConnectScreenHorizontalPadding)
                                .padding(.bottom, 12)
                                .help(localized(model.language, "Scroll to bottom", "Naar beneden"))
                            }
                        }

                        if isSearchVisible {
                            AskDJSearchBar(
                                language: model.language,
                                text: $askDJSearchText,
                                isFocused: $isSearchFocused,
                                resultCount: searchResultIDs.count,
                                selectedIndex: selectedSearchResultIndex,
                                previousAction: { moveAskDJSearchSelection(by: -1, proxy: proxy) },
                                nextAction: { moveAskDJSearchSelection(by: 1, proxy: proxy) },
                                closeAction: { dismissAskDJSearch() }
                            )
                            .padding(.horizontal, djConnectScreenHorizontalPadding)
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if isMoodVisible {
                            AskDJMoodModeControl(
                                model: model,
                                closeAction: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                        isMoodVisible = false
                                    }
                                }
                            )
                            .padding(.horizontal, djConnectScreenHorizontalPadding)
                            .padding(.top, isSearchVisible ? 72 : 10)
                            .zIndex(2)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .onChange(of: model.askDJMessages) {
                        normalizeAskDJSearchSelection()
                        scrollAskDJToInitialBottomIfNeeded(proxy: proxy)
                    }
                    .onAppear {
                        didScrollAskDJToInitialBottom = false
                        scrollAskDJToInitialBottomIfNeeded(proxy: proxy)
                    }
                    .onChange(of: model.isCheckingAskDJHistoryState) { _, isChecking in
                        guard !isChecking else {
                            return
                        }
                        scrollAskDJToInitialBottomIfNeeded(proxy: proxy)
                    }
                    .onDisappear {
                        didScrollAskDJToInitialBottom = false
                    }
                    .onChange(of: model.askDJScrollRequestID) {
                        guard !isSearchVisible else {
                            return
                        }
                        guard let lastID = askDJTimelineMessages.last?.id else {
                            return
                        }
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                    .onChange(of: askDJSearchText) {
                        selectedSearchResultIndex = 0
                        scrollToActiveAskDJSearchResult(proxy: proxy)
                    }
                }

                AskDJInputBar(
                    model: model,
                    canSend: canSend,
                    canUseVoiceInput: canUseVoiceInput,
                    isInputFocused: $isInputFocused
                )
            }
            .background(DJConnectCanvasBackground())
            .overlay(alignment: .bottom) {
                if let toast {
                    StatusToast(text: toast)
                        .padding(.bottom, 76)
                        .padding(.horizontal, djConnectScreenHorizontalPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(screenTitle(model.language, "Ask DJ", "Ask DJ", isDemoMode: model.isDemoMode))
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        toggleAskDJSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(isSearchVisible ? djConnectAccent : .primary)
                    }
                    .help(localized(model.language, "Search Ask DJ", "Zoek in Ask DJ"))
                    .accessibilityLabel(localized(model.language, "Search Ask DJ", "Zoek in Ask DJ"))

                    askDJMoodToolbarButton

                    Button {
                        isInputFocused = false
                        Task {
                            await model.refreshAskDJHistory()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isClearingAskDJHistory)
                    .help(localized(model.language, "Refresh Ask DJ", "Ask DJ vernieuwen"))
                    .accessibilityLabel(localized(model.language, "Refresh Ask DJ", "Ask DJ vernieuwen"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isInputFocused = false
                        showingClearConfirmation = true
                    } label: {
                        Image(systemName: model.isClearingAskDJHistory ? "hourglass" : "trash")
                    }
                    .disabled(model.askDJMessages.isEmpty || model.isClearingAskDJHistory)
                    .help(localized(model.language, "Clear chat", "Chat wissen"))
                }
                #else
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        toggleAskDJSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(isSearchVisible ? djConnectAccent : .primary)
                    }
                    .help(localized(model.language, "Search Ask DJ", "Zoek in Ask DJ"))
                    .accessibilityLabel(localized(model.language, "Search Ask DJ", "Zoek in Ask DJ"))

                    askDJMoodToolbarButton
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isInputFocused = false
                        showingClearConfirmation = true
                    } label: {
                        Image(systemName: model.isClearingAskDJHistory ? "hourglass" : "trash")
                    }
                    .tint(.red)
                    .disabled(model.askDJMessages.isEmpty || model.isClearingAskDJHistory)
                    .help(localized(model.language, "Clear chat", "Chat wissen"))
                    .accessibilityLabel(localized(model.language, "Clear chat", "Chat wissen"))

                    Button {
                        isInputFocused = false
                        Task {
                            await model.refreshAskDJHistory()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isClearingAskDJHistory)
                    .help(localized(model.language, "Refresh Ask DJ", "Ask DJ vernieuwen"))
                    .accessibilityLabel(localized(model.language, "Refresh Ask DJ", "Ask DJ vernieuwen"))
                }
                #endif
            }
            .alert(
                localized(model.language, "Clear Ask DJ chat?", "Ask DJ chat wissen?"),
                isPresented: $showingClearConfirmation
            ) {
                Button(localized(model.language, "Clear Chat", "Chat wissen"), role: .destructive) {
                    isInputFocused = false
                    model.clearAskDJHistory()
                }
                Button(localized(model.language, "Cancel", "Annuleren"), role: .cancel) {}
            } message: {
                Text(localized(
                    model.language,
                    "This clears the Ask DJ chat history on this Home Assistant account.",
                    "Dit wist de Ask DJ chatgeschiedenis voor dit Home Assistant-account."
                ))
            }
        }
        .background(DJConnectCanvasBackground())
        .task {
            await model.runAskDJHistorySyncLoop()
        }
        .sheet(item: $selectedWebLink) { link in
            AskDJWebPreview(link: link, language: model.language)
        }
        .sheet(item: $feedbackMessage) { message in
            AskDJFeedbackPromptView(model: model, message: message)
        }
            .onChange(of: model.askDJToast?.id) { _, _ in
                guard let text = model.askDJToast?.text else {
                    return
                }
            showToast(text)
        }
    }

    @ViewBuilder
    private var askDJMoodToolbarButton: some View {
        Button {
            isInputFocused = false
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isMoodVisible.toggle()
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(isMoodVisible ? djConnectAccent : .primary)
        }
        .help(localized(model.language, "Mood", "Mood"))
        .accessibilityLabel(localized(model.language, "Mood", "Mood"))
    }

    private func dismissAskDJSearch() {
        withAnimation(.easeOut(duration: 0.18)) {
            isSearchVisible = false
        }
        askDJSearchText = ""
        selectedSearchResultIndex = 0
        isSearchFocused = false
    }

    private func toggleAskDJSearch() {
        isInputFocused = false
        if isSearchVisible {
            dismissAskDJSearch()
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isSearchVisible = true
            }
            isSearchFocused = true
        }
    }

    private func normalizeAskDJSearchSelection() {
        guard !searchResultIDs.isEmpty else {
            selectedSearchResultIndex = 0
            return
        }
        selectedSearchResultIndex = min(max(selectedSearchResultIndex, 0), searchResultIDs.count - 1)
    }

    private func moveAskDJSearchSelection(by delta: Int, proxy: ScrollViewProxy) {
        guard !searchResultIDs.isEmpty else {
            return
        }
        let count = searchResultIDs.count
        selectedSearchResultIndex = (selectedSearchResultIndex + delta + count) % count
        scrollToActiveAskDJSearchResult(proxy: proxy)
    }

    private func scrollToActiveAskDJSearchResult(proxy: ScrollViewProxy) {
        normalizeAskDJSearchSelection()
        guard let activeSearchResultID else {
            return
        }
        withAnimation(.easeOut(duration: 0.22)) {
            proxy.scrollTo(activeSearchResultID, anchor: .center)
        }
    }

    private func scrollAskDJToInitialBottomIfNeeded(proxy: ScrollViewProxy) {
        guard !didScrollAskDJToInitialBottom else {
            return
        }
        guard !isSearchVisible, let lastID = askDJTimelineMessages.last?.id else {
            return
        }
        didScrollAskDJToInitialBottom = true
        DispatchQueue.main.async {
            isAskDJAtBottom = true
            proxy.scrollTo(lastID, anchor: .bottom)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            isAskDJAtBottom = true
            proxy.scrollTo(lastID, anchor: .bottom)
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
}


private struct AskDJSearchBar: View {
    let language: String
    var scopeName: String = "Ask DJ"
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let resultCount: Int
    let selectedIndex: Int
    let previousAction: () -> Void
    let nextAction: () -> Void
    let closeAction: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            TextField(text: $text, prompt: searchPrompt) {
                EmptyView()
            }
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .font(.callout.weight(.semibold))
                .submitLabel(.search)
                .focused(isFocused)
                .onSubmit {
                    if resultCount > 0 {
                        nextAction()
                    }
                }
            Text(resultLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))
                .frame(minWidth: 44, alignment: .trailing)
            Button(action: previousAction) {
                Image(systemName: "chevron.up")
            }
            .disabled(resultCount == 0)
            .help(localized(language, "Previous result", "Vorig resultaat"))
            Button(action: nextAction) {
                Image(systemName: "chevron.down")
            }
            .disabled(resultCount == 0)
            .help(localized(language, "Next result", "Volgend resultaat"))
            Button(action: closeAction) {
                Image(systemName: "xmark")
            }
            .help(localized(language, "Close search", "Zoeken sluiten"))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.05, green: 0.05, blue: 0.13).opacity(0.82))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.43, blue: 1.0).opacity(0.55),
                            Color(red: 0.84, green: 0.22, blue: 0.96).opacity(0.45)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.24), radius: 16, y: 8)
        .onKeyPress(.return) {
            guard resultCount > 0 else {
                return .ignored
            }
            nextAction()
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard resultCount > 0 else {
                return .ignored
            }
            nextAction()
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard resultCount > 0 else {
                return .ignored
            }
            previousAction()
            return .handled
        }
        .onKeyPress(.escape) {
            closeAction()
            return .handled
        }
    }

    private var resultLabel: String {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return ""
        }
        guard resultCount > 0 else {
            return localized(language, "0", "0")
        }
        return "\(selectedIndex + 1)/\(resultCount)"
    }

    private var searchPrompt: Text {
        Text(localized(language, "Search \(scopeName)", "Zoek in \(scopeName)"))
    }
}

private struct AskDJEmptyState: View {
    let language: String
    let isRequestingIdleSuggestion: Bool
    let selectExample: (String) -> Void

    private var examples: [String] {
        [
            localized(
                language,
                "What did I listen to last week?",
                "Waar heb ik afgelopen week naar geluisterd?"
            ),
            localized(language, "Surprise me with new music", "Verras me met nieuwe muziek"),
            localized(
                language,
                "Give me a technical analysis of this song",
                "Geef een technische track analyse van dit nummer"
            ),
            localized(language, "Which albums did this artist release?", "Welke albums bracht deze artiest uit?"),
            localized(language, "Play something for cooking", "Speel iets dat past bij koken")
        ]
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.45, blue: 1.00),
                            Color(red: 0.84, green: 0.22, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(localized(language, "Ask DJ", "Ask DJ"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(localized(
                language,
                "Ask about the music or give your DJ a request.",
                "Vraag iets over de muziek of geef je DJ een opdracht."
            ))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    Button {
                        selectExample(example)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.54))
                                .frame(width: 18)
                            Text(example)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.86))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Image(systemName: "plus")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.50))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .frame(maxWidth: 360, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.09))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)

            Text(localized(
                language,
                "Ask DJ can change the music when you ask for it.",
                "Ask DJ kan muziek aanpassen als je daarom vraagt."
            ))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            if isRequestingIdleSuggestion {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text(localized(language, "Finding something to play...", "Iets om af te spelen zoeken..."))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AskDJOfflineNotice: View {
    let language: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(language, "Ask DJ offline", "Ask DJ offline"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(localized(
                    language,
                    "Shown messages may be stale until DJConnect is paired with Home Assistant again.",
                    "Getoonde berichten kunnen verouderd zijn totdat DJConnect weer met Home Assistant is gekoppeld."
                ))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .padding(.horizontal, 4)
    }
}

private struct AskDJMessageBubble: View {
    let message: DJConnectAskDJMessage
    let language: String
    let isStaleHistory: Bool
    let isAudioLoading: Bool
    let isAudioPlaying: Bool
    let isRetryDisabled: Bool
    let playingActionID: String?
    let isSearchResult: Bool
    let isActiveSearchResult: Bool
    let searchText: String
    let retryAction: () -> Void
    let playAction: (DJConnectAskDJPlaybackAction) -> Void
    let audioAction: () -> Void
    let openLink: (DJConnectResponseLink) -> Void
    let feedbackAction: (DJConnectAskDJMessage) -> Void
    let setPromptAction: (String) -> Void

    private var isUser: Bool {
        message.role == .user
    }

    private var isSystemMessage: Bool {
        !isUser && message.messageKind == .system
    }

    private var systemMessageLabel: String? {
        guard isSystemMessage else {
            return nil
        }
        if message.origin == "spotify_playback_context" {
            return localized(language, "DJ fact", "DJ feitje")
        }
        return localized(language, "DJ note", "DJ notitie")
    }

    private var promptText: String {
        message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSetPrompt: Bool {
        !promptText.isEmpty
    }

    private var canReportFeedback: Bool {
        !isUser && !isSystemMessage && !isStaleHistory
    }

    private var isVoiceRequestMessage: Bool {
        guard isUser else {
            return false
        }
        let normalizedText = promptText.lowercased()
        return normalizedText == "stemverzoek" || normalizedText == "voice request"
    }

    private var regularLinks: [DJConnectResponseLink] {
        message.links.filter { !$0.isSourceLike }
    }

    private var sourceLinks: [DJConnectResponseLink] {
        message.links.filter(\.isSourceLike)
    }

    private var shouldAttachImagesToPlaybackActions: Bool {
        false
    }

    private var outputPlaybackActions: [DJConnectAskDJPlaybackAction] {
        message.playbackActions.filter(\.isOutputAction)
    }

    private var shouldRenderOutputActionsAsList: Bool {
        !isUser
            && !outputPlaybackActions.isEmpty
            && outputPlaybackActions.count == message.playbackActions.count
    }

    private var displayText: String {
        guard shouldRenderOutputActionsAsList else {
            return message.text
        }
        let outputTitles = Set(outputPlaybackActions.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let lines = message.text.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("-") || trimmed.hasPrefix("•") else {
                return true
            }
            let title = trimmed
                .dropFirst()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return !outputTitles.contains(title)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isRecentlyPlayedHistoryMessage: Bool {
        guard !isUser else {
            return false
        }
        let intent = message.intentInfo?.intent?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let action = message.intentInfo?.action?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let itemType = message.intentInfo?.itemType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return intent == "recently_played_history"
            && action == "recently_played"
            && ["tracks", "albums", "artists", "playlists"].contains(itemType ?? "")
    }

    private var renderablePlaybackActions: [DJConnectAskDJPlaybackAction] {
        message.renderablePlaybackActions
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 42)
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 10) {
                    if let systemMessageLabel {
                        Label(systemMessageLabel, systemImage: "sparkles")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(1)
                    }
                    if !displayText.isEmpty {
                        if isVoiceRequestMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "mic.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.88))
                                AskDJMarkdownText(text: displayText, highlight: searchText)
                            }
                        } else {
                            AskDJMarkdownText(text: displayText, highlight: searchText)
                        }
                    }
                    if !isUser, let analysis = message.analysis {
                        AskDJAnalysisSummary(analysis: analysis, language: language)
                    }
                    if !isUser, !message.items.isEmpty {
                        AskDJItemList(items: message.items)
                    }
                    if !message.images.isEmpty && !shouldAttachImagesToPlaybackActions && !isRecentlyPlayedHistoryMessage {
                        AskDJImageStrip(images: message.images)
                    }
                    if !regularLinks.isEmpty {
                        AskDJLinkStack(links: regularLinks, openLink: openLink)
                    }
                    if !sourceLinks.isEmpty {
                        AskDJSourcesStack(links: sourceLinks, language: language, openLink: openLink)
                    }
                    if !isStaleHistory, !isUser, !renderablePlaybackActions.isEmpty {
                        AskDJPlaybackActionStack(
                            actions: renderablePlaybackActions,
                            language: language,
                            playingActionID: playingActionID,
                            playAction: playAction
                        )
                    }
                    if !isStaleHistory, !isUser, message.audioURL != nil {
                        AskDJAudioReplayButton(
                            language: language,
                            isLoading: isAudioLoading,
                            isPlaying: isAudioPlaying,
                            action: audioAction
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    bubbleBackground
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(bubbleStrokeStyle, lineWidth: isActiveSearchResult ? 2 : 1)
                }
                HStack(spacing: 8) {
                    Text(messageMetadataText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.46))
                    if isUser, message.status == .failed {
                        Button(action: retryAction) {
                            Label(localized(language, "Retry", "Opnieuw"), systemImage: "arrow.clockwise")
                                .font(.caption2.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.82))
                        .disabled(isRetryDisabled)
                    }
                    if canReportFeedback {
                        Button {
                            DJConnectHaptics.selection()
                            feedbackAction(message)
                        } label: {
                            Label(localized(language, "Feedback", "Feedback"), systemImage: "exclamationmark.bubble")
                                .font(.caption2.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.58))
                        .help(localized(language, "Report this Ask DJ answer", "Meld dit Ask DJ antwoord"))
                        .accessibilityLabel(localized(language, "Report this Ask DJ answer", "Meld dit Ask DJ antwoord"))
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(maxWidth: 560, alignment: isUser ? .trailing : .leading)
            if !isUser {
                Spacer(minLength: 42)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .contentShape(Rectangle())
        .contextMenu {
            if canSetPrompt && !isStaleHistory {
                Button {
                    DJConnectHaptics.selection()
                    setPromptAction(promptText)
                } label: {
                    Label(localized(language, "Set in prompt", "Zet in prompt"), systemImage: "text.cursor")
                }
            }
            if canReportFeedback {
                Button {
                    DJConnectHaptics.selection()
                    feedbackAction(message)
                } label: {
                    Label(localized(language, "Report answer", "Meld antwoord"), systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    private var messageMetadataText: String {
        let timestamp = askDJTimestamp(message.createdAt, language: language)
        guard isUser, let status = message.status else {
            return timestamp
        }
        let statusText: String
        switch status {
        case .sending:
            statusText = localized(language, "sending...", "bezig...")
        case .sent:
            statusText = localized(language, "sent", "verzonden")
        case .delivered:
            statusText = localized(language, "sent", "verzonden")
        case .failed:
            statusText = localized(language, "failed", "mislukt")
        }
        return "\(timestamp) · \(statusText)"
    }

    private var bubbleStrokeStyle: AnyShapeStyle {
        if isActiveSearchResult {
            AnyShapeStyle(LinearGradient(
                colors: [
                    Color.white.opacity(0.92),
                    Color(red: 0.84, green: 0.22, blue: 0.96).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else if isSearchResult {
            AnyShapeStyle(Color.white.opacity(0.36))
        } else if isStaleHistory {
            AnyShapeStyle(Color.white.opacity(0.16))
        } else {
            AnyShapeStyle(Color.white.opacity(isUser ? 0.12 : isSystemMessage ? 0.14 : 0.18))
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isStaleHistory {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else if isUser {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.06, green: 0.43, blue: 1.00))
        } else if isSystemMessage {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.45, blue: 1.00).opacity(0.34),
                            Color(red: 0.47, green: 0.30, blue: 0.98).opacity(0.26),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.49, blue: 0.27),
                            Color(red: 0.74, green: 0.20, blue: 0.77)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

private struct AskDJAudioReplayButton: View {
    let language: String
    let isLoading: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(.white.opacity(0.18))
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 28, height: 28)
                Text(buttonText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: 260, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var buttonText: String {
        if isLoading {
            return localized(language, "Loading audio...", "Audio laden...")
        }
        if isPlaying {
            return localized(language, "Stop DJ response", "DJ antwoord stoppen")
        }
        return localized(language, "Play DJ response", "DJ antwoord afspelen")
    }
}

private struct AskDJAnalysisSummary: View {
    let analysis: DJConnectAskDJTrackAnalysis
    let language: String

    private var modeText: String? {
        switch analysis.mode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "measured_plus_knowledge":
            return localized(language, "Measured + context", "Gemeten + duiding")
        case "measured":
            return localized(language, "Measured", "Gemeten")
        case "knowledge_plus_metadata":
            return localized(language, "Context", "Duiding")
        case "unavailable":
            return localized(language, "Not available", "Niet beschikbaar")
        default:
            return nil
        }
    }

    private var hasMeasuredData: Bool {
        guard let measured = analysis.measured else {
            return false
        }
        return measured.bpm != nil
            || measured.key?.isEmpty == false
            || measured.timeSignature != nil
            || !measured.sections.isEmpty
            || !measured.features.isEmpty
    }

    private var shouldRenderV1Fallback: Bool {
        analysis.sections.isEmpty && analysis.timeline.isEmpty && analysis.djTips.isEmpty
    }

    private var hasInferredData: Bool {
        guard let inferred = analysis.inferred else {
            return false
        }
        return inferred.provider?.isEmpty == false
            || inferred.structure?.isEmpty == false
            || inferred.instrumentation?.isEmpty == false
            || inferred.melodicBuild?.isEmpty == false
            || inferred.energyCurve?.isEmpty == false
            || inferred.mixNotes?.isEmpty == false
    }

    private var sourceText: String? {
        let sources = analysis.sources
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !sources.isEmpty else {
            return nil
        }
        return sources.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let modeText {
                    Label(modeText, systemImage: "waveform.path.ecg")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }
                if let confidence = analysis.confidence, !confidence.isEmpty {
                    Text(confidence)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }
            }
            HStack(spacing: 6) {
                if hasMeasuredData {
                    Text(localized(language, "Measured", "Gemeten"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
                if hasInferredData {
                    Text(localized(language, "Context", "Duiding"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            if let sourceText {
                Text(sourceText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(2)
            }
            if analysis.mode?.lowercased() != "unavailable" {
                ForEach(analysis.sections, id: \.stableID) { section in
                    if section.isMetadataContext {
                        metadataContextRow(section)
                    } else {
                        sectionRow(section)
                    }
                }
                if !analysis.timeline.isEmpty {
                    timelineList
                }
                ForEach(analysis.djTips, id: \.stableID) { tip in
                    tipRow(tip)
                }
                if shouldRenderV1Fallback {
                    v1FallbackRows
                }
            }
            if !analysis.limitations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analysis.limitations, id: \.self) { limitation in
                        Text(limitation)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.50))
                            .lineLimit(3)
                    }
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: 520, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var timelineList: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(localized(language, "Timeline", "Tijdlijn"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
            ForEach(analysis.timeline, id: \.stableID) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(timestampText(for: entry))
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(minWidth: 42, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayLabel(entry.label ?? entry.kind ?? "Segment"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(isLowConfidence(entry.confidence) ? 0.72 : 0.86))
                            .lineLimit(1)
                        if let summary = entry.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(2)
                        }
                        if let meta = metaText(source: entry.source, confidence: entry.confidence) {
                            Text(meta)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.46))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var v1FallbackRows: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let measured = analysis.measured {
                if let bpm = measured.bpm {
                    compactRow(title: "BPM", value: bpm.formatted(.number.precision(.fractionLength(0...1))), meta: nil)
                }
                if let key = measured.key, !key.isEmpty {
                    compactRow(title: localized(language, "Key", "Toonsoort"), value: key, meta: nil)
                }
                ForEach(measured.sections, id: \.stableID) { section in
                    compactRow(
                        title: displayLabel(section.label ?? localized(language, "Section", "Sectie")),
                        value: measuredSectionTime(section),
                        meta: section.confidence.map { localized(language, "confidence \($0)", "confidence \($0)") }
                    )
                }
            }
            if let inferred = analysis.inferred {
                compactRow(title: localized(language, "Structure", "Structuur"), value: inferred.structure, meta: inferred.provider)
                compactRow(title: localized(language, "Instrumentation", "Instrumentatie"), value: inferred.instrumentation, meta: inferred.provider)
                compactRow(title: localized(language, "Energy curve", "Energy curve"), value: inferred.energyCurve, meta: inferred.provider)
                compactRow(title: localized(language, "Mix notes", "Mix-notities"), value: inferred.mixNotes, meta: inferred.provider)
            }
        }
    }

    private func sectionRow(_ section: DJConnectAskDJTrackAnalysis.AnalysisSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayLabel(section.displayTitle))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(isLowConfidence(section.confidence) ? 0.72 : 0.88))
                    .lineLimit(2)
                if let value = section.value, !value.isEmpty {
                    Text(value)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                }
            }
            if let summary = section.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(3)
            }
            if !section.items.isEmpty {
                HStack(spacing: 5) {
                    ForEach(section.items.prefix(4)) { item in
                        Text([item.title, item.value].compactMap { value in
                            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                            return trimmed?.isEmpty == false ? trimmed : nil
                        }.joined(separator: " "))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.10)))
                    }
                }
            }
            if let meta = metaText(source: section.source, confidence: section.confidence) {
                Text(meta)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.07))
        }
    }

    private func metadataContextRow(_ section: DJConnectAskDJTrackAnalysis.AnalysisSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(localized(language, "MusicBrainz / ListenBrainz", "MusicBrainz / ListenBrainz"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                if let title = section.title, !title.isEmpty {
                    Text(displayLabel(title))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }
            if let summary = section.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(3)
            }
            if let metadata = analysis.metadata {
                metadataRows(metadata)
            } else if !section.items.isEmpty {
                metadataItemChips(section.items)
            }
            if let meta = metaText(source: section.source ?? "metabrainz_metadata", confidence: section.confidence) {
                Text(meta)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.055))
        }
    }

    private func metadataRows(_ metadata: DJConnectAskDJTrackAnalysis.Metadata) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            compactRow(title: localized(language, "Recording", "Opname"), value: metadata.recordingTitle, meta: metadata.artist)
            compactRow(title: localized(language, "MusicBrainz ID", "MusicBrainz ID"), value: metadata.musicBrainzRecordingID, meta: nil)
            compactRow(title: localized(language, "First release", "Eerste release"), value: metadata.firstReleaseDate, meta: metadata.release?.title)
            compactRow(title: localized(language, "Release", "Release"), value: metadata.release?.title, meta: metadata.release?.date)
            compactRow(title: localized(language, "Genres", "Genres"), value: metadata.genres.prefix(5).joined(separator: ", "), meta: nil)
            compactRow(title: localized(language, "Tags", "Tags"), value: metadata.tags.prefix(5).joined(separator: ", "), meta: nil)
            if let listenCount = metadata.listenBrainzListenCount {
                compactRow(
                    title: localized(language, "Public listens", "Publieke listens"),
                    value: listenCount.formatted(.number),
                    meta: "ListenBrainz"
                )
            }
            if let matchScore = metadata.matchScore {
                compactRow(
                    title: localized(language, "Metadata confidence", "Metadata-confidence"),
                    value: "\(matchScore)%",
                    meta: "MetaBrainz"
                )
            }
        }
    }

    private func metadataItemChips(_ items: [DJConnectAskDJHistoryItem]) -> some View {
        HStack(spacing: 5) {
            ForEach(items.prefix(4)) { item in
                Text([item.title, item.value].compactMap { value in
                    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed?.isEmpty == false ? trimmed : nil
                }.joined(separator: " "))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
        }
    }

    private func tipRow(_ tip: DJConnectAskDJTrackAnalysis.DJTip) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayLabel(tip.displayTitle))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(isLowConfidence(tip.confidence) ? 0.72 : 0.86))
            if let text = tip.text, !text.isEmpty {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(3)
            }
            if let meta = metaText(source: tip.source, confidence: tip.confidence) {
                Text(meta)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }
        }
    }

    private func compactRow(title: String, value: String?, meta: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                        Text(value)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.64))
                    }
                    if let meta, !meta.isEmpty {
                        Text(meta)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.46))
                    }
                }
            }
        }
    }

    private func measuredSectionTime(_ section: DJConnectAskDJTrackAnalysis.Section) -> String? {
        guard let start = section.startMS else {
            return nil
        }
        if let duration = section.durationMS {
            return "\(formatMilliseconds(start)) · \(formatMilliseconds(duration))"
        }
        return formatMilliseconds(start)
    }

    private func timestampText(for entry: DJConnectAskDJTrackAnalysis.TimelineEntry) -> String {
        if let start = entry.startMS {
            return formatMilliseconds(start)
        }
        return "--:--"
    }

    private func formatMilliseconds(_ value: Int) -> String {
        let totalSeconds = max(0, value / 1000)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func displayLabel(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ")
    }

    private func metaText(source: String?, confidence: String?) -> String? {
        let parts = [source, confidence]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func isLowConfidence(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "low"
    }
}

private extension DJConnectAskDJTrackAnalysis.AnalysisSection {
    var isMetadataContext: Bool {
        id?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "metadata_context"
    }
}

private struct AskDJItemList: View {
    let items: [DJConnectAskDJHistoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    itemArtwork(for: item)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let value = item.value, !value.isEmpty {
                            Text(value)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.82))
                                .lineLimit(2)
                        }
                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                        if let source = item.source, !source.isEmpty {
                            Text(itemDetailText(source: source, confidence: item.confidence))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.48))
                                .lineLimit(1)
                        } else if let confidence = item.confidence, !confidence.isEmpty {
                            Text(confidence)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                        if let playedAtText = playedAtText(for: item) {
                            Text(playedAtText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .frame(maxWidth: 520, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.11))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func itemArtwork(for item: DJConnectAskDJHistoryItem) -> some View {
        if let url = item.thumbnailURL ?? item.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackIcon(for: item)
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(0.14))
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                @unknown default:
                    fallbackIcon(for: item)
                }
            }
            .frame(width: 42, height: 42)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            fallbackIcon(for: item)
                .frame(width: 42, height: 42)
        }
    }

    private func fallbackIcon(for item: DJConnectAskDJHistoryItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.15))
            Image(systemName: iconName(for: item))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func iconName(for item: DJConnectAskDJHistoryItem) -> String {
        switch item.kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "technical_metric":
            return "metronome.fill"
        case "arrangement", "section", "structure":
            return "waveform.path.ecg"
        case "album", "albums":
            return "opticaldisc.fill"
        case "artist", "artists":
            return "person.crop.circle.fill"
        case "playlist", "playlists":
            return "music.note.list"
        default:
            return "music.note"
        }
    }

    private func itemDetailText(source: String, confidence: String?) -> String {
        guard let confidence, !confidence.isEmpty else {
            return source
        }
        return "\(source) · \(confidence)"
    }

    private func playedAtText(for item: DJConnectAskDJHistoryItem) -> String? {
        let text = item.playedAtLabel ?? item.playedAt
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

private struct AskDJPlaybackActionStack: View {
    let actions: [DJConnectAskDJPlaybackAction]
    let language: String
    let playingActionID: String?
    let playAction: (DJConnectAskDJPlaybackAction) -> Void

    private var supportedActions: [DJConnectAskDJPlaybackAction] {
        actions.filter(Self.isSupportedAction)
    }

    var body: some View {
        if supportedActions.allSatisfy(\.isOutputAction) {
            outputActionRows
        } else if supportedActions.allSatisfy(\.isConfirmationAction) {
            confirmationButtons
        } else if supportedActions.allSatisfy(\.isSaveCurrentTrackControlAction) {
            controlButtons
        } else {
            mediaActionCards
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 10) {
            ForEach(supportedActions) { action in
                controlButton(for: action)
            }
        }
    }

    private var confirmationButtons: some View {
        HStack(spacing: 10) {
            ForEach(supportedActions) { action in
                Button {
                    playAction(action)
                } label: {
                    HStack(spacing: 7) {
                        if playingActionID == action.id {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(confirmationLabel(for: action))
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .frame(minWidth: 108)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: confirmationGradientColors(for: action),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(playingActionID != nil)
            }
        }
    }

    private var mediaActionCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(supportedActions) { action in
                if action.isSaveCurrentTrackControlAction {
                    controlButton(for: action)
                } else {
                    mediaActionCard(for: action)
                }
            }
        }
    }

    private func controlButton(for action: DJConnectAskDJPlaybackAction) -> some View {
        Button {
            playAction(action)
        } label: {
            HStack(spacing: 7) {
                if playingActionID == action.id {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if action.active == true {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                } else {
                    Image(systemName: "heart.fill")
                        .font(.caption2.weight(.bold))
                }
                Text(buttonLabel(for: action))
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .frame(minWidth: 132)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.43, blue: 1.00),
                                Color(red: 0.84, green: 0.22, blue: 0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(playingActionID != nil || action.active == true)
    }

    private var outputActionRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(supportedActions) { action in
                HStack(spacing: 10) {
                    outputIcon(isActive: action.isActiveOutputAction)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(outputDisplayName(for: action))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(localized(language, "Speaker", "Speaker"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    Button {
                        playAction(action)
                    } label: {
                        HStack(spacing: 6) {
                            if playingActionID == action.id {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else if action.isActiveOutputAction {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                            }
                            Text(buttonLabel(for: action))
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .frame(minWidth: 82)
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.06, green: 0.43, blue: 1.00),
                                            Color(red: 0.84, green: 0.22, blue: 0.96)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(playingActionID != nil || action.isActiveOutputAction)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: 520, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(action.isActiveOutputAction ? Color.white.opacity(0.46) : .white.opacity(0.18), lineWidth: 1)
                }
            }
        }
    }

    private func mediaActionCard(for action: DJConnectAskDJPlaybackAction) -> some View {
        Button {
            playAction(action)
        } label: {
            HStack(spacing: 10) {
                if action.isOutputAction {
                    outputIcon(isActive: action.isActiveOutputAction)
                } else {
                    artwork(url: action.imageURL, action: action)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let secondaryText = secondaryText(for: action) {
                        Text(secondaryText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(2)
                    }
                    if action.isOutputAction {
                        Text(localized(language, "Speaker", "Speaker"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    } else {
                        mediaTypeBadge(for: action)
                    }
                }

                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    if playingActionID == action.id {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else if action.isActiveOutputAction {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                    } else {
                        Image(systemName: action.isOutputAction ? "speaker.wave.2.fill" : "play.fill")
                            .font(.caption2.weight(.bold))
                    }
                    Text(buttonLabel(for: action))
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.06, green: 0.43, blue: 1.00),
                                    Color(red: 0.84, green: 0.22, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: 520, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(action.isOutputAction ? .white.opacity(0.10) : .white.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(action.isActiveOutputAction ? Color.white.opacity(0.46) : .white.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(playingActionID != nil)
    }

    static func isSupportedAction(_ action: DJConnectAskDJPlaybackAction) -> Bool {
        if action.isSaveCurrentTrackControlAction {
            return true
        }
        if action.isRecommendationAction {
            return true
        }
        if action.isOutputAction {
            return action.outputDeviceID != nil
        }
        if action.isConfirmationAction {
            return true
        }
        return false
    }

    private func secondaryText(for action: DJConnectAskDJPlaybackAction) -> String? {
        let candidate = action.subtitle?.isEmpty == false ? action.subtitle : action.reason
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func outputDisplayName(for action: DJConnectAskDJPlaybackAction) -> String {
        for candidate in [action.deviceName, action.title, action.subtitle, action.outputDeviceID] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return localized(language, "Speaker", "Speaker")
    }

    private func buttonLabel(for action: DJConnectAskDJPlaybackAction) -> String {
        if action.isActiveOutputAction {
            return localized(language, "Active", "Actief")
        }
        if action.isOutputAction {
            return localized(language, "Activate", "Activeer")
        }
        for candidate in [action.buttonLabel, action.title] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return "Play Now"
    }

    private func confirmationLabel(for action: DJConnectAskDJPlaybackAction) -> String {
        let responseValue = action.responseValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if responseValue == "yes" {
            return localized(language, "Yes please", "Ja graag")
        }
        if responseValue == "no" {
            return localized(language, "No thanks", "Nee dank je")
        }
        return buttonLabel(for: action)
    }

    private func confirmationGradientColors(for action: DJConnectAskDJPlaybackAction) -> [Color] {
        let responseValue = action.responseValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if responseValue == "no" {
            return [
                Color.white.opacity(0.18),
                Color.white.opacity(0.10)
            ]
        }
        return [
            Color(red: 0.06, green: 0.43, blue: 1.00),
            Color(red: 0.84, green: 0.22, blue: 0.96)
        ]
    }

    @ViewBuilder
    private func artwork(url: URL?, action: DJConnectAskDJPlaybackAction) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackIcon(for: action)
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(0.14))
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                @unknown default:
                    fallbackIcon(for: action)
                }
            }
            .frame(width: 42, height: 42)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            fallbackIcon(for: action)
                .frame(width: 42, height: 42)
        }
    }

    private func mediaTypeBadge(for action: DJConnectAskDJPlaybackAction) -> some View {
        let type = mediaType(for: action)
        return Label(type.label(language: language), systemImage: type.systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(.white.opacity(0.14))
            }
    }

    private func fallbackIcon(for action: DJConnectAskDJPlaybackAction?) -> some View {
        let type = action.map(mediaType(for:)) ?? .track
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.16))
            Image(systemName: type.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func mediaType(for action: DJConnectAskDJPlaybackAction) -> AskDJPlaybackMediaType {
        AskDJPlaybackMediaType(action: action)
    }

    private func outputIcon(isActive: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? .white.opacity(0.24) : .white.opacity(0.16))
            Image(systemName: isActive ? "checkmark.circle.fill" : "speaker.wave.2.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(isActive ? 0.95 : 0.82))
        }
        .frame(width: 34, height: 34)
    }
}

private enum AskDJPlaybackMediaType {
    case track
    case album
    case playlist
    case podcast
    case artist

    init(action: DJConnectAskDJPlaybackAction) {
        let candidates = [
            action.kind,
            action.command,
            action.uri,
            action.contextURI,
            action.responseValue,
            action.uris.first
        ]
        let normalized = candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: " ")

        if normalized.contains("artist") {
            self = .artist
        } else if normalized.contains("playlist") {
            self = .playlist
        } else if normalized.contains("album") {
            self = .album
        } else if normalized.contains("podcast") || normalized.contains("show") || normalized.contains("episode") {
            self = .podcast
        } else {
            self = .track
        }
    }

    var systemImage: String {
        switch self {
        case .track:
            return "music.note"
        case .album:
            return "square.stack.fill"
        case .playlist:
            return "music.note.list"
        case .podcast:
            return "dot.radiowaves.left.and.right"
        case .artist:
            return "person.crop.circle"
        }
    }

    func label(language: String) -> String {
        switch self {
        case .track:
            return localized(language, "Track", "Nummer")
        case .album:
            return localized(language, "Album", "Album")
        case .playlist:
            return localized(language, "Playlist", "Playlist")
        case .podcast:
            return localized(language, "Podcast", "Podcast")
        case .artist:
            return localized(language, "Artist", "Artiest")
        }
    }
}

private struct AskDJLinkStack: View {
    let links: [DJConnectResponseLink]
    let openLink: (DJConnectResponseLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(links) { link in
                Button {
                    openLink(link)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.white.opacity(0.16)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.title?.isEmpty == false ? link.title! : link.url.host ?? link.url.absoluteString)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if let subtitle = link.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.70))
                                    .lineLimit(2)
                            } else if let host = link.url.host {
                                Text(host)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.70))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "arrow.up.forward")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(maxWidth: 520, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.12))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AskDJSourcesStack: View {
    let links: [DJConnectResponseLink]
    let language: String
    let openLink: (DJConnectResponseLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(localized(language, "Sources", "Bronnen"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.76))
                .textCase(.uppercase)

            ForEach(links) { link in
                if link.isPlaceholderSource {
                    sourceRow(link: link, isInteractive: false)
                } else {
                    Button {
                        openLink(link)
                    } label: {
                        sourceRow(link: link, isInteractive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sourceRow(link: DJConnectResponseLink, isInteractive: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(link.title?.isEmpty == false ? link.title! : link.source ?? link.url.host ?? link.url.absoluteString)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let source = link.source, !source.isEmpty {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                } else if let host = link.url.host {
                    Text(host)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 520, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.09))
        }
    }
}

private struct AskDJMarkdownText: View {
    let text: String
    var highlight: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.blocks(from: text).enumerated()), id: \.offset) { _, block in
                switch block {
                case let .heading(level, value):
                    highlightedText(value)
                        .font(level == 1 ? .headline.weight(.black) : .subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, level == 1 ? 2 : 8)
                        .padding(.bottom, 5)
                case let .paragraph(value):
                    highlightedText(value)
                        .font(.body)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 6)
                case let .bullet(value):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white.opacity(0.86))
                        highlightedText(value)
                            .font(.body)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 5)
                case .blank:
                    Spacer(minLength: 8)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func highlightedText(_ value: String) -> Text {
        let query = highlight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return Text(value)
        }

        var attributed = AttributedString(value)
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let matchRange = attributed[searchRange].range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) {
            attributed[matchRange].backgroundColor = Color.white.opacity(0.24)
            searchRange = matchRange.upperBound..<attributed.endIndex
        }
        return Text(attributed)
    }

    private enum Block {
        case heading(Int, String)
        case paragraph(String)
        case bullet(String)
        case blank
    }

    private static func blocks(from text: String) -> [Block] {
        let lines = text.components(separatedBy: .newlines)
        let blocks = lines.map { line -> Block in
            if line.isEmpty {
                return .blank
            }
            if line.hasPrefix("## ") {
                return .heading(2, String(line.dropFirst(3)))
            }
            if line.hasPrefix("# ") {
                return .heading(1, String(line.dropFirst(2)))
            }
            if line.hasPrefix("- ") {
                return .bullet(String(line.dropFirst(2)))
            }
            return .paragraph(line)
        }
        return blocks.isEmpty ? [.paragraph(text)] : blocks
    }
}

private struct AskDJWebPreview: View {
    let link: DJConnectResponseLink
    let language: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var title: String {
        link.title?.isEmpty == false ? link.title! : link.url.host ?? localized(language, "Link", "Link")
    }

    var body: some View {
        NavigationStack {
            Group {
                #if canImport(WebKit)
                AskDJWebView(url: link.url)
                #else
                VStack(spacing: 14) {
                    Image(systemName: "safari")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text(link.url.absoluteString)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                    Button(localized(language, "Open in Browser", "Open in browser")) {
                        openURL(link.url)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DJConnectCanvasBackground())
                #endif
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(language, "Done", "Gereed")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openURL(link.url)
                    } label: {
                        Label(localized(language, "Open in Browser", "Open in browser"), systemImage: "safari")
                    }
                }
            }
        }
    }
}

#if canImport(WebKit)
#if os(macOS)
private struct AskDJWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard nsView.url != url else {
            return
        }
        nsView.load(URLRequest(url: url))
    }
}
#else
private struct AskDJWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard uiView.url != url else {
            return
        }
        uiView.load(URLRequest(url: url))
    }
}
#endif
#endif

private extension DJConnectResponseLink {
    var isSourceLike: Bool {
        let values = [kind, source]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return values.contains { value in
            ["source", "sources", "citation", "citations", "reference", "references", "bron", "bronnen"].contains(value)
        }
    }

    var isPlaceholderSource: Bool {
        url.scheme?.localizedCaseInsensitiveCompare("djconnect-source") == .orderedSame
    }
}

private struct AskDJImageStrip: View {
    let images: [DJConnectResponseImage]

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 10
            let visibleCount = min(max(images.count, 1), 3)
            let availableWidth = max(1, geometry.size.width)
            let cardWidth = min(
                190,
                floor((availableWidth - spacing * CGFloat(visibleCount - 1)) / CGFloat(visibleCount))
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: spacing) {
                    ForEach(images) { image in
                        AskDJImageCard(image: image, width: cardWidth)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(height: imageStripHeight)
    }

    private var imageStripHeight: CGFloat {
        images.contains { image in
            image.title?.isEmpty == false || image.subtitle?.isEmpty == false
        } ? 250 : 192
    }
}

private struct AskDJImageCard: View {
    let image: DJConnectResponseImage
    let width: CGFloat

    private var displayURL: URL {
        image.thumbnailURL ?? image.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            AsyncImage(url: displayURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    Color.white.opacity(0.10)
                }
            }
            .frame(width: width, height: width)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }

            if image.title?.isEmpty == false || image.subtitle?.isEmpty == false {
                VStack(alignment: .leading, spacing: 2) {
                    if let title = image.title, !title.isEmpty {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    if let subtitle = image.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(2)
                    }
                }
                .frame(width: width, alignment: .leading)
            }
        }
    }
}

private struct AskDJMoodModeControl: View {
    @ObservedObject var model: DJConnectAppModel
    var closeAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: askDJMoodIcon(for: model.askDJMoodStepIndex))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(djConnectAccent)
                Text(localized(model.language, "Mood", "Mood"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(model.askDJMoodLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(djConnectAccent)
                if let closeAction {
                    Button(action: closeAction) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(localized(model.language, "Close", "Sluiten"))
                    .accessibilityLabel(localized(model.language, "Close", "Sluiten"))
                }
            }

            GeometryReader { geometry in
                let steps = model.askDJMoodSteps
                let selectedIndex = model.askDJMoodStepIndex
                let width = max(1, geometry.size.width)
                let horizontalInset: CGFloat = 40
                let usableWidth = max(1, width - horizontalInset * 2)
                let slotWidth = usableWidth / CGFloat(max(steps.count - 1, 1))
                let markerX = horizontalInset + CGFloat(selectedIndex) * slotWidth

                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.14))
                        .frame(height: 4)
                        .padding(.horizontal, horizontalInset)
                        .position(x: width / 2, y: 14)

                    ForEach(steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? djConnectAccent : Color.primary.opacity(0.24))
                            .frame(width: 8, height: 8)
                            .position(x: horizontalInset + CGFloat(index) * slotWidth, y: 14)
                    }

                    Image(systemName: askDJMoodIcon(for: selectedIndex))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(djConnectAccent))
                        .shadow(color: djConnectAccent.opacity(0.28), radius: 8, y: 3)
                        .position(x: max(14, min(width - 14, markerX)), y: 14)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedIndex)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateMood(from: value.location.x, width: width)
                        }
                        .onEnded { value in
                            updateMood(from: value.location.x, width: width)
                        }
                )
            }
            .frame(height: 28)

            AskDJMoodLabelsView(steps: model.askDJMoodSteps, selectedIndex: model.askDJMoodStepIndex)

            Text(localized(
                model.language,
                "Mood guides Ask DJ's recommendations, from calmer tracks to higher-energy picks.",
                "Mood stuurt Ask DJ's aanbevelingen, van rustigere tracks tot energiekere keuzes."
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 136)
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func updateMood(from xPosition: CGFloat, width: CGFloat) {
        let stepCount = max(model.askDJMoodSteps.count, 1)
        guard stepCount > 1 else {
            model.setAskDJMoodStep(0)
            return
        }
        let horizontalInset: CGFloat = 40
        let usableWidth = max(1, width - horizontalInset * 2)
        let clampedX = max(horizontalInset, min(width - horizontalInset, xPosition))
        let ratio = (clampedX - horizontalInset) / usableWidth
        let index = Int((ratio * CGFloat(stepCount - 1)).rounded())
        model.setAskDJMoodStep(index)
    }
}

private struct AskDJMoodLabelsView: View {
    let steps: [(label: String, value: Int)]
    let selectedIndex: Int

    var body: some View {
        GeometryReader { geometry in
            let width = max(CGFloat(1), geometry.size.width)
            let labelWidth = CGFloat(80)
            let horizontalInset = labelWidth / 2
            let usableWidth = max(CGFloat(1), width - horizontalInset * 2)
            let slotWidth = usableWidth / CGFloat(max(steps.count - 1, 1))

            ZStack(alignment: .topLeading) {
                ForEach(Array(steps.enumerated()), id: \.offset) { item in
                    label(for: item.element, index: item.offset, width: width, slotWidth: slotWidth, horizontalInset: horizontalInset, labelWidth: labelWidth)
                }
            }
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }

    private func label(
        for step: (label: String, value: Int),
        index: Int,
        width: CGFloat,
        slotWidth: CGFloat,
        horizontalInset: CGFloat,
        labelWidth: CGFloat
    ) -> some View {
        let isSelected = selectedIndex == index
        let markerX = horizontalInset + CGFloat(index) * slotWidth

        return VStack(spacing: 3) {
            Image(systemName: askDJMoodIcon(for: index))
                .font(.caption2.weight(.bold))
            Text(step.label)
                .font(.caption2.weight(isSelected ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(isSelected ? djConnectAccent : .secondary)
        .frame(width: labelWidth, height: 30)
        .position(x: markerX, y: 16)
    }
}

private func askDJMoodIcon(for index: Int) -> String {
    switch index {
    case 0:
        return "moon.zzz.fill"
    case 1:
        return "waveform"
    case 2:
        return "bolt.fill"
    default:
        return "sparkles"
    }
}

private struct AskDJInputBar: View {
    @ObservedObject var model: DJConnectAppModel
    let canSend: Bool
    let canUseVoiceInput: Bool
    var isInputFocused: FocusState<Bool>.Binding

    @ViewBuilder private var placeholderView: some View {
        HStack(spacing: 0) {
            if model.language.lowercased().hasPrefix("nl") {
                Text("Vraag ")
            }
            Text("Ask DJ").bold()
            Text("...")
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if model.askDJDraft.isEmpty {
                    placeholderView
                        .foregroundStyle(.white.opacity(0.58))
                        .padding(.horizontal, 14)
                        .allowsHitTesting(false)
                }

                TextField("", text: $model.askDJDraft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .focused(isInputFocused)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .onSubmit {
                        if canSend {
                            isInputFocused.wrappedValue = false
                            model.sendAskDJText()
                        }
                    }
                    #if os(iOS)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(localized(model.language, "Done", "Gereed")) {
                                isInputFocused.wrappedValue = false
                            }
                        }
                    }
                    #endif
            }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.06, green: 0.43, blue: 1.00).opacity(0.16),
                                        Color(red: 0.84, green: 0.22, blue: 0.96).opacity(0.12)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            }

            AskDJVoiceInputButton(model: model, isEnabled: canUseVoiceInput)

            Button {
                isInputFocused.wrappedValue = false
                model.sendAskDJText()
            } label: {
                if model.isSendingAskDJText {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.headline.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.43, blue: 1.00),
                                Color(red: 0.84, green: 0.22, blue: 0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(canSend || model.isSendingAskDJText ? 1 : 0.38)
            }
            .disabled(!canSend)
            .help(localized(model.language, "Send", "Verstuur"))
        }
        .padding(.horizontal, djConnectScreenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.43, blue: 1.00).opacity(0.22),
                        Color(red: 0.40, green: 0.25, blue: 0.98).opacity(0.18),
                        Color(red: 0.84, green: 0.22, blue: 0.96).opacity(0.24)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 1)
            }
            .background {
                Rectangle()
                    .fill(Color(red: 0.08, green: 0.06, blue: 0.14).opacity(0.70))
            }
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.43, blue: 1.00).opacity(0.36),
                    Color(red: 0.84, green: 0.22, blue: 0.96).opacity(0.38)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
    }
}

private struct AskDJVoiceInputButton: View {
    @ObservedObject var model: DJConnectAppModel
    let isEnabled: Bool
    @State private var isPressing = false

    private var isActive: Bool {
        model.isRecordingVoice || model.voiceStatus == .listening
    }

    private var isProcessing: Bool {
        model.voiceStatus == .processing
    }

    var body: some View {
        Button {} label: {
            ZStack {
                Circle()
                    .fill(buttonBackground)
                    .opacity(isEnabled || isActive || isProcessing ? 1 : 0.38)
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: isActive ? "stop.fill" : "mic.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: isActive)
                }
            }
            .frame(width: 44, height: 44)
            .overlay {
                Circle()
                    .stroke(.white.opacity(isActive ? 0.34 : 0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled && !isActive)
        .simultaneousGesture(
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
        .help(helpText)
        .accessibilityLabel(helpText)
        .accessibilityHint(localized(
            model.language,
            "Hold to record a voice request for Ask DJ.",
            "Houd ingedrukt om een stemverzoek voor Ask DJ op te nemen."
        ))
        .accessibilityAction {
            DJConnectHaptics.impact()
            model.toggleVoiceRecording()
        }
    }

    private var buttonBackground: LinearGradient {
        let colors: [Color]
        if isActive {
            colors = [
                Color(red: 1.00, green: 0.18, blue: 0.34),
                Color(red: 0.84, green: 0.22, blue: 0.96)
            ]
        } else {
            colors = [
                Color(red: 0.06, green: 0.43, blue: 1.00),
                Color(red: 0.40, green: 0.25, blue: 0.98),
                Color(red: 0.84, green: 0.22, blue: 0.96)
            ]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var helpText: String {
        if isProcessing {
            return localized(model.language, "Processing voice request", "Stemverzoek verwerken")
        }
        if isActive {
            return localized(model.language, "Release to send", "Laat los om te verzenden")
        }
        return localized(model.language, "Hold to talk", "Houd ingedrukt om te praten")
    }
}

struct QueueView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var statusToast: String?
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }
    private var areQueueItemsDisabled: Bool {
        !canUsePlayback || model.isRefreshing || model.isLoadingQueue || model.loadingQueueItemIndex != nil
    }
    private var shouldShowEmptyQueueState: Bool {
        guard !model.queueItems.isEmpty else {
            return true
        }
        guard model.queueItems.count >= 4 else {
            return false
        }
        let signatures = Set(model.queueItems.map { item in
            [
                item.uri ?? "",
                item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                item.artist?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            ].joined(separator: "|")
        })
        return signatures.count == 1 && model.queueItems.allSatisfy { !model.canStartQueueItem($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                queueScrollContent
                #else
                List {
                    if shouldShowEmptyQueueState {
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
                                showStatusToast(localized(model.language, "Track is starting", "Nummer wordt gestart"))
                                model.startQueueItem(item, at: index)
                            } label: {
                                QueueItemRow(item: item, isLoading: model.loadingQueueItemIndex == index)
                                    .opacity(areQueueItemsDisabled || !model.canStartQueueItem(item) ? 0.45 : 1)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(djConnectListRowInsets)
                            .disabled(areQueueItemsDisabled || !model.canStartQueueItem(item))
                            .allowsHitTesting(!areQueueItemsDisabled && model.canStartQueueItem(item))
                            .accessibilityLabel(item.displayTitle)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.visible)
                #endif
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
            #if os(iOS)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            #else
            .contentMargins(.horizontal, djConnectScreenHorizontalPadding, for: .scrollContent)
            #endif
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

    #if os(macOS)
    private var queueScrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 10) {
                if shouldShowEmptyQueueState {
                    DJConnectEmptyState(
                        title: localized(model.language, "No Queue", "Geen wachtrij"),
                        systemImage: "music.note.list"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                } else {
                    ForEach(Array(model.queueItems.enumerated()), id: \.offset) { index, item in
                        Button {
                            DJConnectHaptics.impact()
                            showStatusToast(localized(model.language, "Track is starting", "Nummer wordt gestart"))
                            model.startQueueItem(item, at: index)
                        } label: {
                            QueueItemRow(item: item, isLoading: model.loadingQueueItemIndex == index)
                                .opacity(areQueueItemsDisabled || !model.canStartQueueItem(item) ? 0.45 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(areQueueItemsDisabled || !model.canStartQueueItem(item))
                        .allowsHitTesting(!areQueueItemsDisabled && model.canStartQueueItem(item))
                        .accessibilityLabel(item.displayTitle)
                    }
                }
            }
            .padding(.horizontal, djConnectScreenHorizontalPadding)
            .padding(.vertical, 6)
        }
    }
    #endif

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
    private var arePlaylistItemsDisabled: Bool {
        !canUsePlayback || model.isRefreshing || model.isLoadingPlaylists || model.loadingPlaylistID != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                playlistsScrollContent
                #else
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
                                showStatusToast(localized(model.language, "Playlist is starting", "Afspeellijst wordt gestart"))
                                model.startPlaylist(playlist)
                            } label: {
                                PlaylistRow(playlist: playlist, isLoading: model.loadingPlaylistID == playlist.id)
                                    .opacity(arePlaylistItemsDisabled ? 0.45 : 1)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(djConnectListRowInsets)
                            .disabled(arePlaylistItemsDisabled)
                            .allowsHitTesting(!arePlaylistItemsDisabled)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.visible)
                #endif
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
            #if os(iOS)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            #else
            .contentMargins(.horizontal, djConnectScreenHorizontalPadding, for: .scrollContent)
            #endif
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

    #if os(macOS)
    private var playlistsScrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 10) {
                if model.playlistItems.isEmpty {
                    DJConnectEmptyState(
                        title: localized(model.language, "No Playlists", "Geen afspeellijsten"),
                        systemImage: "rectangle.stack"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                } else {
                    ForEach(model.playlistItems) { playlist in
                        Button {
                            DJConnectHaptics.impact()
                            showStatusToast(localized(model.language, "Playlist is starting", "Afspeellijst wordt gestart"))
                            model.startPlaylist(playlist)
                        } label: {
                            PlaylistRow(playlist: playlist, isLoading: model.loadingPlaylistID == playlist.id)
                                .opacity(arePlaylistItemsDisabled ? 0.45 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(arePlaylistItemsDisabled)
                        .allowsHitTesting(!arePlaylistItemsDisabled)
                    }
                }
            }
            .padding(.horizontal, djConnectScreenHorizontalPadding)
            .padding(.vertical, 6)
        }
    }
    #endif

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
    var systemImage = "play.fill"

    var body: some View {
        Label(text, systemImage: systemImage)
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
                    GameModePicker(selection: $selectedGame)
                        .frame(maxWidth: 540)
                        .frame(maxWidth: .infinity, alignment: .center)

                    LocalGameSurface(game: selectedGame, language: language)
                }
                .djConnectScreenPadding()
                .frame(maxWidth: djConnectContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(DJConnectCanvasBackground())
            .navigationTitle(localized(language, "Games", "Games"))
        }
        .id("games-\(isDemoMode)-\(language)")
    }
}

private struct GameModePicker: View {
    @Binding var selection: LocalGameMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LocalGameMode.allCases) { game in
                Button {
                    DJConnectHaptics.selection()
                    selection = game
                } label: {
                    Text(game.title)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(selection == game ? .white : .white.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if selection == game {
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.98, green: 0.49, blue: 0.27),
                                        Color(red: 0.74, green: 0.20, blue: 0.77)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                Color.clear
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityAddTraits(selection == game ? [.isSelected] : [])
            }
        }
        .padding(8)
        .frame(minHeight: 60)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.03, blue: 0.13).opacity(0.96),
                    Color(red: 0.11, green: 0.05, blue: 0.24).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1.5)
        }
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
    @State private var paddleHitTicks = 0
    @State private var ballWallBounceTicks = 0
    @State private var paddleMissTicks = 0
    @State private var shipX: CGFloat = 160
    @State private var asteroidX: CGFloat = 80
    @State private var asteroidY: CGFloat = 48
    @State private var asteroidSpeed: CGFloat = 1.35
    @State private var asteroidSize: CGFloat = 14
    @State private var asteroidKind = 0
    @State private var meteorStarPhase: CGFloat = 0
    @State private var asteroidBulletY: CGFloat = 120
    @State private var asteroidBulletActive = false
    @State private var asteroidExplosionX: CGFloat = 80
    @State private var asteroidExplosionY: CGFloat = 48
    @State private var asteroidExplosionTicks = 0
    @State private var planeY: CGFloat = 86
    @State private var obstacleX: CGFloat = 300
    @State private var obstacleY: CGFloat = 90
    @State private var obstacleKind = 0
    @State private var spaceScroll: CGFloat = 0
    @State private var skyCrashX: CGFloat = 58
    @State private var skyCrashY: CGFloat = 86
    @State private var skyCrashTicks = 0
    @State private var skyObstacleExplosionX: CGFloat = 300
    @State private var skyObstacleExplosionY: CGFloat = 90
    @State private var skyObstacleExplosionKind = 0
    @State private var skyObstacleExplosionTicks = 0
    @State private var flyShotX: CGFloat = 58
    @State private var flyShotActive = false
    @State private var pacmanX: CGFloat = 46
    @State private var pacmanY: CGFloat = 86
    @State private var pacmanDX: CGFloat = 1
    @State private var pacmanDY: CGFloat = 0
    @State private var ghostX: CGFloat = 250
    @State private var ghostY: CGFloat = 86
    @State private var ghostVulnerableTicks = 0
    @State private var pacmanDeathX: CGFloat = 46
    @State private var pacmanDeathY: CGFloat = 86
    @State private var pacmanDeathTicks = 0
    @State private var pellets: Set<Int> = Set(0..<32)
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
                            .foregroundStyle(.white)
                            .frame(minWidth: 180)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.84, green: 0.18, blue: 1.0),
                                        Color(red: 0.36, green: 0.32, blue: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.28), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
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

            controlsView

            Text(helpText)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    Color(red: 0.13, green: 0.06, blue: 0.24).opacity(0.88),
                    Color(red: 0.06, green: 0.10, blue: 0.22).opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
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
            localized(language, "Move left and right. Fire to hit meteors.", "Beweeg links en rechts. Schiet om meteorieten te raken.")
        case .fly:
            localized(language, "Fly through the gaps. Fire clears an obstacle.", "Vlieg door de openingen. Schieten ruimt een obstakel op.")
        case .pacman:
            localized(language, "Eat dots and dodge the ghost.", "Eet bolletjes en ontwijk de geest.")
        }
    }

    @ViewBuilder
    private var controlsView: some View {
        if game == .pacman {
            HStack(spacing: 10) {
                directionButton(localized(language, "Up", "Omhoog"), icon: "chevron.up") {
                    setPacmanDirection(dx: 0, dy: -1)
                }
                directionButton(localized(language, "Down", "Omlaag"), icon: "chevron.down") {
                    setPacmanDirection(dx: 0, dy: 1)
                }
                directionButton(localized(language, "Left", "Links"), icon: "chevron.left") {
                    setPacmanDirection(dx: -1, dy: 0)
                }
                directionButton(localized(language, "Right", "Rechts"), icon: "chevron.right") {
                    setPacmanDirection(dx: 1, dy: 0)
                }
                resetButton
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)
        } else {
            HStack(spacing: 10) {
                directionButton(primaryMoveLabel, icon: primaryMoveIcon) {
                    move(-1)
                }
                directionButton(secondaryMoveLabel, icon: secondaryMoveIcon) {
                    move(1)
                }

                if game != .pong {
                    Button {
                        DJConnectHaptics.impact()
                        fire()
                    } label: {
                        Label(localized(language, "Fire", "Schiet"), systemImage: "sparkle")
                            .labelStyle(.iconOnly)
                            .frame(height: 24)
                    }
                    .help(localized(language, "Fire", "Schiet"))
                }

                resetButton
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)
        }
    }

    private func directionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            DJConnectHaptics.impact()
            action()
        } label: {
            Label(label, systemImage: icon)
                .labelStyle(.iconOnly)
                .frame(height: 24)
        }
        .help(label)
    }

    private var resetButton: some View {
        Button {
            DJConnectHaptics.selection()
            reset()
        } label: {
            Label(localized(language, "Reset", "Reset"), systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .frame(height: 24)
        }
        .help(localized(language, "Reset", "Reset"))
    }

    private var pacmanPowerPellets: Set<Int> { [0, 7, 24, 31] }
    private var pacmanPowerTicks: Int { 150 }
    private var isGhostVulnerable: Bool { ghostVulnerableTicks > 0 }
    private var isGhostBlinking: Bool {
        isGhostVulnerable && ghostVulnerableTicks < 55 && (ghostVulnerableTicks / 6).isMultiple(of: 2)
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
            drawPaddleHit(in: &context, rect: rect)
            if isPlaying {
                drawBallWallBounce(in: &context, rect: rect)
                context.fill(Path(ellipseIn: rect(ballX - 4, ballY - 4, 8, 8)), with: .color(.green))
            }
        case .asteroids:
            drawMeteorRunBackground(in: &context, scaleX: scaleX, scaleY: scaleY)
            var ship = Path()
            ship.move(to: point(shipX, 128))
            ship.addLine(to: point(shipX - 9, 146))
            ship.addLine(to: point(shipX + 9, 146))
            ship.closeSubpath()
            context.stroke(ship, with: .color(djConnectAccent), lineWidth: 2)
            drawMeteor(in: &context, rect: rect, point: point)
            drawMeteorExplosion(in: &context, rect: rect, point: point, scaleX: scaleX, scaleY: scaleY)
            if asteroidBulletActive {
                context.fill(Path(roundedRect: rect(shipX - 2, asteroidBulletY, 4, 10), cornerRadius: 2), with: .color(.cyan))
            }
        case .fly:
            drawSpaceFlightBackground(in: &context, scaleX: scaleX, scaleY: scaleY)
            var plane = Path()
            plane.move(to: point(62, planeY))
            plane.addLine(to: point(30, planeY - 12))
            plane.addLine(to: point(30, planeY + 12))
            plane.closeSubpath()
            context.fill(plane, with: .color(.cyan))
            drawSkyDashObstacle(in: &context, rect: rect, point: point)
            drawSkyDashCrash(in: &context, rect: rect, point: point, scaleX: scaleX, scaleY: scaleY)
            drawSkyDashObstacleExplosion(in: &context, rect: rect, point: point, scaleX: scaleX, scaleY: scaleY)
            if flyShotActive {
                context.fill(Path(roundedRect: rect(flyShotX, planeY - 2, 14, 4), cornerRadius: 2), with: .color(.cyan))
            }
        case .pacman:
            for pellet in pellets {
                let column = pellet % 8
                let row = pellet / 8
                let isPowerPellet = pacmanPowerPellets.contains(pellet)
                let pelletSize: CGFloat = isPowerPellet ? 8 : 4
                context.fill(
                    Path(ellipseIn: rect(CGFloat(48 + column * 28) - pelletSize / 2, CGFloat(52 + row * 28) - pelletSize / 2, pelletSize, pelletSize)),
                    with: .color(.white.opacity(isPowerPellet ? 0.98 : 0.82))
                )
            }
            context.fill(Path(ellipseIn: rect(pacmanX - 8, pacmanY - 8, 16, 16)), with: .color(.yellow))
            drawPacmanMouth(in: &context, at: point(pacmanX, pacmanY), scaleX: scaleX, scaleY: scaleY)
            drawPacmanEye(in: &context, at: point(pacmanX, pacmanY), scaleX: scaleX, scaleY: scaleY)
            drawGhost(in: &context, at: point(ghostX, ghostY), scaleX: scaleX, scaleY: scaleY, isVulnerable: isGhostVulnerable, isBlinking: isGhostBlinking)
            drawPacmanDeath(in: &context, rect: rect, point: point, scaleX: scaleX, scaleY: scaleY)
        }
    }

    private func drawPaddleHit(in context: inout GraphicsContext, rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect) {
        guard paddleHitTicks > 0 else {
            return
        }
        let progress = CGFloat(10 - paddleHitTicks) / 10
        let opacity = Double(max(0, 1 - progress))
        context.fill(Path(roundedRect: rect(28, paddleY - 22, 4 + progress * 22, 44), cornerRadius: 4), with: .color(.yellow.opacity(opacity * 0.55)))
        context.stroke(Path(ellipseIn: rect(22, paddleY - 17 - progress * 8, 20 + progress * 22, 34 + progress * 16)), with: .color(.green.opacity(opacity)), lineWidth: 2)
    }

    private func drawBallWallBounce(in context: inout GraphicsContext, rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect) {
        guard ballWallBounceTicks > 0 else {
            return
        }
        let progress = CGFloat(8 - ballWallBounceTicks) / 8
        let opacity = Double(max(0, 1 - progress))
        let size = 10 + progress * 12
        context.stroke(
            Path(ellipseIn: rect(ballX - size / 2, ballY - size / 2, size, size)),
            with: .color(.green.opacity(opacity * 0.55)),
            lineWidth: 1.5
        )
    }

    private func drawMeteorRunBackground(in context: inout GraphicsContext, scaleX: CGFloat, scaleY: CGFloat) {
        let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, phase: CGFloat)] = [
            (46, 44, 1.8, 0.0),
            (86, 92, 1.3, 1.2),
            (128, 58, 1.6, 2.4),
            (176, 126, 1.2, 0.8),
            (218, 74, 1.9, 1.8),
            (264, 112, 1.4, 2.8),
            (292, 48, 1.1, 0.4)
        ]
        for star in stars {
            let twinkle = 0.35 + 0.45 * (sin(Double(meteorStarPhase + star.phase)) + 1) / 2
            context.fill(
                Path(ellipseIn: CGRect(x: (star.x - star.size / 2) * scaleX, y: (star.y - star.size / 2) * scaleY, width: star.size * scaleX, height: star.size * scaleY)),
                with: .color(.white.opacity(twinkle))
            )
        }
    }

    private func drawMeteor(
        in context: inout GraphicsContext,
        rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
        point: (CGFloat, CGFloat) -> CGPoint
    ) {
        let half = asteroidSize / 2
        switch asteroidKind {
        case 0:
            context.stroke(Path(ellipseIn: rect(asteroidX - half, asteroidY - half, asteroidSize, asteroidSize)), with: .color(.pink), lineWidth: 2)
        case 1:
            var rock = Path()
            rock.move(to: point(asteroidX - half * 0.7, asteroidY - half))
            rock.addLine(to: point(asteroidX + half * 0.8, asteroidY - half * 0.6))
            rock.addLine(to: point(asteroidX + half, asteroidY + half * 0.35))
            rock.addLine(to: point(asteroidX + half * 0.2, asteroidY + half))
            rock.addLine(to: point(asteroidX - half, asteroidY + half * 0.45))
            rock.closeSubpath()
            context.stroke(rock, with: .color(.orange), lineWidth: 2)
        case 2:
            var diamond = Path()
            diamond.move(to: point(asteroidX, asteroidY - half))
            diamond.addLine(to: point(asteroidX + half, asteroidY))
            diamond.addLine(to: point(asteroidX, asteroidY + half))
            diamond.addLine(to: point(asteroidX - half, asteroidY))
            diamond.closeSubpath()
            context.stroke(diamond, with: .color(.purple), lineWidth: 2)
        default:
            context.stroke(Path(roundedRect: rect(asteroidX - half, asteroidY - half * 0.75, asteroidSize, asteroidSize * 1.5), cornerRadius: 4), with: .color(.mint), lineWidth: 2)
        }
    }

    private func drawMeteorExplosion(
        in context: inout GraphicsContext,
        rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
        point: (CGFloat, CGFloat) -> CGPoint,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) {
        guard asteroidExplosionTicks > 0 else {
            return
        }
        let progress = CGFloat(18 - asteroidExplosionTicks) / 18
        let opacity = Double(max(0, 1 - progress))
        let radius = 8 + progress * 18
        context.stroke(
            Path(ellipseIn: rect(asteroidExplosionX - radius / 2, asteroidExplosionY - radius / 2, radius, radius)),
            with: .color(.orange.opacity(opacity)),
            lineWidth: 2
        )

        let sparks: [(CGFloat, CGFloat)] = [(1, 0), (-1, 0), (0, 1), (0, -1), (0.72, 0.72), (-0.72, 0.72), (0.72, -0.72), (-0.72, -0.72)]
        for spark in sparks {
            let distance = 6 + progress * 18
            let sparkCenter = point(asteroidExplosionX + spark.0 * distance, asteroidExplosionY + spark.1 * distance)
            context.fill(
                Path(ellipseIn: CGRect(x: sparkCenter.x - 2 * scaleX, y: sparkCenter.y - 2 * scaleY, width: 4 * scaleX, height: 4 * scaleY)),
                with: .color(.yellow.opacity(opacity))
            )
        }
    }

    private func drawSpaceFlightBackground(in context: inout GraphicsContext, scaleX: CGFloat, scaleY: CGFloat) {
        let stars: [(x: CGFloat, y: CGFloat, speed: CGFloat, length: CGFloat, opacity: Double)] = [
            (294, 44, 0.55, 13, 0.50),
            (246, 72, 0.82, 18, 0.72),
            (196, 132, 0.48, 10, 0.44),
            (154, 54, 1.05, 22, 0.80),
            (112, 118, 0.68, 15, 0.60),
            (72, 38, 0.40, 9, 0.38),
            (42, 148, 0.92, 20, 0.76)
        ]
        for star in stars {
            let wrappedX = 18 + (star.x - spaceScroll * star.speed).truncatingRemainder(dividingBy: 302)
            let x = wrappedX < 18 ? wrappedX + 302 : wrappedX
            let y = star.y
            context.fill(
                Path(roundedRect: CGRect(x: (x - star.length) * scaleX, y: y * scaleY, width: star.length * scaleX, height: 1.6 * scaleY), cornerRadius: 1),
                with: .color(.white.opacity(star.opacity))
            )
        }
    }

    private func drawSkyDashObstacle(
        in context: inout GraphicsContext,
        rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
        point: (CGFloat, CGFloat) -> CGPoint
    ) {
        let color = skyDashObstacleColor
        switch obstacleKind {
        case 0:
            context.fill(Path(roundedRect: rect(obstacleX - 9, obstacleY - 19, 18, 38), cornerRadius: 3), with: .color(color))
            context.stroke(Path(roundedRect: rect(obstacleX - 9, obstacleY - 19, 18, 38), cornerRadius: 3), with: .color(.white.opacity(0.28)), lineWidth: 1)
        case 1:
            var diamond = Path()
            diamond.move(to: point(obstacleX, obstacleY - 22))
            diamond.addLine(to: point(obstacleX + 16, obstacleY))
            diamond.addLine(to: point(obstacleX, obstacleY + 22))
            diamond.addLine(to: point(obstacleX - 16, obstacleY))
            diamond.closeSubpath()
            context.fill(diamond, with: .color(color))
            context.stroke(diamond, with: .color(.white.opacity(0.25)), lineWidth: 1)
        case 2:
            context.fill(Path(roundedRect: rect(obstacleX - 12, obstacleY - 17, 24, 34), cornerRadius: 10), with: .color(color))
            context.fill(Path(ellipseIn: rect(obstacleX - 5, obstacleY - 5, 10, 10)), with: .color(.black.opacity(0.30)))
        case 3:
            context.fill(Path(roundedRect: rect(obstacleX - 6, obstacleY - 22, 12, 44), cornerRadius: 3), with: .color(color))
            context.fill(Path(roundedRect: rect(obstacleX - 18, obstacleY - 6, 36, 12), cornerRadius: 3), with: .color(color.opacity(0.88)))
        default:
            context.fill(Path(roundedRect: rect(obstacleX - 15, obstacleY - 20, 13, 18), cornerRadius: 3), with: .color(color))
            context.fill(Path(roundedRect: rect(obstacleX + 2, obstacleY + 2, 13, 18), cornerRadius: 3), with: .color(color.opacity(0.82)))
            context.stroke(Path(roundedRect: rect(obstacleX - 16, obstacleY - 21, 32, 42), cornerRadius: 5), with: .color(.white.opacity(0.18)), lineWidth: 1)
        }
    }

    private var skyDashObstacleColor: Color {
        switch obstacleKind {
        case 0:
            .orange
        case 1:
            .pink
        case 2:
            .mint
        case 3:
            .purple
        default:
            .yellow
        }
    }

    private func drawSkyDashCrash(
        in context: inout GraphicsContext,
        rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
        point: (CGFloat, CGFloat) -> CGPoint,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) {
        guard skyCrashTicks > 0 else {
            return
        }
        drawBurst(
            in: &context,
            rect: rect,
            point: point,
            centerX: skyCrashX,
            centerY: skyCrashY,
            remainingTicks: skyCrashTicks,
            totalTicks: 26,
            primaryColor: .red,
            secondaryColor: .orange,
            scaleX: scaleX,
            scaleY: scaleY
        )
    }

    private func drawSkyDashObstacleExplosion(
        in context: inout GraphicsContext,
        rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
        point: (CGFloat, CGFloat) -> CGPoint,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) {
        guard skyObstacleExplosionTicks > 0 else {
            return
        }
        let primary = skyDashColor(for: skyObstacleExplosionKind)
        drawBurst(
            in: &context,
            rect: rect,
            point: point,
            centerX: skyObstacleExplosionX,
            centerY: skyObstacleExplosionY,
            remainingTicks: skyObstacleExplosionTicks,
            totalTicks: 18,
            primaryColor: primary,
            secondaryColor: .white,
            scaleX: scaleX,
            scaleY: scaleY
        )
    }

    private func drawPacmanDeath(
        in context: inout GraphicsContext,
        rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
        point: (CGFloat, CGFloat) -> CGPoint,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) {
        guard pacmanDeathTicks > 0 else {
            return
        }
        drawBurst(
            in: &context,
            rect: rect,
            point: point,
            centerX: pacmanDeathX,
            centerY: pacmanDeathY,
            remainingTicks: pacmanDeathTicks,
            totalTicks: 34,
            primaryColor: .yellow,
            secondaryColor: .pink,
            scaleX: scaleX,
            scaleY: scaleY
        )
    }

    private func drawBurst(
        in context: inout GraphicsContext,
        rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
        point: (CGFloat, CGFloat) -> CGPoint,
        centerX: CGFloat,
        centerY: CGFloat,
        remainingTicks: Int,
        totalTicks: Int,
        primaryColor: Color,
        secondaryColor: Color,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) {
        let progress = CGFloat(totalTicks - remainingTicks) / CGFloat(totalTicks)
        let opacity = Double(max(0, 1 - progress))
        let radius = 10 + progress * 28
        context.stroke(
            Path(ellipseIn: rect(centerX - radius / 2, centerY - radius / 2, radius, radius)),
            with: .color(primaryColor.opacity(opacity)),
            lineWidth: 2
        )

        let sparks: [(CGFloat, CGFloat)] = [(1, 0), (-1, 0), (0, 1), (0, -1), (0.72, 0.72), (-0.72, 0.72), (0.72, -0.72), (-0.72, -0.72)]
        for spark in sparks {
            let distance = 6 + progress * 24
            let sparkCenter = point(centerX + spark.0 * distance, centerY + spark.1 * distance)
            context.fill(
                Path(ellipseIn: CGRect(x: sparkCenter.x - 2 * scaleX, y: sparkCenter.y - 2 * scaleY, width: 4 * scaleX, height: 4 * scaleY)),
                with: .color(secondaryColor.opacity(opacity))
            )
        }
    }

    private func skyDashColor(for kind: Int) -> Color {
        switch kind {
        case 0:
            .orange
        case 1:
            .pink
        case 2:
            .mint
        case 3:
            .purple
        default:
            .yellow
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

    private func drawPacmanEye(in context: inout GraphicsContext, at center: CGPoint, scaleX: CGFloat, scaleY: CGFloat) {
        let eyeOffsetX: CGFloat
        let eyeOffsetY: CGFloat
        if abs(pacmanDX) >= abs(pacmanDY) {
            eyeOffsetX = pacmanDX < 0 ? -2.6 : 2.6
            eyeOffsetY = -4.2
        } else {
            eyeOffsetX = pacmanDX < 0 ? -2.4 : 2.4
            eyeOffsetY = pacmanDY < 0 ? -3.2 : 3.2
        }
        let eyeSize = 2.4 * min(scaleX, scaleY)
        let eyeCenter = CGPoint(x: center.x + eyeOffsetX * scaleX, y: center.y + eyeOffsetY * scaleY)
        context.fill(
            Path(ellipseIn: CGRect(x: eyeCenter.x - eyeSize / 2, y: eyeCenter.y - eyeSize / 2, width: eyeSize, height: eyeSize)),
            with: .color(.black.opacity(0.82))
        )
    }

    private func drawGhost(in context: inout GraphicsContext, at center: CGPoint, scaleX: CGFloat, scaleY: CGFloat, isVulnerable: Bool, isBlinking: Bool) {
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
        let bodyColor: Color = if isVulnerable {
            isBlinking ? .white.opacity(0.94) : .blue.opacity(0.95)
        } else {
            .pink
        }
        context.fill(ghost, with: .color(bodyColor))

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
            setPacmanDirection(dx: -1, dy: 0)
        case (.pacman, .right):
            setPacmanDirection(dx: 1, dy: 0)
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
                DJConnectGameSounds.play(.fire)
                asteroidBulletActive = true
                asteroidBulletY = 120
            }
        case .fly:
            if !flyShotActive {
                DJConnectGameSounds.play(.fire)
                flyShotActive = true
                flyShotX = 58
            }
        case .pacman:
            break
        }
    }

    private func startGame() {
        DJConnectHaptics.selection()
        DJConnectGameSounds.play(.start)
        isPlaying = true
        isGameFocused = true
    }

    private func update() {
        switch game {
        case .pong:
            if paddleMissTicks > 0 {
                paddleMissTicks -= 1
                if paddleMissTicks == 0 {
                    resetPaddleBall()
                }
                return
            }
            if paddleHitTicks > 0 {
                paddleHitTicks -= 1
            }
            if ballWallBounceTicks > 0 {
                ballWallBounceTicks -= 1
            }
            ballX += ballVX
            ballY += ballVY
            if ballY <= 42 || ballY >= 156 {
                ballVY *= -1
                ballWallBounceTicks = 8
                DJConnectHaptics.selection()
                DJConnectGameSounds.play(.bounce)
            }
            if ballX >= 306 {
                ballVX = -abs(ballVX)
                ballWallBounceTicks = 8
                DJConnectHaptics.selection()
                DJConnectGameSounds.play(.bounce)
            }
            if ballX <= 30 {
                if ballY >= paddleY - 20 && ballY <= paddleY + 20 {
                    ballVX = abs(ballVX)
                    paddleHitTicks = 10
                    DJConnectHaptics.impact()
                    DJConnectGameSounds.play(.hit)
                    setScore(score + 1)
                } else {
                    flash()
                    DJConnectHaptics.error()
                    DJConnectGameSounds.play(.gameOver)
                    setScore(0)
                    paddleMissTicks = 24
                    ballVX = 0
                    ballVY = 0
                }
            }
        case .asteroids:
            if asteroidExplosionTicks > 0 {
                asteroidExplosionTicks -= 1
            }
            meteorStarPhase = (meteorStarPhase + 0.08).truncatingRemainder(dividingBy: CGFloat.pi * 2)
            asteroidY += asteroidSpeed + CGFloat(min(score / 8, 3)) * 0.18
            if asteroidBulletActive {
                asteroidBulletY -= 8
                if asteroidBulletY < 36 {
                    asteroidBulletActive = false
                } else if abs(asteroidX - shipX) < max(14, asteroidSize) && abs(asteroidY - asteroidBulletY) < max(14, asteroidSize) {
                    asteroidBulletActive = false
                    startMeteorExplosion()
                    DJConnectHaptics.success()
                    DJConnectGameSounds.play(.explosion)
                    setScore(score + 1)
                    resetAsteroid()
                }
            }
            if asteroidY > 150 {
                flash()
                DJConnectHaptics.warning()
                DJConnectGameSounds.play(.gameOver)
                setScore(0)
                resetAsteroid()
            }
        case .fly:
            if skyCrashTicks > 0 {
                skyCrashTicks -= 1
                if skyCrashTicks == 0 {
                    resetObstacle()
                }
                return
            }
            if skyObstacleExplosionTicks > 0 {
                skyObstacleExplosionTicks -= 1
            }
            spaceScroll = (spaceScroll + 4 + CGFloat(min(score / 8, 4))).truncatingRemainder(dividingBy: 302)
            obstacleX -= 4 + CGFloat(min(score / 6, 4))
            if flyShotActive {
                flyShotX += 9
                if flyShotX > 310 {
                    flyShotActive = false
                } else if abs(flyShotX - obstacleX) < 22 && abs(planeY - obstacleY) < 26 {
                    flyShotActive = false
                    startSkyObstacleExplosion()
                    DJConnectHaptics.success()
                    DJConnectGameSounds.play(.explosion)
                    setScore(score + 1)
                    resetObstacle()
                }
            }
            if obstacleX < 24 {
                setScore(score + 1)
                resetObstacle()
            }
            if obstacleX < 70 && obstacleX > 28 && abs(planeY - obstacleY) < 30 {
                flash()
                startSkyCrash()
                DJConnectHaptics.error()
                DJConnectGameSounds.play(.crash)
                setScore(0)
            }
        case .pacman:
            if pacmanDeathTicks > 0 {
                pacmanDeathTicks -= 1
                if pacmanDeathTicks == 0 {
                    resetPacman()
                }
                return
            }
            pacmanX = min(max(pacmanX + pacmanDX * 4, 28), 292)
            pacmanY = min(max(pacmanY + pacmanDY * 4, 44), 140)
            if ghostVulnerableTicks > 0 {
                ghostVulnerableTicks -= 1
            }
            let ghostStep: CGFloat = (isGhostVulnerable ? 0.62 : 0.88) + CGFloat(min(score / 12, 3)) * 0.20
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
                    if pacmanPowerPellets.contains(pellet) {
                        DJConnectHaptics.success()
                        DJConnectGameSounds.play(.power)
                        ghostVulnerableTicks = pacmanPowerTicks
                    } else {
                        DJConnectHaptics.selection()
                        DJConnectGameSounds.play(.collect)
                    }
                    break
                }
            }
            if pellets.isEmpty {
                pellets = Set(0..<32)
                ghostX = 250
                ghostY = 86
                ghostVulnerableTicks = 0
            }
            if abs(ghostX - pacmanX) < 14 && abs(ghostY - pacmanY) < 14 {
                if isGhostVulnerable {
                    flash()
                    DJConnectHaptics.success()
                    DJConnectGameSounds.play(.explosion)
                    setScore(score + 5)
                    ghostX = 250
                    ghostY = 86
                    ghostVulnerableTicks = max(ghostVulnerableTicks - 60, 0)
                } else {
                    flash()
                    startPacmanDeath()
                    DJConnectHaptics.error()
                    DJConnectGameSounds.play(.gameOver)
                    setScore(0)
                }
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
        paddleHitTicks = 0
        ballWallBounceTicks = 0
        paddleMissTicks = 0
        shipX = 160
        asteroidBulletActive = false
        asteroidExplosionTicks = 0
        meteorStarPhase = 0
        planeY = 86
        spaceScroll = 0
        skyCrashTicks = 0
        skyObstacleExplosionTicks = 0
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
        ghostVulnerableTicks = 0
        pacmanDeathTicks = 0
        pellets = Set(0..<32)
    }

    private func resetPaddleBall() {
        ballX = 160
        ballY = 86
        ballVX = 3
        ballVY = Bool.random() ? 2 : -2
        paddleHitTicks = 0
        ballWallBounceTicks = 0
    }

    private func setPacmanDirection(dx: CGFloat, dy: CGFloat) {
        if !isPlaying {
            startGame()
        }
        pacmanDX = dx
        pacmanDY = dy
    }

    private func resetAsteroid() {
        asteroidX = CGFloat.random(in: 40...280)
        asteroidY = 42
        asteroidKind = Int.random(in: 0...3)
        asteroidSize = CGFloat.random(in: 10...18)
        asteroidSpeed = CGFloat.random(in: 1.05...1.85)
    }

    private func startMeteorExplosion() {
        asteroidExplosionX = asteroidX
        asteroidExplosionY = asteroidY
        asteroidExplosionTicks = 18
    }

    private func startSkyCrash() {
        skyCrashX = 54
        skyCrashY = planeY
        skyCrashTicks = 26
        flyShotActive = false
    }

    private func startSkyObstacleExplosion() {
        skyObstacleExplosionX = obstacleX
        skyObstacleExplosionY = obstacleY
        skyObstacleExplosionKind = obstacleKind
        skyObstacleExplosionTicks = 18
    }

    private func resetObstacle() {
        obstacleX = 310
        obstacleY = CGFloat.random(in: 52...138)
        obstacleKind = Int.random(in: 0...4)
    }

    private func startPacmanDeath() {
        pacmanDeathX = pacmanX
        pacmanDeathY = pacmanY
        pacmanDeathTicks = 34
        pacmanDX = 0
        pacmanDY = 0
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

public struct DJConnectAboutView: View {
    @ObservedObject private var model: DJConnectAppModel

    public init(model: DJConnectAppModel) {
        self.model = model
    }

    public var body: some View {
        AboutView(model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DJConnectCanvasBackground())
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
                        title: localized(model.language, "Playlists", "Afspeellijsten"),
                        systemImage: "rectangle.stack"
                    ) {
                        PlaylistsView(model: model)
                    }
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
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.07, blue: 0.14).opacity(0.98),
                            Color(red: 0.20, green: 0.09, blue: 0.32).opacity(0.96),
                            Color(red: 0.10, green: 0.14, blue: 0.28).opacity(0.90)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
                .padding(.horizontal, djConnectScreenHorizontalPadding)
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
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.leading, 62)
            }
        }
        .buttonStyle(.plain)
        .tint(djConnectAccent)
    }
}

struct SettingsView: View {
    @ObservedObject var model: DJConnectAppModel
    var returnToNowPlaying: () -> Void = {}
    @Environment(\.openURL) private var openURL
    @State private var isShowingResetPairingConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section(localized(model.language, "App", "App")) {
                    if model.isDemoMode {
                        LabeledContent(localized(model.language, "Demo Mode", "Demo modus")) {
                            Button(localized(model.language, "Stop Demo Mode", "Demo modus stoppen"), role: .destructive) {
                                returnToNowPlaying()
                                model.stopDemoMode()
                            }
                        }
                    }
                    if !model.isDemoMode {
                        LabeledContent(localized(model.language, "Pairing", "Koppeling")) {
                            Button(role: .destructive) {
                                isShowingResetPairingConfirmation = true
                            } label: {
                                Text(localized(model.language, "Pair App Again", "App opnieuw koppelen"))
                            }
                        }
                    }
                    LabeledContent(localized(model.language, "Wakeword", "Stemactivatie")) {
                        if model.wakeWordEnabled {
                            Button {
                                model.setWakeWordEnabled(false)
                            } label: {
                                Text(localized(model.language, "Disable Voice Activation", "Stemactivatie uitschakelen"))
                                    .foregroundStyle(djConnectAccent)
                            }
                            .foregroundStyle(djConnectAccent)
                            .tint(djConnectAccent)
                        } else {
                            Button {
                                model.setWakeWordEnabled(true)
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
                    Picker(localized(model.language, "Log Level", "Logniveau"), selection: $model.logLevel) {
                        Text("Debug").tag("debug")
                        Text("Info").tag("info")
                        Text(localized(model.language, "Warning", "Waarschuwing")).tag("warning")
                        Text(localized(model.language, "Error", "Fout")).tag("error")
                    }
                }
                .djSettingsListRowBackground()

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
                    PermissionStatusRow(
                        title: localized(model.language, "Notifications", "Meldingen"),
                        detail: localized(
                            model.language,
                            "Needed for server push notifications when Ask DJ answers.",
                            "Nodig voor server-pushmeldingen wanneer Ask DJ antwoordt."
                        ),
                        status: model.notificationPermissionStatus,
                        language: model.language
                    )
                    if model.microphonePermissionStatus != .granted
                        || model.speechPermissionStatus != .granted
                        || model.notificationPermissionStatus != .granted {
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
                }
                .djSettingsListRowBackground()

            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.plain)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .contentMargins(.vertical, 0, for: .scrollContent)
            #endif
            .scrollContentBackgroundIfAvailable(.hidden)
            .background(.clear)
            .navigationTitle(localized(model.language, "Settings", "Instellingen"))
            .alert(
                localized(model.language, "Pair App Again?", "App opnieuw koppelen?"),
                isPresented: $isShowingResetPairingConfirmation
            ) {
                Button(localized(model.language, "Cancel", "Annuleer"), role: .cancel) {}
                Button(localized(model.language, "Pair App Again", "App opnieuw koppelen"), role: .destructive) {
                    returnToNowPlaying()
                    model.resetPairing()
                }
            } message: {
                Text(localized(
                    model.language,
                    "This clears the local DJConnect pairing and opens pairing setup again.",
                    "Dit wist de lokale DJConnect-koppeling en opent het koppelscherm opnieuw."
                ))
            }
            .task {
                model.refreshPermissionStatuses()
                model.startPairingWait()
            }
            #if os(macOS)
            .djConnectMacDetailContent()
            #endif
        }
        .background(DJConnectCanvasBackground())
    }

}

private struct LogsView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var showingClearConfirmation = false
    @State private var statusToast: String?
    @State private var showsCompactTitle = false
    @State private var isSearchVisible = false
    @State private var logSearchText = ""
    @State private var selectedSearchResultIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var logSearchResultIDs: [UUID] {
        let query = logSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }
        return model.diagnosticLogLines.compactMap { line in
            line.text.localizedCaseInsensitiveContains(query) ? line.id : nil
        }
    }

    private var activeLogSearchResultID: UUID? {
        guard logSearchResultIDs.indices.contains(selectedSearchResultIndex) else {
            return nil
        }
        return logSearchResultIDs[selectedSearchResultIndex]
    }

    private var logSearchButtonTitle: String {
        isSearchVisible
            ? localized(model.language, "Close search", "Zoeken sluiten")
            : localized(model.language, "Search Logs", "Logs zoeken")
    }

    private var selectableLogText: String {
        let digits = logLineNumberDigits(total: model.diagnosticLogLines.count)
        return model.diagnosticLogLines.enumerated().map { index, line in
            let rawNumber = String(index + 1)
            let number = String(repeating: " ", count: max(0, digits - rawNumber.count)) + rawNumber
            return "\(number)  \(line.text)"
        }.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button {
                        copyText(model.diagnosticExportText())
                        showStatusToast(localized(model.language, "Logs copied to clipboard", "Logs gekopieerd naar klembord"))
                    } label: {
                        Label(localized(model.language, "Copy Logs", "Logs kopiëren"), systemImage: "doc.on.doc")
                            .foregroundStyle(djConnectAccent)
                    }
                    .tint(djConnectAccent)
                    .foregroundStyle(djConnectAccent)
                    .disabled(model.diagnosticLogLines.isEmpty)

                    Spacer()

                    Button {
                        toggleLogSearch()
                    } label: {
                        Label(logSearchButtonTitle, systemImage: "magnifyingglass")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(djConnectAccent)
                    }
                    .tint(djConnectAccent)
                    .foregroundStyle(djConnectAccent)
                    .help(logSearchButtonTitle)
                    .accessibilityLabel(logSearchButtonTitle)
                    .disabled(model.diagnosticLogLines.isEmpty)

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
                        VStack(alignment: .leading, spacing: 10) {
                            if isSearchVisible {
                                AskDJSearchBar(
                                    language: model.language,
                                    scopeName: localized(model.language, "logs", "logs"),
                                    text: $logSearchText,
                                    isFocused: $isSearchFocused,
                                    resultCount: logSearchResultIDs.count,
                                    selectedIndex: selectedSearchResultIndex,
                                    previousAction: { moveLogSearchSelection(by: -1, proxy: proxy) },
                                    nextAction: { moveLogSearchSelection(by: 1, proxy: proxy) },
                                    closeAction: { dismissLogSearch() }
                                )
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            ScrollView {
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geometry.frame(in: .named("LogsScrollView")).minY
                                    )
                                }
                                .frame(height: 0)
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(model.diagnosticLogLines) { line in
                                        Color.clear
                                            .frame(height: 0)
                                            .id(line.id)
                                    }
                                    LogSearchText(
                                        text: selectableLogText,
                                        highlight: logSearchText,
                                        isSearchResult: !logSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    )
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.88))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                            }
                            .coordinateSpace(name: "LogsScrollView")
                            .scrollIndicators(.visible)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onAppear {
                                scrollLogsToBottom(proxy)
                            }
                            .onChange(of: model.diagnosticLogLines.last?.id) {
                                if logSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    scrollLogsToBottom(proxy)
                                }
                            }
                            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                                showsCompactTitle = offset < -36
                            }
                        }
                        .onChange(of: logSearchText) {
                            selectedSearchResultIndex = 0
                            scrollToActiveLogSearchResult(proxy)
                        }
                        .onChange(of: logSearchResultIDs) {
                            selectedSearchResultIndex = min(selectedSearchResultIndex, max(logSearchResultIDs.count - 1, 0))
                            scrollToActiveLogSearchResult(proxy)
                        }
                    }
                }
            }
            .padding(.top, 12)
            .background(DJConnectCanvasBackground())
            .navigationTitle(localized(model.language, "Logs", "Logs"))
            #if os(macOS)
            .djConnectMacDetailContent()
            #endif
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    #if os(iOS)
                    if showsCompactTitle {
                        Text(localized(model.language, "Logs", "Logs"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.top, 2)
                            .frame(maxWidth: .infinity)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                    #endif

                    if let statusToast {
                        StatusToast(text: statusToast, systemImage: "doc.on.doc.fill")
                            .padding(.top, 34)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
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
            .background {
                Button("") {
                    showLogSearch()
                }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()

                Button("") {
                    showLogSearch()
                }
                .keyboardShortcut("f", modifiers: .control)
                .hidden()
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

    private func showLogSearch() {
        guard !model.diagnosticLogLines.isEmpty else {
            return
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isSearchVisible = true
        }
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func toggleLogSearch() {
        if isSearchVisible {
            dismissLogSearch()
        } else {
            showLogSearch()
        }
    }

    private func dismissLogSearch() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isSearchVisible = false
        }
        logSearchText = ""
        selectedSearchResultIndex = 0
        isSearchFocused = false
    }

    private func moveLogSearchSelection(by offset: Int, proxy: ScrollViewProxy) {
        guard !logSearchResultIDs.isEmpty else {
            return
        }
        selectedSearchResultIndex = (selectedSearchResultIndex + offset + logSearchResultIDs.count) % logSearchResultIDs.count
        scrollToActiveLogSearchResult(proxy)
    }

    private func scrollToActiveLogSearchResult(_ proxy: ScrollViewProxy) {
        guard let activeLogSearchResultID else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(activeLogSearchResultID, anchor: .center)
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

    private func logLineNumber(_ number: Int, total: Int) -> String {
        String(format: "%0\(logLineNumberDigits(total: total))d", number)
    }

    private func logLineNumberDigits(total: Int) -> Int {
        max(3, String(max(total, 1)).count)
    }

    private func logLineNumberWidth(total: Int) -> CGFloat {
        CGFloat(logLineNumberDigits(total: total)) * 8
    }
}

private struct LogSearchText: View {
    let text: String
    let highlight: String
    let isSearchResult: Bool

    var body: some View {
        Text(highlightedText)
            .foregroundStyle(isSearchResult ? Color.white : Color.white.opacity(0.88))
    }

    private var highlightedText: AttributedString {
        let query = highlight.trimmingCharacters(in: .whitespacesAndNewlines)
        var attributed = AttributedString(text)
        guard !query.isEmpty else {
            return attributed
        }

        var searchRange = attributed.startIndex..<attributed.endIndex
        while let matchRange = attributed[searchRange].range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) {
            attributed[matchRange].backgroundColor = Color.yellow.opacity(0.34)
            attributed[matchRange].foregroundColor = Color.white
            searchRange = matchRange.upperBound..<attributed.endIndex
        }
        return attributed
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
                            Text("https://djconnect.dev")
                                .font(.body)
                                .foregroundStyle(djConnectAccent)
                                .foregroundColor(djConnectAccent)
                                .textSelection(.enabled)
                        }
                        .djConnectLilacButton()
                    }
                    AboutStackedRow(label: localized(model.language, "Device ID", "Device ID")) {
                        SelectableValue(model.identity.deviceID)
                    }
                }

                SettingsSection(title: localized(model.language, "Connection", "Verbinding")) {
                    AboutStackedRow(label: localized(model.language, "Home Assistant address", "Home Assistant adres")) {
                        SelectableValue(model.homeAssistantURL)
                    }
                    AboutStackedRow(label: localized(model.language, "Music", "Muziek")) {
                        SelectableValue(
                            model.backendAvailable
                                ? localized(model.language, "Available", "Beschikbaar")
                                : localized(model.language, "Unavailable", "Niet beschikbaar"),
                            foregroundStyle: model.backendAvailable ? .green : .red
                        )
                    }
                }

                SettingsSection(title: localized(model.language, "Notices", "Notices")) {
                    AboutStackedRow(label: "Copyright") {
                        SelectableValue("2026 Peter van Tol")
                    }
                }
            }
            #if os(macOS)
            .djConnectMacDetailContent(maxWidth: .infinity, alignment: .topLeading)
            #else
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            #endif
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
                    AboutBanner()

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
                #if os(macOS)
                .djConnectMacDetailContent(maxWidth: .infinity, alignment: .topLeading)
                #else
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
                #endif
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
                        "Device tokens are stored locally in the app's private storage. Diagnostics are only shared when you copy them or open a GitHub issue yourself.",
                        "Device-tokens worden lokaal in de private app-opslag bewaard. Diagnostiek wordt alleen gedeeld wanneer je die zelf kopieert of een GitHub issue opent."
                    ))
                    SelectableValue(localized(
                        language,
                        "Push notifications are only used for DJConnect notifications, such as Ask DJ responses. DJConnect stores an Apple push token locally and shares it with your own Home Assistant DJConnect integration so notifications can be delivered through Apple Push Notification service. Push tokens are not used for tracking, advertising, or sale.",
                        "Pushnotificaties worden alleen gebruikt voor DJConnect-meldingen, zoals Ask DJ-reacties. DJConnect bewaart hiervoor een Apple push-token lokaal en deelt dit met je eigen Home Assistant DJConnect-integratie zodat notificaties via Apple Push Notification service kunnen worden bezorgd. Push-tokens worden niet gebruikt voor tracking, advertenties of verkoop."
                    ))
                    SelectableValue(localized(
                        language,
                        "Music, playback, and voice requests are handled through your own Home Assistant DJConnect integration.",
                        "Muziek, playback en stemverzoeken lopen via je eigen Home Assistant DJConnect-integratie."
                    ))
                    SelectableValue(localized(
                        language,
                        "AI and Assist answers can be incorrect and depend on your own Home Assistant and Assist configuration.",
                        "AI- en Assist-antwoorden kunnen onjuist zijn en hangen af van je eigen Home Assistant- en Assist-configuratie."
                    ))
                }
            }
            #if os(macOS)
            .djConnectMacDetailContent(maxWidth: .infinity, alignment: .topLeading)
            #else
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            #endif
        }
        .navigationTitle(localized(language, "Privacy", "Privacy"))
        .background(DJConnectCanvasBackground())
    }
}

private struct AskDJFeedbackPromptView: View {
    @ObservedObject var model: DJConnectAppModel
    let message: DJConnectAskDJMessage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var userNote = ""
    @State private var issueBody = ""

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AboutBanner()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized(model.language, "Report Ask DJ answer", "Ask DJ antwoord melden"))
                            .font(.title.bold())
                        Text(localized(
                            model.language,
                            "Create a GitHub issue draft with redacted Ask DJ context. Nothing is sent automatically.",
                            "Maak een GitHub issue-concept met geredigeerde Ask DJ-context. Er wordt niets automatisch verstuurd."
                        ))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized(model.language, "What was wrong or missing?", "Wat klopte er niet of wat miste er?"))
                            .font(.headline)
                        TextEditor(text: $userNote)
                            .font(.body)
                            .frame(minHeight: 96)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(localized(model.language, "GitHub draft context", "GitHub conceptcontext"))
                                .font(.headline)
                            Spacer()
                            Button {
                                refreshIssueBody()
                            } label: {
                                Label(localized(model.language, "Update", "Bijwerken"), systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .help(localized(model.language, "Update draft context", "Werk conceptcontext bij"))
                        }
                        Text(localized(
                            model.language,
                            "Review this text before opening GitHub. Remove anything you do not want to share.",
                            "Controleer deze tekst voordat GitHub opent. Verwijder alles wat je niet wilt delen."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        TextEditor(text: $issueBody)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 260)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                    }

                    HStack(spacing: 12) {
                        Button {
                            if let url = model.askDJFeedbackIssueURL(for: message, body: issueBody) {
                                openURL(url)
                            }
                            dismiss()
                        } label: {
                            Label(localized(model.language, "Open GitHub Draft", "Open GitHub concept"), systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DJConnectLilacPillButtonStyle())
                        .controlSize(.large)

                        Button {
                            dismiss()
                        } label: {
                            Text(localized(model.language, "Cancel", "Annuleren"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DJConnectLilacPillButtonStyle())
                        .controlSize(.large)
                    }
                }
                .padding(28)
                .frame(minWidth: 360, idealWidth: 960, maxWidth: 1_080)
            }
        }
        .frame(minWidth: 760, idealWidth: 1_020, maxWidth: 1_160)
        .onAppear {
            refreshIssueBody()
        }
    }

    private func refreshIssueBody() {
        issueBody = model.askDJFeedbackIssueBody(for: message, userNote: userNote)
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)

                    Button {
                        dismiss()
                    } label: {
                        Text(localized(model.language, "Not Now", "Niet nu"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
        }
    }
}

private struct AboutBanner: View {
    private var language: String {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("nl") == true ? "nl" : "en"
    }

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
                Text(localized(language, "Music control with character", "Muziekbediening met karakter"))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.12),
                    Color(red: 0.25, green: 0.08, blue: 0.42),
                    Color(red: 0.39, green: 0.12, blue: 0.62),
                    Color(red: 0.08, green: 0.10, blue: 0.23)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.34),
                            .clear,
                            .black.opacity(0.30)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blendMode(.multiply)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.multiply)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
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
    var foregroundStyle: Color = .primary

    init(_ text: String, alignment: Alignment = .leading, foregroundStyle: Color = .primary) {
        self.text = text
        self.alignment = alignment
        self.foregroundStyle = foregroundStyle
    }

    var body: some View {
        Text(text)
            .textSelection(.enabled)
            .lineLimit(nil)
            .foregroundStyle(foregroundStyle)
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
    var showsIcon = true

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
                if showsIcon {
                    Image(systemName: "doc.on.doc")
                } else {
                    Text(copyLabel)
                        .font(.caption.weight(.semibold))
                }
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
        if model.wakeWordEnabled {
            if model.pairingStatus != .paired || !model.isConnected {
                return localized(model.language, "Waiting for Home Assistant", "Wachten op Home Assistant")
            }
            if !model.backendAvailable {
                return localized(model.language, "Playback backend unavailable", "Playback backend niet beschikbaar")
            }
            if !model.voiceEnabled {
                return localized(model.language, "Voice requests unavailable", "Stemverzoeken niet beschikbaar")
            }
        }
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
