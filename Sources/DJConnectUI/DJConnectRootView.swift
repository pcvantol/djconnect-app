import DJConnectCore
import Combine
import SwiftUI

#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import UniformTypeIdentifiers
#endif
#if canImport(AVKit)
@preconcurrency import AVKit
#endif
#if canImport(WebKit)
import WebKit
#endif
#if canImport(MetalKit)
import MetalKit
#endif
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import Darwin
#endif

private func localizedKey(_ language: String, _ key: String, arguments: CVarArg...) -> String {
    String(
        format: DJConnectLocalization.localized(key: key, language: language),
        locale: Locale(identifier: DJConnectLocalization.supportedLanguageCode(language)),
        arguments: arguments
    )
}

private func localizedOutputName(_ outputName: String, language: String) -> String {
    switch outputName {
    case "Not selected", "No output selected":
        localizedKey(language, "ui.no.output.device.selected")
    default:
        outputName
    }
}

private func screenTitle(_ language: String, key: String, isDemoMode: Bool) -> String {
    let title = localizedKey(language, key)
    guard isDemoMode, title != localizedKey(language, "ui.more") else {
        return title
    }
    return "\(title) (demo)"
}

private func askDJTimestamp(_ date: Date, language: String, now: Date = Date()) -> String {
    let elapsed = max(0, now.timeIntervalSince(date))
    if elapsed < 3_600 {
        let minutes = max(1, Int(elapsed / 60))
        return localizedKey(language, "ui.value.min.ago", arguments: minutes)
    }
    if Calendar.current.isDate(date, inSameDayAs: now) {
        return date.formatted(date: .omitted, time: .shortened)
    }
    let days = max(1, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 1)
    switch days {
    case 1:
        return localizedKey(language, "ui.yesterday")
    case 2...6:
        return localizedKey(language, "ui.value.days.ago", arguments: days)
    case 7...13:
        return localizedKey(language, "ui.last.week")
    case 14...30:
        let weeks = max(2, days / 7)
        return localizedKey(language, "ui.value.weeks.ago", arguments: weeks)
    case 31...61:
        return localizedKey(language, "ui.last.month")
    default:
        let months = max(2, days / 30)
        return localizedKey(language, "ui.value.months.ago", arguments: months)
    }
}

private func localizedPairingStatus(_ status: DJConnectPairingStatus, language: String) -> String {
    switch status {
    case .paired:
        localizedKey(language, "ui.paired")
    case .pairing:
        localizedKey(language, "ui.pairing")
    case .waitingForHomeAssistantCompletion:
        localizedKey(language, "ui.waiting.for.home.assistant")
    case .stale:
        localizedKey(language, "ui.stale")
    case .unpaired:
        localizedKey(language, "ui.unpaired")
    }
}

let djConnectAccent = Color(red: 0.84, green: 0.22, blue: 0.96)
private let djConnectButtonBlue = Color(red: 0.16, green: 0.56, blue: 1.0)
private let djConnectButtonPurple = Color(red: 0.84, green: 0.18, blue: 1.0)
private let djConnectScreenHorizontalPadding: CGFloat = 16
private let djConnectScreenVerticalPadding: CGFloat = 12
private let djConnectContentMaxWidth: CGFloat = 760
private let djConnectCompactContentMaxWidth: CGFloat = 640
private let djConnectMacDetailHorizontalPadding: CGFloat = djConnectScreenHorizontalPadding
private let djConnectMacDetailVerticalPadding: CGFloat = djConnectScreenVerticalPadding

private enum DJConnectRootSheet: String, Identifiable {
    case updateRequired
    case pairing
    case welcome
    case crashReportPrompt
    case whatsNew
    case wakeWordActivationPrompt
    case feedback
    case permissionExplanation

    var id: String { rawValue }
}

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

    @ViewBuilder
    func djSettingsSectionTopSpacing() -> some View {
        #if os(macOS)
        self.padding(.top, 18)
        #else
        self
        #endif
    }

    @ViewBuilder
    func djCompactSettingsListRow() -> some View {
        #if os(macOS)
        self.listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        #else
        self
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

struct DJConnectCanvasBackground: View {
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
    case trackInsight
    case musicDNA
    case askDJ
    case queue
    case more
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
                            title: localizedKey(model.language, "ui.now.playing"),
                            systemImage: "music.note",
                            isSelected: selectedSection == .nowPlaying
                        ) { selectedSection = .nowPlaying }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.queue"),
                            systemImage: "music.note.list",
                            isSelected: selectedSection == .queue
                        ) { selectedSection = .queue }
                        SidebarItem(
                            title: "Ask DJ",
                            systemImage: "bubble.left.and.bubble.right",
                            isSelected: selectedSection == .askDJ
                        ) { selectedSection = .askDJ }
                        SidebarItem(
                            title: "Track Insight",
                            systemImage: "waveform.path.ecg",
                            isSelected: selectedSection == .trackInsight
                        ) { selectedSection = .trackInsight }
                        SidebarItem(
                            title: "Music DNA",
                            systemImage: "heart",
                            isSelected: selectedSection == .musicDNA
                        ) { selectedSection = .musicDNA }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.playlists"),
                            systemImage: "rectangle.stack",
                            isSelected: selectedSection == .playlists
                        ) { selectedSection = .playlists }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.games"),
                            systemImage: "gamecontroller",
                            isSelected: selectedSection == .games
                        ) { selectedSection = .games }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.settings"),
                            systemImage: "gearshape",
                            isSelected: selectedSection == .settings
                        ) { selectedSection = .settings }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.logs"),
                            systemImage: "doc.text.magnifyingglass",
                            isSelected: selectedSection == .logs
                        ) { selectedSection = .logs }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.about"),
                            systemImage: "info.circle",
                            isSelected: selectedSection == .about
                        ) { selectedSection = .about }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.legal"),
                            systemImage: "doc.text",
                            isSelected: selectedSection == .legal
                        ) { selectedSection = .legal }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.privacy"),
                            systemImage: "hand.raised",
                            isSelected: selectedSection == .privacy
                        ) { selectedSection = .privacy }
                        Button {
                            showingFeedback = true
                        } label: {
                            Label(localizedKey(model.language, "ui.share.feedback"), systemImage: "bubble.left.and.bubble.right")
                        }
                        .buttonStyle(.plain)
                    }
                    .navigationTitle(screenTitle(model.language, key: "ui.djconnect", isDemoMode: model.isDemoMode))
                    .scrollContentBackgroundIfAvailable(.hidden)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
                } detail: {
                    selectedView
                }
                .tint(Color(red: 0.74, green: 0.22, blue: 0.96))
                .accentColor(Color(red: 0.74, green: 0.22, blue: 0.96))
                #else
                if horizontalSizeClass == .regular {
                    iPadRootTabs
                } else {
                    TabView(selection: $selectedSection) {
                        NowPlayingView(model: model)
                            .tabItem {
                                Label(localizedKey(model.language, "ui.now.playing"), systemImage: "music.note")
                            }
                            .tag(DJConnectSection.nowPlaying)
                        QueueView(model: model)
                            .tabItem {
                                Label(localizedKey(model.language, "ui.queue"), systemImage: "music.note.list")
                            }
                            .tag(DJConnectSection.queue)
                        AskDJView(model: model)
                            .tabItem {
                                Label {
                                    Text("Ask DJ")
                                } icon: {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .symbolVariant(.none)
                                }
                            }
                            .tag(DJConnectSection.askDJ)
                        TrackInsightView(model: model)
                            .tabItem {
                                Label("Track Insight", systemImage: "waveform.path.ecg")
                            }
                            .tag(DJConnectSection.trackInsight)
                        MoreView(model: model) {
                            selectedSection = .nowPlaying
                        }
                        .id(moreResetID)
                            .tabItem {
                                Label(localizedKey(model.language, "ui.more"), systemImage: "ellipsis")
                            }
                            .tag(DJConnectSection.settings)
                    }
                    .tint(djConnectAccent)
                    .accentColor(djConnectAccent)
                }
                #endif
            }
            #if os(iOS)
            .background(.clear)
            #endif
        }
        .sheet(item: rootSheetBinding) { sheet in
            rootSheetView(sheet)
        }
        .onChange(of: model.shouldShowPairingScreen) {
            if model.shouldShowPairingScreen {
                selectedSection = .nowPlaying
            }
        }
        .onOpenURL { url in
            if !model.handleAppNavigationDeepLink(url) {
                model.handlePairingDeepLink(url)
            }
        }
        .onChange(of: model.trackInsightNavigationRequestID) {
            selectedSection = .trackInsight
        }
        .onChange(of: model.homeScreenActionRequest) {
            guard let request = model.homeScreenActionRequest else {
                return
            }
            switch request.action {
            case .nowPlaying:
                selectedSection = .nowPlaying
            case .queue:
                selectedSection = .queue
            case .askDJ:
                selectedSection = .askDJ
            case .trackInsight:
                selectedSection = .trackInsight
            case .playlists:
                selectedSection = .playlists
            }
            model.clearHomeScreenActionRequest(request)
        }
        .onChange(of: selectedSection) {
            #if os(iOS)
            if horizontalSizeClass != .regular, selectedSection == .settings {
                moreResetID = UUID()
            }
            #endif
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                model.refreshPermissionStatuses(retryWakeWord: false)
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
    }

    #if os(iOS)
    private var iPadRootTabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                DJConnectTopTabButton(
                    title: localizedKey(model.language, "ui.now.playing"),
                    systemImage: "music.note",
                    isSelected: selectedSection == .nowPlaying
                ) { selectedSection = .nowPlaying }
                DJConnectTopTabButton(
                    title: localizedKey(model.language, "ui.queue"),
                    systemImage: "music.note.list",
                    isSelected: selectedSection == .queue
                ) { selectedSection = .queue }
                DJConnectTopTabButton(
                    title: "Ask DJ",
                    systemImage: "bubble.left.and.bubble.right",
                    symbolVariant: .none,
                    isSelected: selectedSection == .askDJ
                ) { selectedSection = .askDJ }
                DJConnectTopTabButton(
                    title: "Track Insight",
                    systemImage: "waveform.path.ecg",
                    isSelected: selectedSection == .trackInsight
                ) { selectedSection = .trackInsight }
                DJConnectTopTabButton(
                    title: localizedKey(model.language, "ui.more"),
                    systemImage: "ellipsis",
                    isSelected: isMoreSectionSelected
                ) { selectedSection = .more }
            }
            .padding(6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
            )
            .padding(.top, 18)
            .padding(.bottom, 10)

            selectedView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var isMoreSectionSelected: Bool {
        switch selectedSection {
        case .nowPlaying, .queue, .askDJ, .trackInsight:
            false
        case .more, .musicDNA, .playlists, .games, .settings, .logs, .about, .legal, .privacy:
            true
        }
    }
    #endif

    private var rootSheetBinding: Binding<DJConnectRootSheet?> {
        Binding(
            get: { activeRootSheet },
            set: { newValue in
                if newValue == nil, let activeRootSheet {
                    dismiss(rootSheet: activeRootSheet)
                }
            }
        )
    }

    private var activeRootSheet: DJConnectRootSheet? {
        if model.updateRequiredMessage != nil {
            return .updateRequired
        }
        if model.shouldShowPairingScreen {
            return .pairing
        }
        if model.isShowingWelcome {
            return .welcome
        }
        if model.isShowingCrashReportPrompt {
            return .crashReportPrompt
        }
        if model.isShowingWhatsNew {
            return .whatsNew
        }
        if model.isShowingWakeWordActivationPrompt {
            return .wakeWordActivationPrompt
        }
        if showingFeedback {
            return .feedback
        }
        if model.isShowingPermissionExplanation {
            return .permissionExplanation
        }
        return nil
    }

    @ViewBuilder
    private func rootSheetView(_ sheet: DJConnectRootSheet) -> some View {
        switch sheet {
        case .updateRequired:
            UpdateRequiredView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
                .interactiveDismissDisabled(true)
        case .pairing:
            PairingSheetView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
                .interactiveDismissDisabled(true)
                #if os(iOS)
                .presentationDetents([.large])
                .presentationSizing(.page)
                #endif
                .presentationBackground {
                    DJConnectCanvasBackground()
                }
        case .welcome:
            WelcomeView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
                #if os(iOS)
                .presentationDetents([.large])
                .presentationSizing(.page)
                #endif
                .presentationBackground {
                    DJConnectCanvasBackground()
                }
        case .crashReportPrompt:
            CrashReportPromptView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        case .whatsNew:
            WhatsNewView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        case .wakeWordActivationPrompt:
            WakeWordActivationPromptView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        case .feedback:
            FeedbackPromptView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
        case .permissionExplanation:
            PermissionExplanationView(model: model)
        }
    }

    private func dismiss(rootSheet sheet: DJConnectRootSheet) {
        switch sheet {
        case .updateRequired:
            break
        case .pairing:
            model.completePairingScreen()
        case .welcome:
            model.dismissWelcome()
        case .crashReportPrompt:
            model.dismissCrashReportPrompt()
        case .whatsNew:
            model.dismissWhatsNew()
        case .wakeWordActivationPrompt:
            model.dismissWakeWordActivationPrompt()
        case .feedback:
            showingFeedback = false
        case .permissionExplanation:
            model.cancelPermissionExplanation()
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedSection {
        case .nowPlaying:
            NowPlayingView(model: model)
        case .trackInsight:
            TrackInsightView(model: model)
        case .musicDNA:
            MusicDNAView(model: model)
        case .askDJ:
            AskDJView(model: model)
        case .queue:
            QueueView(model: model)
        case .more:
            MoreView(model: model) {
                selectedSection = .nowPlaying
            }
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
            VStack(alignment: .leading, spacing: 22) {
                AboutBanner()

                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text(localizedKey(model.language, "ui.app.permissions"))
                            .font(.title.bold())
                    } icon: {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [djConnectAccent, Color(red: 0.12, green: 0.55, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .labelStyle(.titleAndIcon)
                    Text(localizedKey(model.language, "ui.djconnect.asks.for.microphone.access.for.voice.requests.and.notifications"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(localizedKey(model.language, "ui.server.push.notifications.use.apple.apns.and.contain.only.a"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(localizedKey(model.language, "ui.after.this.screen.apple.will.ask.for.permission.you.can"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button {
                        model.continueAfterPermissionExplanation()
                    } label: {
                        Label(localizedKey(model.language, "ui.continue"), systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)

                    Button {
                        model.cancelPermissionExplanation()
                    } label: {
                        Text(localizedKey(model.language, "ui.not.now"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
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

#if os(iOS)
private struct DJConnectTopTabButton: View {
    let title: String
    let systemImage: String
    var symbolVariant: SymbolVariants = .none
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .symbolVariant(symbolVariant)
            }
                .font(.headline.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .foregroundStyle(isSelected ? djConnectAccent : .primary)
                .frame(minWidth: 118)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Capsule(style: .continuous))
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.28))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
#endif

private struct PairingSheetView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isManualPairingVisible = false
    #if os(iOS)
    @State private var isShowingQRScanner = false
    @State private var isShowingCameraConsent = false
    @State private var cameraConsentShowsSettings = false
    #endif

    private var contentIdealWidth: CGFloat {
        horizontalSizeClass == .regular ? 780 : 560
    }

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 940 : 680
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 22) {
                AboutBanner()

                if model.isShowingPairingSuccess {
                    pairingSuccess
                } else {
                    pairingPending
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, horizontalSizeClass == .regular ? 8 : 28)
            .padding(.bottom, 28)
            #if !os(macOS)
            .padding(.bottom, 18)
            #endif
            .frame(minWidth: 360, idealWidth: contentIdealWidth, maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .defaultScrollAnchor(.top)
        .background(DJConnectCanvasBackground())
        #if os(iOS)
        .frame(
            minHeight: horizontalSizeClass == .regular ? 760 : nil,
            idealHeight: horizontalSizeClass == .regular ? 860 : nil
        )
        #endif
        #if os(macOS)
        .frame(minHeight: 560)
        #endif
        #if os(iOS)
        .sheet(isPresented: $isShowingCameraConsent) {
            PairingCameraConsentSheet(
                language: model.language,
                showsSettingsAction: cameraConsentShowsSettings,
                continueAction: openScannerAfterCameraConsent,
                settingsAction: openCameraSettings
            )
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isShowingQRScanner) {
            PairingQRScannerView(language: model.language) { value in
                isShowingQRScanner = false
                if model.pairingFlowTarget == .appleWatch {
                    model.handleWatchPairingQRCode(value)
                } else {
                    let accepted = model.handlePairingQRCode(value)
                    if accepted {
                        Task { @MainActor in
                            await Task.yield()
                            model.confirmPairingHomeAssistantURL()
                        }
                    }
                }
            }
            .presentationBackground(.black)
        }
        #endif
    }

    #if os(iOS)
    private func requestCameraConsentForScanner() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingQRScanner = true
        case .notDetermined:
            cameraConsentShowsSettings = false
            isShowingCameraConsent = true
        case .denied, .restricted:
            cameraConsentShowsSettings = true
            isShowingCameraConsent = true
        @unknown default:
            cameraConsentShowsSettings = true
            isShowingCameraConsent = true
        }
    }

    private func openScannerAfterCameraConsent() {
        guard !cameraConsentShowsSettings else {
            openCameraSettings()
            return
        }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                isShowingCameraConsent = false
                if granted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isShowingQRScanner = true
                    }
                } else {
                    cameraConsentShowsSettings = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isShowingCameraConsent = true
                    }
                }
            }
        }
    }

    private func openCameraSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        isShowingCameraConsent = false
        UIApplication.shared.open(url)
    }
    #endif

    private var pairingPending: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(pairingTitle)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(pairingCodeInstruction)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if shouldShowPairingNetworkNotice {
                    PairingNetworkNotice(
                        language: model.language,
                        warning: model.localNetworkRequirementMessage
                    )
                }

                #if os(iOS)
                if model.pairingFlowTarget == .appleWatch {
                    Button {
                        requestCameraConsentForScanner()
                    } label: {
                        Label(
                            localizedKey(model.language, "ui.pair.apple.watch.via.qr.code"),
                            systemImage: "applewatch"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                    .disabled(model.isPairing)
                } else {
                    Button {
                        requestCameraConsentForScanner()
                    } label: {
                        Label(
                            localizedKey(model.language, "ui.pair.iphone.via.qr.code"),
                            systemImage: "qrcode.viewfinder"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                    .disabled(model.isPairing)
                }

                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        isManualPairingVisible.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(localizedKey(model.language, "ui.manual"))
                            .font(.headline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .rotationEffect(.degrees(isManualPairingVisible ? 180 : 0))
                    }
                    .foregroundStyle(djConnectAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedKey(model.language, "ui.manual.pairing"))
                #endif

                if shouldShowManualPairing {
                    PairingEditableURLCard(
                        title: localizedKey(model.language, "ui.local.home.assistant.url"),
                        language: model.language,
                        text: $model.homeAssistantURL
                    ) {}

                PairingCodeEntryCard(
                    title: localizedKey(model.language, "ui.pair.code"),
                    language: model.language,
                    deviceTypeLabel: manualPairingDeviceTypeLabel,
                    text: $model.pairingToken
                )
                }
            }

            if shouldShowManualPairing {
                HStack(spacing: 12) {
                    statusIcon
                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusTitle)
                            .font(.headline)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        if let pairingMessage = pairingStatusMessage {
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
                    if model.pairingFlowTarget == .appleWatch {
                        model.confirmAppleWatchPairingHomeAssistantURL()
                    } else {
                        model.confirmPairingHomeAssistantURL()
                    }
                } label: {
                    Label(
                        manualPairingButtonTitle,
                        systemImage: "link.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                .controlSize(.large)
                .disabled(model.isPairing || !canSubmitPairing)

                if let inlinePairingMessage {
                    Label {
                        Text(inlinePairingMessage)
                            .font(.callout.weight(.semibold))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }

            if model.pairingFlowTarget != .appleWatch {
                Button {
                    model.startDemoMode()
                } label: {
                    Label(
                        localizedKey(model.language, "ui.start.demo.mode"),
                        systemImage: "play.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                .controlSize(.large)
            }

            #if os(macOS)
            Button {
                quitApplication()
            } label: {
                Label(
                    localizedKey(model.language, "ui.quit.app"),
                    systemImage: "power"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)
            #endif
        }
    }

    private var shouldShowManualPairing: Bool {
        #if os(iOS)
        isManualPairingVisible
        #else
        true
        #endif
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
                Text(pairingSuccessTitle)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(pairingSuccessMessage)
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
            return localizedKey(model.language, "ui.demo.mode")
        }
        return switch model.pairingStatus {
        case .pairing:
            model.pairingFlowTarget == .appleWatch
                ? localizedKey(model.language, "ui.pairing.apple.watch.with.home.assistant")
                : localizedKey(model.language, "ui.pairing.with.home.assistant")
        case .waitingForHomeAssistantCompletion:
            localizedKey(model.language, "ui.finish.setup.in.home.assistant")
        case .stale:
            localizedKey(model.language, "ui.not.connected.to.home.assistant")
        default:
            model.pairingFlowTarget == .appleWatch
                ? localizedKey(model.language, "ui.ready.to.pair.apple.watch")
                : localizedKey(model.language, "ui.ready.to.pair")
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if model.pairingStatus == .pairing || model.pairingStatus == .waitingForHomeAssistantCompletion {
            ProgressView()
                .controlSize(.regular)
        } else {
            Image(systemName: statusIconName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(statusIconColor)
                .frame(width: 28, height: 28)
        }
    }

    private var statusIconName: String {
        if model.pairingStatus == .waitingForHomeAssistantCompletion {
            return "hourglass.circle"
        }
        if model.pairingStatus == .stale {
            return "wifi.exclamationmark"
        }
        if !isPairingURLValid || !isPairingCodeValid {
            return "exclamationmark.circle"
        }
        return "link.circle"
    }

    private var statusIconColor: Color {
        if model.pairingStatus == .stale || !isPairingURLValid || !isPairingCodeValid {
            return .orange
        }
        return .blue
    }

    private var pairingStatusMessage: String? {
        if model.pairingStatus == .pairing || model.pairingStatus == .waitingForHomeAssistantCompletion || model.pairingStatus == .stale {
            return model.pairingMessage
        }
        if !isPairingURLValid {
            return invalidURLStatusMessage
        }
        if !isPairingCodeValid {
            return invalidPairCodeStatusMessage
        }
        if let pairingMessage = model.pairingMessage, !isFieldPrompt(pairingMessage) {
            return pairingMessage
        }
        return model.pairingFlowTarget == .appleWatch
            ? localizedKey(model.language, "ui.ready.click.pair.apple.watch.with.home.assistant")
            : localizedKey(model.language, "ui.ready.click.pair.with.home.assistant")
    }

    private var inlinePairingMessage: String? {
        guard let pairingMessage = model.pairingMessage,
              !isFieldPrompt(pairingMessage) else {
            return nil
        }
        return pairingMessage
    }

    private var shouldShowPairingNetworkNotice: Bool {
        if model.localNetworkRequirementMessage != nil {
            return true
        }
        guard let url = DJConnectAppModel.normalizedHomeAssistantURL(from: model.homeAssistantURL),
              url.scheme?.lowercased() == "https" else {
            return false
        }
        return !DJConnectPairingURLPolicy.isWhitelistedDevelopmentTunnelURL(url)
    }

    private var canSubmitPairing: Bool {
        isPairingURLValid && isPairingCodeValid
    }

    private var isPairingURLValid: Bool {
        guard let url = DJConnectAppModel.normalizedHomeAssistantURL(from: model.homeAssistantURL) else {
            return false
        }
        return DJConnectPairingURLPolicy.isAllowedPairingURL(url)
    }

    private var isPairingCodeValid: Bool {
        let code = model.pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return code.count == 6 && code.allSatisfy(\.isNumber)
    }

    private var invalidURLStatusMessage: String {
        return localizedKey(model.language, "ui.enter.your.home.assistant.url.for.example.192.168.1")
    }

    private var invalidPairCodeStatusMessage: String {
        model.pairingFlowTarget == .appleWatch
            ? localizedKey(model.language, "ui.enter.apple.watch.6.digit.pair.code")
            : localizedKey(model.language, "ui.enter.the.6.digit.pair.code.shown.by.home")
    }

    private func isFieldPrompt(_ message: String) -> Bool {
        message == invalidURLStatusMessage || message == invalidPairCodeStatusMessage
    }

    private var pairingCodeInstruction: String {
        #if os(iOS)
        if model.pairingFlowTarget == .appleWatch {
            return localizedKey(model.language, "ui.open.djconnect.on.apple.watch.then.scan.or.enter.the")
        }
        return localizedKey(model.language, "ui.enter.or.scan.the.code.shown.by.home.assistant.while")
        #else
        localizedKey(model.language, "ui.enter.the.code.shown.by.home.assistant.while.this.device")
        #endif
    }

    private var pairingTitle: String {
        model.pairingFlowTarget == .appleWatch
            ? localizedKey(model.language, "ui.pair.apple.watch")
            : localizedKey(model.language, "ui.pair.djconnect")
    }

    private var manualPairingButtonTitle: String {
        model.pairingFlowTarget == .appleWatch
            ? localizedKey(model.language, "ui.pair.apple.watch.with.home.assistant")
            : localizedKey(model.language, "ui.pair.with.home.assistant")
    }

    private var manualPairingDeviceTypeLabel: String {
        model.pairingFlowTarget == .appleWatch
            ? Self.pairingDeviceTypeLabel(for: .watchos)
            : Self.pairingDeviceTypeLabel(for: model.identity.clientType)
    }

    private var pairingSuccessTitle: String {
        model.pairingFlowTarget == .appleWatch
            ? localizedKey(model.language, "ui.apple.watch.paired")
            : localizedKey(model.language, "ui.pairing.successful")
    }

    private var pairingSuccessMessage: String {
        model.pairingFlowTarget == .appleWatch
            ? localizedKey(model.language, "ui.apple.watch.is.paired.with.home.assistant.through.this.iphone")
            : localizedKey(model.language, "ui.djconnect.is.paired.with.home.assistant")
    }

    private static func pairingDeviceTypeLabel(for clientType: DJConnectClientType) -> String {
        switch clientType {
        case .ios:
            "iOS"
        case .macos:
            "macOS"
        case .watchos:
            "watchOS"
        case .esp32:
            "ESP32"
        case .raspberryPi:
            "Raspberry Pi"
        case .windows:
            "Windows"
        }
    }
}

private struct PairingNetworkNotice: View {
    let language: String
    let warning: String?

    var body: some View {
        Label {
            Text(warning ?? localizedKey(language, "ui.pairing.is.local.only.use.the.lan.address.of.home"))
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
        guard let url = DJConnectAppModel.normalizedHomeAssistantURL(from: trimmedText) else {
            return false
        }
        return DJConnectPairingURLPolicy.isAllowedPairingURL(url)
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
                    .accessibilityLabel(localizedKey(language, "ui.clear.home.assistant.url"))
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
                .accessibilityLabel(localizedKey(language, "ui.confirm.home.assistant.url"))
            }
            if !trimmedText.isEmpty, !isValid {
                Label(
                    localizedKey(language, "ui.enter.a.valid.local.home.assistant.url.for.example.http"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
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

private struct PairingCodeEntryCard: View {
    let title: String
    let language: String
    let deviceTypeLabel: String
    @Binding var text: String
    @FocusState private var isCodeFocused: Bool

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        trimmedText.count == 6 && trimmedText.allSatisfy(\.isNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            TextField(title, text: $text)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .textContentType(.oneTimeCode)
                .focused($isCodeFocused)
                #if os(iOS)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .textFieldStyle(.plain)
                .onChange(of: text) {
                    let digits = text.filter(\.isNumber)
                    if digits != text || digits.count > 6 {
                        text = String(digits.prefix(6))
                    }
                }

            if !trimmedText.isEmpty, !isValid {
                Label(
                    localizedKey(language, "ui.enter.the.6.digit.code.shown.by.home.assistant"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else {
                Label(
                    localizedKey(
                        language,
                        "ui.choose.value.in.the.home.assistant.djconnect.setup.flow.and",
                        arguments: deviceTypeLabel
                    ),
                    systemImage: "number"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .djConnectGradientCard(strokeOpacity: !trimmedText.isEmpty && !isValid ? 0.0 : 0.16)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(!trimmedText.isEmpty && !isValid ? .orange.opacity(0.75) : .clear, lineWidth: 1)
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                if isValid {
                    Button(localizedKey(language, "ui.done")) {
                        isCodeFocused = false
                    }
                    .font(.headline.weight(.semibold))
                }
            }
        }
        #endif
    }
}

#if os(iOS) && canImport(AVFoundation)
private struct PairingCameraConsentSheet: View {
    let language: String
    let showsSettingsAction: Bool
    let continueAction: () -> Void
    let settingsAction: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 78)
                    .background(
                        LinearGradient(
                            colors: [djConnectAccent, Color(red: 0.82, green: 0.20, blue: 0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(spacing: 10) {
                    Text(localizedKey(language, "ui.camera.access.for.pairing"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button {
                        showsSettingsAction ? settingsAction() : continueAction()
                    } label: {
                        Label(primaryButtonTitle, systemImage: showsSettingsAction ? "gear" : "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)

                    Button {
                        dismiss()
                    } label: {
                        Text(localizedKey(language, "ui.not.now"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DJConnectCanvasBackground())
            .navigationTitle(localizedKey(language, "ui.camera"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var message: String {
        if showsSettingsAction {
            return localizedKey(language, "ui.camera.access.is.disabled.enable.it.in.settings.to.scan")
        }
        return localizedKey(language, "ui.djconnect.uses.the.camera.only.to.scan.the.pairing.qr")
    }

    private var primaryButtonTitle: String {
        showsSettingsAction
            ? localizedKey(language, "ui.open.settings")
            : localizedKey(language, "ui.allow.camera")
    }
}

private struct PairingQRScannerView: View {
    let language: String
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didDetectCode = false

    var body: some View {
        NavigationStack {
            ZStack {
                PairingQRScannerRepresentable { value in
                    guard !didDetectCode else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        didDetectCode = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(700))
                        onCode(value)
                    }
                }
                    .ignoresSafeArea()
                VStack {
                    if didDetectCode {
                        PairingQRSuccessOverlay(language: language)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                    Spacer()
                    Text(localizedKey(language, "ui.scan.the.djconnect.qr.code.shown.by.home.assistant"))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(localizedKey(language, "ui.scan.qr.code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedKey(language, "ui.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PairingQRSuccessOverlay: View {
    let language: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 58, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(localizedKey(language, "ui.pairing.successful"))
                .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(.green.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .padding(.top, 56)
    }
}

private struct PairingQRScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIViewController(context: Context) -> PairingQRScannerViewController {
        let controller = PairingQRScannerViewController()
        controller.onCode = context.coordinator.handleCode(_:)
        return controller
    }

    func updateUIViewController(_ uiViewController: PairingQRScannerViewController, context: Context) {}

    final class Coordinator {
        private var didSendCode = false
        let onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func handleCode(_ value: String) {
            guard !didSendCode else { return }
            didSendCode = true
            onCode(value)
        }
    }
}

private final class PairingQRScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              object.type == .qr,
              let value = object.stringValue else {
            return
        }
        session.stopRunning()
        onCode?(value)
    }
}
#endif

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
                    localizedKey(language, "ui.copied.to.clipboard"),
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
                Text(localizedKey(model.language, "ui.enable.voice.activation"))
                    .font(.title2.bold())
                Text(localizedKey(model.language, "ui.start.hands.free.with.hey.dj.while.djconnect.is.open"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Button {
                    model.activateWakeWordFromPrompt()
                } label: {
                    Label(localizedKey(model.language, "ui.enable.voice.activation.321a28"), systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                .controlSize(.large)
                Button {
                    model.dismissWakeWordActivationPrompt()
                } label: {
                    Text(localizedKey(model.language, "ui.not.now.b1e535"))
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
                    Text(localizedKey(model.language, "ui.update.required"))
                        .font(.title2.bold())
                    Text(model.updateRequiredMessage ?? localizedKey(model.language, "ui.update.djconnect.before.continuing"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(localizedKey(model.language, "ui.playback.queue.playlists.output.selection.and.voice.controls.are.blocked"))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Link(destination: websiteURL) {
                Label(localizedKey(model.language, "ui.open.djconnect.update.page"), systemImage: "safari")
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
                Label(localizedKey(model.language, "ui.the.app.may.have.crashed"), systemImage: "exclamationmark.triangle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                Text(localizedKey(model.language, "ui.you.can.share.redacted.diagnostics.by.opening.a.github.issue"))
                .foregroundStyle(.secondary)
                Text(localizedKey(model.language, "ui.version") + " \(DJConnectVersionInfo.displayVersion)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button {
                    if let url = model.crashIssueURL() {
                        openURL(url)
                    }
                    model.dismissCrashReportPrompt()
                } label: {
                    Label(localizedKey(model.language, "ui.open.github.issue"), systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                Button {
                    model.dismissCrashReportPrompt()
                } label: {
                    Text(localizedKey(model.language, "ui.not.now.b1e535"))
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedStepIndex = 0
    private let startURL = URL(string: "https://djconnect.dev/start")!
    private var steps: [WelcomeTourStep] { WelcomeTourStep.steps(language: model.language) }
    private var selectedStep: WelcomeTourStep { steps[selectedStepIndex] }
    private var isLastStep: Bool { selectedStepIndex == steps.count - 1 }
    private var contentIdealWidth: CGFloat {
        horizontalSizeClass == .regular ? 780 : 580
    }
    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 940 : 680
    }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(spacing: 20) {
                AboutBanner()

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
                    Text(localizedKey(model.language, "ui.setup.runs.through.home.assistant.spotify.playback.requires.spotify.premium"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                    Link("djconnect.dev/start", destination: startURL)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(djConnectAccent)
                }

                HStack(spacing: 12) {
                    Button {
                        moveWelcomeTour(by: -1)
                    } label: {
                        Label(localizedKey(model.language, "ui.previous"), systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                    .disabled(selectedStepIndex == 0)
                    .opacity(selectedStepIndex == 0 ? 0.46 : 1)

                    if !isLastStep {
                        Button {
                            moveWelcomeTour(by: 1)
                        } label: {
                            Label(localizedKey(model.language, "ui.next"), systemImage: "chevron.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DJConnectLilacPillButtonStyle())
                        .controlSize(.large)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                    }
                }

                Button {
                    model.dismissWelcome()
                } label: {
                    if isLastStep {
                        Label(localizedKey(model.language, "ui.let.s.start"), systemImage: "music.note")
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(localizedKey(model.language, "ui.skip"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(DJConnectLilacPillButtonStyle())
                .controlSize(.large)
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: contentIdealWidth, maxWidth: contentMaxWidth)
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
                title: localizedKey(language, "ui.now.playing"),
                body: localizedKey(language, "ui.control.playback.volume.and.the.active.output.from.the.main"),
                systemImage: "music.note"
            ),
            WelcomeTourStep(
                id: .askDJ,
                title: "Ask DJ",
                body: localizedKey(language, "ui.ask.for.music.context.or.a.voice.reply.djconnect.keeps"),
                systemImage: "bubble.left.and.bubble.right"
            ),
            WelcomeTourStep(
                id: .trackInsight,
                title: "Track Insight",
                body: localizedKey(language, "ui.analyze.the.current.track.for.mood.energy.genre.and.musical"),
                systemImage: "waveform.path.ecg"
            ),
            WelcomeTourStep(
                id: .musicDNA,
                title: "Music DNA",
                body: localizedKey(language, "ui.learn.from.your.taste.and.listening.behavior.to.shape.recommendations"),
                systemImage: "heart"
            ),
            WelcomeTourStep(
                id: .games,
                title: localizedKey(language, "ui.mini.games"),
                body: localizedKey(language, "ui.play.local.mini.games.while.keeping.djconnect.ready.for.your"),
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
                    Text(localizedKey(model.language, "ui.what.s.new"))
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
                            Text(localizedKey(model.language, "ui.loading.release.notes"))
                                .font(.callout)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }

                Button {
                    model.dismissWhatsNew()
                } label: {
                Text(localizedKey(model.language, "ui.continue"))
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
            .navigationTitle(screenTitle(model.language, key: "Now Playing", isDemoMode: model.isDemoMode))
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
        .tint(.primary)
        .help(localizedKey(model.language, "ui.refresh"))
        .accessibilityLabel(localizedKey(model.language, "ui.refresh"))
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

private struct PlaybackControlButtonStyle: ButtonStyle {
    var isProminent = false
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(isProminent || isActive ? 0.12 : 0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isProminent {
            return djConnectAccent.opacity(isPressed ? 0.82 : 0.96)
        }
        if isActive {
            return djConnectAccent.opacity(isPressed ? 0.30 : 0.24)
        }
        return Color.white.opacity(isPressed ? 0.16 : 0.10)
    }
}

struct DJConnectLilacPillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white.opacity(isEnabled ? 1.0 : 0.52))
            .foregroundColor(.white.opacity(isEnabled ? 1.0 : 0.52))
            .tint(.white)
            .accentColor(.white)
            .symbolRenderingMode(.monochrome)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        (isEnabled ? djConnectButtonBlue : Color.white).opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.12),
                        (isEnabled ? djConnectButtonPurple : Color.white).opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.08)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(.white.opacity(isEnabled ? (configuration.isPressed ? 0.18 : 0.12) : 0.10), lineWidth: 1)
            }
            .shadow(color: djConnectButtonPurple.opacity(isEnabled ? 0.26 : 0), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.16), value: isEnabled)
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

enum CachedArtworkImageMode {
    case fit
    case fill
}

struct CachedArtworkImage<Placeholder: View>: View {
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

private struct TrackInsightView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingShare = false
    @State private var isAnimationActive = false
    #if canImport(AVKit) && os(iOS)
    @StateObject private var vibeCastAirPlaySession = VibeCastAirPlaySession()
    #endif

    private var insight: TrackInsight? {
        model.currentTrackInsight
    }

    private var insightID: String? {
        insight?.id
    }

    private func shouldUseWideLayout(for size: CGSize) -> Bool {
        #if os(macOS)
        size.width >= 1_000
        #else
        horizontalSizeClass == .regular && size.width > size.height
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                GeometryReader { proxy in
                    let useWideLayout = shouldUseWideLayout(for: proxy.size)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let insight {
                                if useWideLayout {
                                    HStack(alignment: .top, spacing: 18) {
                                        TrackInsightHero(
                                            model: model,
                                            insight: insight,
                                            isAnimationActive: isAnimationActive
                                        )
                                        .frame(maxWidth: .infinity, alignment: .top)

                                        VStack(alignment: .leading, spacing: 16) {
                                            TrackInsightAnalysisCard(insight: insight, language: model.language)
                                            TrackInsightMetricsGrid(insight: insight, language: model.language)
                                            TrackInsightPrivacyFooter(language: model.language)
                                        }
                                        .frame(minWidth: 390, idealWidth: 470, maxWidth: 540, alignment: .topLeading)
                                    }
                                } else {
                                    TrackInsightHero(model: model, insight: insight, isAnimationActive: isAnimationActive)
                                    TrackInsightAnalysisCard(insight: insight, language: model.language)
                                    TrackInsightMetricsGrid(insight: insight, language: model.language)
                                    TrackInsightPrivacyFooter(language: model.language)
                                }
                            } else {
                                TrackInsightEmptyState(model: model)
                            }
                        }
                        .padding(.horizontal, djConnectScreenHorizontalPadding)
                        .padding(.vertical, djConnectScreenVerticalPadding)
                        .frame(
                            maxWidth: useWideLayout ? 1_520 : djConnectContentMaxWidth,
                            alignment: .topLeading
                        )
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                #if canImport(AVKit) && os(iOS)
                if let player = vibeCastAirPlaySession.player {
                    VideoPlayer(player: player)
                        .frame(width: 2, height: 2)
                        .opacity(0.01)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                #endif
            }
            .navigationTitle(screenTitle(model.language, key: "Track Insight", isDemoMode: model.isDemoMode))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    #if canImport(AVKit) && os(iOS)
                    VibeCastAirPlayToolbarButton(
                        language: model.language,
                        hasInsight: insight != nil,
                        isPreparing: vibeCastAirPlaySession.isPreparing,
                        isReady: vibeCastAirPlaySession.player != nil
                    )
                    #else
                    AirPlayToolbarButton(language: model.language)
                    #endif

                    if insight != nil {
                        Button {
                            isShowingShare = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.primary)
                        }
                        .tint(.primary)
                        .help(localizedKey(model.language, "ui.share.insight"))
                    }
                }
            }
            .sheet(isPresented: $isShowingShare) {
                if let insight {
                    TrackInsightSharePreviewView(insight: insight, language: model.language)
                }
            }
            .djUserNoticeToast(model: model)
        }
        #if canImport(AVKit) && os(iOS)
        .task(id: insightID) {
            guard let insight else {
                vibeCastAirPlaySession.reset()
                return
            }
            await vibeCastAirPlaySession.prepare(insight: insight, language: model.language)
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            vibeCastAirPlaySession.loopIfNeeded(notification.object)
        }
        #endif
        .onAppear {
            isAnimationActive = true
        }
        .onDisappear {
            isAnimationActive = false
        }
    }
}

private struct MusicDNAView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MusicDNAHeroView(model: model)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        MusicDNAContentView(model: model)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.horizontal, djConnectScreenHorizontalPadding)
                    .padding(.vertical, djConnectScreenVerticalPadding)
                    .frame(maxWidth: musicDNAMaxContentWidth, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                #if os(iOS)
                .refreshable {
                    #if DEBUG
                    guard !model.isMusicDNAPreviewMode else { return }
                    #endif
                    await model.refreshMusicDNAProfile()
                }
                #endif
            }
            .navigationTitle(screenTitle(model.language, key: "Music DNA", isDemoMode: model.isDemoMode))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    MusicDNARefreshButton(model: model)
                }
                #else
                ToolbarItem(placement: .topBarTrailing) {
                    MusicDNARefreshButton(model: model)
                }
                #endif
            }
        }
        .task {
            #if DEBUG
            guard !model.isMusicDNAPreviewMode else { return }
            #endif
            await model.refreshMusicDNAProfile()
            model.presentMusicDNAOptInPromptIfNeeded()
        }
        .sheet(isPresented: $model.isShowingMusicDNAOptInPrompt) {
            MusicDNAOptInPromptView(model: model)
        }
    }

    private var musicDNAMaxContentWidth: CGFloat {
        #if os(macOS)
        return 1_680
        #else
        return 1_520
        #endif
    }
}

private struct MusicDNARefreshButton: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        Button {
            Task { await model.refreshMusicDNAProfile() }
        } label: {
            if model.isLoadingMusicDNA {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(model.isLoadingMusicDNA || model.isUpdatingMusicDNA)
        .tint(.primary)
        .help(localizedKey(model.language, "ui.refresh.music.dna"))
        .accessibilityLabel(localizedKey(model.language, "ui.refresh.music.dna"))
    }
}

private struct MusicDNAHeroView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNAHelixView()
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if model.musicDNAProfileResponse?.enabled != true {
                Text(localizedKey(model.language, "ui.djconnect.in.your.home.assistant.environment.does.not.build.a"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .djConnectGradientCard(cornerRadius: 8)
    }
}

private struct MusicDNAOptInPromptView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 18) {
                AboutBanner()

                VStack(alignment: .leading, spacing: 10) {
                    Text(localizedKey(model.language, "ui.enable.music.dna"))
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(localizedKey(model.language, "ui.with.music.dna.djconnect.can.learn.from.your.taste.and"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    if model.isDemoMode {
                        Text(localizedKey(model.language, "ui.in.demo.mode.this.only.unlocks.fictional.sample.data.on"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        localizedKey(model.language, "ui.you.can.clear.the.learned.profile.at.any"),
                        systemImage: "trash"
                    )
                    Label(
                        localizedKey(model.language, "ui.you.can.always.turn.music.dna.off.in"),
                        systemImage: "switch.2"
                    )
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        model.acceptMusicDNAOptInPrompt()
                    } label: {
                        Label(localizedKey(model.language, "ui.enable.music.dna.1adf61"), systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                    .disabled(model.isUpdatingMusicDNA)

                    Button {
                        model.dismissMusicDNAOptInPrompt()
                    } label: {
                        Text(localizedKey(model.language, "ui.not.now.b1e535"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620, minHeight: 420, alignment: .topLeading)
        }
    }
}

private struct MusicDNAContentView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.isLoadingMusicDNA, model.musicDNAProfileResponse == nil {
                MusicDNALoadingView(model: model)
            } else if let response = model.musicDNAProfileResponse {
                if response.enabled {
                    if response.profile.isEmpty {
                        MusicDNANoProfileView(model: model)
                    } else {
                        MusicDNASectionGrid(model: model, response: response)
                    }
                } else {
                    MusicDNADisabledView(model: model)
                }
            } else {
                MusicDNAUnavailableView(model: model)
            }

        }
    }
}

private struct MusicDNASectionGrid: View {
    @ObservedObject var model: DJConnectAppModel
    let response: DJConnectMusicDNAProfileResponse

    private var profile: DJConnectMusicDNAProfile { response.profile }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            MusicDNAPanel(title: localizedKey(model.language, "ui.summary"), value: profile.summary ?? "-", icon: "waveform")
            MusicDNAPanel(title: localizedKey(model.language, "ui.favorite.genres"), value: names(profile.favoriteGenres), icon: "music.quarternote.3")
            MusicDNAPanel(title: localizedKey(model.language, "ui.favorite.artists"), value: names(profile.favoriteArtists), icon: "person.wave.2")
            MusicDNAPanel(title: localizedKey(model.language, "ui.mood"), value: moodSummary, icon: "sparkles")
            MusicDNAPanel(title: localizedKey(model.language, "ui.energy.profile"), value: energyProfile, icon: "bolt.fill")
            MusicDNAPanel(title: localizedKey(model.language, "ui.recent.tracks"), value: tracks(profile.recentTracks), icon: "clock.arrow.circlepath")
            MusicDNAPanel(title: localizedKey(model.language, "ui.signals"), value: signals(profile.recommendationSignals), icon: "safari")
            MusicDNAPanel(title: localizedKey(model.language, "ui.updated"), value: updatedSummary, icon: "checkmark.seal")
        }
    }

    private var gridColumns: [GridItem] {
        return [
            GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)
        ]
    }

    private var energyProfile: String {
        guard let value = profile.mood?.value else {
            return localizedKey(model.language, "ui.not.enough.signals")
        }
        if value >= 72 {
            return localizedKey(model.language, "ui.high.energy.leaning")
        }
        if value <= 42 {
            return localizedKey(model.language, "ui.calm.and.spacious")
        }
        return localizedKey(model.language, "ui.balanced.energy")
    }

    private var moodSummary: String {
        guard let mood = profile.mood else {
            return localizedKey(model.language, "ui.not.enough.signals")
        }
        let zone = mood.zone?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = mood.value.map { "\($0)%" }
        return [zone, value].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - ")
    }

    private var updatedSummary: String {
        if response.generation != nil {
            return localizedKey(model.language, "ui.generation.value", arguments: response.generation ?? 0)
        }
        return localizedKey(model.language, "ui.server.profile")
    }

    private func names(_ values: [DJConnectMusicDNANameValue]) -> String {
        values.map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: ", ")
            .ifEmpty(localizedKey(model.language, "ui.not.enough.signals"))
    }

    private func tracks(_ values: [DJConnectMusicDNATrack]) -> String {
        values.compactMap { track in
            let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let artist = track.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if title.isEmpty { return artist.isEmpty ? nil : artist }
            return artist.isEmpty ? title : "\(title) - \(artist)"
        }
        .prefix(3)
        .joined(separator: ", ")
        .ifEmpty(localizedKey(model.language, "ui.not.enough.signals"))
    }

    private func signals(_ values: [DJConnectMusicDNASignal]) -> String {
        values.compactMap { $0.title ?? $0.name ?? $0.value }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: ", ")
            .ifEmpty(localizedKey(model.language, "ui.not.enough.signals"))
    }
}

private struct MusicDNADisabledView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(localizedKey(model.language, "ui.music.dna.is.not.enabled"), systemImage: "lock")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(localizedKey(model.language, "ui.enable.music.dna.to.get.recommendations.tailored.to.your.listening"))
            .font(.callout)
            .foregroundStyle(.white.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
            Button {
                model.showMusicDNAOptInPrompt()
            } label: {
                Label(localizedKey(model.language, "ui.enable.music.dna.1adf61"), systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)
            .disabled(model.isUpdatingMusicDNA)
        }
        .padding(16)
        .djConnectGradientCard(cornerRadius: 8)
    }
}

private struct MusicDNANoProfileView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                localizedKey(model.language, "ui.no.music.dna.profile.yet"),
                systemImage: "waveform.path.ecg"
            )
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(localizedKey(model.language, "ui.music.dna.is.enabled.but.home.assistant.has.not.built"))
            .font(.callout)
            .foregroundStyle(.white.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
            Label(
                localizedKey(model.language, "ui.ask.dj.track.insight.and.listening.signals.will"),
                systemImage: "clock.arrow.circlepath"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.62))
        }
        .padding(16)
        .djConnectGradientCard(cornerRadius: 8)
    }
}

private struct MusicDNAUnavailableView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                localizedKey(model.language, "ui.music.dna.could.not.be.loaded"),
                systemImage: "wifi.exclamationmark"
            )
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            Text(localizedKey(model.language, "ui.djconnect.cannot.read.the.current.music.dna.state.from.home"))
            .font(.callout)
            .foregroundStyle(.white.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await model.refreshMusicDNAProfile() }
            } label: {
                Label(localizedKey(model.language, "ui.try.again"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .disabled(model.isLoadingMusicDNA)
        }
        .padding(16)
        .djConnectGradientCard(cornerRadius: 8)
    }
}

private struct MusicDNALoadingView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
            Text(localizedKey(model.language, "ui.loading.music.dna.from.home.assistant"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            if let latest = model.currentTrackInsight ?? model.trackInsightHistory.first {
                Text([latest.title, latest.artist].compactMap { $0 }.joined(separator: " - "))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .djConnectGradientCard(cornerRadius: 8)
    }
}

#if DEBUG && (os(iOS) || os(macOS))
#Preview("Music DNA - Populated") {
    MusicDNAView(model: DJConnectAppModel.musicDNAPreviewModel(response: .previewPopulated))
}

#Preview("Music DNA - No Profile Yet") {
    MusicDNAView(model: DJConnectAppModel.musicDNAPreviewModel(response: .previewEnabledEmpty))
}

#Preview("Music DNA - Disabled") {
    MusicDNAView(model: DJConnectAppModel.musicDNAPreviewModel(response: .previewDisabled))
}

#Preview("Music DNA - Unavailable") {
    MusicDNAView(model: DJConnectAppModel.musicDNAPreviewModel(
        response: nil,
        errorMessage: "Home Assistant is temporarily unavailable."
    ))
}

private extension DJConnectAppModel {
    static func musicDNAPreviewModel(response: DJConnectMusicDNAProfileResponse) -> DJConnectAppModel {
        musicDNAPreviewModel(response: response, errorMessage: nil)
    }

    static func musicDNAPreviewModel(response: DJConnectMusicDNAProfileResponse?, errorMessage: String?) -> DJConnectAppModel {
        let model = DJConnectAppModel(startBackgroundTasks: false)
        model.setMusicDNAPreviewResponse(response)
        model.setMusicDNAPreviewErrorMessage(errorMessage)
        return model
    }
}

private extension DJConnectMusicDNAProfileResponse {
    static let previewPopulated = DJConnectMusicDNAProfileResponse(
        success: true,
        musicDNAKey: "user:preview",
        enabled: true,
        generation: 2,
        profile: DJConnectMusicDNAProfile(
            summary: "Warm, nocturnal electronic tracks with soft vocals and spacious low-end.",
            favoriteGenres: [
                DJConnectMusicDNANameValue(name: "ambient"),
                DJConnectMusicDNANameValue(name: "melodic house"),
                DJConnectMusicDNANameValue(name: "indie electronic")
            ],
            favoriteArtists: [
                DJConnectMusicDNANameValue(name: "The xx"),
                DJConnectMusicDNANameValue(name: "Ben Bohmer")
            ],
            recentTracks: [
                DJConnectMusicDNATrack(title: "Intro", artist: "The xx"),
                DJConnectMusicDNATrack(title: "Beyond Beliefs", artist: "Ben Bohmer")
            ],
            mood: DJConnectMusicDNAMood(value: 65, zone: "energy", promptHint: "keep it warm"),
            recommendationSignals: [
                DJConnectMusicDNASignal(title: "soft vocals"),
                DJConnectMusicDNASignal(title: "wide pads")
            ]
        )
    )

    static let previewEnabledEmpty = DJConnectMusicDNAProfileResponse(
        success: true,
        enabled: true,
        profile: DJConnectMusicDNAProfile()
    )

    static let previewDisabled = DJConnectMusicDNAProfileResponse(
        success: true,
        enabled: false,
        profile: DJConnectMusicDNAProfile()
    )
}
#endif

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private struct MusicDNAPanel: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(djConnectAccent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
            Text(value.isEmpty ? "-" : value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct MusicDNATimelinePreview: View {
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Music DNA Evolution", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.headline.weight(.semibold))
            Text(localizedKey(language, "ui.future.timeline.taste.evolution.artist.affinity.mood.shifts.year.in"))
            .font(.callout)
            .foregroundStyle(.white.opacity(0.68))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .djConnectGradientCard(cornerRadius: 8)
    }
}

private struct MusicDNAHelixView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.04, green: 0.06, blue: 0.12),
                        Color(red: 0.18, green: 0.09, blue: 0.32),
                        Color(red: 0.02, green: 0.25, blue: 0.30)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ))

                let strandCount = 28
                for index in 0..<strandCount {
                    let progress = CGFloat(index) / CGFloat(max(strandCount - 1, 1))
                    let y = size.height * (0.12 + progress * 0.76)
                    let phase = Double(progress) * .pi * 4 + time * 0.9
                    let leftX = size.width * (0.50 + CGFloat(sin(phase)) * 0.24)
                    let rightX = size.width * (0.50 + CGFloat(sin(phase + .pi)) * 0.24)
                    let color = Color(hue: 0.58 + Double(progress) * 0.22, saturation: 0.78, brightness: 1.0)

                    var connector = Path()
                    connector.move(to: CGPoint(x: leftX, y: y))
                    connector.addLine(to: CGPoint(x: rightX, y: y))
                    context.stroke(connector, with: .color(.white.opacity(0.10)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(x: leftX - 4, y: y - 4, width: 8, height: 8)), with: .color(color.opacity(0.92)))
                    context.fill(Path(ellipseIn: CGRect(x: rightX - 3, y: y - 3, width: 6, height: 6)), with: .color(.white.opacity(0.68)))
                }
            }
        }
    }
}

private struct TrackInsightHero: View {
    @ObservedObject var model: DJConnectAppModel
    let insight: TrackInsight
    let isAnimationActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var profile: TrackVibeProfile {
        TrackVibeProfile.make(for: insight)
    }

    private var isVisualizerPlaying: Bool {
        model.playback?.isPlaying == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrackInsightHeroScene(
                insight: insight,
                profile: profile,
                playback: model.playback,
                reduceMotion: reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled,
                isActive: isAnimationActive && isVisualizerPlaying,
                language: model.language
            )
            .frame(height: 430)

        }
        .padding(14)
        .background(profile.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.22), lineWidth: 1)
        }
    }
}

private struct TrackInsightHeroScene: View {
    let insight: TrackInsight
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool
    let language: String

    var body: some View {
        Group {
            if reduceMotion || !isActive {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    scene(date: timeline.date)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    scene(date: timeline.date)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 24, x: 0, y: 18)
    }

    private func scene(date: Date) -> some View {
        let phase = TrackVibePlaybackPhase(playback: playback, date: date)
        return GeometryReader { geometry in
            let isCompact = geometry.size.width < 560 || geometry.size.width / max(geometry.size.height, 1) < 1.05
            let artworkSize = min(
                geometry.size.width * (isCompact ? 0.34 : 0.30),
                geometry.size.height * (isCompact ? 0.25 : 0.34),
                210
            )
            let spectrumHeight = max(isCompact ? 96 : 86, geometry.size.height * (isCompact ? 0.16 : 0.22))
            let spectrumY = geometry.size.height * (isCompact ? 0.78 : 0.76)
            let infoBottomPadding = max(isCompact ? 112 : 18, geometry.size.height * (isCompact ? 0.16 : 0.04))
            ZStack {
                TrackInsightPremiumBackground(profile: profile, phase: phase, date: date)
                TrackInsightLightField(profile: profile, phase: phase, date: date)
                TrackInsightHeroArtwork(
                    insight: insight,
                    profile: profile,
                    playback: playback,
                    reduceMotion: reduceMotion,
                    isActive: isActive
                )
                .frame(width: artworkSize, height: artworkSize)
                .position(x: geometry.size.width * 0.50, y: geometry.size.height * (isCompact ? 0.27 : 0.34))

                TrackInsightPremiumSpectrum(profile: profile, phase: phase)
                    .frame(height: spectrumHeight)
                    .padding(.horizontal, max(isCompact ? 28 : 44, geometry.size.width * (isCompact ? 0.08 : 0.11)))
                    .position(x: geometry.size.width / 2, y: spectrumY)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    TrackInsightHeroInfo(insight: insight, language: language)
                        .frame(maxWidth: min(720, geometry.size.width * 0.82))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, infoBottomPadding)
            }
        }
    }
}

private struct TrackInsightPremiumBackground: View {
    let profile: TrackVibeProfile
    let phase: TrackVibePlaybackPhase
    let date: Date

    var body: some View {
        let colors = profile.colors
        let time = date.timeIntervalSinceReferenceDate
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.015, green: 0.020, blue: 0.050),
                    (colors.first ?? djConnectAccent).opacity(0.42),
                    Color(red: 0.010, green: 0.018, blue: 0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    (colors.last ?? djConnectAccent).opacity(0.44),
                    .clear
                ],
                center: UnitPoint(x: 0.22 + phase.progress * 0.56, y: 0.28 + sin(time * 0.18) * 0.06),
                startRadius: 16,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 420
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.58)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }
}

private struct TrackInsightLightField: View {
    let profile: TrackVibeProfile
    let phase: TrackVibePlaybackPhase
    let date: Date

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let time = date.timeIntervalSinceReferenceDate
            let colors = profile.colors
            for index in 0..<18 {
                let progress = CGFloat(index) / 17
                let x = size.width * (0.10 + progress * 0.82)
                let drift = CGFloat(sin(time * 0.22 + Double(index) * 0.61)) * 18
                let y = size.height * (0.18 + CGFloat((index * 37) % 53) / 100) + drift
                let radius = CGFloat(1.8 + profile.glow * 4.2)
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color((colors[safe: index % max(colors.count, 1)] ?? djConnectAccent).opacity(0.16 + phase.energyLift * 0.16))
                )
            }
        }
        .blur(radius: 0.3)
    }
}

private struct TrackInsightHeroArtwork: View {
    let insight: TrackInsight
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cornerRadius = max(16, side * 0.12)
            let iconPadding = max(12, side * 0.16)
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .blur(radius: max(14, side * 0.11))
                    .scaleEffect(1.14)
                CachedArtworkImage(url: insight.artwork, mode: .fill) {
                    TrackHeartbeatIcon(
                        profile: profile,
                        playback: playback,
                        reduceMotion: reduceMotion,
                        isActive: isActive
                    )
                    .padding(iconPadding)
                    .background(profile.gradient)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 1)
                }
                .shadow(color: (profile.colors.last ?? djConnectAccent).opacity(0.42), radius: max(18, side * 0.16), x: 0, y: max(8, side * 0.08))
            }
        }
    }
}

private struct TrackInsightPremiumSpectrum: View {
    let profile: TrackVibeProfile
    let phase: TrackVibePlaybackPhase

    var body: some View {
        GeometryReader { geometry in
            let count = 52
            let spacing: CGFloat = 4
            let barWidth = max(3, (geometry.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    let normalized = spectrumValue(index: index, count: count)
                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(barGradient(index: index, count: count))
                        .frame(width: barWidth, height: max(8, geometry.size.height * normalized))
                        .shadow(color: (profile.colors[safe: index % max(profile.colors.count, 1)] ?? djConnectAccent).opacity(0.28), radius: 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .mask(
                LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .leading, endPoint: .trailing)
            )
        }
        .allowsHitTesting(false)
    }

    private func spectrumValue(index: Int, count: Int) -> CGFloat {
        let base = profile.spectrumProfile[safe: index % max(profile.spectrumProfile.count, 1)] ?? 0.5
        let position = Double(index) / Double(max(count - 1, 1))
        let playhead = max(0, 1 - abs(position - phase.progress) * 6)
        let pulse = (sin(Double(index) * 0.55 + phase.positionSeconds * profile.pulseSpeed) + 1) * 0.5
        return CGFloat(min(1.0, 0.14 + base * 0.42 + pulse * 0.20 + playhead * 0.36 + phase.energyLift * 0.16))
    }

    private func barGradient(index: Int, count: Int) -> LinearGradient {
        let progress = Double(index) / Double(max(count - 1, 1))
        let playhead = max(0, 1 - abs(progress - phase.progress) * 10)
        let colors = profile.colors
        return LinearGradient(
            colors: [
                playheadColor(colors.first ?? .blue, playhead: playhead).opacity(0.70 + playhead * 0.30),
                playheadColor(colors[safe: 1] ?? djConnectAccent, playhead: playhead).opacity(0.78 + playhead * 0.22),
                playheadColor(colors.last ?? .pink, playhead: playhead).opacity(0.86 + playhead * 0.14)
            ],
            startPoint: UnitPoint(x: progress, y: 1),
            endPoint: UnitPoint(x: 1 - progress, y: 0)
        )
    }

    private func playheadColor(_ color: Color, playhead: Double) -> Color {
        color.mix(with: .white, by: min(max(playhead * 0.42, 0), 0.42))
    }
}

private struct TrackInsightHeroInfo: View {
    let insight: TrackInsight
    let language: String

    var body: some View {
        VStack(spacing: 10) {
            Text(insight.title)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(insight.artist)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
            if let album = insight.album, !album.isEmpty {
                Text(album)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }
            if let progressLabel {
                Text(progressLabel)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(.white.opacity(0.12), in: Capsule())
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 18)
        .padding(.bottom, 50)
    }

    private var progressLabel: String? {
        guard let duration = insight.duration, duration > 0 else {
            return nil
        }
        let progress = min(max(insight.progress ?? 0, 0), duration)
        return "\(formatTime(progress)) / \(formatTime(duration))"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}

private struct TrackInsightPrivacyFooter: View {
    let language: String

    var body: some View {
        Label(localizedKey(language, "ui.rendered.privately.on.your.device"), systemImage: "lock.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.46))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
            .padding(.bottom, 6)
    }
}

public struct VibeCastOutputView: View {
    @ObservedObject var model: DJConnectAppModel
    let insight: TrackInsight?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: DJConnectAppModel, insight: TrackInsight? = nil) {
        self.model = model
        self.insight = insight
    }

    public var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            if let insight = insight ?? model.currentTrackInsight {
                VibeCastVisualizerSignalView(
                    insight: insight,
                    playback: model.playback,
                    language: model.language,
                    reduceMotion: reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
                )
            } else {
                VibeCastEmptySignalView(language: model.language)
            }
        }
        .ignoresSafeArea()
    }
}

private struct VibeCastVisualizerSignalView: View {
    let insight: TrackInsight
    let playback: DJConnectPlayback?
    let language: String
    let reduceMotion: Bool

    private var profile: TrackVibeProfile {
        TrackVibeProfile.make(for: insight)
    }

    private var isPlaying: Bool {
        playback?.isPlaying == true
    }

    var body: some View {
        Group {
            if reduceMotion || !isPlaying {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    premiumScene(date: timeline.date)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    premiumScene(date: timeline.date)
                }
            }
        }
    }

    private func premiumScene(date: Date) -> some View {
        let phase = TrackVibePlaybackPhase(playback: playback, date: date)
        return GeometryReader { geometry in
            ZStack {
                TrackInsightPremiumBackground(profile: profile, phase: phase, date: date)
                TrackInsightLightField(profile: profile, phase: phase, date: date)

                TrackInsightHeroArtwork(
                    insight: insight,
                    profile: profile,
                    playback: playback,
                    reduceMotion: reduceMotion,
                    isActive: !reduceMotion && isPlaying
                )
                .frame(width: artworkSize(in: geometry.size), height: artworkSize(in: geometry.size))
                .position(x: geometry.size.width * 0.50, y: geometry.size.height * 0.33)

                TrackInsightPremiumSpectrum(profile: profile, phase: phase)
                    .frame(height: max(118, geometry.size.height * 0.18))
                    .padding(.horizontal, max(52, geometry.size.width * 0.12))
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.72)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    TrackInsightHeroInfo(insight: insight, language: language)
                        .frame(maxWidth: min(920, geometry.size.width * 0.78))
                }
                .padding(.horizontal, max(32, geometry.size.width * 0.04))
                .padding(.bottom, max(34, geometry.size.height * 0.055))

                brandHeader
                    .padding(max(24, geometry.size.width * 0.035))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func artworkSize(in size: CGSize) -> CGFloat {
        min(size.width * 0.24, size.height * 0.36, 360)
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "airplayvideo")
                .font(.headline.weight(.bold))
            Text("DJCONNECT VIBECAST")
                .font(.headline.weight(.bold))
                .tracking(1.2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.88))
    }
}

private struct VibeCastEmptySignalView: View {
    let language: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplayvideo")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(djConnectAccent)
            Text("VibeCast")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text(localizedKey(language, "ui.analyze.a.track.to.publish.the.visualizer.signal"))
                .font(.headline)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(32)
    }
}

#if canImport(AVKit) && os(iOS)
private func makeAirPlayPreviewPlayer(url: URL) async -> AVPlayer {
    await Task.detached(priority: .userInitiated) {
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.actionAtItemEnd = .none
        avPlayer.allowsExternalPlayback = true
        avPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
        try? AVAudioSession.sharedInstance().setActive(true)
        return avPlayer
    }.value
}

@MainActor
private final class VibeCastAirPlaySession: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPreparing = false
    @Published var progress = 0.0
    @Published var errorMessage: String?

    private var preparedInsightID: String?
    private var renderedURL: URL?

    func prepare(insight: TrackInsight, language: String) async {
        if preparedInsightID == insight.id, player != nil {
            player?.play()
            return
        }
        reset()
        preparedInsightID = insight.id
        isPreparing = true
        progress = 0
        errorMessage = nil
        do {
            let url = try await TrackInsightShareRenderer.renderVideo(
                insight: insight,
                format: .linkPreview,
                language: language
            ) { [weak self] value in
                self?.progress = value
            }
            try Task.checkCancellation()
            renderedURL = url
            let avPlayer = await makeAirPlayPreviewPlayer(url: url)
            player = avPlayer
            isPreparing = false
            avPlayer.play()
        } catch is CancellationError {
            reset()
        } catch {
            errorMessage = error.localizedDescription
            isPreparing = false
        }
    }

    func reset() {
        player?.pause()
        player = nil
        renderedURL = nil
        preparedInsightID = nil
        progress = 0
        errorMessage = nil
        isPreparing = false
    }

    func loopIfNeeded(_ object: Any?) {
        guard let item = object as? AVPlayerItem,
              item == player?.currentItem else {
            return
        }
        item.seek(to: .zero, completionHandler: nil)
        player?.play()
    }
}

private struct VibeCastAirPlayToolbarButton: View {
    let language: String
    let hasInsight: Bool
    let isPreparing: Bool
    let isReady: Bool

    var body: some View {
        if hasInsight, isReady {
            NativeAirPlayRoutePicker()
                .frame(width: 30, height: 30)
                .accessibilityLabel(localizedKey(language, "ui.airplay.vibecast"))
                .help(localizedKey(language, "ui.send.vibecast.video.to.airplay"))
        } else if hasInsight, isPreparing {
            ProgressView()
                .controlSize(.small)
                .frame(width: 30, height: 30)
                .tint(.primary)
                .accessibilityLabel(localizedKey(language, "ui.preparing.vibecast.video"))
        } else {
            Button {} label: {
                Image(systemName: "airplayvideo")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(true)
            .opacity(0.42)
            .accessibilityLabel(localizedKey(language, "ui.analyze.track.insight.before.using.vibecast"))
            .help(localizedKey(language, "ui.analyze.track.insight.before.using.vibecast"))
        }
    }
}
#endif

#if canImport(AVKit)
private struct VibeCastAVPlayerPreviewSheet: View {
    let insight: TrackInsight
    let language: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var renderedURL: URL?
    @State private var progress = 0.0
    @State private var errorMessage: String?
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VibeCast")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Text(localizedKey(language, "ui.local.avplayer.preview"))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer(minLength: 0)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.82))
                    .background(.white.opacity(0.10), in: Circle())
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.black.opacity(0.36))
                    if let player {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onAppear {
                                player.play()
                            }
                    } else if let errorMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text(errorMessage)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                    } else {
                        VStack(spacing: 12) {
                            ProgressView(value: progress)
                                .tint(djConnectAccent)
                                .frame(maxWidth: 260)
                            Text(localizedKey(language, "ui.rendering.vibecast.video"))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                            Text("\(Int((progress * 100).rounded()))%")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(.white.opacity(0.54))
                        }
                        .padding(20)
                    }
                }
                .aspectRatio(1200.0 / 628.0, contentMode: .fit)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }

                #if os(iOS)
                HStack(spacing: 12) {
                    Label(
                        localizedKey(language, "ui.route.this.vibecast.video.with.airplay"),
                        systemImage: "airplayvideo"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(player == nil ? 0.42 : 0.78))
                    Spacer(minLength: 0)
                    NativeAirPlayRoutePicker()
                        .frame(width: 42, height: 42)
                        .opacity(player == nil ? 0.38 : 1)
                        .disabled(player == nil)
                        .accessibilityLabel(localizedKey(language, "ui.choose.airplay.display"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
                #endif

                Text(localizedKey(language, "ui.this.mp4.is.played.through.avplayer.use.the.airplay.control"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
            .frame(maxWidth: 860)
        }
        .task(id: insight.id) {
            startRender()
        }
        .onDisappear {
            renderTask?.cancel()
            player?.pause()
            player = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item == player?.currentItem else {
                return
            }
            item.seek(to: .zero, completionHandler: nil)
            player?.play()
        }
    }

    private func startRender() {
        guard renderTask == nil else {
            return
        }
        progress = 0
        errorMessage = nil
        renderTask = Task { @MainActor in
            do {
                let url = try await TrackInsightShareRenderer.renderVideo(
                    insight: insight,
                    format: .linkPreview,
                    language: language
                ) { value in
                    progress = value
                }
                try Task.checkCancellation()
                renderedURL = url
                #if !os(macOS)
                let avPlayer = await makeAirPlayPreviewPlayer(url: url)
                #else
                let item = AVPlayerItem(url: url)
                let avPlayer = AVPlayer(playerItem: item)
                avPlayer.actionAtItemEnd = .none
                avPlayer.allowsExternalPlayback = true
                #endif
                player = avPlayer
                avPlayer.play()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif

private struct AirPlayToolbarButton: View {
    let language: String
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        #if canImport(AVKit) && os(iOS)
        NativeAirPlayRoutePicker()
            .frame(width: 30, height: 30)
            .accessibilityLabel(localizedKey(language, "ui.airplay"))
            .help(airPlayHelpText)
        #elseif canImport(AVKit) && os(macOS)
        NativeAirPlayRoutePicker {
            openWindow(id: "vibecast")
        }
        .frame(width: 30, height: 30)
        .accessibilityLabel(localizedKey(language, "ui.airplay"))
        .help(airPlayHelpText)
        #elseif os(macOS)
        Button {
            openWindow(id: "vibecast")
        } label: {
            Image(systemName: "airplayvideo")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .accessibilityLabel(localizedKey(language, "ui.vibecast"))
        .help(airPlayHelpText)
        #else
        Button {} label: {
            Image(systemName: "airplayvideo")
        }
        .disabled(true)
        .help(localizedKey(language, "ui.vibecast.unavailable"))
        #endif
    }

    private var airPlayHelpText: String {
        #if os(macOS)
        localizedKey(language, "ui.choose.an.airplay.display.for.vibecast")
        #else
        localizedKey(language, "ui.vibecast.via.airplay")
        #endif
    }
}

#if canImport(AVKit) && os(iOS)
private struct NativeAirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        picker.backgroundColor = .clear
        picker.tintColor = .white
        picker.activeTintColor = UIColor(red: 0.72, green: 0.28, blue: 1.0, alpha: 1.0)
        picker.prioritizesVideoDevices = true
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#elseif canImport(AVKit) && os(macOS)
private struct NativeAirPlayRoutePicker: NSViewRepresentable {
    let onActivate: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onActivate: onActivate)
    }

    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        picker.wantsLayer = true
        picker.layer?.backgroundColor = NSColor.clear.cgColor
        let recognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.activate))
        recognizer.delaysPrimaryMouseButtonEvents = false
        picker.addGestureRecognizer(recognizer)
        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        context.coordinator.onActivate = onActivate
    }

    final class Coordinator: NSObject {
        var onActivate: () -> Void

        init(onActivate: @escaping () -> Void) {
            self.onActivate = onActivate
        }

        @objc func activate() {
            onActivate()
        }
    }
}
#endif

private struct TrackVibeVisualizerView: View {
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool

    private var isPlaying: Bool {
        playback?.isPlaying == true
    }

    private var shouldAnimate: Bool {
        isActive && isPlaying
    }

    var body: some View {
        visualizer
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .bottom) {
                TrackVibePhaseSpectrum(profile: profile, progress: playbackPhase(at: Date()).progress)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
    }

    @ViewBuilder
    private var visualizer: some View {
        #if canImport(MetalKit) && (os(iOS) || os(macOS))
        TrackVibeMetalVisualizerView(
            profile: profile,
            playback: playback,
            reduceMotion: reduceMotion,
            isActive: shouldAnimate
        )
        #else
        canvasVisualizer
            .drawingGroup(opaque: true, colorMode: .linear)
        #endif
    }

    @ViewBuilder
    private var canvasVisualizer: some View {
        if !shouldAnimate {
            TrackVibeCanvas(profile: profile, playbackPhase: playbackPhase(at: Date()), liveBeat: 0)
        } else if reduceMotion {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                TrackVibeCanvas(profile: profile, playbackPhase: playbackPhase(at: Date()), liveBeat: 0)
            }
        } else {
            #if os(macOS)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let phase = playbackPhase(at: timeline.date)
                TrackVibeCanvas(
                    profile: profile,
                    playbackPhase: phase,
                    liveBeat: playback?.isPlaying == true ? timeline.date.timeIntervalSinceReferenceDate : phase.positionSeconds
                )
            }
            #else
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let phase = playbackPhase(at: timeline.date)
                TrackVibeCanvas(
                    profile: profile,
                    playbackPhase: phase,
                    liveBeat: playback?.isPlaying == true ? timeline.date.timeIntervalSinceReferenceDate : phase.positionSeconds
                )
            }
            #endif
        }
    }

    private func playbackPhase(at date: Date) -> TrackVibePlaybackPhase {
        TrackVibePlaybackPhase(playback: playback, date: date)
    }
}

#if canImport(MetalKit) && (os(iOS) || os(macOS))
#if os(iOS)
private struct TrackVibeMetalVisualizerView: UIViewRepresentable {
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool

    func makeCoordinator() -> TrackVibeMetalRenderer {
        TrackVibeMetalRenderer()
    }

    func makeUIView(context: Context) -> MTKView {
        makeView(context: context)
    }

    func updateUIView(_ view: MTKView, context: Context) {
        update(view, context: context)
    }
}
#elseif os(macOS)
private struct TrackVibeMetalVisualizerView: NSViewRepresentable {
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool

    func makeCoordinator() -> TrackVibeMetalRenderer {
        TrackVibeMetalRenderer()
    }

    func makeNSView(context: Context) -> MTKView {
        makeView(context: context)
    }

    func updateNSView(_ view: MTKView, context: Context) {
        update(view, context: context)
    }
}
#endif

private extension TrackVibeMetalVisualizerView {
    func makeView(context: Context) -> MTKView {
        let device = MTLCreateSystemDefaultDevice()
        let view = MTKView(frame: .zero, device: device)
        view.delegate = context.coordinator
        view.framebufferOnly = true
        view.clearColor = MTLClearColor(red: 0.015, green: 0.018, blue: 0.045, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        context.coordinator.configure(device: view.device, colorPixelFormat: view.colorPixelFormat)
        update(view, context: context)
        return view
    }

    func update(_ view: MTKView, context: Context) {
        context.coordinator.profile = profile
        context.coordinator.playback = playback
        context.coordinator.reduceMotion = reduceMotion
        view.preferredFramesPerSecond = reduceMotion ? 1 : 60
        view.isPaused = !isActive
        if !isActive || reduceMotion {
            view.draw()
        }
    }
}

private final class TrackVibeMetalRenderer: NSObject, MTKViewDelegate {
    var profile: TrackVibeProfile?
    var playback: DJConnectPlayback?
    var reduceMotion = false

    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?
    private let startDate = Date()

    func configure(device: MTLDevice?, colorPixelFormat: MTLPixelFormat) {
        guard pipelineState == nil, let device else { return }
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float4 color;
        };

        vertex VertexOut vertex_main(const device float *data [[buffer(0)]], uint vertexID [[vertex_id]]) {
            uint base = vertexID * 6;
            VertexOut out;
            out.position = float4(data[base], data[base + 1], 0.0, 1.0);
            out.color = float4(data[base + 2], data[base + 3], data[base + 4], data[base + 5]);
            return out;
        }

        fragment float4 fragment_main(VertexOut in [[stage_in]]) {
            return in.color;
        }
        """
        do {
            let library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            commandQueue = device.makeCommandQueue()
        } catch {
            pipelineState = nil
            commandQueue = nil
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState,
              let commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
              let device = view.device else {
            return
        }

        let vertices = makeVertices(size: view.drawableSize)
        guard !vertices.isEmpty,
              let buffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<Float>.stride,
                options: .storageModeShared
              ) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count / 6)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeVertices(size: CGSize) -> [Float] {
        guard size.width > 0, size.height > 0 else { return [] }
        let profile = profile
        let phase = TrackVibePlaybackPhase(playback: playback, date: Date())
        let elapsed = reduceMotion ? phase.positionSeconds : Date().timeIntervalSince(startDate)
        let songTime = phase.positionSeconds
        let progress = phase.progress
        let waveform = Float(profile?.waveform ?? 0.8)
        let glow = Float(profile?.glow ?? 0.7)
        var vertices: [Float] = []
        vertices.reserveCapacity(6 * (6 + 2 + 90))

        addGradientQuad(to: &vertices)
        addOrb(to: &vertices, progress: Float(progress), elapsed: Float(elapsed), glow: glow)
        addBars(to: &vertices, songTime: Float(songTime), progress: Float(progress), waveform: waveform)
        addBottomFade(to: &vertices)
        return vertices
    }

    private func addGradientQuad(to vertices: inout [Float]) {
        appendQuad(
            to: &vertices,
            x0: -1, y0: -1, x1: 1, y1: 1,
            colors: [
                SIMD4<Float>(0.02, 0.02, 0.07, 1.0),
                SIMD4<Float>(0.14, 0.22, 0.56, 1.0),
                SIMD4<Float>(0.03, 0.05, 0.10, 1.0),
                SIMD4<Float>(0.00, 0.02, 0.03, 1.0)
            ]
        )
    }

    private func addOrb(to vertices: inout [Float], progress: Float, elapsed: Float, glow: Float) {
        let centerX = -0.64 + progress * 1.28 + sin(elapsed * 0.7) * 0.08
        let centerY = 0.24 + cos(elapsed * 0.45) * 0.08
        let size = 0.42 + glow * 0.18
        appendQuad(
            to: &vertices,
            x0: centerX - size,
            y0: centerY - size * 0.7,
            x1: centerX + size,
            y1: centerY + size * 0.7,
            color: SIMD4<Float>(0.34, 0.32, 1.0, 0.18 + glow * 0.12)
        )
    }

    private func addBars(to vertices: inout [Float], songTime: Float, progress: Float, waveform: Float) {
        let barCount = 82
        let startX: Float = -0.45
        let endX: Float = 0.48
        let width = (endX - startX) / Float(barCount)
        let baseY: Float = -0.70
        for index in 0..<barCount {
            let t = Float(index) / Float(max(1, barCount - 1))
            let x = startX + Float(index) * width
            let distance = abs(t - progress)
            let playheadBoost = max(0, 1 - distance * 7)
            let signal = (sin(Float(index) * 0.57 + songTime * 2.1) + 1) * 0.5
            let height = 0.05 + (signal * 0.16 + playheadBoost * 0.22) * max(0.35, waveform)
            let color = interpolatedBarColor(t: t, boost: playheadBoost)
            appendQuad(
                to: &vertices,
                x0: x,
                y0: baseY,
                x1: x + width * 0.42,
                y1: baseY + height,
                color: color
            )
        }
    }

    private func addBottomFade(to vertices: inout [Float]) {
        appendQuad(
            to: &vertices,
            x0: -1, y0: -1, x1: 1, y1: -0.42,
            colors: [
                SIMD4<Float>(0.0, 0.0, 0.0, 0.70),
                SIMD4<Float>(0.0, 0.0, 0.0, 0.70),
                SIMD4<Float>(0.0, 0.0, 0.0, 0.0),
                SIMD4<Float>(0.0, 0.0, 0.0, 0.0)
            ]
        )
    }

    private func interpolatedBarColor(t: Float, boost: Float) -> SIMD4<Float> {
        let blue = SIMD3<Float>(0.12, 0.43, 1.0)
        let purple = SIMD3<Float>(0.52, 0.24, 1.0)
        let pink = SIMD3<Float>(1.0, 0.18, 0.70)
        let color: SIMD3<Float>
        if t < 0.5 {
            let local = t / 0.5
            color = blue * (1 - local) + purple * local
        } else {
            let local = (t - 0.5) / 0.5
            color = purple * (1 - local) + pink * local
        }
        return SIMD4<Float>(color.x, color.y, color.z, 0.42 + boost * 0.42)
    }

    private func appendQuad(to vertices: inout [Float], x0: Float, y0: Float, x1: Float, y1: Float, color: SIMD4<Float>) {
        appendQuad(to: &vertices, x0: x0, y0: y0, x1: x1, y1: y1, colors: [color, color, color, color])
    }

    private func appendQuad(to vertices: inout [Float], x0: Float, y0: Float, x1: Float, y1: Float, colors: [SIMD4<Float>]) {
        let c0 = colors[0]
        let c1 = colors[1]
        let c2 = colors[2]
        let c3 = colors[3]
        appendVertex(to: &vertices, x0, y0, c0)
        appendVertex(to: &vertices, x1, y0, c1)
        appendVertex(to: &vertices, x0, y1, c2)
        appendVertex(to: &vertices, x1, y0, c1)
        appendVertex(to: &vertices, x1, y1, c3)
        appendVertex(to: &vertices, x0, y1, c2)
    }

    private func appendVertex(to vertices: inout [Float], _ x: Float, _ y: Float, _ color: SIMD4<Float>) {
        vertices.append(contentsOf: [x, y, color.x, color.y, color.z, color.w])
    }
}
#endif

private struct TrackVibeCanvas: View {
    let profile: TrackVibeProfile
    let playbackPhase: TrackVibePlaybackPhase
    let liveBeat: TimeInterval

    var body: some View {
        Canvas(opaque: true, colorMode: .linear, rendersAsynchronously: true) { context, size in
            draw(context: &context, size: size)
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let colors = profile.colors
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.015, green: 0.018, blue: 0.045),
                colors.first?.opacity(0.34) ?? djConnectAccent.opacity(0.34),
                Color.black
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: size.width, y: size.height)
        ))

        let songTime = playbackPhase.positionSeconds
        let progress = playbackPhase.progress
        let energyLift = playbackPhase.energyLift
        let pulse = sin((songTime + liveBeat * 0.12) * profile.pulseSpeed) * 0.5 + 0.5
        let horizonY = size.height * 0.54
        let orbRadius = min(size.width, size.height) * (0.15 + pulse * 0.04 + energyLift * 0.07)
        let orbCenter = CGPoint(
            x: size.width * (0.18 + progress * 0.64 + sin(songTime * 0.12) * 0.04),
            y: size.height * (0.40 + cos(songTime * 0.10) * 0.04)
        )
        context.addFilter(.blur(radius: 22 + profile.glow * 14))
        context.fill(
            Path(ellipseIn: CGRect(x: orbCenter.x - orbRadius, y: orbCenter.y - orbRadius, width: orbRadius * 2, height: orbRadius * 2)),
            with: .color((colors.last ?? djConnectAccent).opacity(0.22 + pulse * 0.18 + energyLift * 0.18))
        )
        context.addFilter(.blur(radius: 0))
        for ring in 0..<4 {
            let radius = orbRadius * (0.78 + CGFloat(ring) * 0.18 + CGFloat(pulse) * 0.05)
            context.stroke(
                Path(ellipseIn: CGRect(x: orbCenter.x - radius, y: orbCenter.y - radius, width: radius * 2, height: radius * 2)),
                with: .color((colors[safe: ring] ?? djConnectAccent).opacity(0.40 - Double(ring) * 0.06)),
                lineWidth: 1.3
            )
        }

        for layer in 0..<9 {
            var path = Path()
            let layerProgress = CGFloat(layer) / 8
            let baseY = horizonY + layerProgress * size.height * 0.34
            path.move(to: CGPoint(x: -20, y: baseY))
            let steps = 72
            for index in 0...steps {
                let progress = CGFloat(index) / CGFloat(steps)
                let x = size.width * progress
                let depth = 1 + layerProgress * 2.4
                let waveA = sin(Double(index) * 0.28 + songTime * profile.animationSpeed + Double(layer) * 0.58)
                let waveB = cos(Double(index) * 0.13 + songTime * 0.42 + Double(layer))
                let y = baseY + CGFloat(waveA) * 18 * profile.waveform * depth * CGFloat(0.72 + energyLift) + CGFloat(waveB) * 8
                path.addLine(to: CGPoint(x: x, y: y))
            }
            let hueColor = colors[safe: layer % max(colors.count, 1)] ?? djConnectAccent
            context.stroke(path, with: .color(hueColor.opacity(0.18 + Double(layer) * 0.045)), lineWidth: 1.1 + layerProgress * 1.6)
        }

        for column in stride(from: 0, through: Int(size.width), by: 7) {
            let x = CGFloat(column)
            let seed = Double(column + 17)
            let distanceFromPlayhead = abs((x / max(size.width, 1)) - progress)
            let playheadBoost = max(0, 1 - distanceFromPlayhead * 6)
            let normalized = (sin(seed * 0.21 + songTime * 1.3) + 1) / 2
            let barSignal = normalized + playheadBoost * 0.72 + energyLift * 0.42
            let height = CGFloat(12 + barSignal * 64 * profile.waveform)
            let top = horizonY - height * 0.55
            var bar = Path()
            bar.move(to: CGPoint(x: x, y: horizonY))
            bar.addLine(to: CGPoint(x: x, y: top))
            context.stroke(bar, with: .color((colors.last ?? djConnectAccent).opacity(0.10 + normalized * 0.14 + playheadBoost * 0.28)), lineWidth: 2)
        }

        let particleCount = max(10, Int(28 * profile.particleDensity))
        for index in 0..<particleCount {
            let seed = Double(index + 1)
            let x = size.width * CGFloat((sin(seed * 12.989 + songTime * profile.particleVelocity) + 1) / 2)
            let y = size.height * CGFloat((cos(seed * 7.233 + songTime * 0.37) + 1) / 2)
            let radius = CGFloat(1.5 + (seed.truncatingRemainder(dividingBy: 4)))
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                with: .color(.white.opacity(0.16 + profile.glow * 0.24))
            )
        }

        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [.clear, .black.opacity(0.72)]),
            startPoint: CGPoint(x: size.width / 2, y: size.height * 0.58),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))
    }
}

private struct TrackHeartbeatIcon: View {
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool

    var body: some View {
        Group {
            if !isActive {
                icon(phase: TrackVibePlaybackPhase(playback: playback, date: Date()), reduceMotion: true)
            } else if reduceMotion {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    icon(phase: TrackVibePlaybackPhase(playback: playback, date: timeline.date), reduceMotion: true)
                }
            } else {
                TimelineView(.animation) { timeline in
                    icon(phase: TrackVibePlaybackPhase(playback: playback, date: timeline.date), reduceMotion: false)
                }
            }
        }
    }

    private func icon(phase: TrackVibePlaybackPhase, reduceMotion: Bool) -> some View {
        let pulse = reduceMotion ? 0.45 : (sin(phase.positionSeconds * profile.pulseSpeed * 1.8) * 0.5 + 0.5)
        let strokeOpacity = 0.12 + pulse * 0.18

        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(profile.gradient)
            .overlay {
                TrackHeartbeatRunner(
                    progress: reduceMotion ? 0.58 : phase.positionSeconds * profile.pulseSpeed * 0.34,
                    pulse: pulse,
                    accent: profile.colors.last ?? djConnectAccent,
                    reduceMotion: reduceMotion
                )
                .padding(24)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
            }
    }
}

private struct TrackHeartbeatRunner: View {
    let progress: Double
    let pulse: Double
    let accent: Color
    let reduceMotion: Bool

    private let points = [
        CGPoint(x: 0.04, y: 0.54),
        CGPoint(x: 0.28, y: 0.54),
        CGPoint(x: 0.38, y: 0.22),
        CGPoint(x: 0.50, y: 0.82),
        CGPoint(x: 0.60, y: 0.38),
        CGPoint(x: 0.69, y: 0.54),
        CGPoint(x: 0.96, y: 0.54)
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let path = heartbeatPath(in: size)
            let dot = point(at: progress, in: size)
            let dotRadius = max(5, min(size.width, size.height) * 0.075)
            let bounce = reduceMotion ? 0 : CGFloat(sin(progress * .pi * 2)) * -2

            ZStack {
                path
                    .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    .blur(radius: 7)
                path
                    .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                path
                    .trim(from: 0, to: CGFloat(reduceMotion ? 1 : normalizedProgress))
                    .stroke(
                        LinearGradient(colors: [.white, accent.opacity(0.95)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: accent.opacity(0.64), radius: 12)

                Circle()
                    .fill(.white)
                    .frame(width: dotRadius * 2, height: dotRadius * 2)
                    .overlay {
                        Circle()
                            .stroke(accent.opacity(0.72), lineWidth: 2)
                    }
                    .shadow(color: .white.opacity(0.74), radius: 8)
                    .shadow(color: accent.opacity(0.82), radius: 18)
                    .position(x: dot.x, y: dot.y + bounce)
                    .opacity(reduceMotion ? 0.88 : 0.9 + pulse * 0.1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var normalizedProgress: Double {
        progress - floor(progress)
    }

    private func heartbeatPath(in size: CGSize) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let mapped = CGPoint(x: point.x * size.width, y: point.y * size.height)
            if index == 0 {
                path.move(to: mapped)
            } else {
                path.addLine(to: mapped)
            }
        }
        return path
    }

    private func point(at progress: Double, in size: CGSize) -> CGPoint {
        let t = normalizedProgress
        let segmentLengths = zip(points, points.dropFirst()).map { lhs, rhs in
            hypot(rhs.x - lhs.x, rhs.y - lhs.y)
        }
        let totalLength = segmentLengths.reduce(0, +)
        var remaining = t * totalLength

        for index in segmentLengths.indices {
            let length = segmentLengths[index]
            if remaining <= length {
                let local = length == 0 ? 0 : remaining / length
                let lhs = points[index]
                let rhs = points[index + 1]
                return CGPoint(
                    x: (lhs.x + (rhs.x - lhs.x) * local) * size.width,
                    y: (lhs.y + (rhs.y - lhs.y) * local) * size.height
                )
            }
            remaining -= length
        }

        let fallback = points.last ?? .zero
        return CGPoint(x: fallback.x * size.width, y: fallback.y * size.height)
    }
}

private struct TrackVibePlaybackPhase {
    let progress: Double
    let positionSeconds: TimeInterval
    let energyLift: Double

    init(playback: DJConnectPlayback?, date: Date) {
        let durationMS = max(playback?.durationMS ?? 0, 0)
        let progressMS = max(playback?.progressMS ?? 0, 0)
        let durationSeconds = durationMS > 0 ? Double(durationMS) / 1_000 : 240
        let basePositionSeconds = Double(progressMS) / 1_000
        let liveFraction = playback?.isPlaying == true
            ? date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
            : 0
        let positionSeconds = min(basePositionSeconds + liveFraction, durationSeconds)
        let progress = durationSeconds > 0 ? min(max(positionSeconds / durationSeconds, 0), 1) : 0
        let phrase = sin(progress * .pi * 10)
        let section = sin(progress * .pi * 2 - .pi / 2) * 0.5 + 0.5

        self.progress = progress
        self.positionSeconds = positionSeconds
        self.energyLift = max(0, min(1, 0.28 + phrase * 0.18 + section * 0.54))
    }
}

private struct TrackVibePhaseSpectrum: View {
    let profile: TrackVibeProfile
    let progress: Double
    var sectionTitles: [String] = []

    private var visibleSectionTitles: [String] {
        sectionTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<64, id: \.self) { index in
                    let base = profile.spectrumProfile[index % profile.spectrumProfile.count]
                    let position = Double(index) / 63
                    let playheadBoost = max(0, 1 - abs(position - progress) * 9)
                    let lift = sin(Double(index) * 0.31 + progress * .pi * 8) * 0.5 + 0.5
                    let opacity = 0.56 + playheadBoost * 0.38
                    let heightSignal = base * (0.55 + lift * 0.55) + playheadBoost * 0.82
                    let height = 5 + CGFloat(heightSignal) * 36
                    let color = Color(hue: 0.60 + Double(index) / 170, saturation: 0.85, brightness: 1.0)
                    Capsule()
                        .fill(color.opacity(opacity))
                        .frame(width: 3, height: height)
                }
            }
            if !visibleSectionTitles.isEmpty {
                HStack {
                    ForEach(visibleSectionTitles, id: \.self) { phase in
                        Text(phase)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                        if phase != visibleSectionTitles.last {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}

private extension TrackVibePhaseSpectrum {
    func sections(_ sections: [TrackInsightSection]) -> TrackVibePhaseSpectrum {
        var copy = self
        copy.sectionTitles = sections.map(\.title)
        return copy
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct TrackInsightMetricsGrid: View {
    let insight: TrackInsight
    let language: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 10, alignment: .top)], spacing: 10) {
            TrackInsightMetricPill(title: "BPM", value: insight.bpm.map { String(Int($0.rounded())) })
            TrackInsightMetricPill(title: localizedKey(language, "ui.key"), value: insight.key)
            TrackInsightMetricPill(title: localizedKey(language, "ui.genre"), value: insight.genre)
            TrackInsightMetricPill(title: localizedKey(language, "ui.mood"), value: insight.mood)
            TrackInsightMetricPill(title: localizedKey(language, "ui.energy"), value: percent(insight.energy))
            TrackInsightMetricPill(title: localizedKey(language, "ui.dance"), value: percent(insight.danceability))
            TrackInsightMetricPill(title: localizedKey(language, "ui.intensity"), value: percent(insight.intensity))
            TrackInsightMetricPill(title: localizedKey(language, "ui.vibe"), value: insight.vibe)
            TrackInsightMetricPill(title: localizedKey(language, "ui.texture"), value: insight.texture)
        }
    }

    private func percent(_ value: Double?) -> String? {
        value.map { "\(Int(($0 * 100).rounded()))%" }
    }
}

private struct TrackInsightMetricPill: View {
    let title: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(value?.isEmpty == false ? value! : "-")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(minHeight: 74, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TrackInsightAnalysisCard: View {
    let insight: TrackInsight
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedKey(language, "watch.track.energy"))
                .font(.headline.weight(.semibold))
            Text(insight.summary)
                .font(.body)
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            let groups = insight.structuredAnalysisGroups(language: language)
            if !groups.isEmpty {
                Divider().overlay(.white.opacity(0.16))
                ForEach(groups.prefix(8)) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                        ForEach(section.values.prefix(5), id: \.self) { value in
                            Text(value)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .djConnectGradientCard(cornerRadius: 8)
    }
}

private struct TrackInsightStructuredGroup: Identifiable {
    let id: String
    let title: String
    let values: [String]
}

private extension TrackInsight {
    func structuredAnalysisGroups(language: String) -> [TrackInsightStructuredGroup] {
        [
            TrackInsightStructuredGroup(id: "production", title: localizedKey(language, "ui.production"), values: productionNotes),
            TrackInsightStructuredGroup(id: "instrumentation", title: localizedKey(language, "ui.instrumentation"), values: instrumentation),
            TrackInsightStructuredGroup(id: "arrangement", title: localizedKey(language, "ui.arrangement"), values: arrangementNotes),
            TrackInsightStructuredGroup(id: "listening", title: localizedKey(language, "ui.listening.cues"), values: listeningCues),
            TrackInsightStructuredGroup(
                id: "similar",
                title: localizedKey(language, "ui.similar.tracks"),
                values: similarTracks.map { track in
                    if let reason = track.reason, !reason.isEmpty {
                        return "\(track.title) - \(track.artist): \(reason)"
                    }
                    return "\(track.title) - \(track.artist)"
                }
            )
        ].filter { !$0.values.isEmpty }
    }
}

private struct TrackInsightEmptyState: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(djConnectAccent)
            Text("Track Insight")
                .font(.title2.weight(.bold))
            Text(localizedKey(model.language, "ui.see.what.makes.the.current.track.feel.the.way.it"))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let error = model.trackInsightErrorMessage {
                Text(error)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Button {
                model.analyzeCurrentTrack(open: false)
            } label: {
                Label(localizedKey(model.language, "ui.analyze.track"), systemImage: "sparkles")
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .disabled(model.isLoadingTrackInsight)
            if model.isLoadingTrackInsight {
                ProgressView()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .djConnectGradientCard(cornerRadius: 8)
    }
}

extension TrackVibeProfile {
    var colors: [Color] {
        palette.map { Color(hex: $0) ?? djConnectAccent }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private extension Color {
    init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") {
            raw.removeFirst()
        }
        guard raw.count == 6, let value = Int(raw, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xff) / 255.0,
            green: Double((value >> 8) & 0xff) / 255.0,
            blue: Double(value & 0xff) / 255.0
        )
    }
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
                    if !model.isDemoMode {
                        model.refresh()
                    }
                }
            }
            .navigationTitle(screenTitle(model.language, key: "Now Playing", isDemoMode: model.isDemoMode))
            .navigationBarTitleDisplayMode(.large)
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
                    Text(localizedKey(model.language, "ui.code"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    CopyableValue(
                        text: model.pairingToken,
                        copyLabel: localizedKey(model.language, "ui.copy.pair.code"),
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
                    localizedKey(model.language, "ui.playback.is.unavailable.ncheck.the.spotify.authorization.in.home.assistant"),
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
                .accessibilityLabel(localizedKey(model.language, "ui.playback.available"))
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.75))
                .frame(width: 11, height: 11)
                .shadow(color: Color.secondary.opacity(0.35), radius: 8)
                .frame(width: 22, height: 22)
                .accessibilityLabel(localizedKey(model.language, "ui.playback.unavailable"))
        }
    }

    private var statusTitle: String {
        return switch model.pairingStatus {
        case .paired:
            localizedKey(model.language, "ui.paired")
        case .pairing:
            localizedKey(model.language, "ui.pairing.with.home.assistant")
        case .waitingForHomeAssistantCompletion:
            localizedKey(model.language, "ui.finish.setup.in.home.assistant")
        case .stale:
            localizedKey(model.language, "ui.not.connected.to.home.assistant")
        case .unpaired:
            localizedKey(model.language, "ui.ready.to.pair")
        }
    }

    private var statusSubtitle: String? {
        if model.isDemoMode {
            return localizedKey(model.language, "ui.app.store.preview.without.home.assistant")
        }
        return switch model.pairingStatus {
        case .paired:
            nil
        case .pairing:
            localizedKey(model.language, "ui.enter.this.code.in.the.djconnect.home.assistant")
        case .waitingForHomeAssistantCompletion:
            localizedKey(model.language, "ui.waiting.for.setup.to.be.completed.in.home")
        case .stale:
            localizedKey(model.language, "ui.open.settings.to.reset.or.recover.pairing")
        case .unpaired:
            localizedKey(model.language, "ui.add.your.home.assistant.url.in.settings")
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
        case .waitingForHomeAssistantCompletion:
            "hourglass.circle.fill"
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
        case .waitingForHomeAssistantCompletion:
            .orange
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
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(playback?.trackName ?? localizedKey(model.language, "ui.nothing.playing"))
                            .font(.title2.weight(.bold))
                            .lineLimit(2)
                        Text(playback?.artistName ?? playback?.device?.name ?? localizedKey(model.language, "ui.select.an.output.device"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                    accessibilityLabel: localizedKey(model.language, "ui.previous.track")
                ) {
                    model.sendPlaybackCommand("previous")
                }

                playbackButton(
                    model.isPlaying ? "pause.fill" : "play.fill",
                    size: 66,
                    prominent: true,
                    accessibilityLabel: model.isPlaying ? localizedKey(model.language, "ui.pause") : localizedKey(model.language, "ui.play")
                ) {
                    model.togglePlayback()
                }

                playbackButton(
                    "forward.end.fill",
                    size: 54,
                    accessibilityLabel: localizedKey(model.language, "ui.next.track")
                ) {
                    model.sendPlaybackCommand("next")
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.1.fill")
                    .foregroundStyle(.secondary)
                Slider(value: $model.volume, in: 0...100) { editing in
                    if !editing {
                        DJConnectHaptics.selection()
                        model.commitVolumeChange()
                    }
                }
                .tint(djConnectAccent)
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

                TrackInsightIconButton(model: model)
                    .disabled(!canUsePlayback)

                RepeatModeButton(model: model)
                    .disabled(!canUsePlayback)
            }
        }
        .disabled(!canUsePlayback)
        .opacity(canUsePlayback ? 1 : 0.55)
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .foregroundStyle(.white)
        }
        .buttonStyle(PlaybackControlButtonStyle(isProminent: prominent))
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
                        localizedKey(model.language, "ui.playback.is.unavailable.ncheck.the.spotify.authorization.in.home.assistant"),
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

                VStack(alignment: .leading, spacing: 6) {
                    setupDetailRow(
                        localizedKey(model.language, "ui.route"),
                        connectionModeTitle
                    )
                    setupDetailRow(
                        localizedKey(model.language, "ui.backend"),
                        backendTitle
                    )
                    setupDetailRow(
                        localizedKey(model.language, "ui.playback"),
                        playbackTitle
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func setupDetailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .fontWeight(.semibold)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
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
        case .waitingForHomeAssistantCompletion:
            "hourglass.circle"
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
        case .waitingForHomeAssistantCompletion:
            .orange
        case .stale:
            .orange
        case .unpaired:
            .secondary
        }
    }

    private var statusDotLabel: String {
        guard model.isConnected else {
            return localizedKey(model.language, "ui.disconnected")
        }
        guard model.backendAvailable else {
            return localizedKey(model.language, "ui.playback.unavailable")
        }
        return localizedKey(model.language, "ui.connected")
    }

    private var statusTitle: String {
        if model.isDemoMode {
            return localizedKey(model.language, "ui.demo.mode")
        }
        return switch model.pairingStatus {
        case .paired:
            localizedKey(model.language, "ui.paired")
        case .pairing:
            localizedKey(model.language, "ui.pairing.with.home.assistant")
        case .waitingForHomeAssistantCompletion:
            localizedKey(model.language, "ui.finish.setup.in.home.assistant")
        case .stale:
            localizedKey(model.language, "ui.not.connected.to.home.assistant")
        case .unpaired:
            localizedKey(model.language, "ui.ready.to.pair")
        }
    }

    private var connectionModeTitle: String {
        if model.isDemoMode {
            return localizedKey(model.language, "ui.local.demo.mode")
        }
        return switch model.haConnectionMode {
        case .local:
            localizedKey(model.language, "ui.local.home.assistant")
        case .remote:
            localizedKey(model.language, "ui.remote.home.assistant")
        case .offline:
            localizedKey(model.language, "ui.offline")
        }
    }

    private var backendTitle: String {
        let name = model.musicBackendSummary.musicBackendName
            ?? model.musicBackendSummary.musicBackend
            ?? localizedKey(model.language, "ui.not.reported")
        guard let available = model.musicBackendSummary.musicBackendAvailable else {
            return name
        }
        return available
            ? localizedKey(model.language, "ui.value.available", arguments: name)
            : localizedKey(model.language, "ui.value.unavailable", arguments: name)
    }

    private var playbackTitle: String {
        guard model.pairingStatus == .paired || model.isDemoMode else {
            return localizedKey(model.language, "ui.locked.until.pairing")
        }
        guard model.canUsePlaybackFeatures else {
            return localizedKey(model.language, "ui.unavailable")
        }
        if model.playback?.hasPlayback == true {
            return model.isPlaying
                ? localizedKey(model.language, "ui.playing")
                : localizedKey(model.language, "ui.paused")
        }
        return localizedKey(model.language, "ui.no.active.playback")
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
                Text(playback?.trackName ?? localizedKey(model.language, "ui.nothing.playing.13ae37"))
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(playback?.artistName ?? playback?.device?.name ?? localizedKey(model.language, "ui.select.an.output.device"))
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
            .accessibilityLabel(localizedKey(model.language, "ui.playback.position"))

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
            .help(localizedKey(model.language, "ui.back.15.seconds"))
            .accessibilityLabel(localizedKey(model.language, "ui.back.15.seconds"))

            Button {
                DJConnectHaptics.impact()
                model.seekRelative(milliseconds: seekStepMS)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 48, height: 44)
                    .foregroundStyle(.white)
            }
            .help(localizedKey(model.language, "ui.forward.15.seconds"))
            .accessibilityLabel(localizedKey(model.language, "ui.forward.15.seconds"))
        }
        .buttonStyle(PlaybackControlButtonStyle())
        .disabled(!canSeek)
        .opacity(canSeek ? 1 : 0.45)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct TrackInsightIconButton: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        Button {
            DJConnectHaptics.selection()
            model.analyzeCurrentTrack(open: true)
        } label: {
            if model.isLoadingTrackInsight {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 44, height: 40)
            } else {
                TrackInsightPulseIcon()
                    .stroke(style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(model.currentTrackInsight == nil ? .white.opacity(0.68) : djConnectAccent)
                    .frame(width: 27, height: 23)
                    .frame(width: 44, height: 40)
            }
        }
        .buttonStyle(PlaybackControlButtonStyle(isActive: model.currentTrackInsight != nil))
        .disabled(model.isLoadingTrackInsight || !model.canStartTrackInsightAnalysis)
        .opacity(model.canStartTrackInsightAnalysis ? 1 : 0.45)
        .accessibilityLabel(localizedKey(model.language, "ui.open.track.insight"))
        .accessibilityHint(localizedKey(model.language, "ui.sends.the.current.track.to.the.backend.for.analysis.and"))
        .help(localizedKey(model.language, "ui.track.insight"))
    }
}

private struct TrackInsightPulseIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width
        let height = rect.height
        path.move(to: CGPoint(x: rect.minX + width * 0.02, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + width * 0.24, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + width * 0.34, y: rect.minY + height * 0.26))
        path.addLine(to: CGPoint(x: rect.minX + width * 0.46, y: rect.maxY - height * 0.18))
        path.addLine(to: CGPoint(x: rect.minX + width * 0.56, y: rect.minY + height * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + width * 0.66, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + width * 0.98, y: midY))
        return path
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
                        .foregroundStyle(.white)
                }
                .buttonStyle(PlaybackControlButtonStyle())
                .help(localizedKey(model.language, "ui.previous"))
                .accessibilityLabel(localizedKey(model.language, "ui.previous.track"))
                .disabled(!canUsePlayback)

                Button {
                    DJConnectHaptics.impact()
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 50, height: 44)
                        .foregroundStyle(.white)
                }
                .buttonStyle(PlaybackControlButtonStyle(isProminent: true))
                .help(model.isPlaying ? localizedKey(model.language, "ui.pause") : localizedKey(model.language, "ui.play"))
                .accessibilityLabel(model.isPlaying ? localizedKey(model.language, "ui.pause") : localizedKey(model.language, "ui.play"))
                .disabled(!canUsePlayback)

                Button {
                    DJConnectHaptics.impact()
                    model.sendPlaybackCommand("next")
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 44, height: 40)
                        .foregroundStyle(.white)
                }
                .buttonStyle(PlaybackControlButtonStyle())
                .help(localizedKey(model.language, "ui.next"))
                .accessibilityLabel(localizedKey(model.language, "ui.next.track"))
                .disabled(!canUsePlayback)
            }

            HStack {
                Image(systemName: "speaker.wave.1")
                Slider(value: $model.volume, in: 0...100) { editing in
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

                TrackInsightIconButton(model: model)
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
            ? localizedKey(model.language, "ui.remove.from.favorites")
            : localizedKey(model.language, "ui.add.to.favorites")
    }

    var body: some View {
        Button {
            DJConnectHaptics.selection()
            model.toggleCurrentTrackFavorite()
        } label: {
            if model.isSavingCurrentTrack {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 44, height: 40)
            } else {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isFavorite ? djConnectAccent : .white)
                    .frame(width: 44, height: 40)
            }
        }
        .buttonStyle(PlaybackControlButtonStyle(isActive: isFavorite))
        .tint(isFavorite ? djConnectAccent : .white)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localizedKey(model.language, "ui.output.device"))
                    .font(.headline)
                Spacer()
            }

            if model.availableOutputs.isEmpty {
                OutputDeviceChoiceRow(
                    language: model.language,
                    output: nil,
                    title: localizedOutputName(model.selectedOutput, language: model.language),
                    isActive: false,
                    isEnabled: false,
                    action: {}
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(model.availableOutputs) { output in
                        OutputDeviceChoiceRow(
                            language: model.language,
                            output: output,
                            title: output.name,
                            isActive: output.active == true,
                            isEnabled: canUsePlayback,
                            action: {
                                guard canUsePlayback else {
                                    return
                                }
                                if output.active != true {
                                    DJConnectHaptics.selection()
                                }
                                model.selectOutput(output)
                            }
                        )
                    }
                }
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

private struct OutputDeviceChoiceRow: View {
    let language: String
    let output: DJConnectOutputDevice?
    let title: String
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var iconName: String {
        switch output?.type?.lowercased() {
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

    private var subtitle: String {
        if isActive {
            return localizedKey(language, "ui.active")
        }
        if let volume = output?.volumePercent {
            return "\(volume)%"
        }
        if let type = output?.type, !type.isEmpty {
            return type
        }
        return localizedKey(language, "ui.output")
    }

    private var activeColor: Color {
        djConnectAccent
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? activeColor : .white.opacity(0.68))
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(isActive ? activeColor.opacity(0.18) : Color.white.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isActive ? activeColor.opacity(0.92) : .white.opacity(0.56))
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(activeColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.10) : Color.white.opacity(0.055))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.white.opacity(0.22) : Color.white.opacity(0.10), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
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
                .foregroundStyle(isShuffling ? djConnectAccent : .white.opacity(0.68))
                .frame(width: 44, height: 40)
        }
        .buttonStyle(PlaybackControlButtonStyle(isActive: isShuffling))
        .help(localizedKey(model.language, "ui.shuffle"))
        .accessibilityLabel(localizedKey(model.language, "ui.shuffle"))
        .accessibilityValue(isShuffling ? localizedKey(model.language, "ui.on") : localizedKey(model.language, "ui.off"))
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
                .foregroundStyle(repeatState == .off ? .white.opacity(0.68) : djConnectAccent)
                .frame(width: 44, height: 40)
        }
        .buttonStyle(PlaybackControlButtonStyle(isActive: repeatState != .off))
        .help(repeatHelpText)
        .accessibilityLabel(localizedKey(model.language, "ui.repeat"))
        .accessibilityValue(repeatState.localizedName(language: model.language))
    }

    private var repeatHelpText: String {
        let state = repeatState.localizedName(language: model.language)
        let next = repeatState.next.localizedName(language: model.language)
        return localizedKey(model.language, "ui.repeat.value.click.for.value", arguments: state, next)
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
            localizedKey(language, "ui.off")
        case .track:
            localizedKey(language, "ui.track")
        case .context:
            localizedKey(language, "ui.context")
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
                            if !model.isDemoMode {
                                await model.refreshAskDJHistory()
                            }
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
                                .help(localizedKey(model.language, "ui.scroll.to.bottom"))
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
                .padding(.bottom, 8)
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
            .navigationTitle(screenTitle(model.language, key: "Ask DJ", isDemoMode: model.isDemoMode))
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        toggleAskDJSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(isSearchVisible ? djConnectAccent : .primary)
                    }
                    .help(localizedKey(model.language, "ui.search.ask.dj"))
                    .accessibilityLabel(localizedKey(model.language, "ui.search.ask.dj"))

                    askDJMoodToolbarButton

                    Button {
                        isInputFocused = false
                        Task {
                            if !model.isDemoMode {
                                await model.refreshAskDJHistory()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(model.isDemoMode ? .secondary : .primary)
                    }
                    .tint(.primary)
                    .disabled(model.isDemoMode || model.isClearingAskDJHistory)
                    .help(localizedKey(model.language, "ui.refresh.ask.dj"))
                    .accessibilityLabel(localizedKey(model.language, "ui.refresh.ask.dj"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isInputFocused = false
                        showingClearConfirmation = true
                    } label: {
                        Image(systemName: model.isClearingAskDJHistory ? "hourglass" : "trash")
                    }
                    .disabled(model.askDJMessages.isEmpty || model.isClearingAskDJHistory)
                    .help(localizedKey(model.language, "ui.clear.chat"))
                }
                #else
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        toggleAskDJSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(isSearchVisible ? djConnectAccent : .primary)
                    }
                    .help(localizedKey(model.language, "ui.search.ask.dj"))
                    .accessibilityLabel(localizedKey(model.language, "ui.search.ask.dj"))

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
                    .help(localizedKey(model.language, "ui.clear.chat"))
                    .accessibilityLabel(localizedKey(model.language, "ui.clear.chat"))

                    Button {
                        isInputFocused = false
                        Task {
                            if !model.isDemoMode {
                                await model.refreshAskDJHistory()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(model.isDemoMode ? .secondary : .primary)
                    }
                    .tint(.primary)
                    .disabled(model.isDemoMode || model.isClearingAskDJHistory)
                    .help(localizedKey(model.language, "ui.refresh.ask.dj"))
                    .accessibilityLabel(localizedKey(model.language, "ui.refresh.ask.dj"))
                }
                #endif
            }
            .alert(
                localizedKey(model.language, "ui.clear.ask.dj.chat"),
                isPresented: $showingClearConfirmation
            ) {
                Button(localizedKey(model.language, "ui.clear.chat.9ad354"), role: .destructive) {
                    isInputFocused = false
                    model.clearAskDJHistory()
                }
                Button(localizedKey(model.language, "ui.cancel"), role: .cancel) {}
            } message: {
                Text(localizedKey(model.language, "ui.this.clears.the.ask.dj.chat.history.on.this.home"))
            }
        }
        .background(DJConnectCanvasBackground())
        .onAppear {
            model.presentMusicDNAOptInPromptIfNeeded()
        }
        .task {
            await model.runAskDJHistorySyncLoop()
        }
        .sheet(item: $selectedWebLink) { link in
            AskDJWebPreview(link: link, language: model.language)
        }
        .sheet(item: $feedbackMessage) { message in
            AskDJFeedbackPromptView(model: model, message: message)
            #if os(iOS)
                .presentationDetents([.large])
                .presentationSizing(.page)
            #endif
        }
        .sheet(isPresented: $model.isShowingMusicDNAOptInPrompt) {
            MusicDNAOptInPromptView(model: model)
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
        .help(localizedKey(model.language, "ui.mood"))
        .accessibilityLabel(localizedKey(model.language, "ui.mood"))
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
            .help(localizedKey(language, "ui.previous.result"))
            Button(action: nextAction) {
                Image(systemName: "chevron.down")
            }
            .disabled(resultCount == 0)
            .help(localizedKey(language, "ui.next.result"))
            Button(action: closeAction) {
                Image(systemName: "xmark")
            }
            .help(localizedKey(language, "ui.close.search"))
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
            return localizedKey(language, "ui.0")
        }
        return "\(selectedIndex + 1)/\(resultCount)"
    }

    private var searchPrompt: Text {
        Text(localizedKey(language, "ui.search.value", arguments: scopeName))
    }
}

private struct AskDJEmptyState: View {
    let language: String
    let isRequestingIdleSuggestion: Bool
    let selectExample: (String) -> Void

    private var examples: [String] {
        [
            localizedKey(language, "ui.what.did.i.listen.to.last.week"),
            localizedKey(language, "ui.surprise.me.with.new.music"),
            localizedKey(language, "ui.give.me.track.insight.for.this.song"),
            localizedKey(language, "ui.which.albums.did.this.artist.release"),
            localizedKey(language, "ui.play.something.for.cooking")
        ]
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
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
            Text(localizedKey(language, "ui.ask.dj"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(localizedKey(language, "ui.ask.about.the.music.or.give.your.dj.a.request"))
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

            Text(localizedKey(language, "ui.ask.dj.can.change.the.music.when.you.ask.for"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            if isRequestingIdleSuggestion {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text(localizedKey(language, "ui.finding.something.to.play"))
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
                Text(localizedKey(language, "ui.ask.dj.offline"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(localizedKey(language, "ui.shown.messages.may.be.stale.until.djconnect.is.paired.with"))
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
            return localizedKey(language, "ui.dj.fact")
        }
        return localizedKey(language, "ui.dj.note")
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
                    if !isUser, let trackInsight = message.trackInsight {
                        AskDJTrackInsightSummary(insight: trackInsight, language: language)
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
                            Label(localizedKey(language, "ui.retry"), systemImage: "arrow.clockwise")
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
                            Label(localizedKey(language, "ui.feedback"), systemImage: "exclamationmark.bubble")
                                .font(.caption2.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.58))
                        .help(localizedKey(language, "ui.report.this.ask.dj.answer"))
                        .accessibilityLabel(localizedKey(language, "ui.report.this.ask.dj.answer"))
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
                    Label(localizedKey(language, "ui.set.in.prompt"), systemImage: "text.cursor")
                }
            }
            if canReportFeedback {
                Button {
                    DJConnectHaptics.selection()
                    feedbackAction(message)
                } label: {
                    Label(localizedKey(language, "ui.report.answer"), systemImage: "exclamationmark.bubble")
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
            statusText = localizedKey(language, "ui.sending")
        case .sent:
            statusText = localizedKey(language, "ui.sent")
        case .delivered:
            statusText = localizedKey(language, "ui.sent")
        case .failed:
            statusText = localizedKey(language, "ui.failed")
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
            return localizedKey(language, "ui.loading.audio")
        }
        if isPlaying {
            return localizedKey(language, "ui.stop.dj.response")
        }
        return localizedKey(language, "ui.play.dj.response")
    }
}

private struct AskDJTrackInsightSummary: View {
    let insight: TrackInsight
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Track Insight", systemImage: "waveform.path.ecg")
                .font(.caption.weight(.semibold))
                .foregroundStyle(djConnectAccent)
            Text(insight.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(insight.summary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(3)
            HStack(spacing: 8) {
                if let genre = insight.genre {
                    Text(genre)
                }
                if let bpm = insight.bpm {
                    Text("\(Int(bpm.rounded())) BPM")
                }
                if let key = insight.key {
                    Text(key)
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityLabel(localizedKey(language, "ui.track.insight.preview"))
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
                        Text(localizedKey(language, "ui.speaker"))
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
                        Text(localizedKey(language, "ui.speaker"))
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
        return localizedKey(language, "ui.speaker")
    }

    private func buttonLabel(for action: DJConnectAskDJPlaybackAction) -> String {
        if action.isActiveOutputAction {
            return localizedKey(language, "ui.active")
        }
        if action.isOutputAction {
            return localizedKey(language, "ui.activate")
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
            return localizedKey(language, "ui.yes.please")
        }
        if responseValue == "no" {
            return localizedKey(language, "ui.no.thanks")
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
            return localizedKey(language, "ui.track")
        case .album:
            return localizedKey(language, "ui.album")
        case .playlist:
            return localizedKey(language, "ui.playlist")
        case .podcast:
            return localizedKey(language, "ui.podcast")
        case .artist:
            return localizedKey(language, "ui.artist")
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
            Text(localizedKey(language, "ui.sources"))
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
        link.title?.isEmpty == false ? link.title! : link.url.host ?? localizedKey(language, "ui.link")
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
                    Button(localizedKey(language, "ui.open.in.browser")) {
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
                    Button(localizedKey(language, "ui.done")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openURL(link.url)
                    } label: {
                        Label(localizedKey(language, "ui.open.in.browser"), systemImage: "safari")
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
                Text(localizedKey(model.language, "ui.mood"))
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
                    .help(localizedKey(model.language, "ui.close"))
                    .accessibilityLabel(localizedKey(model.language, "ui.close"))
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

            Text(localizedKey(model.language, "ui.mood.guides.ask.dj.s.recommendations.from.calmer.tracks.to"))
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

                #if os(iOS)
                AskDJPromptTextView(text: $model.askDJDraft, isInputFocused: isInputFocused)
                    .frame(minHeight: 44)
                #else
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
            .help(localizedKey(model.language, "ui.send"))
        }
        .padding(.horizontal, djConnectScreenHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 18)
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

#if os(iOS)
private struct AskDJPromptTextView: UIViewRepresentable {
    @Binding var text: String
    var isInputFocused: FocusState<Bool>.Binding

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.tintColor = UIColor(djConnectAccent)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 11, left: 10, bottom: 11, right: 10)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
            context.coordinator.moveCaretToEnd(in: textView)
        }

        if isInputFocused.wrappedValue {
            if !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
            context.coordinator.moveCaretToEnd(in: textView)
        } else if textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 240
        let fittingSize = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: min(max(fittingSize.height, 44), 104))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isInputFocused: isInputFocused)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var isInputFocused: FocusState<Bool>.Binding

        init(text: Binding<String>, isInputFocused: FocusState<Bool>.Binding) {
            _text = text
            self.isInputFocused = isInputFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isInputFocused.wrappedValue = true
            moveCaretToEnd(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isInputFocused.wrappedValue = false
        }

        func moveCaretToEnd(in textView: UITextView) {
            let end = textView.endOfDocument
            textView.selectedTextRange = textView.textRange(from: end, to: end)
        }
    }
}
#endif

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
        .accessibilityHint(localizedKey(model.language, "ui.hold.to.record.a.voice.request.for.ask.dj"))
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
            return localizedKey(model.language, "ui.processing.voice.request")
        }
        if isActive {
            return localizedKey(model.language, "ui.release.to.send")
        }
        return localizedKey(model.language, "ui.hold.to.talk")
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
                            title: localizedKey(model.language, "ui.no.queue"),
                            systemImage: "music.note.list"
                        )
                        .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(Array(model.queueItems.enumerated()), id: \.offset) { index, item in
                            Button {
                                DJConnectHaptics.impact()
                                showStatusToast(localizedKey(model.language, "ui.track.is.starting"))
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
            .navigationTitle(screenTitle(model.language, key: "Queue", isDemoMode: model.isDemoMode))
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
                    .help(localizedKey(model.language, "ui.reload.queue"))
                    .accessibilityLabel(localizedKey(model.language, "ui.reload.queue"))
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
                        title: localizedKey(model.language, "ui.no.queue"),
                        systemImage: "music.note.list"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                } else {
                    ForEach(Array(model.queueItems.enumerated()), id: \.offset) { index, item in
                        Button {
                            DJConnectHaptics.impact()
                            showStatusToast(localizedKey(model.language, "ui.track.is.starting"))
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
                            title: localizedKey(model.language, "ui.no.playlists"),
                            systemImage: "rectangle.stack"
                        )
                        .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(model.playlistItems) { playlist in
                            Button {
                                DJConnectHaptics.impact()
                                showStatusToast(localizedKey(model.language, "ui.playlist.is.starting"))
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
            .navigationTitle(screenTitle(model.language, key: "ui.playlists", isDemoMode: model.isDemoMode))
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
                    .help(localizedKey(model.language, "ui.reload.playlists"))
                    .accessibilityLabel(localizedKey(model.language, "ui.reload.playlists"))
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
                        title: localizedKey(model.language, "ui.no.playlists"),
                        systemImage: "rectangle.stack"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                } else {
                    ForEach(model.playlistItems) { playlist in
                        Button {
                            DJConnectHaptics.impact()
                            showStatusToast(localizedKey(model.language, "ui.playlist.is.starting"))
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedGame = LocalGameMode.pong

    private func contentMaxWidth(for size: CGSize) -> CGFloat {
        #if os(macOS)
        size.width >= 1_000 ? 1_280 : djConnectContentMaxWidth
        #else
        horizontalSizeClass == .regular && size.width > size.height ? 1_320 : djConnectContentMaxWidth
        #endif
    }

    private func pickerMaxWidth(for size: CGSize) -> CGFloat {
        min(contentMaxWidth(for: size), 760)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let contentMaxWidth = contentMaxWidth(for: proxy.size)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GameModePicker(selection: $selectedGame)
                            .frame(maxWidth: pickerMaxWidth(for: proxy.size))
                            .frame(maxWidth: .infinity, alignment: .center)

                        LocalGameSurface(game: selectedGame, language: language)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .djConnectScreenPadding()
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(DJConnectCanvasBackground())
            }
            .navigationTitle(localizedKey(language, "ui.games"))
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
    private let gameAspectRatio: CGFloat = 320.0 / 170.0

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
                Text("\(localizedKey(language, "ui.score")) \(score)")
                    .monospacedDigit()
                Text("\(localizedKey(language, "ui.high")) \(highScore)")
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
                        Label(localizedKey(language, "ui.tap.to.play"), systemImage: "play.fill")
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
            .aspectRatio(gameAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
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
        game == .asteroids ? localizedKey(language, "ui.left") : localizedKey(language, "ui.up")
    }

    private var secondaryMoveLabel: String {
        game == .asteroids ? localizedKey(language, "ui.right") : localizedKey(language, "ui.down")
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
            localizedKey(language, "ui.move.the.paddle.and.keep.the.ball.alive")
        case .asteroids:
            localizedKey(language, "ui.move.left.and.right.fire.to.hit.meteors")
        case .fly:
            localizedKey(language, "ui.fly.through.the.gaps.fire.clears.an.obstacle")
        case .pacman:
            localizedKey(language, "ui.eat.dots.and.dodge.the.ghost")
        }
    }

    @ViewBuilder
    private var controlsView: some View {
        if game == .pacman {
            LazyVGrid(columns: controlColumns(count: 5), spacing: 10) {
                directionButton(localizedKey(language, "ui.up"), icon: "chevron.up") {
                    setPacmanDirection(dx: 0, dy: -1)
                }
                directionButton(localizedKey(language, "ui.down"), icon: "chevron.down") {
                    setPacmanDirection(dx: 0, dy: 1)
                }
                directionButton(localizedKey(language, "ui.left"), icon: "chevron.left") {
                    setPacmanDirection(dx: -1, dy: 0)
                }
                directionButton(localizedKey(language, "ui.right"), icon: "chevron.right") {
                    setPacmanDirection(dx: 1, dy: 0)
                }
                resetButton
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)
        } else {
            LazyVGrid(columns: controlColumns(count: game == .pong ? 3 : 4), spacing: 10) {
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
                        Label(localizedKey(language, "ui.fire"), systemImage: "sparkle")
                            .labelStyle(.iconOnly)
                            .frame(height: 24)
                    }
                    .help(localizedKey(language, "ui.fire"))
                }

                resetButton
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)
        }
    }

    private func controlColumns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 96), spacing: 10), count: count)
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
            Label(localizedKey(language, "ui.reset"), systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .frame(height: 24)
        }
        .help(localizedKey(language, "ui.reset"))
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
                        title: "Music DNA",
                        systemImage: "heart"
                    ) {
                        MusicDNAView(model: model)
                    }
                    MoreNavigationRow(
                        title: localizedKey(model.language, "ui.playlists"),
                        systemImage: "rectangle.stack"
                    ) {
                        PlaylistsView(model: model)
                    }
                    MoreNavigationRow(
                        title: localizedKey(model.language, "ui.games"),
                        systemImage: "gamecontroller"
                    ) {
                        GamesView(language: model.language, isDemoMode: model.isDemoMode)
                    }
                    MoreNavigationRow(
                        title: localizedKey(model.language, "ui.settings"),
                        systemImage: "gearshape"
                    ) {
                        SettingsView(model: model, returnToNowPlaying: returnToNowPlaying)
                    }
                    MoreNavigationRow(
                        title: localizedKey(model.language, "ui.logs"),
                        systemImage: "doc.text.magnifyingglass"
                    ) {
                        LogsView(model: model)
                    }
                    MoreNavigationRow(
                        title: localizedKey(model.language, "ui.about"),
                        systemImage: "info.circle"
                    ) {
                        AboutView(model: model)
                    }
                    MoreNavigationRow(
                        title: localizedKey(model.language, "ui.legal"),
                        systemImage: "doc.text"
                    ) {
                        LegalNoticesView(language: model.language)
                    }
                    MoreNavigationRow(
                        title: localizedKey(model.language, "ui.privacy"),
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
                                .foregroundStyle(djConnectAccent)
                                .frame(width: 30)
                            Text(localizedKey(model.language, "ui.share.feedback"))
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
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
            .navigationTitle(screenTitle(model.language, key: "More", isDemoMode: model.isDemoMode))
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
    @State private var isShowingMusicDNADisableConfirmation = false
    @State private var isShowingMusicDNAClearConfirmation = false

    private var musicDNAEnabled: Bool {
        model.musicDNAProfileResponse?.enabled == true
    }

    private var musicDNAHowItWorksText: String {
        if musicDNAEnabled {
            return localizedKey(model.language, "ui.music.dna.is.enabled.home.assistant.can.use.future.listening")
        }
        if model.musicDNAProfileResponse?.enabled == false {
            return localizedKey(model.language, "ui.music.dna.is.disabled.no.listening.profile.is.being.built")
        }
        return localizedKey(model.language, "ui.djconnect.is.still.checking.the.current.music.dna.status")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                List {
                Section(localizedKey(model.language, "ui.app")) {
                    Picker(localizedKey(model.language, "ui.app.language"), selection: $model.appLanguageSelectionCode) {
                        Text(localizedKey(model.language, "ui.system.language")).tag("")
                        ForEach(DJConnectLocalization.supportedLanguageCodes, id: \.self) { code in
                            Text(DJConnectLocalization.nativeLanguageName(for: code)).tag(code)
                        }
                    }
                    if model.isDemoMode {
                        LabeledContent(localizedKey(model.language, "ui.demo.mode")) {
                            Button(localizedKey(model.language, "ui.stop.demo.mode"), role: .destructive) {
                                returnToNowPlaying()
                                model.stopDemoMode()
                            }
                        }
                    }
                    if !model.isDemoMode {
                        LabeledContent(localizedKey(model.language, "ui.pairing")) {
                            Button(role: .destructive) {
                                isShowingResetPairingConfirmation = true
                            } label: {
                                Text(localizedKey(model.language, "ui.pair.app.again"))
                            }
                        }
                    }
                    LabeledContent(localizedKey(model.language, "ui.wakeword")) {
                        if model.wakeWordEnabled {
                            Button {
                                model.setWakeWordEnabled(false)
                            } label: {
                                Text(localizedKey(model.language, "ui.disable.voice.activation"))
                                    .foregroundStyle(djConnectAccent)
                            }
                            .foregroundStyle(djConnectAccent)
                            .tint(djConnectAccent)
                        } else {
                            Button {
                                model.setWakeWordEnabled(true)
                            } label: {
                                Text(localizedKey(model.language, "ui.enable.voice.activation.321a28"))
                                    .foregroundStyle(djConnectAccent)
                            }
                            .foregroundStyle(djConnectAccent)
                            .tint(djConnectAccent)
                        }
                    }
                    wakeWordPhraseField(model)
                    LabeledContent(localizedKey(model.language, "ui.wakeword.status")) {
                        Text(wakeWordStatusText(model))
                            .foregroundStyle(.secondary)
                    }
                    Picker(localizedKey(model.language, "ui.log.level"), selection: $model.logLevel) {
                        Text("Debug").tag("debug")
                        Text("Info").tag("info")
                        Text(localizedKey(model.language, "ui.warning")).tag("warning")
                        Text(localizedKey(model.language, "ui.error")).tag("error")
                    }
                }
                .djSettingsListRowBackground()

                Section("Music DNA") {
                    LabeledContent(localizedKey(model.language, "ui.how.it.works")) {
                        Text(musicDNAHowItWorksText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .djCompactSettingsListRow()

                    LabeledContent("Music DNA") {
                        if musicDNAEnabled {
                            Button(role: .destructive) {
                                isShowingMusicDNADisableConfirmation = true
                            } label: {
                                Text(localizedKey(model.language, "ui.turn.off"))
                            }
                            .disabled(model.isUpdatingMusicDNA || (!model.isDemoMode && model.pairingStatus != .paired))
                        } else {
                            Button {
                                model.showMusicDNAOptInPrompt()
                            } label: {
                                Text(localizedKey(model.language, "ui.turn.on"))
                                    .foregroundStyle(djConnectAccent)
                            }
                            .foregroundStyle(djConnectAccent)
                            .tint(djConnectAccent)
                            .disabled(model.isUpdatingMusicDNA || (!model.isDemoMode && model.pairingStatus != .paired))
                        }
                    }
                    .djCompactSettingsListRow()

                    if musicDNAEnabled {
                        LabeledContent(localizedKey(model.language, "ui.listening.profile")) {
                            Button(role: .destructive) {
                                isShowingMusicDNAClearConfirmation = true
                            } label: {
                                Text(localizedKey(model.language, "ui.clear"))
                            }
                            .disabled(model.isUpdatingMusicDNA || (!model.isDemoMode && model.pairingStatus != .paired))
                        }
                        .djCompactSettingsListRow()
                    }
                }
                .djSettingsSectionTopSpacing()
                .djSettingsListRowBackground()

                Section(localizedKey(model.language, "ui.permissions")) {
                    PermissionStatusRow(
                        title: localizedKey(model.language, "ui.microphone"),
                        detail: localizedKey(model.language, "ui.needed.for.push.to.talk.voice.requests"),
                        status: model.microphonePermissionStatus,
                        language: model.language
                    )
                    PermissionStatusRow(
                        title: localizedKey(model.language, "ui.speech.recognition"),
                        detail: localizedKey(model.language, "ui.needed.for.the.foreground.wake.phrase"),
                        status: model.speechPermissionStatus,
                        language: model.language
                    )
                    PermissionStatusRow(
                        title: localizedKey(model.language, "ui.notifications"),
                        detail: localizedKey(model.language, "ui.needed.for.server.push.notifications.when.ask.dj.answers"),
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
                                    localizedKey(model.language, "ui.request.permissions"),
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
                .djSettingsSectionTopSpacing()
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
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(localizedKey(model.language, "ui.settings"))
            .alert(
                localizedKey(model.language, "ui.pair.app.again.c2c7b2"),
                isPresented: $isShowingResetPairingConfirmation
            ) {
                Button(localizedKey(model.language, "ui.cancel"), role: .cancel) {}
                Button(localizedKey(model.language, "ui.pair.app.again"), role: .destructive) {
                    returnToNowPlaying()
                    model.resetPairing()
                }
            } message: {
                Text(localizedKey(model.language, "ui.this.clears.the.local.djconnect.pairing.and.opens.pairing.setup"))
            }
            .alert(
                localizedKey(model.language, "ui.turn.off.music.dna"),
                isPresented: $isShowingMusicDNADisableConfirmation
            ) {
                Button(localizedKey(model.language, "ui.cancel"), role: .cancel) {}
                Button(localizedKey(model.language, "ui.turn.off"), role: .destructive) {
                    Task { await model.setMusicDNAEnabled(false) }
                }
            } message: {
                Text(localizedKey(model.language, "ui.this.turns.off.music.dna.and.removes.your.listening.profile"))
            }
            .alert(
                localizedKey(model.language, "ui.clear.music.dna"),
                isPresented: $isShowingMusicDNAClearConfirmation
            ) {
                Button(localizedKey(model.language, "ui.cancel"), role: .cancel) {}
                if model.isDemoMode {
                    Button(localizedKey(model.language, "ui.keep.demo.profile")) {
                        Task { await model.clearMusicDNA() }
                    }
                } else {
                    Button(localizedKey(model.language, "ui.clear.music.dna.817df9"), role: .destructive) {
                        Task { await model.clearMusicDNA() }
                    }
                }
            } message: {
                if model.isDemoMode {
                    Text(localizedKey(model.language, "ui.in.the.real.app.this.clears.learned.music.dna.on"))
                } else {
                    Text(localizedKey(model.language, "ui.this.clears.learned.music.dna.on.your.home.assistant.backend"))
                }
            }
            .task {
                model.refreshPermissionStatuses()
                model.startPairingWait()
            }
            #if os(macOS)
            .djConnectMacDetailContent()
            #endif
        }
        .sheet(isPresented: $model.isShowingMusicDNAOptInPrompt) {
            MusicDNAOptInPromptView(model: model)
        }
        .background(DJConnectCanvasBackground())
    }

}

private struct LogsView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
            ? localizedKey(model.language, "ui.close.search")
            : localizedKey(model.language, "ui.search.logs")
    }

    @ViewBuilder
    private var logSearchButtonLabel: some View {
        if horizontalSizeClass == .regular {
            Label(localizedKey(model.language, "ui.search"), systemImage: "magnifyingglass")
        } else {
            Label(logSearchButtonTitle, systemImage: "magnifyingglass")
                .labelStyle(.iconOnly)
        }
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
                        toggleLogSearch()
                    } label: {
                        logSearchButtonLabel
                            .foregroundStyle(djConnectAccent)
                    }
                    .tint(djConnectAccent)
                    .foregroundStyle(djConnectAccent)
                    .help(logSearchButtonTitle)
                    .accessibilityLabel(logSearchButtonTitle)
                    .disabled(model.diagnosticLogLines.isEmpty)

                    Button {
                        copyText(model.diagnosticExportText())
                        showStatusToast(localizedKey(model.language, "ui.logs.copied.to.clipboard"))
                    } label: {
                        Label(localizedKey(model.language, "ui.copy.logs"), systemImage: "doc.on.doc")
                            .foregroundStyle(djConnectAccent)
                    }
                    .tint(djConnectAccent)
                    .foregroundStyle(djConnectAccent)
                    .disabled(model.diagnosticLogLines.isEmpty)

                    Spacer()

                    Button {
                        showingClearConfirmation = true
                    } label: {
                        Label(localizedKey(model.language, "ui.clear.logs"), systemImage: "trash")
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
                            localizedKey(model.language, "ui.no.logs"),
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
                                    scopeName: localizedKey(model.language, "ui.logs.474c79"),
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
                                        lineNumberWidth: logLineNumberDigits(total: model.diagnosticLogLines.count),
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
            .navigationTitle(localizedKey(model.language, "ui.logs"))
            #if os(macOS)
            .djConnectMacDetailContent(maxWidth: 1280)
            #endif
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    #if os(iOS)
                    if showsCompactTitle {
                        Text(localizedKey(model.language, "ui.logs"))
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
            .alert(localizedKey(model.language, "ui.clear.logs.1489bd"), isPresented: $showingClearConfirmation) {
                Button(localizedKey(model.language, "ui.clear.logs"), role: .destructive) {
                    model.clearDiagnosticLog()
                }
                Button(localizedKey(model.language, "ui.cancel"), role: .cancel) {}
            } message: {
                Text(localizedKey(model.language, "ui.this.removes.the.visible.and.persisted.diagnostic.logs"))
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
    let lineNumberWidth: Int
    let highlight: String
    let isSearchResult: Bool

    var body: some View {
        Text(highlightedText)
            .foregroundStyle(isSearchResult ? Color.white : Color.white.opacity(0.88))
    }

    private var highlightedText: AttributedString {
        let query = highlight.trimmingCharacters(in: .whitespacesAndNewlines)
        var attributed = AttributedString(text)
        applyLineNumberColor(to: &attributed)
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

    private func applyLineNumberColor(to attributed: inout AttributedString) {
        var lineStart = attributed.startIndex
        while lineStart < attributed.endIndex {
            let lineEnd = attributed[lineStart..<attributed.endIndex].characters.firstIndex(of: "\n") ?? attributed.endIndex
            let numberEnd = attributed.characters.index(
                lineStart,
                offsetBy: lineNumberWidth,
                limitedBy: lineEnd
            ) ?? lineEnd
            if lineStart < numberEnd {
                attributed[lineStart..<numberEnd].foregroundColor = Color.white.opacity(0.48)
            }
            guard lineEnd < attributed.endIndex else {
                break
            }
            lineStart = attributed.characters.index(after: lineEnd)
        }
    }
}

private struct AboutView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let websiteURL = URL(string: "https://djconnect.dev")!

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? .infinity : 760
    }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    AboutBanner()

                    SettingsSection(title: localizedKey(model.language, "ui.app")) {
                        AboutStackedRow(label: localizedKey(model.language, "ui.version")) {
                            SelectableValue(model.version)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.device.name")) {
                            SelectableValue(model.identity.deviceName)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.website")) {
                            Link(destination: websiteURL) {
                                Text("https://djconnect.dev")
                                    .font(.body)
                                    .foregroundStyle(djConnectAccent)
                                    .foregroundColor(djConnectAccent)
                                    .textSelection(.enabled)
                            }
                            .djConnectLilacButton()
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.device.id")) {
                            SelectableValue(model.identity.deviceID)
                        }
                    }

                    SettingsSection(title: localizedKey(model.language, "ui.connection")) {
                        AboutStackedRow(label: localizedKey(model.language, "ui.connection.type")) {
                            SelectableValue(connectionModeTitle, foregroundStyle: connectionModeColor)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.connection.speed")) {
                            SelectableValue(connectionTransportTitle, foregroundStyle: connectionTransportColor)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.home.assistant.address")) {
                            SelectableValue(model.homeAssistantURL)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.music")) {
                            SelectableValue(
                                model.backendAvailable
                                    ? localizedKey(model.language, "ui.available")
                                    : localizedKey(model.language, "ui.unavailable"),
                                foregroundStyle: model.backendAvailable ? .green : .red
                            )
                        }
                    }

                    SettingsSection(title: localizedKey(model.language, "ui.notices")) {
                        AboutStackedRow(label: "Copyright") {
                            SelectableValue("2026 Peter van Tol")
                        }
                    }
                }
                #if os(macOS)
                .djConnectMacDetailContent(maxWidth: .infinity, alignment: .topLeading)
                #else
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(localizedKey(model.language, "ui.about"))
    }

    private var connectionModeTitle: String {
        if model.isDemoMode {
            return localizedKey(model.language, "ui.local.demo.mode")
        }
        switch model.haConnectionMode {
        case .local:
            return localizedKey(model.language, "ui.local.home.assistant")
        case .remote:
            return localizedKey(model.language, "ui.remote.home.assistant")
        case .offline:
            return localizedKey(model.language, "ui.offline")
        }
    }

    private var connectionModeColor: Color {
        if model.isDemoMode {
            return djConnectAccent
        }
        switch model.haConnectionMode {
        case .local:
            return .green
        case .remote:
            return djConnectAccent
        case .offline:
            return .red
        }
    }

    private var connectionTransportTitle: String {
        if model.isDemoMode {
            return localizedKey(model.language, "ui.demo")
        }
        if model.haConnectionMode == .offline {
            return localizedKey(model.language, "ui.not.active")
        }
        if model.fastPathDiagnostics.websocketConnected {
            return localizedKey(model.language, "ui.fast.local.link.websocket")
        }
        return localizedKey(model.language, "ui.normal.link.http")
    }

    private var connectionTransportColor: Color {
        if model.isDemoMode {
            return djConnectAccent
        }
        if model.haConnectionMode == .offline {
            return .red
        }
        return model.fastPathDiagnostics.websocketConnected ? .green : .secondary
    }
}

private struct LegalNoticesView: View {
    let language: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? .infinity : 760
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        AboutBanner()

                        SettingsSection(title: localizedKey(language, "ui.legal")) {
                            SelectableValue(localizedKey(language, "ui.djconnect.is.not.affiliated.with.endorsed.by.or.sponsored.by"))
                            SelectableValue(localizedKey(language, "ui.spotify.is.a.trademark.of.spotify.ab.home.assistant.is"))
                        }

                        SettingsSection(title: "OSS") {
                            SelectableValue(localizedKey(language, "ui.djconnect.uses.apple.platform.frameworks.and.swift.package.manager.third"))
                        }
                    }
                    #if os(macOS)
                    .djConnectMacDetailContent(maxWidth: .infinity, alignment: .topLeading)
                    #else
                    .padding(24)
                    .frame(maxWidth: contentMaxWidth, alignment: .leading)
                    #endif
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(localizedKey(language, "ui.legal"))
        }
    }
}

private struct PrivacyView: View {
    let language: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? .infinity : 760
    }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AboutBanner()
                    SettingsSection(title: localizedKey(language, "ui.privacy")) {
                        SelectableValue(localizedKey(language, "ui.djconnect.does.not.collect.sell.or.process.personal.data.in"))
                        SelectableValue(localizedKey(language, "ui.device.tokens.are.stored.locally.in.the.app.s.private"))
                        SelectableValue(localizedKey(language, "ui.push.notifications.are.only.used.for.djconnect.notifications.such.as"))
                        SelectableValue(localizedKey(language, "ui.music.playback.and.voice.requests.are.handled.through.your.own"))
                        SelectableValue(localizedKey(language, "ui.ai.and.assist.answers.can.be.incorrect.and.depend.on"))
                    }
                }
                #if os(macOS)
                .djConnectMacDetailContent(maxWidth: .infinity, alignment: .topLeading)
                #else
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(localizedKey(language, "ui.privacy"))
    }
}

private struct AskDJFeedbackPromptView: View {
    @ObservedObject var model: DJConnectAppModel
    let message: DJConnectAskDJMessage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var userNote = ""
    @State private var issueBody = ""

    private var isCompact: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var contentMinWidth: CGFloat? {
        isCompact ? nil : 760
    }

    private var contentIdealWidth: CGFloat? {
        isCompact ? nil : 920
    }

    private var contentMaxWidth: CGFloat {
        isCompact ? .infinity : 1_080
    }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AboutBanner()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedKey(model.language, "ui.report.ask.dj.answer"))
                            .font(.title.bold())
                        Text(localizedKey(model.language, "ui.create.a.github.issue.draft.with.redacted.ask.dj.context"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedKey(model.language, "ui.what.was.wrong.or.missing"))
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
                            Text(localizedKey(model.language, "ui.github.draft.context"))
                                .font(.headline)
                            Spacer()
                            Button {
                                refreshIssueBody()
                            } label: {
                                Label(localizedKey(model.language, "ui.update"), systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.white)
                            .help(localizedKey(model.language, "ui.update.draft.context"))
                        }
                        Text(localizedKey(model.language, "ui.review.this.text.before.opening.github.remove.anything.you.do"))
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

                    actionButtons
                }
                .padding(.horizontal, isCompact ? 18 : 28)
                .padding(.top, isCompact ? 18 : 8)
                .padding(.bottom, isCompact ? 18 : 28)
                .frame(
                    minWidth: contentMinWidth,
                    idealWidth: contentIdealWidth,
                    maxWidth: contentMaxWidth,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .defaultScrollAnchor(.top)
        }
        #if os(macOS)
        .frame(minWidth: 760, idealWidth: 1_020, maxWidth: 1_160)
        #endif
        .onAppear {
            refreshIssueBody()
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        let layout = isCompact ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Button {
                if let url = model.askDJFeedbackIssueURL(for: message, body: issueBody) {
                    openURL(url)
                }
                dismiss()
            } label: {
                Label(localizedKey(model.language, "ui.open.github.issue"), systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)

            Button {
                dismiss()
            } label: {
                Text(localizedKey(model.language, "ui.not.now"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DJConnectLilacPillButtonStyle())
            .controlSize(.large)
        }
    }

    private func refreshIssueBody() {
        issueBody = model.askDJFeedbackIssueBody(for: message, userNote: userNote)
    }
}

#if os(iOS)
#Preview("Ask DJ Feedback - Compact") {
    let model = DJConnectAppModel(startBackgroundTasks: false)
    model.language = "nl"
    let message = DJConnectAskDJMessage(
        role: .dj,
        text: "Ik koos dit nummer omdat de warme synths, het tempo en de late-night energie goed aansluiten."
    )
    return AskDJFeedbackPromptView(model: model, message: message)
}
#endif

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
                    Text(localizedKey(model.language, "ui.share.feedback"))
                        .font(.title.bold())
                    Text(localizedKey(model.language, "ui.open.a.github.issue.with.redacted.app.context.nothing.is"))
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
                        Label(localizedKey(model.language, "ui.open.github.issue"), systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)

                    Button {
                        dismiss()
                    } label: {
                        Text(localizedKey(model.language, "ui.not.now.b1e535"))
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
                Text(localizedKey(language, "ui.music.control.with.character"))
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesHorizontalLayout: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    private var labelColumnWidth: CGFloat {
        #if os(macOS)
        280
        #else
        240
        #endif
    }

    var body: some View {
        if usesHorizontalLayout {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                Text(label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(width: labelColumnWidth, alignment: .trailing)
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
    LabeledContent(localizedKey(model.language, "ui.wake.word")) {
        TextField(localizedKey(model.language, "ui.wake.word"), text: phrase)
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
    #else
    LabeledContent(localizedKey(model.language, "ui.wake.word")) {
        TextField(localizedKey(model.language, "ui.wake.word"), text: phrase)
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
                return localizedKey(model.language, "ui.pair.home.assistant.first")
            }
            if !model.backendAvailable {
                return localizedKey(model.language, "ui.playback.backend.unavailable")
            }
            if !model.voiceEnabled {
                return localizedKey(model.language, "ui.voice.requests.unavailable")
            }
        }
        return localizedKey(model.language, "ui.idle")
    case .listening:
        return localizedKey(model.language, "ui.listening.for.wake.word")
    case .detected:
        return localizedKey(model.language, "ui.wake.word.detected")
    case .unavailable:
        if model.isDemoMode {
            return localizedKey(model.language, "ui.not.available.in.demo.mode")
        }
        return localizedKey(model.language, "ui.not.available")
    }
}

private func permissionStatusText(_ status: DJConnectPermissionStatus, language: String) -> String {
    switch status {
    case .unknown:
        localizedKey(language, "ui.ask.when.needed")
    case .granted:
        localizedKey(language, "ui.allowed")
    case .denied:
        localizedKey(language, "ui.denied")
    case .restricted:
        localizedKey(language, "ui.restricted")
    case .unavailable:
        localizedKey(language, "ui.not.available")
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
