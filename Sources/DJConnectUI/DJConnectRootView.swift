import DJConnectCore
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Shared feature identity across native tabs, sidebar, heroes and notices.
enum DJConnectFeatureSymbols {
    static let djSession = "opticaldisc"
}

/// Keep screen refresh at the platform's consistent action edge.
/// Navigation chrome (back and sidebar controls) remains system-owned.
var djConnectRefreshToolbarPlacement: ToolbarItemPlacement {
    #if os(macOS)
    .navigation
    #else
    .primaryAction
    #endif
}


#if canImport(AVFoundation)
@preconcurrency import AVFoundation
#endif
#if canImport(MetalKit)
import MetalKit
#endif
#if os(iOS)
import UIKit
import Darwin
#elseif os(macOS)
import AppKit
import Darwin
#endif

@MainActor
private func openDJConnectSystemNetworkSettings() {
    #if os(iOS)
    let urls = [
        URL(string: "App-Prefs:root=WIFI"),
        URL(string: "prefs:root=WIFI"),
        URL(string: "App-Prefs:")
    ].compactMap { $0 }
    openFirstAvailableURL(urls) { url, completion in
        UIApplication.shared.open(url, options: [:], completionHandler: completion)
    }
    #elseif os(macOS)
    let urls = [
        URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension"),
        URL(string: "x-apple.systempreferences:com.apple.preference.network")
    ].compactMap { $0 }
    openFirstAvailableURL(urls) { url, completion in
        completion(NSWorkspace.shared.open(url))
    }
    #endif
}

@MainActor
private func openFirstAvailableURL(
    _ urls: [URL],
    opener: @MainActor @escaping @Sendable (URL, @escaping @Sendable (Bool) -> Void) -> Void
) {
    guard let url = urls.first else {
        return
    }
    opener(url) { didOpen in
        guard !didOpen else {
            return
        }
        Task { @MainActor in
            openFirstAvailableURL(Array(urls.dropFirst()), opener: opener)
        }
    }
}

@MainActor
private func resignPlatformFirstResponder() {
    #if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #elseif os(macOS)
    NSApp.keyWindow?.makeFirstResponder(nil)
    #endif
}

private func localizedKey(_ language: String, _ key: String, arguments: CVarArg...) -> String {
    DJConnectLocalization.localized(key: key, language: language, arguments: arguments)
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

// Preserve expanded content without changing the native tab/toolbar traits.
private struct DJConnectContentSizeClassKey: EnvironmentKey {
    static let defaultValue: UserInterfaceSizeClass? = nil
}
private extension EnvironmentValues {
    var djConnectContentSizeClass: UserInterfaceSizeClass? {
        get { self[DJConnectContentSizeClassKey.self] }
        set { self[DJConnectContentSizeClassKey.self] = newValue }
    }
}

let djConnectAccent = Color(red: 0.84, green: 0.22, blue: 0.96)
enum DJConnectCardAppearance {
    static let cornerRadius: CGFloat = 32
    static var searchFocusGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.92), Color(red: 0.16, green: 0.56, blue: 1.0), djConnectAccent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let searchMatchBackground = Color(red: 1.0, green: 0.84, blue: 0.30)
    static let searchMatchForeground = Color(red: 0.07, green: 0.04, blue: 0.15)
    static let searchFocusWidth: CGFloat = 3
    static let segmentedContentInset: CGFloat = 8
    static var segmentedItemShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: max(0, cornerRadius - segmentedContentInset), style: .continuous)
    }
    // Compact conversation bubbles retain their own geometry; all borders share these tokens.
    static let conversationCornerRadius: CGFloat = 18
    static let borderOpacity: Double = 0.32
    static let borderWidth: CGFloat = 1.25
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
}
private struct DJConnectCardOutline: ViewModifier {
    func body(content: Content) -> some View {
        content.clipShape(DJConnectCardAppearance.shape)
            .overlay { DJConnectCardAppearance.shape.stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth) }
    }
}
private let djConnectButtonBlue = Color(red: 0.16, green: 0.56, blue: 1.0)
private let djConnectButtonPurple = Color(red: 0.84, green: 0.18, blue: 1.0)
private let djConnectIconGradient = LinearGradient(
    colors: [
        Color(red: 0.12, green: 0.45, blue: 1.00),
        Color(red: 0.84, green: 0.22, blue: 0.96)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
private let djConnectScreenHorizontalPadding: CGFloat = 16
let djConnectScreenVerticalPadding: CGFloat = 12
private let djConnectContentMaxWidth: CGFloat = 760
private let djConnectCompactContentMaxWidth: CGFloat = 640
private let djConnectMacDetailContentMaxWidth: CGFloat = 1_680
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
    case vibeCastSessionStart
    case permissionExplanation
    case musicDNAOptIn
    case sessionHistory

    var id: String { rawValue }
}

private var djConnectListRowInsets: EdgeInsets {
    #if os(iOS)
    EdgeInsets(top: 5, leading: djConnectScreenHorizontalPadding, bottom: 5, trailing: djConnectScreenHorizontalPadding)
    #else
    EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
    #endif
}

private var djConnectSearchContentHorizontalPadding: CGFloat {
    #if os(macOS)
    djConnectScreenHorizontalPadding * 2
    #else
    djConnectScreenHorizontalPadding
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
                in: DJConnectCardAppearance.shape
            )
            .modifier(DJConnectCardOutline())
    }
}

private struct DJConnectHeroCardStyle: ViewModifier {
    var colors: [Color]? = nil

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if colors != nil {
                        DJConnectCardAppearance.shape.fill(.black.opacity(0.60))
                    }
                    DJConnectCardAppearance.shape.fill(
                        LinearGradient(
                            colors: colors?.map { $0.opacity(0.42) } ?? [Color(red: 0.08, green: 0.15, blue: 0.32),
                                     Color(red: 0.13, green: 0.09, blue: 0.27),
                                     Color(red: 0.17, green: 0.08, blue: 0.32)],
                            startPoint: .leading, endPoint: .trailing)
                    )
                }
            }
            .modifier(DJConnectCardOutline())
    }
}

private extension View {
    func djConnectHeroCard(colors: [Color]? = nil) -> some View {
        modifier(DJConnectHeroCardStyle(colors: colors))
    }

    func djConnectGradientCard() -> some View {
        modifier(DJConnectGradientCardStyle())
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
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
    func djConnectMacDetailContent(maxWidth: CGFloat = djConnectMacDetailContentMaxWidth, alignment: Alignment = .top) -> some View {
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
        self.frame(minHeight: 44, alignment: .leading)
        #endif
    }

    @ViewBuilder
    func djMusicDNASettingsListRow() -> some View {
        #if os(macOS)
        self.listRowInsets(EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0))
        #else
        self.frame(minHeight: 44, alignment: .leading)
        #endif
    }
}

enum DJConnectHaptics {
    @MainActor
    static func impact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }

    @MainActor
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }

    @MainActor
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }

    @MainActor
    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }

    @MainActor
    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #elseif os(macOS)
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.generic, performanceTime: .now)
        performer.perform(.alignment, performanceTime: .now)
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

    @ViewBuilder
    func djTransparentMacListBackground() -> some View {
        #if os(macOS)
        self.background(DJConnectMacListBackgroundClearer())
        #else
        self
        #endif
    }
}

#if os(macOS)
// Opt in only from main vertical content, never from nested card carousels.
private struct DJConnectMacMainScrollPolicy: NSViewRepresentable {
    func makeNSView(context: Context) -> MainScrollPolicyView { MainScrollPolicyView() }
    func updateNSView(_ view: MainScrollPolicyView, context: Context) { view.scheduleConfiguration() }

    final class MainScrollPolicyView: NSView {
        override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); scheduleConfiguration() }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); scheduleConfiguration() }
        override func layout() { super.layout(); scheduleConfiguration() }

        func scheduleConfiguration() {
            DispatchQueue.main.async { [weak self] in self?.configureEnclosingScrollView() }
        }

        private func configureEnclosingScrollView() {
            guard let scroll = enclosingScrollView else { return }
            // Legacy bars stay visible for overflow, independent of input-device policy.
            // Hide the bar only when all content fits; no application/global defaults change.
            if scroll.scrollerStyle != .legacy { scroll.scrollerStyle = .legacy }
            if !scroll.hasVerticalScroller { scroll.hasVerticalScroller = true }
            if !scroll.autohidesScrollers { scroll.autohidesScrollers = true }
        }
    }
}

private struct DJConnectMacListBackgroundClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.postsFrameChangedNotifications = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            clearBackgrounds(from: nsView)
        }
    }

    private func clearBackgrounds(from view: NSView) {
        var current: NSView? = view
        while let candidate = current {
            if let scrollView = candidate as? NSScrollView {
                scrollView.drawsBackground = false
                scrollView.backgroundColor = .clear
                clearDescendantBackgrounds(in: scrollView)
                return
            }
            current = candidate.superview
        }
    }

    private func clearDescendantBackgrounds(in view: NSView) {
        if let tableView = view as? NSTableView {
            tableView.backgroundColor = .clear
            tableView.enclosingScrollView?.drawsBackground = false
            tableView.enclosingScrollView?.backgroundColor = .clear
        }
        if let collectionView = view as? NSCollectionView {
            collectionView.backgroundColors = [.clear]
            collectionView.enclosingScrollView?.drawsBackground = false
            collectionView.enclosingScrollView?.backgroundColor = .clear
        }
        view.subviews.forEach(clearDescendantBackgrounds)
    }
}
#endif

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
    case djSession
    case savedSessions
    case nowPlaying
    case trackInsight
    case discovery
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

#if os(macOS)
private enum DJConnectSidebarFocusTarget: Hashable {
    case section(DJConnectSection)
    case feedback
}
#endif

public struct DJConnectRootView: View {
    @ObservedObject private var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSection = DJConnectSection.djSession
    @State private var openedSavedSessionID: String?
    #if os(macOS)
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @FocusState private var focusedSidebarItem: DJConnectSidebarFocusTarget?
    #endif
    @State private var moreResetID = UUID()
    @State private var showingFeedback = false

    public init(model: DJConnectAppModel) {
        self.model = model
        self.history = model.sessionHistory
    }

    public var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            Group {
                #if os(macOS)
                NavigationSplitView(columnVisibility: $sidebarVisibility) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                        SidebarItem(
                            title: localizedKey(model.language, "ui.session.title"),
                            systemImage: DJConnectFeatureSymbols.djSession,
                            isSelected: selectedSection == .djSession,
                            focusTarget: .section(.djSession),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.djSession) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.now.playing"),
                            systemImage: "music.note",
                            isSelected: selectedSection == .nowPlaying,
                            focusTarget: .section(.nowPlaying),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.nowPlaying) }
                        SidebarItem(
                            title: "Track Insight",
                            systemImage: "waveform.path.ecg",
                            isSelected: selectedSection == .trackInsight,
                            focusTarget: .section(.trackInsight),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.trackInsight) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.discover"),
                            systemImage: "wand.and.stars",
                            isSelected: selectedSection == .discovery,
                            focusTarget: .section(.discovery),
                            focus: $focusedSidebarItem
                        ) { selectDiscovery() }
                        SidebarItem(
                            title: "Ask DJ",
                            systemImage: "bubble.left.and.bubble.right",
                            isSelected: selectedSection == .askDJ,
                            focusTarget: .section(.askDJ),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.askDJ) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.session.history.title"),
                            systemImage: "clock.arrow.circlepath",
                            isSelected: selectedSection == .savedSessions,
                            focusTarget: .section(.savedSessions),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.savedSessions) }
                        SidebarItem(
                            title: "Music DNA",
                            systemImage: "heart",
                            isSelected: selectedSection == .musicDNA,
                            focusTarget: .section(.musicDNA),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.musicDNA) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.queue"),
                            systemImage: "music.note.list",
                            isSelected: selectedSection == .queue,
                            focusTarget: .section(.queue),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.queue) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.playlists"),
                            systemImage: "rectangle.stack",
                            isSelected: selectedSection == .playlists,
                            focusTarget: .section(.playlists),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.playlists) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.games"),
                            systemImage: "gamecontroller",
                            isSelected: selectedSection == .games,
                            focusTarget: .section(.games),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.games) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.settings"),
                            systemImage: "gearshape",
                            isSelected: selectedSection == .settings,
                            focusTarget: .section(.settings),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.settings) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.logs"),
                            systemImage: "doc.text.magnifyingglass",
                            isSelected: selectedSection == .logs,
                            focusTarget: .section(.logs),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.logs) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.about"),
                            systemImage: "info.circle",
                            isSelected: selectedSection == .about,
                            focusTarget: .section(.about),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.about) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.legal"),
                            systemImage: "doc.text",
                            isSelected: selectedSection == .legal,
                            focusTarget: .section(.legal),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.legal) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.privacy"),
                            systemImage: "hand.raised",
                            isSelected: selectedSection == .privacy,
                            focusTarget: .section(.privacy),
                            focus: $focusedSidebarItem
                        ) { selectSidebarSection(.privacy) }
                        SidebarItem(
                            title: localizedKey(model.language, "ui.share.feedback"),
                            systemImage: "bubble.left.and.bubble.right",
                            isSelected: false,
                            focusTarget: .feedback,
                            focus: $focusedSidebarItem
                        ) { openedSavedSessionID = nil; showingFeedback = true }
                    }
                        }
                        .padding(12)
                    .navigationTitle(screenTitle(model.language, key: "ui.djconnect", isDemoMode: model.isDemoMode))
                    .scrollContentBackgroundIfAvailable(.hidden)
                    .scrollIndicators(.hidden)
                    .toolbar(removing: .sidebarToggle)
                    .focusSection()
                    .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
                } detail: {
                    GeometryReader { viewport in
                    ZStack(alignment: .bottom) {
                        selectedView
                            .id(selectedSection)
                            .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
                        if shouldShowOfflineNetworkBanner {
                            OfflineNetworkBanner(
                                language: model.language,
                                refreshAction: model.refreshNetworkAvailability,
                                settingsAction: openDJConnectSystemNetworkSettings
                            )
                            .padding(.horizontal, 18)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.snappy(duration: 0.22), value: shouldShowOfflineNetworkBanner)
                    }
                    // Native chrome already occupies its own titlebar. Do not
                    // add macOS's scroll-edge veil over the top of detail content.
                    .scrollEdgeEffectHidden(true, for: .top)
                    .toolbar(removing: .sidebarToggle)
                    .focusSection()
                }
                .toolbar(removing: .sidebarToggle)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            sidebarVisibility = sidebarVisibility == .detailOnly ? .all : .detailOnly
                        } label: {
                            Image(systemName: "sidebar.left")
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 28)
                        }
                        .djConnectPlainButtonStyle()
                        .tint(.white)
                        .foregroundStyle(.white)
                        .accessibilityLabel(localizedKey(model.language, "ui.navigation.menu"))
                        .accessibilityIdentifier("main-sidebar-toggle")
                    }
                }
                .tint(Color(red: 0.74, green: 0.22, blue: 0.96))
                .accentColor(Color(red: 0.74, green: 0.22, blue: 0.96))
                #else
                GeometryReader { proxy in
                    Group {
                        if usesNativeiPadTabs {
                            iPadRootTabs
                        } else {
                            compactRootTabs
                                .id("compact-tabs-\(orientationID(for: proxy.size))")
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                #endif
            }
            #if os(iOS)
            .background(.clear)
            #endif
            #if DEBUG
            if model.isUITestRuntimeFixtureActive {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("uitest-runtime-fixture-active")
                    .accessibilityLabel("uitest-runtime-fixture-active")
                if model.uiTestRuntimeFixtureScenario == "session_history_contract",
                   ProcessInfo.processInfo.environment["DJCONNECT_UITEST_DIAGNOSTICS"] == "1" {
                    Text(verbatim: "available=\(history.available) scope=\(history.profileScopeActive) owner=\(history.hasAuthorizedOwner) foreground=\(model.canRefreshSessionHistory) compatible=\(model.isRuntimeCompatible) mode=\(model.haConnectionMode.rawValue) canAsk=\(model.canUseProfileConversation) sending=\(model.isSendingAskDJText) draft=\(model.askDJDraft.count)")
                        .font(.caption2).frame(width: 1, height: 1).opacity(0.01)
                        .accessibilityIdentifier("session-history-runtime-diagnostics")
                        .accessibilityHidden(true)
                }
                if let scenario = model.uiTestRuntimeFixtureScenario {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("uitest-runtime-fixture-\(scenario)")
                        .accessibilityLabel("uitest-runtime-fixture-\(scenario)")
                }
                if model.voiceStatus == .unavailable {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("uitest-voice-unavailable")
                        .accessibilityLabel("uitest-voice-unavailable")
                }
            }
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
        .task { await model.refreshActiveDJSession() }
        .task(id: model.pairingStatus) { await history.prepare() }
        .overlay(alignment: .bottom) {
            if let key = history.navigationErrorKey {
                HStack {
                    Text(localizedKey(model.language, key))
                    Button(localizedKey(model.language, "ui.close")) { history.clearNavigationError() }
                }
                .font(.callout).padding(16).frame(maxWidth: 650)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding(.bottom, 80)
            }
        }
        .onAppear {
            handleScreenshotScreenRequestIfNeeded()
            handleHomeScreenActionRequestIfNeeded()
        }
        .onChange(of: model.trackInsightNavigationRequestID) {
            selectedSection = .trackInsight
        }
        .onChange(of: model.homeScreenActionRequest) {
            handleHomeScreenActionRequestIfNeeded()
        }
        .onChange(of: selectedSection) {
            #if os(macOS)
            openedSavedSessionID = nil
            #else
            if horizontalSizeClass != .regular, selectedSection == .more {
                moreResetID = UUID()
            }
            #endif
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                handleHomeScreenActionRequestIfNeeded()
                model.refreshPermissionStatuses(retryWakeWord: false)
                model.markActiveSession()
                model.recoverPairingClientAPIIfNeeded()
                Task { await history.prepare() }
            case .inactive:
                model.markInactiveSession(enteringBackground: false)
            case .background:
                model.markInactiveSession()
            @unknown default:
                break
            }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    private func handleHomeScreenActionRequestIfNeeded() {
        guard let request = model.homeScreenActionRequest else {
            return
        }
        moreResetID = UUID()
        switch request.action {
        case .djSession:
            selectedSection = .djSession
        case .nowPlaying:
            selectedSection = .nowPlaying
        case .queue:
            selectedSection = .queue
        case .askDJ:
            selectSidebarSection(.askDJ)
        case .trackInsight:
            selectedSection = .trackInsight
        case .discovery:
            selectedSection = .discovery
        case .playlists:
            selectedSection = .playlists
        case .about:
            selectedSection = .about
        }
        model.clearHomeScreenActionRequest(request)
    }

    private func handleScreenshotScreenRequestIfNeeded() {
        #if DEBUG
        guard let screen = UserDefaults.standard.string(forKey: "DJCONNECTScreenshotScreen")
            ?? launchArgumentValue(named: "-DJCONNECTScreenshotScreen")
            ?? ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--screenshot-screen=") })?
            .split(separator: "=", maxSplits: 1)
            .last
            .map(String.init) else {
            return
        }
        switch screen {
        case "dj-session":
            selectedSection = .djSession
        case "more":
            selectedSection = .more
        case "now-playing":
            selectedSection = .nowPlaying
        case "queue":
            selectedSection = .queue
        case "ask-dj":
            selectedSection = .askDJ
        case "track-insight":
            selectedSection = .trackInsight
        case "discover", "discovery", "ontdek":
            selectedSection = .discovery
        case "music-dna":
            selectedSection = .musicDNA
        case "playlists":
            selectedSection = .playlists
        case "games":
            selectedSection = .games
        case "settings":
            selectedSection = .settings
        case "logs":
            selectedSection = .logs
        case "about":
            selectedSection = .about
        case "legal":
            selectedSection = .legal
        case "privacy":
            selectedSection = .privacy
        default:
            break
        }
        #endif
    }

    #if DEBUG
    private func launchArgumentValue(named name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(arguments.index(after: index)) else {
            return nil
        }
        let value = arguments[arguments.index(after: index)]
        return value.isEmpty ? nil : value
    }
    #endif

    #if os(iOS)
    private var usesNativeiPadTabs: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private func orientationID(for size: CGSize) -> String {
        size.width > size.height ? "landscape" : "portrait"
    }

    private var compactTabSelection: Binding<DJConnectSection> {
        Binding(
            get: {
                isMoreSectionSelected ? .more : selectedSection
            },
            set: { newValue in
                if newValue == .more && isMoreSectionSelected { return }
                if newValue == .discovery {
                    selectDiscovery()
                } else {
                    selectedSection = newValue
                }
            }
        )
    }

    private var compactRootTabs: some View {
        TabView(selection: compactTabSelection) {
            DJSessionView(model: model) {
                selectedSection = .queue
            }
                .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }
                .tabItem {
                    Label(localizedKey(model.language, "ui.session.title"), systemImage: DJConnectFeatureSymbols.djSession)
                }
                .tag(DJConnectSection.djSession)
            NowPlayingView(model: model) { selectedSection = .queue }
                .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }
                .tabItem { Label(localizedKey(model.language, "ui.now.playing"), systemImage: "music.note") }
                .tag(DJConnectSection.nowPlaying)
            TrackInsightView(model: model)
                .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }
                .tabItem {
                    Label("Track Insight", systemImage: "waveform.path.ecg")
                }
                .tag(DJConnectSection.trackInsight)
            MusicDiscoveryView(model: model)
                .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }
                .tabItem {
                    Label(localizedKey(model.language, "ui.discover"), systemImage: "wand.and.stars")
                }
                .tag(DJConnectSection.discovery)
            MoreView(model: model, requestedSection: isMoreSectionSelected && selectedSection != .more ? selectedSection : nil) {
                selectedSection = .nowPlaying
            }
            .id(moreResetID)
                .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }
                .tabItem {
                    Label(localizedKey(model.language, "ui.more"), systemImage: "ellipsis")
                }
                .tag(DJConnectSection.more)
        }
        .tabViewStyle(.tabBarOnly)
        .tint(djConnectAccent)
        .accentColor(djConnectAccent)
        .environment(\.symbolVariants, .none)
    }

    @ViewBuilder private var nativeTabOfflineNotice: some View {
        if shouldShowOfflineNetworkBanner {
            OfflineNetworkBanner(language: model.language,
                                 refreshAction: model.refreshNetworkAvailability,
                                 settingsAction: openDJConnectSystemNetworkSettings)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var iPadRootTabs: some View {
        let sections: [DJConnectSection] = [.djSession, .nowPlaying, .trackInsight, .discovery, .more]
        let selection = Binding<Int>(
            get: { sections.firstIndex(of: compactTabSelection.wrappedValue) ?? 0 },
            set: { index in if sections.indices.contains(index) { compactTabSelection.wrappedValue = sections[index] } }
        )
        return NativeBottomTabBar(
            screens: [
                AnyView(DJSessionView(model: model) { selectedSection = .queue }
                    .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                    .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }),
                AnyView(NowPlayingView(model: model) { selectedSection = .queue }
                    .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                    .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }),
                AnyView(TrackInsightView(model: model)
                    .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                    .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }),
                AnyView(MusicDiscoveryView(model: model)
                    .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                    .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice }),
                AnyView(MoreView(model: model, requestedSection: isMoreSectionSelected && selectedSection != .more ? selectedSection : nil) {
                    selectedSection = .nowPlaying
                }.id(moreResetID)
                    .environment(\.djConnectContentSizeClass, horizontalSizeClass)
                    .safeAreaInset(edge: .bottom, spacing: 0) { nativeTabOfflineNotice })
            ],
            titles: [localizedKey(model.language, "ui.session.title"), localizedKey(model.language, "ui.now.playing"), "Track Insight",
                     localizedKey(model.language, "ui.discover"), localizedKey(model.language, "ui.more")],
            symbols: [DJConnectFeatureSymbols.djSession, "music.note", "waveform.path.ecg", "wand.and.stars", "ellipsis"],
            scenePhase: scenePhase, selection: selection)
    }

    private var isMoreSectionSelected: Bool {
        switch selectedSection {
        case .djSession, .nowPlaying, .trackInsight, .discovery:
            false
        case .savedSessions, .askDJ, .more, .queue, .musicDNA, .playlists, .games, .settings, .logs, .about, .legal, .privacy:
            true
        }
    }

    #endif

    private var shouldShowOfflineNetworkBanner: Bool {
        guard model.isOfflineModeActive else {
            return false
        }
        switch selectedSection {
        case .djSession, .savedSessions, .nowPlaying, .askDJ, .trackInsight, .discovery, .musicDNA, .queue, .playlists:
            return true
        case .more, .games, .settings, .logs, .about, .legal, .privacy:
            return false
        }
    }

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
        if model.isShowingVibeCastSessionStart, model.activeDJSession != nil {
            return .vibeCastSessionStart
        }
        if model.isShowingPermissionExplanation {
            return .permissionExplanation
        }
        if model.isShowingMusicDNAOptInPrompt {
            return .musicDNAOptIn
        }
        if history.openTarget != nil { return .sessionHistory }
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
        case .vibeCastSessionStart:
            VibeCastSessionStartDialog(model: model)
        case .permissionExplanation:
            PermissionExplanationView(model: model)
        case .musicDNAOptIn:
            MusicDNAOptInPromptView(model: model)
                .tint(djConnectAccent)
                .accentColor(djConnectAccent)
                #if os(iOS)
                .presentationDetents([.large])
                .presentationSizing(.page)
                #endif
                .presentationBackground {
                    DJConnectCanvasBackground()
                }
        case .sessionHistory:
            if let target = history.openTarget {
                NavigationStack {
                    SessionTimelineScreen(model: model, sessionID: target.sessionID,
                                          initialAnchor: target.entryID)
                        .navigationTitle(savedSessionNavigationTitle(target.sessionID, history: history, language: model.language))
                        .toolbar { Button(localizedKey(model.language, "ui.close")) { history.openTarget = nil } }
                }
                #if os(macOS)
                .frame(minWidth: 500, idealWidth: 900, minHeight: 550, idealHeight: 800)
                #endif
            }
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
        case .vibeCastSessionStart:
            model.isShowingVibeCastSessionStart = false
        case .permissionExplanation:
            model.cancelPermissionExplanation()
        case .musicDNAOptIn:
            model.dismissMusicDNAOptInPrompt()
        case .sessionHistory:
            history.openTarget = nil
        }
    }

    private func selectDiscovery() {
        selectSidebarSection(.discovery)
        model.presentMusicDNAOptInPromptIfNeeded()
    }

    private func selectSidebarSection(_ section: DJConnectSection) {
        // Withdraw the pushed archive before replacing its detail root, including
        // a click on the already-selected Earlier Sessions overview.
        openedSavedSessionID = nil
        selectedSection = section
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedSection {
        case .djSession:
            DJSessionView(model: model) { selectedSection = .queue }
        case .savedSessions:
            #if os(macOS)
            SavedSessionsView(model: model, openedSessionID: $openedSavedSessionID)
            #else
            SavedSessionsView(model: model)
            #endif
        case .nowPlaying:
            NowPlayingView(model: model) {
                selectedSection = .queue
            }
        case .trackInsight:
            TrackInsightView(model: model)
        case .discovery:
            MusicDiscoveryView(model: model)
        case .musicDNA:
            MusicDNAView(model: model)
        case .askDJ:
            AskDJView(model: model) {
                selectedSection = .trackInsight
                model.openTrackInsight()
            }
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
            ScrollView(.vertical) {
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
                        Text(permissionExplanationPrimaryText)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if model.permissionExplanationKind == .notifications {
                            Text(localizedKey(model.language, "ui.push.notifications.are.only.used.for.djconnect.notifications.such.as"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
                        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                        .controlSize(.large)

                        DJConnectNotNowLinkButton(language: model.language) {
                            model.cancelPermissionExplanation()
                        }
                    }
                }
                .padding(28)
                .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionExplanationPrimaryText: String {
        switch model.permissionExplanationKind {
        case .notifications:
            localizedKey(model.language, "ui.needed.for.server.push.notifications.when.ask.dj.answers")
        case .microphone:
            localizedKey(model.language, "watch.djconnect.only.uses.the.microphone.when.you.start")
        }
    }
}

#if os(macOS)
private struct SidebarItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let focusTarget: DJConnectSidebarFocusTarget
    let focus: FocusState<DJConnectSidebarFocusTarget?>.Binding
    let action: () -> Void

    var body: some View {
        Button {
            // A mouse click moves the same native keyboard focus as Tab.
            // Otherwise macOS can keep its ring on the previous menu item.
            focus.wrappedValue = focusTarget
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isSelected ? .white : djConnectAccent)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
                .background {
                    selectionBackground
                }
        }
        .djConnectPlainButtonStyle()
        .focused(focus, equals: focusTarget)
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
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
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
            .padding(28)
            .frame(minWidth: 360, idealWidth: contentIdealWidth, maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .defaultScrollAnchor(.top)
        .background(DJConnectCanvasBackground())
        .accessibilityIdentifier("screen-pairing")
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
                #if os(iOS)
                if model.shouldShowPairingWiFiSettingsLink {
                    Button {
                        openDJConnectSystemNetworkSettings()
                    } label: {
                        Label(
                            localizedKey(model.language, "ui.device.offline.enable.wifi"),
                            systemImage: "wifi.slash"
                        )
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    }
                    .djConnectPlainButtonStyle()
                    .accessibilityLabel(localizedKey(model.language, "ui.device.offline.enable.wifi"))
                }
                #endif

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
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .secondary, expands: true))
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
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .secondary, expands: true))
                    .controlSize(.large)
                    .disabled(model.isPairing)
                }
                #endif

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

                #if os(iOS)
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
                .djConnectPlainButtonStyle()
                .accessibilityLabel(localizedKey(model.language, "ui.manual.pairing"))
                .accessibilityIdentifier("pairing-manual-toggle")
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
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                .controlSize(.large)
                .disabled(model.isPairing || !canSubmitPairing)
                .accessibilityIdentifier("pairing-submit-button")

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
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .secondary, expands: true))
                .controlSize(.large)
                .accessibilityIdentifier("pairing-start-demo-button")
            }

            #if os(iOS)
            if model.pairingFlowTarget == .appleWatch {
                Button {
                    model.dismissAppleWatchPairingForNow()
                } label: {
                    Text(localizedKey(model.language, "ui.not.now"))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .djConnectPlainButtonStyle()
                .foregroundStyle(.secondary)
                .controlSize(.large)
                .disabled(model.isPairing)
            }
            #endif

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
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .tertiary, expands: true))
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
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
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
        if model.pairingStatus == .stale {
            return .orange
        }
        return djConnectAccent
    }

    private var pairingStatusMessage: String? {
        if model.pairingStatus == .pairing || model.pairingStatus == .waitingForHomeAssistantCompletion || model.pairingStatus == .stale {
            return model.pairingMessage
        }
        if let pairingMessage = model.pairingMessage, !isFieldPrompt(pairingMessage) {
            return pairingMessage
        }
        return nil
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
            DJConnectCardAppearance.shape
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            DJConnectCardAppearance.shape
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#if os(iOS) || os(macOS)
private struct OfflineNetworkBanner: View {
    let language: String
    let refreshAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 17, weight: .bold))
                .accessibilityHidden(true)

            Text(localizedKey(language, "ui.offline.network.banner"))
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)

            Button(action: settingsAction) {
                Text(localizedKey(language, "ui.open.settings"))
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .djConnectPlainButtonStyle()

            Button(action: refreshAction) {
                Image(systemName: "arrow.clockwise").foregroundStyle(.white)
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .djConnectPlainButtonStyle()
            .accessibilityLabel(localizedKey(language, "ui.refresh.network"))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.34, blue: 0.94),
                    Color(red: 0.03, green: 0.54, blue: 0.96)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: -3)
        .accessibilityElement(children: .combine)
    }
}
#endif

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
                    .accessibilityIdentifier("pairing-home-assistant-url-field")
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
                    .djConnectPlainButtonStyle()
                    .accessibilityLabel(localizedKey(language, "ui.clear.home.assistant.url"))
                }

                Button {
                    confirmURL()
                } label: {
                    Image(systemName: didConfirm ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isValid ? .green : .secondary)
                }
                .djConnectPlainButtonStyle()
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
        .djConnectGradientCard()
        .overlay {
            DJConnectCardAppearance.shape
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
                .accessibilityIdentifier("pairing-code-field")
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
        .djConnectGradientCard()
        .overlay {
            DJConnectCardAppearance.shape
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
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                    .controlSize(.large)

                    DJConnectNotNowLinkButton(language: language) {
                        dismiss()
                    }
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
                    DJConnectHaptics.success()
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
            Text(localizedKey(language, "ui.pair.code.scanned"))
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
    private weak var captureDevice: AVCaptureDevice?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updatePreviewOrientation()
        configureFocusAndExposure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreviewOrientation()
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePreviewOrientation()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.previewLayer?.frame = self?.view.bounds ?? .zero
            self?.updatePreviewOrientation()
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        captureDevice = device
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
        updatePreviewOrientation()
        configureFocusAndExposure()
    }

    private func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection,
              let angle = captureVideoRotationAngle,
              connection.isVideoRotationAngleSupported(angle) else {
            return
        }
        connection.videoRotationAngle = angle
    }

    private var captureVideoRotationAngle: CGFloat? {
        guard let interfaceOrientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation else {
            return nil
        }
        switch interfaceOrientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }

    private func configureFocusAndExposure() {
        guard let device = captureDevice else {
            return
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if device.isSubjectAreaChangeMonitoringEnabled == false {
                device.isSubjectAreaChangeMonitoringEnabled = true
            }
        } catch {
        }
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
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                .controlSize(.large)
                DJConnectNotNowLinkButton(language: model.language, key: "ui.not.now.b1e535") {
                    model.dismissWakeWordActivationPrompt()
                }
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
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
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
                VStack(alignment: .leading, spacing: 18) {
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
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                    DJConnectNotNowLinkButton(language: model.language, key: "ui.not.now.b1e535") {
                        model.dismissCrashReportPrompt()
                    }
                }
                .padding(20)
                .djSessionFrostedSurface()
                .accessibilityIdentifier("crash-report-content-card")
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
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
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
            ScrollView(.vertical) {
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

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                moveWelcomeTour(by: -1)
                            } label: {
                                Label(localizedKey(model.language, "ui.previous"), systemImage: "chevron.left")
                                    .frame(maxWidth: .infinity)
                            }
                            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .secondary, expands: true))
                            .controlSize(.large)
                            .disabled(selectedStepIndex == 0)
                            .opacity(selectedStepIndex == 0 ? 0.46 : 1)

                            Button {
                                moveWelcomeTour(by: 1)
                            } label: {
                                Label(localizedKey(model.language, "ui.next"), systemImage: "chevron.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                            .controlSize(.large)
                            .disabled(isLastStep)
                            .opacity(isLastStep ? 0 : 1)
                            .accessibilityHidden(isLastStep)
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
                        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: isLastStep ? .primary : .tertiary, expands: true))
                        .controlSize(.large)
                        .accessibilityIdentifier("welcome-dismiss-button")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(28)
                .frame(minWidth: 360, idealWidth: contentIdealWidth, maxWidth: contentMaxWidth)
                #if os(macOS)
                .frame(minHeight: 620)
                #endif
            }
            .defaultScrollAnchor(.top)
            .accessibilityIdentifier("screen-welcome")
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
                id: .discovery,
                title: localizedKey(language, "ui.discover"),
                body: localizedKey(language, "ui.discovery.recommendations.will.appear.after.music.dna.has.more.signals"),
                systemImage: "wand.and.stars"
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
        .background(Color.white.opacity(0.07), in: DJConnectCardAppearance.shape)
        .overlay {
            DJConnectCardAppearance.shape
                .stroke(Color.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
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
        .djConnectPlainButtonStyle()
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
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
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

private struct UpdateNotesView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 20) {
                AboutBanner()
                    .frame(maxWidth: 560)

                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(djConnectAccent)
                    Text(localizedKey(model.language, "ui.update.available"))
                        .font(.title.bold())
                }

                Text(model.updateNotesTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    WhatsNewMarkdownBody(text: model.updateNotesBody, clientType: model.identity.clientType)
                        .padding(.vertical, 2)
                }
                #if os(macOS)
                .frame(minHeight: 260)
                #else
                .frame(minHeight: 300)
                #endif

                Button {
                    model.isShowingUpdateNotes = false
                } label: {
                    Text(localizedKey(model.language, "ui.done"))
                        .frame(maxWidth: .infinity)
                }
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .tertiary, expands: true))
                .controlSize(.large)
            }
            .padding(28)
        }
        .frame(minWidth: 360, idealWidth: 560, maxWidth: 680)
        #if os(macOS)
        .frame(minHeight: 620)
        #endif
    }
}

private struct WhatsNewMarkdownBody: View {
    let text: String
    let clientType: DJConnectClientType

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
    var openQueueAction: () -> Void = {}
    @State private var statusToast: DJConnectVisualNotice?

    var body: some View {
        #if os(iOS)
        IOSNowPlayingView(model: model, openQueueAction: openQueueAction)
            .accessibilityIdentifier("screen-now-playing")
        #else
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrackSummaryView(model: model)
                    OutputSelectorView(model: model)
                }
                .djConnectScreenPadding()
                .frame(maxWidth: djConnectContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(screenTitle(model.language, key: "Now Playing", isDemoMode: model.isDemoMode))
            .toolbar {
                ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                    RefreshButton(model: model) {
                        Task { await refreshNowPlayingWithToast() }
                    }
                }
                ConnectionStatusToolbar(model: model)
            }
            .djStatusToastOverlay(statusToast, screenImage: "music.note")
            .djUserNoticeToast(model: model, screenImage: "music.note")
        }
        .accessibilityIdentifier("screen-now-playing")
        #endif
    }

    private func refreshNowPlayingWithToast() async {
        let didRefresh = await model.refreshNowPlaying()
        showStatusToast(
            didRefresh ? localizedKey(model.language, "appModel.now.playing.updated") : localizedKey(model.language, "appModel.now.playing.update.failed"),
            systemImage: "music.note"
        )
    }

    private func showStatusToast(_ text: String, systemImage: String) {
        let notice = DJConnectVisualNotice(text: text, systemImage: systemImage)
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = notice
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast?.id == notice.id else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }
}

private struct AppleWatchPairingReminderButton: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        Button {
            model.presentAppleWatchPairingScreen()
        } label: {
            Image(systemName: "applewatch")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.orange)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.16))
                )
                .overlay {
                    Circle()
                        .stroke(Color.orange.opacity(0.36), lineWidth: 1)
                }
        }
        .djConnectPlainButtonStyle()
        .help(localizedKey(model.language, "ui.pair.apple.watch"))
        .accessibilityLabel(localizedKey(model.language, "ui.pair.apple.watch"))
    }
}

struct RefreshButton: View {
    @ObservedObject var model: DJConnectAppModel
    var action: (() -> Void)?

    var body: some View {
        Button {
            if let action {
                action()
            } else {
                model.refresh()
            }
        } label: {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise").foregroundStyle(.white)
            }
        }
        .disabled(model.isDemoMode || model.pairingStatus != .paired || model.isRefreshing)
        .tint(.white)
        .help(localizedKey(model.language, "ui.refresh"))
        .accessibilityLabel(localizedKey(model.language, "ui.refresh"))
        .accessibilityIdentifier("screen-refresh")
    }
}

/// One family for app actions; system alerts and navigation retain native presentation.
enum DJConnectButtonAppearance {
    static let iconSize: CGFloat = 44
    static let iconFont: Font = .system(size: 18, weight: .semibold)
    static let textFont: Font = .headline.weight(.semibold)
    static let pressedScale: CGFloat = 0.98
    static let selectedFill = djConnectAccent.opacity(0.22)
    static let primaryGradient = LinearGradient(colors: [djConnectButtonBlue, djConnectButtonPurple],
                                                startPoint: .leading, endPoint: .trailing)
}

struct DJConnectButtonStyle: ButtonStyle {
    enum Emphasis { case primary, secondary, tertiary, selected, destructive }
    enum ShapeKind { case capsule, icon, segmented }
    var emphasis: Emphasis = .secondary
    var shape: ShapeKind = .capsule
    var expands = false
    var usesLiveGlass = true
    var iconDiameter: CGFloat = DJConnectButtonAppearance.iconSize
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var outline: AnyShape {
        switch shape {
        case .segmented: AnyShape(DJConnectCardAppearance.segmentedItemShape)
        case .icon: AnyShape(Circle())
        case .capsule: AnyShape(Capsule())
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let role: Emphasis = configuration.role == .destructive ? .destructive : emphasis
        let pressed = configuration.isPressed && isEnabled
        configuration.label
            .font(shape == .icon ? DJConnectButtonAppearance.iconFont : DJConnectButtonAppearance.textFont)
            .foregroundStyle(role == .destructive ? Color.red : Color.white.opacity(role == .tertiary ? 0.72 : 1))
            .symbolRenderingMode(.monochrome)
            .padding(.horizontal, shape == .icon ? 0 : 16)
            .padding(.vertical, shape == .capsule ? 10 : 0)
            .frame(width: shape == .icon ? iconDiameter : nil,
                   height: shape == .icon ? iconDiameter : nil)
            .frame(minHeight: DJConnectButtonAppearance.iconSize)
            .frame(maxWidth: expands ? .infinity : nil)
            .background {
                switch role {
                case .primary: outline.fill(DJConnectButtonAppearance.primaryGradient)
                case .selected: outline.fill(DJConnectButtonAppearance.selectedFill)
                case .destructive: outline.fill(Color.red.opacity(0.12))
                case .secondary:
                    if usesLiveGlass { outline.fill(.white.opacity(0.04)).glassEffect(.regular.interactive(), in: outline) }
                    else { outline.fill(.white.opacity(0.10)) }
                case .tertiary: Color.clear
                }
            }
            .overlay { outline.stroke(role == .selected ? djConnectAccent.opacity(0.55) : .white.opacity(role == .tertiary ? 0 : 0.12), lineWidth: 1).allowsHitTesting(false) }
            .overlay { outline.fill(.white.opacity(pressed ? 0.10 : 0)).allowsHitTesting(false) }
            .overlay { outline.stroke(.white.opacity(isFocused ? 0.95 : 0), lineWidth: 3).allowsHitTesting(false) }
            .contentShape(outline)
            .opacity(isEnabled ? 1 : 0.40)
            .scaleEffect(pressed && !reduceMotion ? DJConnectButtonAppearance.pressedScale : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
    }
}

private struct DJConnectNotNowLinkButton: View {
    let language: String
    let key: String
    let action: () -> Void

    init(language: String, key: String = "ui.not.now", action: @escaping () -> Void) {
        self.language = language
        self.key = key
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(localizedKey(language, key))
        }
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .tertiary, expands: true))
        .controlSize(.large)
    }
}

private struct AnimatedAlbumArtworkView: View {
    let playback: DJConnectPlayback?
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
    }

    private var artworkContent: some View {
        CachedArtworkImage(url: playback?.albumImageURL, mode: .fit, usesAlbumGlassFrame: true) {
            AlbumArtworkPlaceholder(tint: artworkTintColor(for: playback), isPlaying: playback?.isPlaying == true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// An unframed, quiet vinyl silhouette when artwork is absent or unavailable.
/// Its soft halo merges into the parent player card; it is not an album image.
private struct AlbumArtworkPlaceholder: View {
    let tint: Color
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var elapsedBeforePause: TimeInterval = 0
    @State private var spinningSince: Date?

    private var shouldSpin: Bool {
        isPlaying && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let record = side * 0.66
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.30), .clear],
                                         center: .center, startRadius: 0, endRadius: side * 0.46))
                    .frame(width: side * 0.92, height: side * 0.92)
                    .blur(radius: side * 0.06)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !shouldSpin)) { context in
                    let elapsed = elapsedBeforePause + (spinningSince.map { max(0, context.date.timeIntervalSince($0)) } ?? 0)
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.13, blue: 0.20),
                                                          Color(red: 0.025, green: 0.03, blue: 0.07)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: record, height: record)
                        ForEach([0.78, 0.90], id: \.self) { scale in
                            Circle().stroke(.white.opacity(0.045), lineWidth: 1)
                                .frame(width: record * scale, height: record * scale)
                        }
                        // An asymmetric reflection and label mark make the
                        // rotation visible without spinning the surrounding halo.
                        Circle().trim(from: 0.04, to: 0.18)
                            .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: record * 0.012, lineCap: .round))
                            .frame(width: record * 0.84, height: record * 0.84)
                        Circle()
                            .fill(djConnectIconGradient)
                            .frame(width: record * 0.26, height: record * 0.26)
                            .opacity(0.85)
                        Capsule().fill(.white.opacity(0.65))
                            .frame(width: record * 0.07, height: record * 0.012)
                            .offset(y: -record * 0.075)
                        Circle().fill(Color(red: 0.035, green: 0.04, blue: 0.09))
                            .frame(width: record * 0.045, height: record * 0.045)
                    }
                    .rotationEffect(.degrees(elapsed.truncatingRemainder(dividingBy: 12) * 30))
                    .shadow(color: .black.opacity(0.18), radius: side * 0.06, y: side * 0.035)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: shouldSpin, initial: true) { _, spinning in
            let now = Date()
            if spinning {
                spinningSince = now
            } else if let started = spinningSince {
                elapsedBeforePause += max(0, now.timeIntervalSince(started))
                spinningSince = nil
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

enum CachedArtworkImageMode {
    case fit
    case fill
}

struct CachedArtworkImage<Placeholder: View>: View {
    let url: URL?
    let mode: CachedArtworkImageMode
    var usesAlbumGlassFrame = false
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var loadedImage: Image?
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let loadedImage, loadedURL == url {
                if usesAlbumGlassFrame {
                    loadedImage
                        .resizable()
                        .cachedArtworkContentMode(mode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.22))
                        .djAlbumArtworkGlassCard()
                } else {
                    loadedImage
                        .resizable()
                        .cachedArtworkContentMode(mode)
                }
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
        guard let requestedURL = url else { loadedURL = nil; loadedImage = nil; return }
        if loadedURL == requestedURL, loadedImage != nil { return }
        for attempt in 0..<2 {
            do {
                let data = try await DJConnectArtworkDataCache.shared.data(for: requestedURL)
                guard !Task.isCancelled, url == requestedURL else { return }
                guard let image = makeArtworkImage(from: data) else { return }
                loadedURL = requestedURL; loadedImage = image
                return
            } catch {
                guard !Task.isCancelled, url == requestedURL else { return }
                if attempt == 0 {
                    do { try await Task.sleep(for: .seconds(4)) } catch { return }
                }
            }
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
func makeArtworkImage(from data: Data) -> Image? {
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

actor DJConnectArtworkDataCache {
    static let shared = DJConnectArtworkDataCache()

    private struct Entry {
        var data: Data
        var tint: Color?
        var expiresAt: Date
    }

    private var entries: [URL: Entry] = [:]
    private var failedUntil: [URL: Date] = [:]
    private let ttl: TimeInterval = 24 * 60 * 60
    private let failureTTL: TimeInterval = 3
    private let maxEntries = 180
    private let session: URLSession
    private struct Download: Sendable {
        let data: Data
        let cacheLifetime: TimeInterval
    }
    private var inFlight: [URL: Task<Download, Error>] = [:]

    init(session: URLSession = .shared) { self.session = session }

    func data(for url: URL) async throws -> Data {
        let now = Date()
        if let entry = entries[url], entry.expiresAt > now {
            return entry.data
        }
        if let retryAt = failedUntil[url], retryAt > now {
            throw URLError(.cannotConnectToHost)
        }

        if let pending = inFlight[url] { return try await pending.value.data }
        // A SwiftUI row can disappear while another row needs the same image.
        // Keep the shared download independent of an individual view task.
        let pending = Task { [session] in
            var request = URLRequest(url: url)
            request.cachePolicy = .useProtocolCachePolicy
            request.timeoutInterval = 10
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let directives = (http.value(forHTTPHeaderField: "Cache-Control") ?? "").lowercased()
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            // A protected artwork lease explicitly forbids retaining its bytes.
            // Respect that policy in the app cache as well as URLCache.
            var lifetime: TimeInterval = 24 * 60 * 60
            if directives.contains("no-store") || directives.contains("no-cache") { lifetime = 0 }
            if let maxAge = directives.first(where: { $0.hasPrefix("max-age=") }),
               let seconds = Double(maxAge.dropFirst(8)) { lifetime = min(lifetime, max(0, seconds)) }
            return Download(data: data, cacheLifetime: lifetime)
        }
        inFlight[url] = pending
        defer { inFlight[url] = nil }
        do {
            let download = try await pending.value
            let data = download.data
            if download.cacheLifetime > 0 {
                entries[url] = Entry(data: data, tint: nil, expiresAt: Date().addingTimeInterval(min(ttl, download.cacheLifetime)))
            }
            failedUntil.removeValue(forKey: url)
            trimIfNeeded()
            return data
        } catch {
            if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                failedUntil[url] = Date().addingTimeInterval(failureTTL)
            }
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

/// Shared ground tones for the current Session header and Now Playing card.
/// Track-derived tint blending remains local to the player; Music DNA keeps its own palette.
struct DJConnectSessionMoodPalette {
    let colors: [Color]
    let glow: Double
    init(mood: String) {
        self.init(stepIndex: ["chill", "groove", "energy", "party"].firstIndex(of: mood) ?? 0)
    }
    init(stepIndex: Int) {
        let themes: [DJConnectSessionMoodTheme] = [.chill, .groove, .energy, .party]
        let theme = themes.indices.contains(stepIndex) ? themes[stepIndex] : .chill
        colors = theme.colorValues.map { value in
            Color(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
        }
        glow = theme.glow
    }
}

/// The pinned Session surface follows confirmed mood; the conversation canvas stays unchanged.
struct DJSessionPinnedMoodBackground: View {
    let mood: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stepIndex: Int { ["chill", "groove", "energy", "party"].firstIndex(of: mood) ?? 0 }

    private var colors: [Color] { DJConnectSessionMoodPalette(stepIndex: stepIndex).colors }

    var body: some View {
        let strength = stepIndex == 0 ? 0.20 : stepIndex == 2 ? 0.34 : 0.30
        ZStack {
            DJConnectCanvasBackground()
            LinearGradient(colors: [colors[0].opacity(strength),
                                    colors[1].opacity(stepIndex == 0 ? 0.10 : strength * 0.65),
                                    colors[2].opacity(stepIndex == 0 ? 0.14 : strength * 0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if stepIndex != 0 {
                RadialGradient(colors: [colors[2].opacity(0.10), .clear],
                               center: .bottomTrailing, startRadius: 0, endRadius: 650)
            }
        }
        .clipped()
        .ignoresSafeArea(.container, edges: .top)
        .animation(djSessionReducedMotion(reduceMotion) ? nil : .easeInOut(duration: 0.28), value: stepIndex)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct NowPlayingArtworkCardBackground: View {
    let tint: Color
    var body: some View {
        ZStack {
            LinearGradient(colors: [tint.opacity(0.82), tint.opacity(0.34), .black.opacity(0.82)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [tint.opacity(0.38), .clear], center: .topLeading,
                           startRadius: 20, endRadius: 520)
        }
    }
}

private func artworkTintColor(for playback: DJConnectPlayback?) -> Color {
    // Neutral while artwork loads; never pretend a title hash is a cover colour.
    Color(white: 0.22)
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

struct TrackInsightView: View {
    @ObservedObject var model: DJConnectAppModel
    var explicitMoment = false
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
    // A visual preference only; Session mood remains confirmed backend state.
    @State private var standaloneMoodStepIndex = 1
    @State private var isShowingShare = false
    #if os(iOS)
    @State private var menuIntent: SessionControlIntent?
    @State private var menuFrames: [SessionControlIntent.Kind: CGRect] = [:]
    #endif
    @State private var isAnimationActive = false
    @State private var statusToast: DJConnectVisualNotice?

    private var moodStepIndex: Int {
        model.confirmedSessionMoodInt == nil ? standaloneMoodStepIndex : model.playbackMoodStepIndex
    }

    @ViewBuilder private var moodToolbarButton: some View {
        if let session = model.activeDJSession {
            #if os(iOS)
            ActiveSessionMoodToolbar(model: model, session: session) {
                menuIntent = SessionControlIntent(kind: .mood, sessionID: session.id, epoch: model.sessionHistory.responseEpoch, sourceRect: menuFrames[.mood] ?? .zero)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { menuFrames[.mood] = $0 }
            #else
            ActiveSessionMoodToolbar(model: model, session: session)
            #endif
        } else {
            #if os(iOS)
            TrackInsightVisualMoodToolbar(language: model.language, selectedIndex: $standaloneMoodStepIndex,
                                         requestPresentation: {
                                             menuIntent = SessionControlIntent(kind: .visualMood, sessionID: "", epoch: model.sessionHistory.responseEpoch, sourceRect: menuFrames[.visualMood] ?? .zero)
                                         })
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { menuFrames[.visualMood] = $0 }
            #else
            TrackInsightVisualMoodToolbar(language: model.language, selectedIndex: $standaloneMoodStepIndex)
            #endif
        }
    }

    private var insight: TrackInsight? {
        explicitMoment ? model.momentTrackInsight : model.currentTrackInsight
    }

    private var insightID: String? {
        insight?.id
    }


    private var playbackShareIdentity: String {
        Self.shareIdentity(title: model.playback?.trackName, artist: model.playback?.artistName)
    }

    private var insightShareIdentity: String {
        Self.shareIdentity(title: insight?.title, artist: insight?.artist)
    }

    private func shouldUseWideLayout(for size: CGSize) -> Bool {
        #if os(macOS)
        size.width >= 1_000
        #else
        horizontalSizeClass == .regular && size.width > size.height
        #endif
    }

    private func maxContentWidth(for size: CGSize) -> CGFloat {
        shouldUseWideLayout(for: size) ? djConnectMacDetailContentMaxWidth : djConnectContentMaxWidth
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                GeometryReader { proxy in
                    let contentWidth = min(maxContentWidth(for: proxy.size), proxy.size.width)
                    ZStack(alignment: .top) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if let insight {
                                    TrackInsightHero(
                                        model: model,
                                        insight: insight,
                                        moodStepIndex: moodStepIndex,
                                        isAnimationActive: isAnimationActive,
                                        isPinnedSubject: explicitMoment
                                    )
                                    .id(trackInsightHeroRenderID(for: insight))
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                    TrackInsightAnalysisCard(insight: insight, language: model.language)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                    TrackInsightMetricsGrid(insight: insight, language: model.language, moodStepIndex: moodStepIndex)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                } else if explicitMoment {
                                    VStack(alignment: .leading, spacing: 16) {
                                        if model.isLoadingMomentTrackInsight {
                                            ProgressView(localizedKey(model.language, "ui.session.insight.loading"))
                                        } else {
                                            Text(model.momentTrackInsightErrorMessage ?? localizedKey(model.language, "ui.session.insight.unavailable"))
                                                .fixedSize(horizontal: false, vertical: true)
                                            if model.canRetryMomentTrackInsight {
                                                Button(localizedKey(model.language, "ui.retry")) { Task { await model.refreshMomentTrackInsight() } }
                                            }
                                        }
                                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).djSessionFrostedSurface()
                                } else {
                                    TrackInsightEmptyState(model: model)
                                }
                            }
                            .padding(.horizontal, djConnectScreenHorizontalPadding)
                            .padding(.vertical, djConnectScreenVerticalPadding)
                            .frame(width: contentWidth, alignment: .topLeading)
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        #if os(iOS)
                        .refreshable {
                            await refreshTrackInsightWithToast()
                        }
                        #endif
                    }
                }
            }
            .djStatusToastOverlay(statusToast, screenImage: "waveform.path.ecg")
            .navigationTitle(screenTitle(model.language, key: "Track Insight", isDemoMode: model.isDemoMode))
            .accessibilityIdentifier(explicitMoment ? "screen-moment-track-insight" : "screen-track-insight")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if explicitMoment {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizedKey(model.language, "ui.close")) { model.dismissMomentTrackInsight() }
                    }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if insight != nil && !explicitMoment {
                        Button {
                            isShowingShare = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.primary)
                        }
                        .tint(.primary)
                        .help(localizedKey(model.language, "ui.share.insight"))
                    }

                    if !explicitMoment {
                        moodToolbarButton
                        SessionConnectionToolbarButton(model: model) {
                            menuIntent = SessionControlIntent(kind: .connection, sessionID: model.activeDJSession?.id ?? "", epoch: model.sessionHistory.responseEpoch, sourceRect: menuFrames[.connection] ?? .zero)
                        }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { menuFrames[.connection] = $0 }
                    }
                    insightRefreshButton
                }
                #else
                ToolbarItemGroup(placement: .navigation) {
                    if insight != nil && !explicitMoment {
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
                ToolbarItemGroup(placement: .confirmationAction) {
                    if !explicitMoment {
                        moodToolbarButton
                        SessionConnectionToolbarButton(model: model)
                    }
                    insightRefreshButton
                }
                #endif
            }
            #if os(iOS)
            // Own presentation in stable screen content, never in a replaceable toolbar item.
            .overlay {
                SessionControlPopoverHost(model: model, intent: $menuIntent, visualMoodSelection: $standaloneMoodStepIndex)
            }
            #endif
            .sheet(isPresented: $isShowingShare) {
                if let insight {
                    TrackInsightSharePreviewView(
                        insight: insight,
                        language: model.language,
                        moodStepIndex: moodStepIndex
                    )
                }
            }
            .onChange(of: playbackShareIdentity) {
                dismissShareIfPlaybackMovedOn()
            }
            .onChange(of: insightShareIdentity) {
                dismissShareIfPlaybackMovedOn()
            }
            .onChange(of: errorMessage) { _, message in
                guard let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return
                }
                showStatusToast(message, systemImage: "exclamationmark.triangle.fill")
            }
            .djUserNoticeToast(model: model, screenImage: "waveform.path.ecg")
        }
        .onAppear {
            isAnimationActive = true
        }
        .task(id: !explicitMoment && model.isPlaying && model.canStartTrackInsightAnalysis) {
            guard !explicitMoment else { return }
            await model.loadTrackInsightOnOpen()
        }
        .onDisappear {
            isAnimationActive = false
            if explicitMoment { model.dismissMomentTrackInsight() }
        }
    }

    private var errorMessage: String? { explicitMoment ? model.momentTrackInsightErrorMessage : model.trackInsightErrorMessage }

    @ViewBuilder private var insightRefreshButton: some View {
        if explicitMoment {
            Button { Task { await refreshTrackInsightWithToast() } } label: {
                if model.isLoadingMomentTrackInsight { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise") }
            }.disabled(!model.canRetryMomentTrackInsight)
            .accessibilityLabel(localizedKey(model.language, "ui.retry"))
        } else {
            TrackInsightRefreshButton(model: model) { Task { await refreshTrackInsightWithToast() } }
        }
    }

    private func trackInsightHeroRenderID(for insight: TrackInsight) -> String {
        [
            insight.id,
            insight.title,
            insight.artist,
            insight.visualProfile?.motionStyle?.rawValue ?? "",
            insight.visualProfile?.palette.joined(separator: ",") ?? "",
            String(moodStepIndex),
            String(model.confirmedSessionMoodInt ?? 35)
        ].joined(separator: "|")
    }

    private func dismissShareIfPlaybackMovedOn() {
        guard isShowingShare, !playbackShareIdentity.isEmpty, !insightShareIdentity.isEmpty else {
            return
        }
        if playbackShareIdentity != insightShareIdentity {
            isShowingShare = false
        }
    }

    private func refreshTrackInsightWithToast() async {
        guard !model.isDemoMode, model.pairingStatus == .paired else { return }
        let didRefresh = explicitMoment ? await model.refreshMomentTrackInsight() : await model.refreshTrackInsight(open: true, forceRefresh: true)
        let failureMessage = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        showStatusToast(
            didRefresh
                ? localizedKey(model.language, "appModel.track.insight.updated")
                : (failureMessage?.isEmpty == false ? failureMessage! : localizedKey(model.language, "appModel.track.insight.update.failed")),
            systemImage: "waveform.path.ecg"
        )
    }


    private func showStatusToast(_ text: String, systemImage: String) {
        let notice = DJConnectVisualNotice(text: text, systemImage: systemImage)
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = notice
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast?.id == notice.id else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }

    private static func shareIdentity(title: String?, artist: String?) -> String {
        let parts = [title, artist].map { value in
            value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) ?? ""
        }
        guard parts.contains(where: { !$0.isEmpty }) else {
            return ""
        }
        return parts.joined(separator: "\u{1F}")
    }
}

/// Standalone color selection is ephemeral UI state, never a Profile mood or
/// an analysis input. An active Session uses ActiveSessionMoodToolbar instead.
private struct TrackInsightVisualMoodToolbar: View {
    let language: String
    @Binding var selectedIndex: Int
    var requestPresentation: (() -> Void)? = nil
    @State private var isPresented = false
    private let moods = ["chill", "groove", "energy", "party"]
    private func text(_ key: String) -> String { localizedKey(language, key) }

    var body: some View {
        Button {
            if let requestPresentation { requestPresentation() }
            else { isPresented.toggle() }
        } label: {
            Image(systemName: askDJMoodIcon(for: selectedIndex)).foregroundStyle(.white)
        }
        .accessibilityLabel(text("ui.session.select_mood"))
        .accessibilityValue(text("ui.session.mood." + moods[selectedIndex]))
        .accessibilityIdentifier("track-insight-visual-mood-toggle")
        .help(text("ui.session.select_mood"))
        .popover(isPresented: $isPresented) {
            SessionGlassChoiceSelector(
                steps: moods.enumerated().map { (text("ui.session.mood." + $0.element), $0.offset) },
                selectedIndex: selectedIndex, language: language
            ) { selectedIndex = $0 }
            .padding(12)
            .frame(idealWidth: 360)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct TrackInsightRefreshButton: View {
    @ObservedObject var model: DJConnectAppModel
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            if model.isLoadingTrackInsight {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise").foregroundStyle(.white)
            }
        }
        .disabled(model.isDemoMode || model.pairingStatus != .paired || model.isLoadingTrackInsight || !model.canStartTrackInsightAnalysis)
        .tint(.white)
        .help(localizedKey(model.language, "ui.refresh.track.insight"))
        .accessibilityLabel(localizedKey(model.language, "ui.refresh.track.insight"))
    }
}

private struct MusicDNAView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
    @State private var statusToast: DJConnectVisualNotice?

    private func shouldUseWideLayout(for size: CGSize) -> Bool {
        #if os(macOS)
        size.width >= 1_000
        #else
        horizontalSizeClass == .regular && size.width > size.height
        #endif
    }

    private func maxContentWidth(for size: CGSize) -> CGFloat {
        shouldUseWideLayout(for: size) ? djConnectMacDetailContentMaxWidth : djConnectContentMaxWidth
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                GeometryReader { proxy in
                    ScrollView {
                        let contentWidth = min(maxContentWidth(for: proxy.size), proxy.size.width)
                        VStack(alignment: .leading, spacing: 16) {
                            MusicDNAHeroView(model: model, moodStepIndex: model.askDJMoodStepIndex)
                                .frame(maxWidth: .infinity, alignment: .top)
                            MusicDNAContentView(model: model)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            if let updatedSummary {
                                MusicDNAUpdatedFooter(language: model.language, updatedSummary: updatedSummary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.horizontal, djConnectScreenHorizontalPadding)
                        .padding(.top, djConnectScreenVerticalPadding)
                        .padding(.bottom, djConnectScreenVerticalPadding + 28)
                        .frame(maxWidth: contentWidth, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .top)
                        #if os(macOS)
                        .background(DJConnectMacMainScrollPolicy())
                        #endif
                    }
                }
                #if os(iOS)
                .refreshable {
                    #if DEBUG
                    guard !model.isMusicDNAPreviewMode else { return }
                    #endif
                    guard !model.isDemoMode, model.pairingStatus == .paired else { return }
                    await model.refreshMusicDNAProfile(showToast: true)
                }
                #endif
            }
            .djStatusToastOverlay(statusToast, screenImage: "heart")
            .navigationTitle(screenTitle(model.language, key: "Music DNA", isDemoMode: model.isDemoMode))
            .accessibilityIdentifier("screen-music-dna")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                    MusicDNARefreshButton(model: model)
                }
                #else
                ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                    MusicDNARefreshButton(model: model)
                }
                #endif
                ConnectionStatusToolbar(model: model)
            }
        }
        .task(id: scenePhase) {
            #if DEBUG
            guard !model.isMusicDNAPreviewMode else { return }
            #endif
            guard scenePhase == .active else { return }
            await model.refreshMusicDNAProfile()
            await model.loadMusicDiscovery()
            model.presentMusicDNAOptInPromptIfNeeded()
            while !Task.isCancelled && !model.isDemoMode {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard !Task.isCancelled else { return }
                if model.musicDNAProfileNeedsRecovery { await model.refreshMusicDNAProfile() }
            }
        }
        .onChange(of: model.musicDNAToast?.id) { _, _ in
            guard let toast = model.musicDNAToast else {
                return
            }
            showStatusToast(toast)
        }
    }

    private var updatedSummary: String? {
        guard let response = model.musicDNAProfileResponse,
              let updatedAt = response.profile.updatedAt ?? response.updatedAt else {
            return nil
        }
        if Calendar.current.isDate(updatedAt, inSameDayAs: Date()) {
            return updatedAt.formatted(date: .omitted, time: .shortened)
        }
        return updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func showStatusToast(_ toast: DJConnectVisualNotice) {
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = toast
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            guard statusToast?.id == toast.id else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }
}

private struct MusicDNAUpdatedFooter: View {
    let language: String
    let updatedSummary: String

    var body: some View {
        Text("\(localizedKey(language, "ui.updated")): \(updatedSummary)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.46))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
            .padding(.bottom, 10)
    }
}

private struct MusicDNARefreshButton: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        Button {
            Task { await model.refreshMusicDNAProfile(showToast: true) }
        } label: {
            if model.isLoadingMusicDNA {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise").foregroundStyle(.white)
            }
        }
        .disabled(model.isDemoMode || model.pairingStatus != .paired || model.isLoadingMusicDNA || model.isUpdatingMusicDNA)
        .tint(.white)
        .help(localizedKey(model.language, "ui.refresh.music.dna"))
        .accessibilityLabel(localizedKey(model.language, "ui.refresh.music.dna"))
    }
}

private struct MusicDNAHeroView: View {
    @ObservedObject var model: DJConnectAppModel
    let moodStepIndex: Int

    var body: some View {
        if model.musicDNAProfileResponse?.enabled == true {
            activeHero
        } else {
            inactiveHero
        }
    }

    private var activeHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNAHelixView(moodStepIndex: moodStepIndex)
                .frame(height: 220)
                .clipShape(DJConnectCardAppearance.shape)
            Text(localizedKey(model.language, "ui.music.dna.hero.description"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("music-dna-hero-description")
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 268, alignment: .center)
        .djConnectHeroCard()
    }

    private var inactiveHero: some View {
        VStack(spacing: 16) {
            DJConnectHeroGlyph(systemImage: "heart")

            Text("Music DNA")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(localizedKey(model.language, model.musicDNAProfileResponse?.enabled == false
                ? "ui.djconnect.in.your.home.assistant.environment.does.not.build.a"
                : "ui.djconnect.is.still.checking.the.current.music.dna.status"))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 190)
        .djConnectHeroCard()
    }
}

private struct MusicDNAOptInPromptView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 18) {
                AboutBanner()
                MusicDNAPromptIcon()

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
                    .labelStyle(DJConnectRedTrashLabelStyle())
                    Label(
                        localizedKey(model.language, "ui.you.can.always.turn.music.dna.off.in"),
                        systemImage: "switch.2"
                    )
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))

                Spacer(minLength: 0)

                if let message = model.musicDNAErrorMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("music-dna-opt-in-error")
                }

                VStack(spacing: 10) {
                    Button {
                        Task { await model.acceptMusicDNAOptInPrompt() }
                    } label: {
                        Label(localizedKey(model.language, "ui.enable.music.dna.1adf61"), systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                    .controlSize(.large)
                    .disabled(model.isUpdatingMusicDNA)

                    DJConnectNotNowLinkButton(language: model.language, key: "ui.not.now.b1e535") {
                        model.dismissMusicDNAOptInPrompt()
                    }
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620, minHeight: 420, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("music-dna-opt-in-prompt")
    }
}

private struct MusicDNAPromptIcon: View {
    var body: some View {
        Image(systemName: "heart")
            .font(.system(size: 50, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(djConnectIconGradient)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

private struct MusicDNAContentView: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let error = model.musicDNAErrorMessage {
                Label(error, systemImage: model.musicDNAProfileNeedsRecovery ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("music-dna-error")
            }
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
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var profile: DJConnectMusicDNAProfile { response.profile }

    var body: some View {
        if usesHorizontalRows {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    panels
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        } else {
            MusicDNAAdaptiveCardLayout(minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 360 : 280) {
                panels
            }
        }
    }

    @ViewBuilder
    private var panels: some View {
        musicDNAPanel {
            MusicDNASummaryPanel(title: localizedKey(model.language, "ui.summary"), rows: summaryRows, fallback: summaryText)
        }
        if let favoriteGenres = profile.favoriteGenres, !favoriteGenres.isEmpty {
            musicDNAPanel {
                MusicDNAPanel(title: localizedKey(model.language, "ui.favorite.genres"), value: names(favoriteGenres), icon: "music.quarternote.3")
            }
        }
        if let favoriteArtists = profile.favoriteArtists, !favoriteArtists.isEmpty {
            musicDNAPanel {
                MusicDNAArtistsPanel(title: localizedKey(model.language, "ui.favorite.artists"), artists: favoriteArtists, artworkURL: artistArtwork)
            }
        }
        if let moodMetric {
            musicDNAPanel {
                MusicDNAMetricPanel(metric: moodMetric, moodStepIndex: model.askDJMoodStepIndex)
            }
        }
        if let energyMetrics {
            musicDNAPanel {
                MusicDNAMetricPanel(metric: energyMetrics, moodStepIndex: model.askDJMoodStepIndex)
            }
        }
        if let listeningRhythm = profile.listeningRhythm, listeningRhythm.isDisplayable {
            musicDNAPanel {
                MusicDNAListeningRhythmPanel(
                    rhythm: listeningRhythm,
                    title: localizedKey(model.language, "ui.listening.rhythm")
                )
            }
        }
        if let moodMix = profile.moodMix, moodMix.isDisplayable {
            musicDNAPanel {
                MusicDNAMoodMixPanel(
                    moodMix: moodMix,
                    title: localizedKey(model.language, "ui.mood.mix"),
                    averageTitle: localizedKey(model.language, "ui.average")
                )
            }
        }
        if let playtime = profile.playtime, playtime.isDisplayable {
            musicDNAPanel {
                MusicDNAPlaytimePanel(
                    playtime: playtime,
                    title: localizedKey(model.language, "ui.playtime"),
                    subtitle: localizedKey(model.language, "ui.total.in.your.music.dna"),
                    topArtistsTitle: localizedKey(model.language, "ui.top.artists.by.playtime"),
                    topAlbumsTitle: localizedKey(model.language, "ui.top.albums.by.playtime")
                )
            }
        }
        if let repeatMagnets = profile.repeatMagnets, repeatMagnets.isDisplayable {
            musicDNAPanel {
                MusicDNARepeatMagnetsPanel(
                    repeatMagnets: repeatMagnets,
                    title: localizedKey(model.language, "ui.repeat.magnets")
                )
            }
        }
        if let explicitPositives = profile.explicitPositives, explicitPositives.isDisplayable {
            musicDNAPanel {
                MusicDNAExplicitPositivesPanel(
                    positives: explicitPositives,
                    title: localizedKey(model.language, "ui.explicit.positives"),
                    favoritesTitle: localizedKey(model.language, "ui.favorites"),
                    acceptedRecommendationsTitle: localizedKey(model.language, "ui.accepted.recommendations"),
                    artistImages: acceptedArtistImages
                )
            }
        }
        if let tasteAnchors = profile.tasteAnchors, tasteAnchors.isDisplayable {
            musicDNAPanel {
                MusicDNATasteAnchorsPanel(
                    anchors: tasteAnchors,
                    title: localizedKey(model.language, "ui.taste.anchors")
                )
            }
        }
        if let recentTracks = profile.recentTracks, !recentTracks.isEmpty {
            musicDNAPanel {
                MusicDNATrackListPanel(title: localizedKey(model.language, "ui.recent.tracks"), tracks: recentTracks, artworkURL: trackArtwork, icon: "clock.arrow.circlepath", identifier: "musicDNARecentTracksSection")
            }
        }
        if let recentFavoriteTracks = profile.recentFavoriteTracks, !recentFavoriteTracks.isEmpty {
            musicDNAPanel {
                MusicDNATrackListPanel(
                    title: localizedKey(model.language, "ui.recent.favorite.tracks"),
                    tracks: recentFavoriteTracks, artworkURL: trackArtwork
                )
            }
        }
        if profile.topTracksByRange.values.contains(where: { !$0.isEmpty }) {
            musicDNAPanel {
                MusicDNATopTracksPanel(title: localizedKey(model.language, "ui.music.dna.top.tracks.by.range"),
                                      ranges: profile.topTracksByRange, language: model.language, artworkURL: trackArtwork)
            }
        }
        if profile.topArtistsByRange.values.contains(where: { !$0.isEmpty }) {
            musicDNAPanel {
                MusicDNATopArtistsPanel(title: localizedKey(model.language, "ui.music.dna.top.artists.by.range"),
                                       ranges: profile.topArtistsByRange, language: model.language, artworkURL: artistArtwork)
            }
        }
        if let discoveryFeedback = profile.discoveryFeedback, discoveryFeedback.isDisplayable {
            musicDNAPanel {
                MusicDNAPanel(title: localizedKey(model.language, "ui.music.dna.discovery.feedback"), value: discoveryFeedbackText(discoveryFeedback), icon: "sparkles")
            }
        }
        if let privacyDashboard = profile.privacyDashboard, privacyDashboard.isDisplayable {
            musicDNAPanel {
                MusicDNAPanel(title: localizedKey(model.language, "ui.music.dna.privacy.dashboard"), value: privacyDashboardText(privacyDashboard), icon: "lock.shield")
            }
        }
        if let basisSignals {
            musicDNAPanel {
                if !basisTracks.isEmpty {
                    MusicDNATrackListPanel(title: localizedKey(model.language, "ui.signals"), tracks: basisTracks, artworkURL: trackArtwork,
                                           icon: "safari", identifier: "musicDNABasisTracksSection", limit: 4)
                } else {
                    MusicDNAPanel(title: localizedKey(model.language, "ui.signals"), value: basisSignals, icon: "safari")
                }
            }
        }
    }

    private var usesHorizontalRows: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact && UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    @ViewBuilder
    private func musicDNAPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: usesHorizontalRows ? 292 : nil, alignment: .top)
            .frame(height: usesHorizontalRows ? horizontalPanelHeight : nil, alignment: .top)
    }

    private var horizontalPanelHeight: CGFloat {
        #if os(iOS)
        verticalSizeClass == .compact ? 260 : 320
        #else
        musicDNADashboardPanelMinHeight
        #endif
    }

    private var summaryRows: [MusicDNASummaryItem] {
        var rows: [MusicDNASummaryItem] = []
        if let playtime = profile.playtime {
            let duration = playtime.formattedTotal?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("\(playtime.totalSeconds)s") ?? "\(playtime.totalSeconds)s"
            rows.append(.init(label: localizedKey(model.language, "ui.playtime"), value: duration, icon: "clock"))
        }
        if let count = profile.trackCount {
            rows.append(.init(label: localizedKey(model.language, "ui.tracks"), value: String(count), icon: "music.note"))
        } else if let tracks = profile.recentTracks {
            rows.append(.init(label: localizedKey(model.language, "ui.recent.tracks"), value: String(tracks.count), icon: "music.note"))
        }
        if let count = profile.artistCount ?? profile.favoriteArtists?.count {
            rows.append(.init(label: localizedKey(model.language, "ui.artists"), value: String(count), icon: "person.2"))
        }
        if let genres = profile.favoriteGenres, !genres.isEmpty {
            rows.append(.init(label: localizedKey(model.language, "ui.genres"), value: names(genres), icon: "music.quarternote.3"))
        }
        if let zone = profile.mood?.zone ?? profile.mood?.averageZone {
            rows.append(.init(label: localizedKey(model.language, "ui.profile.mood"), value: musicDNAZoneDisplayLabel(zone) ?? zone, icon: musicDNAMoodIcon(zone)))
        }
        return rows
    }

    private var summaryText: String {
        let summary = profile.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let counts = [
            profile.trackCount.map { "\($0) tracks" },
            profile.artistCount.map { "\($0) artiesten" },
            profile.genreCount.map { "\($0) genres" }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
        if !summary.isEmpty, !counts.isEmpty {
            return "\(summary)\n\(counts)"
        }
        if !summary.isEmpty {
            return summary
        }
        return counts.ifEmpty(localizedKey(model.language, "ui.not.enough.signals"))
    }

    private var energyMetrics: MusicDNAMetricPanel.Metric? {
        guard let energyProfile = profile.energyProfile,
              (energyProfile.sampleCount ?? 0) > 0,
              let energyPercent = energyProfile.energyPercent else {
            return nil
        }
        let zone = musicDNAZoneLabel(energyProfile.zone) ?? localizedKey(model.language, "ui.energy.profile")
        let primarySubtitle = energyProfile.sampleCount.map { analysisCountLabel($0) }
        let secondary = [
            energyProfile.danceabilityPercent.map {
                MusicDNAMetricPanel.SecondaryMetric(
                    title: localizedKey(model.language, "ui.dance"),
                    percent: $0,
                    icon: "figure.dance"
                )
            },
            energyProfile.intensityPercent.map {
                MusicDNAMetricPanel.SecondaryMetric(
                    title: localizedKey(model.language, "ui.intensity"),
                    percent: $0,
                    icon: "flame.fill"
                )
            }
        ]
        .compactMap { $0 }
        return MusicDNAMetricPanel.Metric(
            title: localizedKey(model.language, "ui.energy.profile"),
            headline: zone,
            percent: energyPercent,
            icon: "bolt.fill",
            subtitle: primarySubtitle,
            secondaryMetrics: secondary
        )
    }

    private var moodSummary: String {
        guard let mood = profile.mood else {
            if let tasteDirection = profile.tasteDirection?.trimmingCharacters(in: .whitespacesAndNewlines), !tasteDirection.isEmpty {
                return tasteDirection
            }
            return localizedKey(model.language, "ui.music.dna.needs.more.listening.for.profile.mood")
        }
        let value = mood.average ?? mood.value
        let zone = mood.averageZone ?? mood.zone
        let sampleCount = mood.sampleCount
        let hasMoodSignal = value != nil || (sampleCount ?? 0) > 0
        guard hasMoodSignal else {
            return localizedKey(model.language, "ui.music.dna.needs.more.listening.for.profile.mood")
        }
        let zoneLabel = musicDNAZoneLabel(zone)
        let zoneText = mood.average != nil && zoneLabel != nil ? "\(zoneLabel!) gemiddeld" : zoneLabel
        return [
            zoneText,
            value.map { "\($0)%" },
            sampleCount.map { signalCountLabel($0) }
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
        .ifEmpty(localizedKey(model.language, "ui.music.dna.needs.more.listening.for.profile.mood"))
    }

    private var moodMetric: MusicDNAMetricPanel.Metric? {
        guard let mood = profile.mood else {
            return nil
        }
        let value = mood.average ?? mood.value
        guard let value else {
            return nil
        }
        let zone = mood.averageZone ?? mood.zone
        let zoneLabel = musicDNAZoneLabel(zone) ?? localizedKey(model.language, "ui.profile.mood")
        let headline = mood.average != nil ? "\(zoneLabel) gemiddeld" : zoneLabel
        return MusicDNAMetricPanel.Metric(
            title: localizedKey(model.language, "ui.profile.mood"),
            headline: headline,
            percent: value,
            icon: musicDNAMoodIcon(zone),
            subtitle: mood.sampleCount.map { signalCountLabel($0) },
            secondaryMetrics: []
        )
    }

    private var basisTracks: [DJConnectMusicDNATrack] {
        let tracks: [DJConnectMusicDNATrack]
        if let basedOn = profile.basedOn, !basedOn.isEmpty {
            tracks = basedOn.compactMap { signal in
                guard let title = signal.title, !title.isEmpty, let artist = signal.artist, !artist.isEmpty else { return nil }
                return DJConnectMusicDNATrack(title: title, artist: artist, album: signal.album)
            }
            guard tracks.count == basedOn.count else { return [] }
        } else if let recent = profile.energyProfile?.recentSignals, !recent.isEmpty {
            tracks = recent.compactMap { signal in
                guard let title = signal.title, !title.isEmpty else { return nil }
                return DJConnectMusicDNATrack(title: title, artist: signal.artist, album: signal.album)
            }
        } else if let signals = profile.recommendationSignals, !signals.isEmpty {
            tracks = signals.compactMap { signal in
                guard let title = signal.title, !title.isEmpty, let artist = signal.artist, !artist.isEmpty else { return nil }
                return DJConnectMusicDNATrack(title: title, artist: artist, album: signal.album)
            }
            guard tracks.count == signals.count else { return [] }
        } else { return [] }
        let knownTracks = (profile.recentTracks ?? []) + (profile.recentFavoriteTracks ?? []) + profile.topTracksByRange.values.flatMap { $0 }
        func key(_ value: String?) -> String { (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return tracks.map { track in
            guard !key(track.title).isEmpty, !key(track.artist).isEmpty, !key(track.album).isEmpty else { return track }
            let matches = knownTracks.filter { key($0.title) == key(track.title) && key($0.artist) == key(track.artist) && key($0.album) == key(track.album) }
            let identities = Set(matches.compactMap(\.uri))
            let images = Set(matches.compactMap(\.imageURL))
            guard identities.count == 1, images.count == 1 else { return track }
            var result = track
            result.imageURL = images.first
            return result
        }
    }

    private var basisSignals: String? {
        if let basedOn = profile.basedOn, !basedOn.isEmpty {
            return signals(basedOn)
        }
        if let recentSignals = profile.energyProfile?.recentSignals, !recentSignals.isEmpty {
            return energySignals(recentSignals)
        }
        if let recommendationSignals = profile.recommendationSignals, !recommendationSignals.isEmpty {
            return signals(recommendationSignals)
        }
        return nil
    }

    private func names(_ values: [DJConnectMusicDNANameValue]) -> String {
        values.map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: ", ")
    }

    private func tracks(_ values: [DJConnectMusicDNATrack]) -> String {
        values.compactMap { track in
            let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let artist = track.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let album = track.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if title.isEmpty { return artist.isEmpty ? nil : artist }
            let titleArtist = artist.isEmpty ? title : "\(title) — \(artist)"
            return album.isEmpty ? titleArtist : "\(titleArtist) · \(album)"
        }
        .prefix(3)
        .joined(separator: "\n")
        .ifEmpty(localizedKey(model.language, "ui.music.dna.needs.more.listening.for.recent.tracks"))
    }

    private func artistArtwork(_ artist: DJConnectMusicDNANameValue) -> URL? {
        model.resolvedMusicDNAArtworkURL(artist.imageURL, uri: artist.uri, artist: true)
    }

    private func trackArtwork(_ track: DJConnectMusicDNATrack) -> URL? {
        model.resolvedMusicDNAArtworkURL(track.imageURL, uri: track.uri, artist: false)
    }

    private var acceptedArtistImages: [String: URL] {
        guard let discovery = model.musicDiscoveryResponse,
              let profileID = model.musicDNAProfileResponse?.profileID,
              !profileID.isEmpty, discovery.profileID == profileID else { return [:] }
        var images: [String: URL] = [:]
        for item in discovery.sections.flatMap(\.items) where item.kind == .artist {
            guard let uri = item.uri, uri.hasPrefix("spotify:artist:"),
                  let url = model.resolvedMusicDNAArtworkURL(nil, uri: uri, artist: true) else { continue }
            images[uri] = url
        }
        return images
    }

    private func rangeText<T>(_ ranges: [String: [T]], formatter: ([T]) -> String) -> String? {
        let lines = ranges.keys.sorted().compactMap { key -> String? in
            guard let values = ranges[key], !values.isEmpty else { return nil }
            let formatted = formatter(values).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !formatted.isEmpty else { return nil }
            return "\(key.replacingOccurrences(of: "_", with: " ")): \(formatted)"
        }
        .prefix(4)
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func discoveryFeedbackText(_ feedback: DJConnectMusicDNADiscoveryFeedback) -> String {
        var lines: [String] = []
        if !feedback.acceptedRecommendations.isEmpty {
            let accepted = feedback.acceptedRecommendations.prefix(3).compactMap { $0.title ?? $0.subtitle ?? $0.reason }.joined(separator: ", ")
            if !accepted.isEmpty {
                lines.append("\(localizedKey(model.language, "ui.accepted.recommendations")): \(accepted)")
            }
        }
        if !feedback.negativeSignals.isEmpty {
            lines.append("\(localizedKey(model.language, "ui.discovery.less.like.this")): \(signals(feedback.negativeSignals))")
        }
        if !feedback.hiddenArtists.isEmpty {
            lines.append("\(localizedKey(model.language, "ui.discovery.hide.artist")): \(names(feedback.hiddenArtists))")
        }
        if !feedback.counts.isEmpty {
            let counts = feedback.counts.keys.sorted().map { "\($0.replacingOccurrences(of: "_", with: " ")): \(feedback.counts[$0] ?? 0)" }.joined(separator: ", ")
            lines.append(counts)
        }
        return lines.joined(separator: "\n").ifEmpty(localizedKey(model.language, "ui.not.enough.signals"))
    }

    private func privacyDashboardText(_ dashboard: DJConnectMusicDNAPrivacyDashboard) -> String {
        MusicDNAPrivacySummary.text(dashboard, language: model.language)
    }

    private func energySignals(_ values: [DJConnectMusicDNAEnergySignal]) -> String {
        values.compactMap { signal in
            let title = signal.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let artist = signal.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let album = signal.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty || !artist.isEmpty || !album.isEmpty else {
                return nil
            }
            if title.isEmpty {
                return artist.isEmpty ? album : artist
            }
            let titleArtist = artist.isEmpty ? title : "\(title) — \(artist)"
            return album.isEmpty ? titleArtist : "\(titleArtist) · \(album)"
        }
        .prefix(4)
        .joined(separator: "\n")
        .ifEmpty(localizedKey(model.language, "ui.music.dna.needs.more.listening.for.basis"))
    }

    private func signals(_ values: [DJConnectMusicDNASignal]) -> String {
        values.compactMap { signal -> String? in
            let title = signal.title ?? signal.name ?? signal.value
            let artist = signal.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let album = signal.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let genres = signal.genres
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(2)
                .joined(separator: ", ")
            let primary = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if primary.isEmpty, artist.isEmpty, album.isEmpty, genres.isEmpty {
                return nil
            }
            if !primary.isEmpty {
                if !artist.isEmpty {
                    return album.isEmpty ? "\(primary) — \(artist)" : "\(primary) — \(artist) · \(album)"
                }
                if !genres.isEmpty {
                    return "\(primary) · \(genres)"
                }
                return primary
            }
            if !artist.isEmpty {
                return album.isEmpty ? artist : "\(artist) · \(album)"
            }
            return genres
        }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "\n")
            .ifEmpty(localizedKey(model.language, "ui.music.dna.needs.more.listening.for.basis"))
    }

    private func musicDNAZoneLabel(_ zone: String?) -> String? {
        switch zone?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "chill":
            return "Chill"
        case "groove":
            return "Groove"
        case "energy":
            return "Energy"
        case "party":
            return "Party"
        case let value? where !value.isEmpty:
            return value
                .split(separator: "_")
                .map { String($0.prefix(1)).uppercased() + String($0.dropFirst()) }
                .joined(separator: " ")
        default:
            return nil
        }
    }

    private func signalCountLabel(_ count: Int) -> String {
        count == 1 ? "1 signaal" : "\(count) signalen"
    }

    private func analysisCountLabel(_ count: Int) -> String {
        count == 1 ? "1 analyse" : "\(count) analyses"
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
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
            .controlSize(.large)
            .disabled(model.isUpdatingMusicDNA)
        }
        .padding(24)
        .djConnectGradientCard()
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
        .padding(24)
        .djConnectGradientCard()
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
                Task { await model.refreshMusicDNAProfile(showToast: true) }
            } label: {
                Label(localizedKey(model.language, "ui.try.again"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
            .disabled(model.isLoadingMusicDNA)
        }
        .padding(24)
        .djConnectGradientCard()
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
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .djConnectGradientCard()
    }
}

#if DEBUG && os(iOS) && targetEnvironment(simulator)
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
#endif

private extension DJConnectMusicDNAProfileResponse {
    static let previewPopulated = DJConnectMusicDNAProfileResponse(
        success: true,
        musicDNAKey: "user:preview",
        enabled: true,
        generation: 2,
        updatedAt: Date(),
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
            recentFavoriteTracks: [
                DJConnectMusicDNATrack(title: "VCR", artist: "The xx", album: "xx"),
                DJConnectMusicDNATrack(title: "Breathing", artist: "Ben Bohmer", album: "Breathing")
            ],
            mood: DJConnectMusicDNAMood(value: 65, zone: "energy", promptHint: "keep it warm"),
            energyProfile: DJConnectMusicDNAEnergyProfile(
                sampleCount: 3,
                energy: 0.68,
                energyPercent: 68,
                zone: "energy",
                danceability: 0.62,
                danceabilityPercent: 62,
                intensity: 0.58,
                intensityPercent: 58,
                recentSignals: [
                    DJConnectMusicDNAEnergySignal(title: "Intro", artist: "The xx", album: "xx"),
                    DJConnectMusicDNAEnergySignal(title: "Beyond Beliefs", artist: "Ben Bohmer")
                ]
            ),
            playtime: DJConnectMusicDNAPlaytime(
                totalSeconds: 8_460,
                totalHours: 2.35,
                formattedTotal: "2u 21m",
                topArtists: [
                    DJConnectMusicDNAPlaytimeArtist(name: "The xx", seconds: 3_000, hours: 0.83, formatted: "50m"),
                    DJConnectMusicDNAPlaytimeArtist(name: "Ben Bohmer", seconds: 2_400, hours: 0.67, formatted: "40m"),
                    DJConnectMusicDNAPlaytimeArtist(name: "Tycho", seconds: 1_500, hours: 0.42, formatted: "25m")
                ],
                topAlbums: [
                    DJConnectMusicDNAPlaytimeArtist(name: "xx", seconds: 2_700, hours: 0.75, formatted: "45m"),
                    DJConnectMusicDNAPlaytimeArtist(name: "Breathing", seconds: 2_100, hours: 0.58, formatted: "35m")
                ]
            ),
            listeningRhythm: DJConnectMusicDNAListeningRhythm(
                sampleCount: 5,
                topDaypart: "Avond",
                topWeekday: "Vrijdag",
                dayparts: [
                    DJConnectMusicDNAListeningRhythmItem(daypart: "Avond", count: 3, percent: 60),
                    DJConnectMusicDNAListeningRhythmItem(daypart: "Nacht", count: 2, percent: 40)
                ],
                weekdays: [
                    DJConnectMusicDNAListeningRhythmItem(weekday: "Vrijdag", count: 2, percent: 40),
                    DJConnectMusicDNAListeningRhythmItem(weekday: "Zaterdag", count: 2, percent: 40),
                    DJConnectMusicDNAListeningRhythmItem(weekday: "Zondag", count: 1, percent: 20)
                ]
            ),
            moodMix: DJConnectMusicDNAMoodMix(
                sampleCount: 4,
                average: 61,
                topZone: "groove",
                zones: [
                    DJConnectMusicDNAMoodMixZone(zone: "chill", count: 1, percent: 25),
                    DJConnectMusicDNAMoodMixZone(zone: "groove", count: 2, percent: 50),
                    DJConnectMusicDNAMoodMixZone(zone: "energy", count: 1, percent: 25)
                ]
            ),
            repeatMagnets: DJConnectMusicDNARepeatMagnets(
                eligible: true,
                items: [
                    DJConnectMusicDNARepeatMagnetItem(kind: "artist", name: "The xx", count: 4),
                    DJConnectMusicDNARepeatMagnetItem(kind: "album", name: "xx", formatted: "45m"),
                    DJConnectMusicDNARepeatMagnetItem(kind: "artist", name: "Ben Bohmer", count: 3)
                ]
            ),
            explicitPositives: DJConnectMusicDNAExplicitPositives(
                eligible: true,
                signalCount: 3,
                favoriteTracks: [
                    DJConnectMusicDNAFavoriteTrackSignal(title: "VCR", artist: "The xx"),
                    DJConnectMusicDNAFavoriteTrackSignal(title: "Breathing", artist: "Ben Bohmer")
                ],
                acceptedRecommendations: [
                    DJConnectMusicDNAAcceptedRecommendationSignal(title: "A Walk", subtitle: "Wide pads"),
                    DJConnectMusicDNAAcceptedRecommendationSignal(title: "Glue", subtitle: "Soft vocal fragments")
                ]
            ),
            tasteAnchors: DJConnectMusicDNATasteAnchors(
                eligible: true,
                items: [
                    DJConnectMusicDNATasteAnchorItem(kind: "artist", name: "The xx", playCount: 5, formatted: "50m"),
                    DJConnectMusicDNATasteAnchorItem(kind: "genre", name: "ambient"),
                    DJConnectMusicDNATasteAnchorItem(kind: "genre", name: "melodic house"),
                    DJConnectMusicDNATasteAnchorItem(kind: "artist", name: "Ben Bohmer", playCount: 4, formatted: "40m")
                ]
            ),
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

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private let musicDNADashboardPanelMinHeight: CGFloat = 220
private let musicDNAIPhoneDashboardPanelHeight: CGFloat = 320
private let musicDNAIPhoneLandscapeDashboardPanelHeight: CGFloat = 260

private struct MusicDNASummaryItem {
    let label: String
    let value: String
    let icon: String
}

private struct MusicDNASummaryPanel: View {
    let title: String
    let rows: [MusicDNASummaryItem]
    let fallback: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MusicDNACompactPanelHeader(title: title, icon: "waveform")
            if rows.isEmpty {
                ForEach(Array(fallback.split(whereSeparator: { $0 == ";" || $0 == "\n" }).enumerated()), id: \.offset) { _, clause in
                    Text(clause.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: row.icon)
                            .foregroundStyle(djConnectAccent).frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.label).font(.caption).foregroundStyle(.secondary)
                            Text(row.value).font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNASummarySection")
    }
}

private struct MusicDNAPanel: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: icon)
            Text(value.isEmpty ? "-" : value)
                .font(.headline.weight(.semibold))
                .lineSpacing(6)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
    }
}

private struct MusicDNATrackListPanel: View {
    let title: String
    let tracks: [DJConnectMusicDNATrack]
    let artworkURL: (DJConnectMusicDNATrack) -> URL?
    var icon = "heart.fill"
    var identifier = "musicDNARecentFavoriteTracksSection"
    var limit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicDNACompactPanelHeader(title: title, icon: icon)

            VStack(spacing: 10) {
                ForEach(Array(tracks.prefix(limit).enumerated()), id: \.offset) { _, track in
                    MusicDNATrackListRow(track: track, artworkURL: artworkURL(track))
                }
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier(identifier)
    }
}

private struct MusicDNATopTracksPanel: View {
    let title: String
    let ranges: [String: [DJConnectMusicDNATrack]]
    let language: String
    let artworkURL: (DJConnectMusicDNATrack) -> URL?

    private var orderedRanges: [String] {
        let known = ["short_term", "medium_term", "long_term"]
        return (known + ranges.keys.filter { !known.contains($0) }.sorted())
            .filter { !(ranges[$0]?.isEmpty ?? true) }
    }

    private func rangeTitle(_ range: String) -> String {
        switch range {
        case "short_term", "medium_term", "long_term":
            localizedKey(language, "ui.music.dna.range." + range)
        default: range.replacingOccurrences(of: "_", with: " ")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: "chart.bar.xaxis")
            ForEach(Array(orderedRanges.prefix(4)), id: \.self) { range in
                VStack(alignment: .leading, spacing: 10) {
                    Text(rangeTitle(range))
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(Array((ranges[range] ?? []).prefix(3).enumerated()), id: \.offset) { _, track in
                        MusicDNATrackListRow(track: track, artworkURL: artworkURL(track))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNATopTracksByRangeSection")
    }
}

private struct MusicDNAArtistsPanel: View {
    let title: String
    let artists: [DJConnectMusicDNANameValue]
    let artworkURL: (DJConnectMusicDNANameValue) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: "person.wave.2")
            MusicDNAArtistStrip(artists: artists, artworkURL: artworkURL)
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNAFavoriteArtistsSection")
    }
}

private struct MusicDNAArtistStrip: View {
    let artists: [DJConnectMusicDNANameValue]
    let artworkURL: (DJConnectMusicDNANameValue) -> URL?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(Array(artists.enumerated()), id: \.offset) { _, artist in
                    VStack(spacing: 8) {
                        CachedArtworkImage(url: artworkURL(artist), mode: .fill) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable().scaledToFit()
                                .foregroundStyle(djConnectAccent.opacity(0.7))
                                .padding(14)
                                .background(.white.opacity(0.08), in: Circle())
                        }
                        .frame(width: 72, height: 72).clipShape(Circle())
                        .accessibilityHidden(true)
                        Text(artist.name)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(width: 96)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct MusicDNATopArtistsPanel: View {
    let title: String
    let ranges: [String: [DJConnectMusicDNANameValue]]
    let language: String
    let artworkURL: (DJConnectMusicDNANameValue) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MusicDNACompactPanelHeader(title: title, icon: "person.2.wave.2")
            ForEach(["long_term", "medium_term", "short_term"], id: \.self) { range in
                VStack(alignment: .leading, spacing: 10) {
                    Text(localizedKey(language, "ui.music.dna.range." + range))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    if let artists = ranges[range], !artists.isEmpty {
                        MusicDNAArtistStrip(artists: artists, artworkURL: artworkURL)
                    } else {
                        Text(localizedKey(language, "ui.not.enough.signals"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNATopArtistsByRangeSection")
    }
}

private struct MusicDNAListeningRhythmPanel: View {
    let rhythm: DJConnectMusicDNAListeningRhythm
    let title: String

    private var primaryValue: String {
        rhythm.topDaypart?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("-") ?? "-"
    }

    private var secondaryValue: String? {
        let value = rhythm.topWeekday?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: "clock")
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryValue)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let secondaryValue {
                    Text(secondaryValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !rhythm.dayparts.isEmpty {
                MusicDNADistributionList(
                    items: rhythm.dayparts.map { item in
                        MusicDNADistributionItem(
                            label: item.daypart ?? "",
                            percent: item.percent,
                            tint: djConnectAccent
                        )
                    }
                )
            }
            if !rhythm.visibleWeekdays.isEmpty {
                MusicDNAChipRow(
                    items: rhythm.visibleWeekdays.map { item in
                        MusicDNAChipItem(label: item.weekday ?? "", detail: item.percent.map(percentText))
                    }
                )
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNAListeningRhythmSection")
    }
}

private struct MusicDNAMoodMixPanel: View {
    let moodMix: DJConnectMusicDNAMoodMix
    let title: String
    let averageTitle: String

    private var primaryValue: String {
        musicDNAZoneDisplayLabel(moodMix.topZone)
            ?? moodMix.topZone?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("-")
            ?? "-"
    }

    private var averageValue: String? {
        guard let average = moodMix.average else {
            return nil
        }
        return "\(averageTitle): \(average)/100"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: musicDNAMoodIcon(moodMix.topZone))
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryValue)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let averageValue {
                    Text(averageValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            MusicDNADistributionList(
                items: moodMix.zones.map { zone in
                    MusicDNADistributionItem(
                        label: musicDNAZoneDisplayLabel(zone.zone) ?? zone.zone,
                        percent: zone.percent,
                        tint: musicDNAMoodTint(zone.zone)
                    )
                }
            )
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNAMoodMixSection")
    }
}

private struct MusicDNAPlaytimePanel: View {
    let playtime: DJConnectMusicDNAPlaytime
    let title: String
    let subtitle: String
    let topArtistsTitle: String
    let topAlbumsTitle: String

    private var totalText: String {
        let formatted = playtime.formattedTotal?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return formatted.isEmpty ? "\(playtime.totalSeconds)s" : formatted
    }

    private var visibleArtists: [DJConnectMusicDNAPlaytimeArtist] {
        playtime.visibleTopArtists
    }

    private var visibleAlbums: [DJConnectMusicDNAPlaytimeArtist] {
        playtime.visibleTopAlbums
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: "timer")

            VStack(alignment: .leading, spacing: 4) {
                Text(totalText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !visibleArtists.isEmpty {
                MusicDNAPlaytimeRanking(title: topArtistsTitle, items: visibleArtists)
            }
            if !visibleAlbums.isEmpty {
                MusicDNAPlaytimeRanking(title: topAlbumsTitle, items: visibleAlbums)
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNAPlaytimeSection")
    }
}

private struct MusicDNARepeatMagnetsPanel: View {
    let repeatMagnets: DJConnectMusicDNARepeatMagnets
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: "repeat")
            VStack(spacing: 10) {
                ForEach(Array(repeatMagnets.visibleItems.enumerated()), id: \.offset) { _, item in
                    MusicDNAProfileSignalRow(
                        title: item.name,
                        subtitle: repeatMagnetSubtitle(item),
                        icon: item.kind == "album" ? "square.stack" : "person.wave.2"
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNARepeatMagnetsSection")
    }

    private func repeatMagnetSubtitle(_ item: DJConnectMusicDNARepeatMagnetItem) -> String? {
        switch item.kind {
        case "artist":
            return item.count.map { $0 == 1 ? "1 keer" : "\($0) keer" } ?? item.formatted
        case "album":
            return item.formatted ?? item.count.map { $0 == 1 ? "1 keer" : "\($0) keer" }
        default:
            return item.formatted ?? item.count.map { $0 == 1 ? "1 keer" : "\($0) keer" }
        }
    }
}

private struct MusicDNAExplicitPositivesPanel: View {
    let positives: DJConnectMusicDNAExplicitPositives
    let title: String
    let favoritesTitle: String
    let acceptedRecommendationsTitle: String
    var artistImages: [String: URL] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: "hand.thumbsup.fill")
            if !positives.visibleFavoriteTracks.isEmpty {
                MusicDNAProfileSignalSection(title: favoritesTitle) {
                    ForEach(Array(positives.visibleFavoriteTracks.enumerated()), id: \.offset) { _, track in
                        MusicDNAProfileSignalRow(
                            title: track.title,
                            subtitle: track.artist,
                            icon: "heart.fill"
                        )
                    }
                }
            }
            if !positives.visibleAcceptedRecommendations.isEmpty {
                MusicDNAProfileSignalSection(title: acceptedRecommendationsTitle) {
                    ForEach(Array(positives.visibleAcceptedRecommendations.enumerated()), id: \.offset) { _, recommendation in
                        MusicDNAProfileSignalRow(
                            title: recommendation.title?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(recommendation.subtitle ?? "-") ?? recommendation.subtitle ?? "-",
                            subtitle: recommendation.subtitle,
                            icon: "checkmark.seal.fill",
                            imageURL: recommendation.uri.flatMap { artistImages[$0] }
                        )
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNAExplicitPositivesSection")
    }
}

private struct MusicDNATasteAnchorsPanel: View {
    let anchors: DJConnectMusicDNATasteAnchors
    let title: String

    private var artistItems: [DJConnectMusicDNATasteAnchorItem] {
        anchors.visibleItems.filter { $0.kind == "artist" }
    }

    private var genreItems: [DJConnectMusicDNATasteAnchorItem] {
        anchors.visibleItems.filter { $0.kind == "genre" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: title, icon: "anchor")
            if !artistItems.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(artistItems.enumerated()), id: \.offset) { _, item in
                        MusicDNAProfileSignalRow(
                            title: item.name,
                            subtitle: tasteAnchorSubtitle(item),
                            icon: "person.wave.2"
                        )
                    }
                }
            }
            if !genreItems.isEmpty {
                MusicDNAChipRow(
                    items: genreItems.map { MusicDNAChipItem(label: $0.name, detail: nil, icon: musicDNAGenreGlyph($0.name)) }
                )
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .accessibilityIdentifier("musicDNATasteAnchorsSection")
    }

    private func tasteAnchorSubtitle(_ item: DJConnectMusicDNATasteAnchorItem) -> String? {
        if let playCount = item.playCount {
            return playCount == 1 ? "1 keer" : "\(playCount) keer"
        }
        return item.formatted
    }
}

private struct MusicDNACompactPanelHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(djConnectAccent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MusicDNAProfileSignalSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
            VStack(spacing: 10) {
                content
            }
        }
    }
}

private struct MusicDNAProfileSignalRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    var imageURL: URL? = nil

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("-")
    }

    private var cleanSubtitle: String? {
        let value = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    var body: some View {
        HStack(spacing: 10) {
            CachedArtworkImage(url: imageURL, mode: .fill) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.white.opacity(0.08))
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(djConnectAccent)
            }
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(cleanTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let cleanSubtitle {
                    Text(cleanSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MusicDNAPlaytimeRanking: View {
    let title: String
    let items: [DJConnectMusicDNAPlaytimeArtist]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(djConnectAccent)
                        .frame(width: 18, alignment: .leading)
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(item.formatted?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("-") ?? "-")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct MusicDNADistributionItem: Equatable {
    var label: String
    var percent: Double?
    var tint: Color
}

private struct MusicDNADistributionList: View {
    let items: [MusicDNADistributionItem]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let sanitizedLabel = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitizedLabel.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(sanitizedLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(percentText(item.percent))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.64))
                                .lineLimit(1)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.10))
                                Capsule()
                                    .fill(item.tint.opacity(0.82))
                                    .frame(width: max(4, proxy.size.width * CGFloat(clampedPercent(item.percent) / 100)))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
}

private func musicDNAGenreGlyph(_ genre: String) -> String {
    let name = genre.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    let families: [([String], String)] = [
        (["children", "kids", "kinder", "sprookjes"], "sparkles"),
        (["metal", "hard rock", "punk"], "bolt.fill"),
        (["classical", "klassiek", "piano"], "pianokeys"),
        (["jazz", "blues"], "music.quarternote.3"),
        (["hip hop", "hip-hop", "rap"], "mic.fill"),
        (["electronic", "techno", "house", "trance", "synth"], "waveform"),
        (["dance", "disco"], "figure.dance"),
        (["ambient", "chill", "meditation"], "water.waves"),
        (["rock", "folk", "country", "acoustic"], "guitars.fill"),
        (["soul", "r&b", "rnb"], "heart.fill"),
        (["reggae", "latin", "salsa"], "sun.max.fill"),
        (["pop"], "star.fill")
    ]
    return families.first { $0.0.contains(where: name.contains) }?.1 ?? "music.note"
}

private struct MusicDNAChipItem: Equatable {
    var label: String
    var detail: String?
    var icon: String? = nil
}

private struct MusicDNAChipRow: View {
    let items: [MusicDNAChipItem]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let sanitizedLabel = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitizedLabel.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 7) {
                            if let icon = item.icon {
                                Image(systemName: icon)
                                    .foregroundStyle(djConnectAccent)
                                    .frame(width: 16)
                                    .accessibilityHidden(true)
                            }
                            Text(sanitizedLabel)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .font(.caption.weight(.semibold))
                        if let detail = item.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
                            Text(detail)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.58))
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
        }
    }
}

/// Keep source/accessibility order stable while filling the shortest visible column.
private struct MusicDNAAdaptiveCardLayout: Layout {
    var minimumColumnWidth: CGFloat = 280
    var spacing: CGFloat = 12

    private func arrangement(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        guard !subviews.isEmpty else { return ([], 0) }
        let columns = min(subviews.count, max(1, Int((width + spacing) / (minimumColumnWidth + spacing))))
        let columnWidth = max(1, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        var bottoms = Array(repeating: CGFloat.zero, count: columns)
        var frames: [CGRect] = []
        for subview in subviews {
            // First minimum wins ties, keeping equal-height cards left-to-right.
            let column = bottoms.indices.min { bottoms[$0] < bottoms[$1] } ?? 0
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            frames.append(CGRect(x: CGFloat(column) * (columnWidth + spacing), y: bottoms[column], width: columnWidth, height: height))
            bottoms[column] += height + spacing
        }
        return (frames, max(0, (bottoms.max() ?? 0) - spacing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? max(1, $0) : nil } ?? minimumColumnWidth
        return CGSize(width: width, height: arrangement(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrangement(width: bounds.width, subviews: subviews).frames
        for (index, subview) in subviews.enumerated() {
            let frame = frames[index]
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
}

private struct MusicDNADashboardPanelModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @ViewBuilder
    func body(content: Content) -> some View {
        if usesBoundedPhoneCard {
            ScrollView(.vertical, showsIndicators: false) {
                content.padding(18).frame(maxWidth: .infinity, alignment: .topLeading)
            }
            #if os(iOS)
            .scrollBounceBehavior(.basedOnSize)
            #endif
            .frame(maxWidth: .infinity, minHeight: panelMinHeight, alignment: .topLeading)
            .djSessionFrostedSurface()
        } else {
            content
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .djSessionFrostedSurface()
        }
    }

    private var usesBoundedPhoneCard: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact && UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var panelMinHeight: CGFloat {
        #if os(iOS)
        if horizontalSizeClass == .compact, UIDevice.current.userInterfaceIdiom == .phone {
            return verticalSizeClass == .compact
                ? musicDNAIPhoneLandscapeDashboardPanelHeight
                : musicDNAIPhoneDashboardPanelHeight
        }
        #endif
        return musicDNADashboardPanelMinHeight
    }
}

private extension View {
    func musicDNADashboardPanel() -> some View {
        modifier(MusicDNADashboardPanelModifier())
    }
}

private func clampedPercent(_ value: Double?) -> Double {
    min(100, max(0, value ?? 0))
}

private func percentText(_ value: Double?) -> String {
    let percent = clampedPercent(value)
    if percent.rounded() == percent {
        return "\(Int(percent))%"
    }
    return String(format: "%.1f%%", percent)
}

private func musicDNAZoneDisplayLabel(_ zone: String?) -> String? {
    switch zone?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "chill":
        return "Chill"
    case "groove":
        return "Groove"
    case "energy":
        return "Energy"
    case "party":
        return "Party"
    case let value? where !value.isEmpty:
        return value
            .split(separator: "_")
            .map { String($0.prefix(1)).uppercased() + String($0.dropFirst()) }
            .joined(separator: " ")
    default:
        return nil
    }
}

private func musicDNAMoodIcon(_ zone: String?) -> String {
    switch zone?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "chill":
        return "moon.zzz.fill"
    case "groove":
        return "waveform"
    case "energy":
        return "bolt.fill"
    case "party":
        return "party.popper.fill"
    default:
        return "sparkles"
    }
}

private func musicDNAMoodTint(_ zone: String) -> Color {
    switch zone.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "chill":
        return Color(red: 0.34, green: 0.74, blue: 1.0)
    case "groove":
        return Color(red: 0.36, green: 0.90, blue: 0.60)
    case "energy":
        return Color(red: 1.0, green: 0.70, blue: 0.24)
    case "party":
        return djConnectAccent
    default:
        return djConnectAccent
    }
}

private struct MusicDiscoveryView: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
    @State private var selectedDetail: MusicDiscoveryDetailSelection?
    @State private var statusToast: DJConnectVisualNotice?

    private var visibleSections: [DJConnectMusicDiscoverySection] {
        model.musicDiscoveryResponse?.visibleSections ?? []
    }

    private func shouldUseWideLayout(for size: CGSize) -> Bool {
        #if os(macOS)
        size.width >= 1_000
        #else
        horizontalSizeClass == .regular && size.width > size.height
        #endif
    }

    private func maxContentWidth(for size: CGSize) -> CGFloat {
        shouldUseWideLayout(for: size) ? djConnectMacDetailContentMaxWidth : djConnectContentMaxWidth
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                GeometryReader { proxy in
                    ScrollView {
                        let contentWidth = min(maxContentWidth(for: proxy.size), proxy.size.width)
                        VStack(alignment: .leading, spacing: 18) {
                            header
                            content
                        }
                        .padding(.horizontal, djConnectScreenHorizontalPadding)
                        .padding(.vertical, djConnectScreenVerticalPadding)
                        .frame(width: contentWidth, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    #if os(iOS)
                    .refreshable { await refreshMusicDiscoveryWithToast() }
                    #endif
                }
            }
            .djStatusToastOverlay(statusToast ?? model.musicDNAToast, screenImage: "wand.and.stars")
            .accessibilityIdentifier("screen-discovery")
            .navigationTitle(screenTitle(model.language, key: "ui.discover", isDemoMode: model.isDemoMode))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                    Button {
                        Task { await refreshMusicDiscoveryWithToast() }
                    } label: {
                        if model.isRefreshingMusicDiscovery || model.isLoadingMusicDiscovery {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise").foregroundStyle(.white)
                        }
                    }
                    .disabled(model.isRefreshingMusicDiscovery || model.isLoadingMusicDiscovery)
                    .tint(.white)
                    .accessibilityLabel(localizedKey(model.language, "ui.refresh.discover"))
                }
                ConnectionStatusToolbar(model: model)
            }
            .task(id: model.isDemoMode || (model.pairingStatus == .paired && model.isRuntimeCompatible)) {
                await model.loadMusicDiscovery(showToast: true)
            }
            .sheet(item: $selectedDetail) { selection in
                MusicDiscoveryDetailView(
                    model: model,
                    sectionID: selection.sectionID,
                    item: selection.item
                )
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
            }
        }
    }

    private func refreshMusicDiscoveryWithToast() async {
        let didRefresh = await model.refreshMusicDiscovery()
        let failureMessage = model.musicDiscoveryErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        showStatusToast(
            didRefresh
                ? localizedKey(model.language, "appModel.discovery.updated")
                : (failureMessage?.isEmpty == false ? failureMessage! : localizedKey(model.language, "appModel.discovery.update.failed")),
            systemImage: "wand.and.stars"
        )
    }

    private func showStatusToast(_ text: String, systemImage: String) {
        let notice = DJConnectVisualNotice(text: text, systemImage: systemImage)
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = notice
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast?.id == notice.id else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if shouldShowMusicDNALockedState {
            MusicDiscoveryLockedState(model: model)
        } else if model.musicDiscoveryResponse == nil || visibleSections.isEmpty {
            MusicDiscoveryEmptyState(model: model)
        } else {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(visibleSections) { section in
                    MusicDiscoverySectionView(
                        model: model,
                        section: section,
                        showDetail: { item in
                            selectedDetail = MusicDiscoveryDetailSelection(sectionID: section.id, item: item)
                        }
                    )
                }
            }
        }
    }

    private var shouldShowMusicDNALockedState: Bool {
        if model.musicDNAProfileResponse?.enabled == true {
            return false
        }
        return model.musicDiscoveryResponse?.isMusicDNADisabled == true
            || model.musicDNAProfileResponse?.enabled == false
    }

    private var header: some View {
        VStack(spacing: 16) {
            DJConnectHeroGlyph(systemImage: "wand.and.stars")

            Text(localizedKey(model.language, "ui.discover"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(localizedKey(model.language, "ui.learn.from.your.taste.and.listening.behavior.to.shape.recommendations"))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 190)
        .djConnectHeroCard()
    }
}

private struct MusicDiscoveryDetailSelection: Identifiable {
    let sectionID: String
    let item: DJConnectMusicDiscoveryItem

    var id: String { "\(sectionID)-\(item.id)" }
}

private struct MusicDiscoverySectionView: View {
    @ObservedObject var model: DJConnectAppModel
    let section: DJConnectMusicDiscoverySection
    let showDetail: (DJConnectMusicDiscoveryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(section.visibleItems) { item in
                        MusicDiscoveryCard(
                            model: model,
                            sectionID: section.id,
                            item: item,
                            showDetail: { showDetail(item) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(20)
        .clipShape(DJConnectCardAppearance.shape)
        .djSessionFrostedSurface()
    }
}

private struct MusicDiscoveryCard: View {
    @ObservedObject var model: DJConnectAppModel
    let sectionID: String
    let item: DJConnectMusicDiscoveryItem
    let showDetail: () -> Void

    private var artworkURL: URL? {
        musicDiscoveryArtworkURL(item.imageURL, model: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                    #if os(iOS)
                    DJConnectHaptics.selection()
                    #endif
                    showDetail()
                } label: {
                    artwork.contentShape(DJConnectCardAppearance.shape)
                }
                .djConnectPlainButtonStyle()
                .accessibilityLabel(item.title)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
                if !item.reason.isEmpty {
                    Text(item.reason)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                }
                MusicDiscoveryFitLabel(item: item)
                Text(item.kind.rawValue.capitalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(djConnectAccent)
                    .textCase(.uppercase)
            }
            .frame(width: 142, alignment: .leading)
        }
    }

    private var artwork: some View {
        ZStack {
            DJConnectCardAppearance.shape
                .fill(.white.opacity(0.10))
            if let artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    default:
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }
            } else {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.74))
            }
            if model.playingMusicDiscoveryItemID == item.id {
                Color.black.opacity(0.36)
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: 142, height: 142)
        .clipShape(DJConnectCardAppearance.shape)
        .overlay {
            DJConnectCardAppearance.shape
                .stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
        }
    }
}

private struct MusicDiscoveryDetailView: View {
    @ObservedObject var model: DJConnectAppModel
    let sectionID: String
    let item: DJConnectMusicDiscoveryItem
    @Environment(\.dismiss) private var dismiss

    private var artworkURL: URL? {
        musicDiscoveryArtworkURL(item.imageURL, model: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    MusicDiscoveryDetailArtwork(url: artworkURL)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                        Text(item.kind.rawValue.capitalized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(djConnectAccent)
                    }
                    Spacer()
                }

                if !item.reason.isEmpty {
                    Text(item.reason)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }

                MusicDiscoveryQualityView(item: item)

                if !item.reasonSources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(item.reasonSources, id: \.self) { source in
                                Text(source.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.10), in: Capsule())
                            }
                        }
                    }
                    .scrollClipDisabled()
                }

                if item.isPlayable {
                    Button {
                        Task {
                            if await model.playMusicDiscoveryItem(item, sectionID: sectionID) { dismiss() }
                        }
                    } label: {
                        Label(localizedKey(model.language, "ui.play.now"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                    .disabled(model.playingMusicDiscoveryItemID == item.id)
                }

                if let error = model.musicDiscoveryErrorMessage {
                    Text(error).font(.callout).foregroundStyle(.white)
                        .accessibilityIdentifier("discovery-play-error")
                }

                if model.supportsMusicDiscoveryFeedback {
                    Menu {
                        Button(localizedKey(model.language, "ui.discovery.not.for.me")) {
                            Task {
                                await model.sendMusicDiscoveryFeedback(.notForMe, item: item, sectionID: sectionID)
                                dismiss()
                            }
                        }
                        Button(localizedKey(model.language, "ui.discovery.less.like.this")) {
                            Task {
                                await model.sendMusicDiscoveryFeedback(.lessLikeThis, item: item, sectionID: sectionID)
                                dismiss()
                            }
                        }
                        Button(localizedKey(model.language, "ui.discovery.hide.artist")) {
                            Task {
                                await model.sendMusicDiscoveryFeedback(.hideArtist, item: item, sectionID: sectionID)
                                dismiss()
                            }
                        }
                    } label: {
                        Label(localizedKey(model.language, "ui.feedback"), systemImage: "hand.thumbsdown")
                            .frame(maxWidth: .infinity)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .secondary, expands: true))
                }

                Button {
                    dismiss()
                } label: {
                    Text(localizedKey(model.language, "ui.close"))
                        .frame(maxWidth: .infinity)
                }
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .tertiary, expands: true))
                .padding(.top, -4)
            }
            .padding(22)
        }
        .background(DJConnectCanvasBackground())
    }
}

private struct MusicDiscoveryFitLabel: View {
    let item: DJConnectMusicDiscoveryItem

    var body: some View {
        if let text = fitText {
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)
        }
    }

    private var fitText: String? {
        if let band = item.qualityBand?.trimmingCharacters(in: .whitespacesAndNewlines), !band.isEmpty {
            return band.replacingOccurrences(of: "_", with: " ")
        }
        if let confidence = item.confidence {
            return confidence.rawValue
        }
        if let score = item.qualityScore {
            return "\(Int((score * 100).rounded()))%"
        }
        return nil
    }
}

private struct MusicDiscoveryQualityView: View {
    let item: DJConnectMusicDiscoveryItem

    var body: some View {
        let chips = qualityChips
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.78))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.08), in: Capsule())
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var qualityChips: [String] {
        var chips: [String] = []
        if let confidence = item.confidence {
            chips.append(confidence.rawValue.replacingOccurrences(of: "_", with: " "))
        }
        if let score = item.qualityScore {
            chips.append("\(Int((score * 100).rounded()))%")
        }
        if let band = item.qualityBand?.trimmingCharacters(in: .whitespacesAndNewlines), !band.isEmpty {
            chips.append(band.replacingOccurrences(of: "_", with: " "))
        }
        chips.append(contentsOf: item.qualityFactors.map { $0.replacingOccurrences(of: "_", with: " ") })
        return chips
    }
}

private struct MusicDiscoveryDetailArtwork: View {
    let url: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.10))
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }
            } else {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.white.opacity(0.74))
            }
        }
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DJConnectStatusCard<Action: View>: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
    @ViewBuilder var action: Action

    init(
        title: String,
        message: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
        self.action = action()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            action
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: 520, alignment: .leading)
        .background(.white.opacity(0.08), in: DJConnectCardAppearance.shape)
        .overlay {
            DJConnectCardAppearance.shape
                .stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
        }
    }
}

private extension DJConnectStatusCard where Action == EmptyView {
    init(title: String, message: String, systemImage: String, tint: Color) {
        self.init(title: title, message: message, systemImage: systemImage, tint: tint) {
            EmptyView()
        }
    }
}

private struct MusicDiscoveryLockedState: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    lockIcon
                    title
                }
                VStack(alignment: .leading, spacing: 14) {
                    lockIcon
                    title
                }
            }

            Text(localizedKey(model.language, "ui.enable.music.dna.to.get.recommendations.tailored.to.your.listening"))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                model.showMusicDNAOptInPrompt()
            } label: {
                Label(localizedKey(model.language, "ui.enable.music.dna.1adf61"), systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.03, blue: 0.13).opacity(0.98),
                    Color(red: 0.12, green: 0.06, blue: 0.24).opacity(0.96),
                    Color(red: 0.11, green: 0.15, blue: 0.33).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: DJConnectCardAppearance.shape
        )
        .overlay {
            DJConnectCardAppearance.shape
                .stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
        }
        .shadow(color: djConnectButtonPurple.opacity(0.18), radius: 18, y: 10)
    }

    private var lockIcon: some View {
        Image(systemName: "lock.fill")
            .font(.title2.weight(.semibold))
            .foregroundStyle(djConnectIconGradient)
            .frame(width: 30, alignment: .leading)
    }

    private var title: some View {
        Text(localizedKey(model.language, "ui.music.dna.is.not.enabled"))
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
    }
}

private struct MusicDiscoveryEmptyState: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        if !model.isLoadingMusicDiscovery && !model.isRefreshingMusicDiscovery {
            Text(localizedKey(model.language, "ui.no.discovery.recommendations.available.currently"))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
        }
    }
}

@MainActor
private func musicDiscoveryArtworkURL(_ rawValue: String?, model: DJConnectAppModel) -> URL? {
    model.resolvedMusicDiscoveryImageURL(rawValue)
}

private struct MusicDNATrackListRow: View {
    let track: DJConnectMusicDNATrack

    private var title: String {
        track.title?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("-") ?? "-"
    }

    private var subtitle: String {
        [
            track.artist?.trimmingCharacters(in: .whitespacesAndNewlines),
            track.album?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    let artworkURL: URL?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                CachedArtworkImage(url: artworkURL, mode: .fill) { placeholder }

            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white.opacity(0.10))
            Image(systemName: "music.note")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white.opacity(0.56))
        }
    }
}

private struct MusicDNAMetricPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringGlowIsActive = false

    struct SecondaryMetric: Equatable {
        var title: String
        var percent: Int
        var icon: String
    }

    struct Metric: Equatable {
        var title: String
        var headline: String
        var percent: Int
        var icon: String
        var subtitle: String?
        var secondaryMetrics: [SecondaryMetric]
    }

    let metric: Metric
    let moodStepIndex: Int

    private var moodPalette: MusicDNAHelixMoodPalette {
        MusicDNAHelixMoodPalette(stepIndex: moodStepIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(title: metric.title, icon: metric.icon)

            if metric.secondaryMetrics.isEmpty {
                HStack(alignment: .center, spacing: 16) {
                    metricRing(
                        percent: metric.percent,
                        size: 118,
                        lineWidth: 13,
                        percentFont: .title3.weight(.bold)
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(metric.headline)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle = metric.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.66))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                equalMetricsRow
            }
            Spacer(minLength: 0)
        }
        .musicDNADashboardPanel()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                ringGlowIsActive = true
            }
        }
    }

    private var equalMetricsRow: some View {
        GeometryReader { proxy in
            let tileSpacing: CGFloat = 22
            let ringSize = min(104, max(70, (proxy.size.width - (tileSpacing * 2)) / 3))
            HStack(alignment: .top, spacing: tileSpacing) {
                metricTile(
                    title: metric.headline,
                    subtitle: metric.subtitle,
                    percent: metric.percent,
                    ringSize: ringSize
                )
                ForEach(metric.secondaryMetrics.prefix(2), id: \.title) { secondary in
                    metricTile(
                        title: secondary.title,
                        subtitle: nil,
                        percent: secondary.percent,
                        ringSize: ringSize
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(height: 164)
    }

    private func metricTile(
        title: String,
        subtitle: String?,
        percent: Int,
        ringSize: CGFloat
    ) -> some View {
        VStack(spacing: 8) {
            metricRing(
                percent: percent,
                size: ringSize,
                lineWidth: max(8, ringSize * 0.10),
                percentFont: .headline.weight(.bold)
            )
            VStack(spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricRing(
        percent: Int,
        size: CGFloat,
        lineWidth: CGFloat,
        percentFont: Font
    ) -> some View {
        let normalizedValue = min(1, max(0, Double(percent) / 100))
        let ringGradient = moodRingGradient(moodPalette.colors)
        let glowColor = moodPalette.colors[safe: 1] ?? djConnectAccent
        return ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: glowColor.opacity(reduceMotion ? 0.18 : (ringGlowIsActive ? 0.56 : 0.24)),
                    radius: reduceMotion ? 4 : (ringGlowIsActive ? 22 : 8),
                    x: 0,
                    y: 0
                )
            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth + 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: reduceMotion ? 4 : (ringGlowIsActive ? 14 : 5))
                .opacity(reduceMotion ? 0.14 : (ringGlowIsActive ? 0.34 : 0.12))
            Text("\(min(100, max(0, percent)))%")
                .font(percentFont)
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.68)
                .lineLimit(1)
                .padding(.horizontal, 6)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(percent)%")
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
        .djConnectGradientCard()
    }
}

private struct MusicDNAHelixView: View {
    let moodStepIndex: Int

    private var moodPalette: MusicDNAHelixMoodPalette {
        MusicDNAHelixMoodPalette(stepIndex: moodStepIndex)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let palette = moodPalette
                let colors = palette.colors
                let primary = colors[safe: 0] ?? Color(red: 0.18, green: 0.78, blue: 1.0)
                let secondary = colors[safe: 1] ?? djConnectAccent
                let tertiary = colors[safe: 2] ?? Color(red: 0.33, green: 0.96, blue: 0.72)
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [
                        primary.opacity(0.16),
                        secondary.opacity(0.22),
                        tertiary.opacity(0.24)
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
                    let color = interpolatedMusicDNAHelixColor(colors: colors, progress: progress)

                    var connector = Path()
                    connector.move(to: CGPoint(x: leftX, y: y))
                    connector.addLine(to: CGPoint(x: rightX, y: y))
                    context.stroke(connector, with: .color(color.opacity(0.10 + palette.glow * 0.16)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(x: leftX - 4, y: y - 4, width: 8, height: 8)), with: .color(color.opacity(0.92)))
                    context.fill(Path(ellipseIn: CGRect(x: rightX - 3, y: y - 3, width: 6, height: 6)), with: .color(color.opacity(0.42 + palette.glow * 0.30)))
                }
            }
        }
    }
}

private struct MusicDNAHelixMoodPalette {
    let colors: [Color]
    let glow: Double

    init(stepIndex: Int) {
        switch max(0, min(3, stepIndex)) {
        case 0:
            colors = ["#4DA3FF", "#7B61FF", "#D184FF"].compactMap(Color.init(hex:))
            glow = 0.36
        case 1:
            colors = ["#2EC4B6", "#7B61FF", "#D184FF"].compactMap(Color.init(hex:))
            glow = 0.46
        case 2:
            colors = ["#8AC926", "#FFD166", "#FF6A3D"].compactMap(Color.init(hex:))
            glow = 0.58
        default:
            colors = ["#FF2E63", "#A855F7", "#FFD166"].compactMap(Color.init(hex:))
            glow = 0.66
        }
    }
}

private func interpolatedMusicDNAHelixColor(colors: [Color], progress: CGFloat) -> Color {
    guard !colors.isEmpty else {
        return djConnectAccent
    }
    guard colors.count > 1 else {
        return colors[0]
    }
    let scaled = max(0, min(1, progress)) * CGFloat(colors.count - 1)
    let lowerIndex = min(colors.count - 1, max(0, Int(floor(scaled))))
    let upperIndex = min(colors.count - 1, lowerIndex + 1)
    guard lowerIndex != upperIndex else {
        return colors[lowerIndex]
    }
    let fraction = Double(scaled - CGFloat(lowerIndex))
    return blendMusicDNAHelixColors(colors[lowerIndex], colors[upperIndex], fraction: fraction)
}

private func moodRingGradient(_ colors: [Color]) -> AngularGradient {
    let primary = colors[safe: 0] ?? Color(red: 0.30, green: 0.63, blue: 1.0)
    let secondary = colors[safe: 1] ?? Color(red: 0.82, green: 0.28, blue: 1.0)
    let tertiary = colors[safe: 2] ?? Color(red: 0.23, green: 0.91, blue: 0.84)
    return AngularGradient(
        colors: [
            primary,
            secondary,
            tertiary,
            blendMusicDNAHelixColors(primary, secondary, fraction: 0.45),
            primary
        ],
        center: .center
    )
}

private func blendMusicDNAHelixColors(_ lhs: Color, _ rhs: Color, fraction: Double) -> Color {
    #if canImport(UIKit)
    let lhsPlatform = UIColor(lhs)
    let rhsPlatform = UIColor(rhs)
    var lhsRed: CGFloat = 0
    var lhsGreen: CGFloat = 0
    var lhsBlue: CGFloat = 0
    var lhsAlpha: CGFloat = 0
    var rhsRed: CGFloat = 0
    var rhsGreen: CGFloat = 0
    var rhsBlue: CGFloat = 0
    var rhsAlpha: CGFloat = 0
    lhsPlatform.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha)
    rhsPlatform.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha)
    #elseif canImport(AppKit)
    let lhsPlatform = NSColor(lhs).usingColorSpace(.deviceRGB) ?? .white
    let rhsPlatform = NSColor(rhs).usingColorSpace(.deviceRGB) ?? .white
    let lhsRed = lhsPlatform.redComponent
    let lhsGreen = lhsPlatform.greenComponent
    let lhsBlue = lhsPlatform.blueComponent
    let lhsAlpha = lhsPlatform.alphaComponent
    let rhsRed = rhsPlatform.redComponent
    let rhsGreen = rhsPlatform.greenComponent
    let rhsBlue = rhsPlatform.blueComponent
    let rhsAlpha = rhsPlatform.alphaComponent
    #endif
    let clamped = max(0, min(1, fraction))
    return Color(
        red: Double(lhsRed) + (Double(rhsRed) - Double(lhsRed)) * clamped,
        green: Double(lhsGreen) + (Double(rhsGreen) - Double(lhsGreen)) * clamped,
        blue: Double(lhsBlue) + (Double(rhsBlue) - Double(lhsBlue)) * clamped,
        opacity: Double(lhsAlpha) + (Double(rhsAlpha) - Double(lhsAlpha)) * clamped
    )
}

private struct TrackInsightHero: View {
    @ObservedObject var model: DJConnectAppModel
    let insight: TrackInsight
    let moodStepIndex: Int
    let isAnimationActive: Bool
    var isPinnedSubject = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var profile: TrackVibeProfile {
        let base = TrackVibeProfile.make(for: insight)
        return isPinnedSubject ? base : base.applyingTrackInsightMoodRenderOverride(stepIndex: moodStepIndex)
    }

    private var isVisualizerPlaying: Bool {
        !isPinnedSubject && model.playback?.isPlaying == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrackInsightHeroScene(
                insight: insight,
                profile: profile,
                playback: isPinnedSubject ? nil : model.playback,
                reduceMotion: reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled,
                isActive: isAnimationActive && isVisualizerPlaying,
                language: model.language,
                privateArtwork: isPinnedSubject
            )
            .frame(height: 430)
            .frame(maxWidth: .infinity)

        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .clipped()
        .djConnectHeroCard(colors: profile.colors)
    }
}

private struct TrackInsightHeroScene: View {
    let insight: TrackInsight
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool
    let language: String
    var privateArtwork = false
    @State private var playbackAnchor = TrackVibePlaybackAnchor()
    @State private var motionClock = TrackInsightMotionClock()
    @Environment(\.scenePhase) private var scenePhase

    private var clockRuns: Bool { isActive && !reduceMotion && scenePhase == .active }
    private var motionRate: Double { TrackInsightLightField.motionRate(for: profile) }

    private func updateMotionClock() {
        motionClock.update(running: clockRuns, rate: motionRate, at: ProcessInfo.processInfo.systemUptime)
    }

    private var playbackSignature: String {
        TrackVibePlaybackAnchor.signature(for: playback)
    }

    var body: some View {
        Group {
            if !clockRuns {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    scene(date: timeline.date)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    scene(date: timeline.date)
                }
            }
        }
        .onAppear {
            updateMotionClock()
            playbackAnchor.update(from: playback, at: Date())
        }
        .onChange(of: clockRuns) { updateMotionClock() }
        .onChange(of: motionRate) { updateMotionClock() }
        .onChange(of: playbackSignature) {
            playbackAnchor.update(from: playback, at: Date())
        }
        .onChange(of: playback?.isPlaying) {
            playbackAnchor.update(from: playback, at: Date())
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 24, x: 0, y: 18)
    }

    private func scene(date: Date) -> some View {
        let phase = TrackVibePlaybackPhase(playback: playback, anchor: playbackAnchor, date: date)
        let motion = motionClock.frame(at: ProcessInfo.processInfo.systemUptime)
        let motionDate = Date(timeIntervalSinceReferenceDate: motion.elapsed)
        return GeometryReader { geometry in
            let isCompact = geometry.size.width < 560 || geometry.size.width / max(geometry.size.height, 1) < 1.05
            let artworkSize = min(
                geometry.size.width * (isCompact ? 0.34 : 0.30),
                geometry.size.height * (isCompact ? 0.25 : 0.34),
                210
            )
            #if os(macOS)
            let artworkY = geometry.size.height * (isCompact ? 0.21 : 0.25)
            #else
            let artworkY = geometry.size.height * (isCompact ? 0.24 : 0.30)
            #endif
            let infoY = min(
                geometry.size.height * (isCompact ? 0.56 : 0.57),
                artworkY + artworkSize / 2 + (isCompact ? 64 : 74)
            )
            let spectrumHeight = max(isCompact ? 88 : 96, geometry.size.height * (isCompact ? 0.15 : 0.20))
            let spectrumY = geometry.size.height * (isCompact ? 0.88 : 0.86)
            ZStack {
                TrackInsightPremiumBackground(profile: profile, phase: phase, date: motionDate)
                TrackInsightLightField(profile: profile, phase: phase, date: motionDate, motionTravel: motion.travel)
                TrackInsightHeroArtwork(
                    insight: insight,
                    profile: profile,
                    playback: playback,
                    reduceMotion: reduceMotion,
                    isActive: isActive,
                    renderedArtworkImage: nil,
                    privateArtwork: privateArtwork
                )
                .frame(width: artworkSize, height: artworkSize)
                .position(x: geometry.size.width * 0.50, y: artworkY)

                TrackInsightHeroInfo(insight: insight, language: language)
                    .frame(maxWidth: min(720, geometry.size.width * 0.82))
                    .position(x: geometry.size.width / 2, y: infoY)

                TrackInsightPremiumSpectrum(profile: profile, phase: phase)
                    .frame(height: spectrumHeight)
                    .padding(.horizontal, max(isCompact ? 28 : 44, geometry.size.width * (isCompact ? 0.08 : 0.11)))
                    .position(x: geometry.size.width / 2, y: spectrumY)
            }
        }
    }
}

struct TrackInsightPremiumBackground: View {
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

struct TrackInsightLightField: View {
    let profile: TrackVibeProfile
    let phase: TrackVibePlaybackPhase
    let date: Date
    var motionTravel: Double? = nil

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let time = date.timeIntervalSinceReferenceDate
            let colors = profile.colors
            let density = min(max(profile.particleDensity, 0.12), 0.95)
            let travel = motionTravel ?? time * Self.motionRate(for: profile)
            let circleCount = Int(10 + density * 22)
            let starCount = Int(3 + profile.waveform * 8 + profile.glow * 4)
            let sparkCount = 24
            let sparkPopulation = 4 + profile.pulseSpeed * 5 + phase.energyLift * 7

            for index in 0..<circleCount {
                let seed = Double(index + 1)
                let lane = noise(seed, 2)
                let drift = travel * (0.018 + noise(seed, 3) * 0.038)
                let xPhase = noise(seed, 0) + drift + sin(time * 0.12 + seed) * 0.018
                let seam = TrackInsightParticleWrap(xPhase)
                let x = CGFloat(seam.position) * size.width
                let yBase = noise(seed, 1)
                let yDrift = sin(time * (0.18 + lane * 0.22) + seed * 0.71) * 0.035
                let y = size.height * CGFloat(0.14 + yBase * 0.58 + yDrift)
                let radius = CGFloat(2.0 + density * 5.5 + noise(seed, 4) * 7.0)
                let color = colors[safe: index % max(colors.count, 1)] ?? djConnectAccent
                let opacity = 0.08 + density * 0.08 + phase.energyLift * 0.10 + noise(seed, 5) * 0.08

                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color.opacity(opacity * seam.opacity))
                )
            }

            for index in 0..<starCount {
                let seed = Double(index + 101)
                let orbit = travel * (0.026 + noise(seed, 2) * 0.044)
                let seam = TrackInsightParticleWrap(noise(seed, 0) + orbit)
                let x = CGFloat(seam.position) * size.width
                let yPhase = 0.12 + noise(seed, 1) * 0.48
                let yDrift = cos(time * 0.16 + seed) * 0.026
                let y = size.height * CGFloat(yPhase + yDrift)
                let outer = CGFloat(4 + profile.glow * 7 + noise(seed, 3) * 7)
                let innerRatio = 0.34 + noise(seed, 4) * 0.14
                let inner = outer * CGFloat(innerRatio)
                let points = profile.motionStyle == .organic ? 5 : 4
                let rotation = CGFloat(travel * 0.24 + seed)
                let color = colors[safe: (index + 1) % max(colors.count, 1)] ?? djConnectAccent
                let star = starPath(center: CGPoint(x: x, y: y), outerRadius: outer, innerRadius: inner, points: points, rotation: rotation)
                context.fill(star, with: .color(color.opacity((0.10 + profile.glow * 0.16 + phase.energyLift * 0.10) * seam.opacity)))
            }

            for index in 0..<sparkCount {
                let visibility = TrackInsightParticleWrap.populationOpacity(index: index, population: sparkPopulation)
                guard visibility > 0 else { continue }
                let seed = Double(index + 211)
                let fall = travel * (0.05 + noise(seed, 2) * 0.08)
                let seamX = TrackInsightParticleWrap(noise(seed, 0) + fall * 0.52)
                let seamY = TrackInsightParticleWrap(noise(seed, 1) + fall)
                let x = CGFloat(seamX.position) * size.width
                let y = CGFloat(seamY.position) * size.height
                let opacity = visibility * seamX.opacity * seamY.opacity
                let sparkLength = 12 + profile.pulseSpeed * 10 + phase.energyLift * 18 + noise(seed, 3) * 18
                let length = CGFloat(sparkLength)
                let tilt = CGFloat(-0.7 + noise(seed, 4) * 1.4)
                let color = colors[safe: (index + 2) % max(colors.count, 1)] ?? djConnectAccent
                let dx = cos(tilt) * length * 0.5
                let dy = sin(tilt) * length * 0.5
                let start = CGPoint(x: x - dx, y: y - dy)
                let end = CGPoint(x: x + dx, y: y + dy)
                var spark = Path()
                spark.move(to: start)
                spark.addLine(to: end)
                context.stroke(
                    spark,
                    with: .linearGradient(
                        Gradient(colors: [.clear, color.opacity((0.20 + phase.energyLift * 0.22) * opacity), .clear]),
                        startPoint: start,
                        endPoint: end
                    ),
                    style: StrokeStyle(lineWidth: 1.1 + profile.glow * 1.4, lineCap: .round)
                )
            }
        }
        .blur(radius: 0.3)
    }

    static func motionRate(for profile: TrackVibeProfile) -> Double {
        let styleSpeed: Double
        switch profile.motionStyle {
        case .dreamy: styleSpeed = 0.58
        case .energetic: styleSpeed = 1.42
        case .organic: styleSpeed = 0.82
        case .dark: styleSpeed = 0.70
        case .balanced: styleSpeed = 1.0
        }
        return styleSpeed * (0.32 + profile.particleVelocity * 0.72 + profile.pulseSpeed * 0.18)
    }

    private func noise(_ seed: Double, _ offset: Double) -> Double {
        let value = sin(seed * 12.9898 + offset * 78.233) * 43_758.5453
        return value - floor(value)
    }

    private func starPath(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int, rotation: CGFloat) -> Path {
        var path = Path()
        let totalPoints = max(points, 3) * 2
        for index in 0..<totalPoints {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = rotation - .pi / 2 + CGFloat(index) * .pi / CGFloat(max(points, 3))
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct TrackInsightHeroArtwork: View {
    let insight: TrackInsight
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool
    let renderedArtworkImage: Image?

    var privateArtwork = false
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
                Group {
                    if let renderedArtworkImage {
                        renderedArtworkImage
                            .resizable()
                            .scaledToFill()
                    } else if privateArtwork {
                        ScopedTrackInsightArtwork(url: insight.artwork) {
                            TrackHeartbeatIcon(profile: profile, playback: nil, reduceMotion: true, isActive: false)
                                .padding(iconPadding).background(profile.gradient)
                        }
                    } else {
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
                    }
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

/// The private detail's pixels live only with this view. No shared/disk image cache.
private struct ScopedTrackInsightArtwork<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var loaded: Image?
    var body: some View {
        Group {
            if let loaded { loaded.resizable().scaledToFill() }
            else { placeholder() }
        }
        .task(id: url) {
            loaded = nil
            guard let url, url.scheme == "https", url.user == nil, url.password == nil else { return }
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.timeoutIntervalForResource = 15
            let session = URLSession(configuration: config)
            defer { session.invalidateAndCancel() }
            do {
                let (data, response) = try await session.data(from: url)
                guard !Task.isCancelled, let response = response as? HTTPURLResponse,
                      response.statusCode == 200, response.mimeType?.hasPrefix("image/") == true,
                      data.count <= 2_097_152 else { return }
                #if os(iOS)
                guard let image = UIImage(data: data) else { return }
                loaded = Image(uiImage: image)
                #elseif os(macOS)
                guard let image = NSImage(data: data) else { return }
                loaded = Image(nsImage: image)
                #endif
            } catch { }
        }
        .onDisappear { loaded = nil }
    }
}

struct TrackInsightPremiumSpectrum: View {
    let profile: TrackVibeProfile
    let phase: TrackVibePlaybackPhase

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 420
            let count = isCompact ? 40 : 52
            let spacing: CGFloat = isCompact ? 2.5 : 4
            let spectrumWidth = geometry.size.width * 0.86
            let barWidth = max(1.8, (spectrumWidth - CGFloat(count - 1) * spacing) / CGFloat(count))
            let clampedProgress = min(max(phase.progress, 0), 1)
            let progressX = spectrumWidth * clampedProgress
            ZStack(alignment: .bottomLeading) {
                progressRail(width: spectrumWidth, progressX: progressX, height: geometry.size.height)

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(0..<count, id: \.self) { index in
                        let normalized = spectrumValue(index: index, count: count)
                        let position = Double(index) / Double(max(count - 1, 1))
                        let hasPlayed = position <= clampedProgress
                        RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                            .fill(barGradient(index: index, count: count))
                            .frame(width: barWidth, height: max(8, geometry.size.height * normalized))
                            .opacity(hasPlayed ? 1.0 : 0.52)
                            .shadow(
                                color: (profile.colors[safe: index % max(profile.colors.count, 1)] ?? djConnectAccent)
                                    .opacity(hasPlayed ? 0.34 : 0.12),
                                radius: hasPlayed ? 8 : 3
                            )
                    }
                }
                .frame(width: spectrumWidth)
                .frame(maxHeight: .infinity, alignment: .bottom)

                playhead(width: spectrumWidth, progressX: progressX, height: geometry.size.height)
            }
            .frame(width: spectrumWidth)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
    }

    private func progressRail(width: CGFloat, progressX: CGFloat, height: CGFloat) -> some View {
        let railY = height - 3
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.14))
                .frame(width: width, height: 3)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            (profile.colors.first ?? djConnectAccent).opacity(0.95),
                            .white.opacity(0.92),
                            (profile.colors.last ?? djConnectAccent).opacity(0.95)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(8, progressX), height: 3)
                .shadow(color: .white.opacity(0.34), radius: 8)
        }
        .position(x: width / 2, y: railY)
    }

    private func playhead(width: CGFloat, progressX: CGFloat, height: CGFloat) -> some View {
        let x = max(7, min(width - 7, progressX))
        return ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.62), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: height * 0.86)
                .position(x: x, y: height * 0.46)
            Circle()
                .fill(.white)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke((profile.colors.last ?? djConnectAccent).opacity(0.85), lineWidth: 2)
                }
                .shadow(color: .white.opacity(0.72), radius: 8)
                .shadow(color: (profile.colors.last ?? djConnectAccent).opacity(0.70), radius: 14)
                .position(x: x, y: height - 3)
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
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

    private var titleFontSize: CGFloat {
        #if os(macOS)
        40
        #else
        usesIPhoneTypography ? 40 : 48
        #endif
    }

    private var artistFontSize: CGFloat {
        #if os(macOS)
        20
        #else
        usesIPhoneTypography ? 21 : 24
        #endif
    }

    private var albumFont: Font {
        #if os(macOS)
        .callout.weight(.semibold)
        #else
        .headline.weight(.semibold)
        #endif
    }

    private var usesIPhoneTypography: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(insight.title)
                .font(.system(size: titleFontSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            Text(insight.artist)
                .font(.system(size: artistFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.66)
            if let album = insight.album, !album.isEmpty {
                Text(album)
                    .font(albumFont)
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
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

private struct TrackVibeVisualizerView: View {
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let reduceMotion: Bool
    let isActive: Bool
    @State private var playbackAnchor = TrackVibePlaybackAnchor()

    private var isPlaying: Bool {
        playback?.isPlaying == true
    }

    private var shouldAnimate: Bool {
        isActive && isPlaying
    }

    private var playbackSignature: String {
        TrackVibePlaybackAnchor.signature(for: playback)
    }

    var body: some View {
        visualizer
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .bottom) {
                TrackVibePhaseSpectrum(profile: profile, progress: playbackPhase(at: Date()).progress)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            .onAppear {
                playbackAnchor.update(from: playback, at: Date())
            }
            .onChange(of: playbackSignature) {
                playbackAnchor.update(from: playback, at: Date())
            }
            .onChange(of: playback?.progressMS) {
                playbackAnchor.update(from: playback, at: Date())
            }
            .onChange(of: playback?.isPlaying) {
                playbackAnchor.update(from: playback, at: Date())
            }
            .onChange(of: playback?.durationMS) {
                playbackAnchor.update(from: playback, at: Date())
            }
    }

    @ViewBuilder
    private var visualizer: some View {
        #if canImport(MetalKit) && (os(iOS) || os(macOS))
        TrackVibeMetalVisualizerView(
            profile: profile,
            playback: playback,
            playbackAnchor: playbackAnchor,
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
        TrackVibePlaybackPhase(playback: playback, anchor: playbackAnchor, date: date)
    }
}

#if canImport(MetalKit) && (os(iOS) || os(macOS))
#if os(iOS)
private struct TrackVibeMetalVisualizerView: UIViewRepresentable {
    let profile: TrackVibeProfile
    let playback: DJConnectPlayback?
    let playbackAnchor: TrackVibePlaybackAnchor
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
    let playbackAnchor: TrackVibePlaybackAnchor
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
        context.coordinator.playbackAnchor = playbackAnchor
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
    var playbackAnchor = TrackVibePlaybackAnchor()
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
        let phase = TrackVibePlaybackPhase(playback: playback, anchor: playbackAnchor, date: Date())
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

struct TrackVibePlaybackPhase {
    let progress: Double
    let positionSeconds: TimeInterval
    let energyLift: Double

    init(playback: DJConnectPlayback?, anchor: TrackVibePlaybackAnchor = TrackVibePlaybackAnchor(), date: Date) {
        let durationMS = max(playback?.durationMS ?? 0, 0)
        let progressMS = max(playback?.progressMS ?? 0, 0)
        let durationSeconds = durationMS > 0 ? Double(durationMS) / 1_000 : 240
        let positionSeconds = anchor.positionSeconds(for: playback, fallbackProgressMS: progressMS, durationSeconds: durationSeconds, at: date)
        let progress = durationSeconds > 0 ? min(max(positionSeconds / durationSeconds, 0), 1) : 0
        let phrase = sin(progress * .pi * 10)
        let section = sin(progress * .pi * 2 - .pi / 2) * 0.5 + 0.5

        self.progress = progress
        self.positionSeconds = positionSeconds
        self.energyLift = max(0, min(1, 0.28 + phrase * 0.18 + section * 0.54))
    }

    init(shareProgress: Double, duration: TimeInterval) {
        let durationSeconds = max(duration, 1)
        let loopedPosition = shareProgress.truncatingRemainder(dividingBy: durationSeconds)
        let positionSeconds = loopedPosition < 0 ? loopedPosition + durationSeconds : loopedPosition
        let progress = min(max(positionSeconds / durationSeconds, 0), 1)
        let phrase = sin(progress * .pi * 10)
        let section = sin(progress * .pi * 2 - .pi / 2) * 0.5 + 0.5

        self.progress = progress
        self.positionSeconds = positionSeconds
        self.energyLift = max(0, min(1, 0.28 + phrase * 0.18 + section * 0.54))
    }
}

struct TrackVibePlaybackAnchor: Equatable {
    var signature: String = ""
    var progressMS: Int = 0
    var durationMS: Int = 0
    var snapshotDate: Date = .distantPast
    var isPlaying: Bool = false

    static func signature(for playback: DJConnectPlayback?) -> String {
        [
            playback?.trackName,
            playback?.artistName,
            playback?.contextURI,
            playback?.durationMS.map(String.init)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
        .joined(separator: "|")
    }

    mutating func update(from playback: DJConnectPlayback?, at date: Date) {
        let nextSignature = Self.signature(for: playback)
        let nextProgressMS = max(playback?.progressMS ?? 0, 0)
        let nextDurationMS = max(playback?.durationMS ?? 0, 0)
        let nextIsPlaying = playback?.isPlaying == true
        let estimatedMS = Int((positionSeconds(
            for: playback,
            fallbackProgressMS: progressMS,
            durationSeconds: nextDurationMS > 0 ? Double(nextDurationMS) / 1_000 : 240,
            at: date
        ) * 1_000).rounded())

        let didChangeTrack = nextSignature != signature
        let didSeekBackward = nextProgressMS + 2_000 < estimatedMS
        let anchoredProgressMS = didChangeTrack || didSeekBackward ? nextProgressMS : max(nextProgressMS, estimatedMS)

        signature = nextSignature
        progressMS = anchoredProgressMS
        durationMS = nextDurationMS
        snapshotDate = date
        isPlaying = nextIsPlaying
    }

    func positionSeconds(
        for playback: DJConnectPlayback?,
        fallbackProgressMS: Int,
        durationSeconds: TimeInterval,
        at date: Date
    ) -> TimeInterval {
        let playbackSignature = Self.signature(for: playback)
        let baseMS = playbackSignature == signature && !signature.isEmpty ? progressMS : max(playback?.progressMS ?? fallbackProgressMS, 0)
        let elapsed = playback?.isPlaying == true && isPlaying ? max(0, date.timeIntervalSince(snapshotDate)) : 0
        return min(Double(baseMS) / 1_000 + elapsed, durationSeconds)
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
    let moodStepIndex: Int
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if usesHorizontalRows {
                horizontalMetricRow {
                    TrackInsightMetricRing(title: localizedKey(language, "ui.energy"), value: insight.energy, icon: "bolt.fill", moodStepIndex: moodStepIndex)
                        .frame(width: 148)
                    TrackInsightMetricRing(title: localizedKey(language, "trackInsight.share.danceability"), value: insight.danceability, icon: "figure.dance", moodStepIndex: moodStepIndex)
                        .frame(width: 148)
                    TrackInsightMetricRing(title: localizedKey(language, "ui.intensity"), value: insight.intensity, icon: "flame.fill", moodStepIndex: moodStepIndex)
                        .frame(width: 148)
                }

                horizontalMetricRow {
                    metricPills
                }
            } else {
                LazyVGrid(columns: metricColumns, spacing: 10) {
                    TrackInsightMetricRing(title: localizedKey(language, "ui.energy"), value: insight.energy, icon: "bolt.fill", moodStepIndex: moodStepIndex)
                    TrackInsightMetricRing(title: localizedKey(language, "trackInsight.share.danceability"), value: insight.danceability, icon: "figure.dance", moodStepIndex: moodStepIndex)
                    TrackInsightMetricRing(title: localizedKey(language, "ui.intensity"), value: insight.intensity, icon: "flame.fill", moodStepIndex: moodStepIndex)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 10, alignment: .top)], spacing: 10) {
                    metricPills
                }
            }
        }
    }

    @ViewBuilder
    private var metricPills: some View {
        if let genre = insight.genre?.trimmingCharacters(in: .whitespacesAndNewlines), !genre.isEmpty {
            TrackInsightMetricPill(title: localizedKey(language, "ui.genre"), value: genre, icon: "music.quarternote.3")
                .frame(width: usesHorizontalRows ? 204 : nil, alignment: .top)
        }
        TrackInsightMetricPill(title: localizedKey(language, "ui.mood"), value: insight.mood, icon: musicDNAMoodIcon(insight.mood))
            .frame(width: usesHorizontalRows ? 204 : nil, alignment: .top)
        TrackInsightMetricPill(title: localizedKey(language, "ui.vibe"), value: insight.vibe, icon: "waveform.path")
            .frame(width: usesHorizontalRows ? 204 : nil, alignment: .top)
        TrackInsightMetricPill(title: localizedKey(language, "ui.texture"), value: insight.texture, icon: "square.stack.3d.up.fill")
            .frame(width: usesHorizontalRows ? 204 : nil, alignment: .top)
    }

    private var usesHorizontalRows: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact && UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private func horizontalMetricRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 10) {
                content()
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var metricColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 132), spacing: 10, alignment: .top), count: 3)
    }
}

private struct TrackInsightMetricRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringGlowIsActive = false

    let title: String
    let value: Double?
    let icon: String
    let moodStepIndex: Int

    private var moodPalette: DJConnectSessionMoodPalette {
        DJConnectSessionMoodPalette(stepIndex: moodStepIndex)
    }

    private var normalizedValue: Double {
        min(1, max(0, value ?? 0))
    }

    private var percentText: String {
        guard let value else { return "-" }
        return "\(Int((min(1, max(0, value)) * 100).rounded()))%"
    }

    var body: some View {
        let ringGradient = moodRingGradient(moodPalette.colors)
        let glowColor = moodPalette.colors[safe: 1] ?? djConnectAccent

        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(glowColor)
                .frame(width: 22, height: 18)
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: glowColor.opacity(reduceMotion ? 0.18 : (ringGlowIsActive ? 0.52 : 0.22)), radius: reduceMotion ? 4 : (ringGlowIsActive ? 20 : 8), x: 0, y: 0)
                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: 17, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: reduceMotion ? 4 : (ringGlowIsActive ? 13 : 5))
                    .opacity(reduceMotion ? 0.14 : (ringGlowIsActive ? 0.32 : 0.12))
                Text(percentText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
            }
            .frame(width: 108, height: 108)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(.white.opacity(0.09), in: DJConnectCardAppearance.shape)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                ringGlowIsActive = true
            }
        }
    }
}

private struct TrackInsightMetricPill: View {
    let title: String
    let value: String?
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(djConnectAccent)
                    .frame(width: 16)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            Text(value?.isEmpty == false ? value! : "-")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(.white.opacity(0.10), in: DJConnectCardAppearance.shape)
    }
}

private struct TrackInsightAnalysisCard: View {
    let insight: TrackInsight
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicDNACompactPanelHeader(
                title: localizedKey(language, insight.verifiedCredit == nil ? (insight.hasUnavailableAnalysis ? "ui.trackInsight.analysis.title" : "watch.track.energy") : "ui.trackInsight.verified_credits"),
                icon: insight.verifiedCredit == nil ? "bolt.fill" : "checkmark.seal")
            Text(insight.verifiedCredit?.context ?? insight.displaySummary(language: language))
                .font(.headline.weight(.semibold))
                .lineSpacing(6)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let credit = insight.verifiedCredit {
                Link("\(credit.source.provider) · \(credit.source.license)", destination: credit.source.url)
                    .font(.caption).tint(djConnectAccent)
                if insight.summary != credit.context {
                    MusicDNACompactPanelHeader(title: localizedKey(language, "ui.trackInsight.interpretation"), icon: "text.bubble")
                    Text(insight.displaySummary(language: language)).fixedSize(horizontal: false, vertical: true)
                }
            }

            let groups = insight.hasUnavailableAnalysis ? [] : insight.structuredAnalysisGroups(language: language)
            if !groups.isEmpty {
                Divider().overlay(.white.opacity(0.16))
                ForEach(groups.prefix(8)) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        MusicDNACompactPanelHeader(title: section.title, icon: section.iconName)
                        ForEach(section.values.prefix(5), id: \.self) { value in
                            Text(value)
                                .font(.subheadline.weight(.medium))
                                .lineSpacing(4)
                                .foregroundStyle(.white.opacity(0.82))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .djSessionFrostedSurface()
    }
}

private struct TrackInsightStructuredGroup: Identifiable {
    let id: String
    let title: String
    let values: [String]

    var iconName: String {
        switch id {
        case "production":
            "slider.horizontal.3"
        case "instrumentation":
            "music.note.list"
        case "arrangement":
            "square.stack.3d.up"
        case "listening":
            "ear"
        case "similar":
            "sparkles"
        default:
            "waveform"
        }
    }

    var iconColor: Color {
        switch id {
        case "production":
            Color(red: 0.30, green: 0.63, blue: 1.0)
        case "instrumentation":
            Color(red: 0.23, green: 0.91, blue: 0.84)
        case "arrangement":
            Color(red: 0.82, green: 0.28, blue: 1.0)
        case "listening":
            Color(red: 1.0, green: 0.82, blue: 0.34)
        case "similar":
            Color(red: 0.96, green: 0.38, blue: 0.72)
        default:
            djConnectAccent
        }
    }
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

/// A quiet white highlight travels around the native glyph's contours.
/// Only the light moves; the symbol itself keeps its position and scale.
private struct DJConnectHeroGlyph: View {
    let systemImage: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = ProcessInfo.processInfo.systemUptime

    var body: some View {
        Group {
            if reduceMotion || scenePhase != .active {
                artwork(angle: nil)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                    let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
                    let turn = elapsed.truncatingRemainder(dividingBy: 12) / 12
                    artwork(angle: turn * 360)
                }
            }
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func artwork(angle: Double?) -> some View {
        symbol.foregroundStyle(djConnectIconGradient)
            .overlay {
                if let angle {
                    let light = AngularGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.70),
                        .init(color: .white.opacity(0.04), location: 0.78),
                        .init(color: .white.opacity(0.25), location: 0.90),
                        .init(color: .white.opacity(0.82), location: 0.96),
                        .init(color: .white.opacity(0.18), location: 0.985),
                        .init(color: .clear, location: 1)
                    ], center: .center, startAngle: .degrees(angle), endAngle: .degrees(angle + 360))
                    ZStack {
                        light.mask(symbol.foregroundStyle(.white))
                            .blur(radius: 2).opacity(0.45)
                        light.mask(symbol.foregroundStyle(.white))
                    }
                }
            }
    }

    private var symbol: some View {
        Image(systemName: systemImage)
            .font(.system(size: 50, weight: .semibold))
    }
}

private struct TrackInsightEmptyState: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(spacing: 16) {
            DJConnectHeroGlyph(systemImage: "waveform.path.ecg")
            Text("Track Insight")
                .font(.title2.weight(.bold))
            Text(localizedKey(model.language, "ui.see.what.makes.the.current.track.feel.the.way.it"))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button {
                guard model.isPlaying else { return }
                model.analyzeCurrentTrack(open: false)
            } label: {
                HStack(spacing: 10) {
                    if model.isLoadingTrackInsight {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(localizedKey(model.language, "ui.analyze.track"))
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
            .disabled(model.isLoadingTrackInsight || !model.isPlaying)
            .accessibilityIdentifier("track-insight-analyze")
            if !model.isPlaying {
                Text(localizedKey(model.language, "ui.track.insight.play.music.first"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("track-insight-playback-required")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .djConnectHeroCard()
    }
}

extension TrackVibeProfile {
    var colors: [Color] {
        palette.map { Color(hex: $0) ?? djConnectAccent }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func applyingTrackInsightMoodRenderOverride(stepIndex: Int) -> TrackVibeProfile {
        var copy = self
        let clampedStep = max(0, min(3, stepIndex))
        switch clampedStep {
        case 0:
            copy.palette = ["#4DA3FF", "#7B61FF", "#D184FF"]
            copy.glow = max(0.30, glow * 0.78)
            copy.pulseSpeed = max(0.35, pulseSpeed * 0.72)
            copy.waveform = max(0.20, waveform * 0.74)
            copy.particleDensity = max(0.12, particleDensity * 0.70)
            copy.particleVelocity = max(0.18, particleVelocity * 0.70)
            copy.animationSpeed = max(0.45, animationSpeed * 0.70)
            copy.motionStyle = .dreamy
        case 1:
            copy.palette = ["#06C7AD", "#169BC8", "#10B981"]
            copy.glow = max(0.38, glow * 0.95)
            copy.pulseSpeed = max(0.55, pulseSpeed * 0.92)
            copy.waveform = max(0.34, waveform * 0.96)
            copy.particleDensity = max(0.22, particleDensity * 0.92)
            copy.particleVelocity = max(0.26, particleVelocity * 0.88)
            copy.animationSpeed = max(0.58, animationSpeed * 0.90)
            copy.motionStyle = .balanced
        case 2:
            copy.palette = ["#DDFF00", "#00B8FF", "#39FF78"]
            copy.glow = min(0.95, max(0.48, glow * 1.14))
            copy.pulseSpeed = min(2.2, max(0.75, pulseSpeed * 1.16))
            copy.waveform = min(1.0, max(0.46, waveform * 1.12))
            copy.particleDensity = min(0.92, max(0.30, particleDensity * 1.12))
            copy.particleVelocity = min(1.18, max(0.34, particleVelocity * 1.08))
            copy.animationSpeed = min(1.9, max(0.75, animationSpeed * 1.12))
            copy.motionStyle = .energetic
        default:
            copy.palette = ["#FF287F", "#AA38F5", "#F43DCE"]
            copy.glow = min(0.95, max(0.56, glow * 1.26))
            copy.pulseSpeed = min(2.2, max(0.95, pulseSpeed * 1.34))
            copy.waveform = min(1.0, max(0.56, waveform * 1.24))
            copy.particleDensity = min(0.92, max(0.44, particleDensity * 1.28))
            copy.particleVelocity = min(1.18, max(0.42, particleVelocity * 1.18))
            copy.animationSpeed = min(1.9, max(0.90, animationSpeed * 1.24))
            copy.motionStyle = .energetic
        }
        copy.spectrumProfile = copy.spectrumProfile.enumerated().map { index, value in
            let position = Double(index) / Double(max(copy.spectrumProfile.count - 1, 1))
            let lift: Double
            switch clampedStep {
            case 0:
                lift = 0.78 - position * 0.08
            case 1:
                lift = 0.88 + (1.0 - abs(position - 0.5) * 2.0) * 0.18
            case 2:
                lift = 0.96 + position * 0.24
            default:
                lift = 1.02 + sin(position * .pi * 3.0) * 0.20
            }
            return min(1.0, max(0.12, value * lift))
        }
        return copy
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

private struct DJSessionView: View {
    @ObservedObject var model: DJConnectAppModel
    var openQueueAction: () -> Void
    @State private var statusToast: DJConnectVisualNotice?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: DJConnectAppModel, openQueueAction: @escaping () -> Void) {
        self.model = model; self.openQueueAction = openQueueAction
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                if let session = model.activeDJSession {
                    SessionTimelineScreen(model: model, sessionID: session.id, activeSession: session,
                                          openQueueAction: openQueueAction,
                                          refreshAction: { Task { await refreshNowPlayingWithToast() } })
                } else {
                ScrollView {
                    IdleDJSessionView(model: model)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(.clear)
                .refreshable {
                    if !model.isDemoMode, model.pairingStatus == .paired {
                        await refreshNowPlayingWithToast()
                    }
                }
                }
            }
            .djStatusToastOverlay(statusToast, screenImage: DJConnectFeatureSymbols.djSession)
            .navigationTitle(sessionNavigationTitle)
            .djSessionNavigationTitleStyle(compactPhone: true)
            .toolbar {
                #if os(iOS)
                if model.shouldShowAppleWatchPairingReminder {
                    ToolbarItem(placement: .topBarLeading) {
                        AppleWatchPairingReminderButton(model: model)
                    }
                }
                #endif
                #if os(macOS)
                if model.activeDJSession == nil {
                    sessionRefreshToolbar
                }
                sessionConnectionToolbar
                #else
                sessionConnectionToolbar
                if model.activeDJSession == nil {
                    sessionRefreshToolbar
                }
                #endif

            }
            .djUserNoticeToast(model: model, screenImage: DJConnectFeatureSymbols.djSession)
        }
        .accessibilityIdentifier("screen-dj-session")
    }

    @ToolbarContentBuilder private var sessionRefreshToolbar: some ToolbarContent {
        ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
            RefreshButton(model: model) { Task { await refreshNowPlayingWithToast() } }
        }
    }

    @ToolbarContentBuilder private var sessionConnectionToolbar: some ToolbarContent {
        if model.activeDJSession == nil {
            #if os(macOS)
            ToolbarItem(placement: .confirmationAction) { SessionConnectionToolbarButton(model: model) }
            #else
            ToolbarItem(placement: djConnectRefreshToolbarPlacement) { SessionConnectionToolbarButton(model: model) }
            #endif
        }
    }

    private var sessionNavigationTitle: String {
        #if os(iOS)
        return ""
        #else
        return localizedKey(model.language, "ui.session.title")
        #endif
    }

    private func refreshNowPlayingWithToast() async {
        statusToast = DJConnectVisualNotice(text: localizedKey(model.language, "ui.session.refresh.loading"), systemImage: DJConnectFeatureSymbols.djSession)
        _ = await model.refreshNowPlaying()
        let didRefresh = await model.refreshActiveDJSession()
        showStatusToast(
            didRefresh ? localizedKey(model.language, "ui.session.refresh.updated") : localizedKey(model.language, "ui.session.unavailable"),
            systemImage: DJConnectFeatureSymbols.djSession
        )
    }

    private func showStatusToast(_ text: String, systemImage: String) {
        let notice = DJConnectVisualNotice(text: text, systemImage: systemImage)
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = notice
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast?.id == notice.id else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }
}

private struct IdleDJSessionView: View {
    @ObservedObject var model: DJConnectAppModel
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 42
    private let moods: [(id: String, glyph: String)] = [
        ("chill", "moon.stars"), ("groove", "waveform"),
        ("energy", "bolt"), ("party", "sparkles")
    ]

    private var usesIconOnlyMoodButtons: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 36) {
                    welcomeCopy(compactArtwork: false).frame(width: 380, alignment: .leading)
                    Spacer(minLength: 0)
                    DJSessionWelcomeArtwork().frame(width: 280, height: 280)
                }
                welcomeCopy(compactArtwork: true)
            }
            VStack(alignment: .leading, spacing: 16) {
                Text(localizedKey(model.language, "ui.session.welcome.mood"))
                    .font(.headline)
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(moods, id: \.id) { mood in
                            moodButton(mood.id, glyph: mood.glyph)
                        }
                    }
                    .padding(DJConnectCardAppearance.segmentedContentInset)
                    .djConnectGradientCard()
                    if usesIconOnlyMoodButtons {
                        Text(localizedKey(model.language, "ui.session.mood." + model.selectedSessionMood))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("session-welcome-selected-mood")
                    }
                }
                Button { Task { await model.startDJSession() } } label: {
                    HStack(spacing: 12) {
                        if model.isLoadingDJSession { ProgressView().tint(.white) }
                        else { Image(systemName: "play.fill") }
                        Text(localizedKey(model.language, "ui.session.start"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                .disabled(model.isLoadingDJSession || (!model.isDemoMode && model.pairingStatus != .paired) || !model.canUsePlaybackFeatures)
                .accessibilityIdentifier("session-welcome-start")
                if model.isDemoMode {
                    Text(localizedKey(model.language, "demo.session.notice")).font(.footnote).foregroundStyle(.secondary)
                } else if model.pairingStatus != .paired || !model.canUsePlaybackFeatures {
                    Text(localizedKey(model.language, "ui.session.requires_connection")).font(.footnote).foregroundStyle(.secondary)
                }
                if let error = model.djSessionErrorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .padding(28)
        .djConnectHeroCard()
        .frame(maxWidth: 960)
        .frame(maxWidth: .infinity, alignment: .top)
        #if !os(macOS)
        .padding(.vertical, 12)
        #endif
        .accessibilityIdentifier("screen-idle-dj-session")
    }

    private func welcomeCopy(compactArtwork: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Label(localizedKey(model.language, "ui.session.welcome.eyebrow"), systemImage: DJConnectFeatureSymbols.djSession)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 0.89, green: 0.65, blue: 1))
                if compactArtwork {
                    Spacer(minLength: 0)
                    DJSessionWelcomeArtwork().frame(width: 84, height: 84)
                }
            }
            Text(localizedKey(model.language, "ui.session.welcome.title"))
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(localizedKey(model.language, "ui.session.welcome.subtitle"))
                .font(.body).foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            Label(localizedKey(model.language, "ui.session.welcome.promise"), systemImage: "bubble.left.and.bubble.right")
                .font(.subheadline).foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func moodButton(_ mood: String, glyph: String) -> some View {
        let selected = model.selectedSessionMood == mood
        return Button { model.selectedSessionMood = mood } label: {
            Group {
                if usesIconOnlyMoodButtons {
                    Image(systemName: glyph)
                        .font(.title3.weight(.semibold))
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Image(systemName: glyph)
                            Text(localizedKey(model.language, "ui.session.mood." + mood))
                        }
                        VStack(spacing: 4) {
                            Image(systemName: glyph)
                            Text(localizedKey(model.language, "ui.session.mood." + mood))
                        }
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(selected ? 1 : 0.78))
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: selected ? .selected : .secondary, shape: .segmented, expands: true))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(localizedKey(model.language, "ui.session.mood." + mood))
        .accessibilityIdentifier("session-welcome-mood-" + mood)
    }
}

/// Decorative native artwork; it carries no playback or Session state.
struct DJSessionWelcomeArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(djConnectIconGradient).blur(radius: size * 0.13).opacity(0.45)
                    .frame(width: size * 0.85, height: size * 0.85)
                animatedRecord(size: size)
                Circle().fill(djConnectIconGradient).frame(width: size * 0.32, height: size * 0.32)
                Circle().fill(Color(red: 0.04, green: 0.03, blue: 0.10)).frame(width: size * 0.07, height: size * 0.07)
                artworkGlyph("music.note", size: size).offset(x: size * 0.35, y: -size * 0.25)
                artworkGlyph("bubble.left.and.bubble.right", size: size).offset(x: -size * 0.35, y: size * 0.13)
                HStack(spacing: size * 0.012) {
                    ForEach(Array([10.0, 18, 28, 15, 34, 23, 12, 27, 17].enumerated()), id: \.offset) { bar in
                        Capsule().fill(djConnectIconGradient)
                            .frame(width: size * 0.015, height: size * 0.10 * bar.element / 34)
                    }
                }
                // Match the two square badges exactly in height.
                .frame(width: size * 0.32, height: size * 0.18)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.2)) }
                .offset(x: size * 0.16, y: size * 0.32)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder private func animatedRecord(size: CGFloat) -> some View {
        if reduceMotion || scenePhase != .active {
            record(size: size, rotation: .zero)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
                let turn = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 32) / 32
                record(size: size, rotation: .degrees(turn * 360))
            }
        }
    }

    private func record(size: CGFloat, rotation: Angle) -> some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: [.black.opacity(0.85), Color(red: 0.19, green: 0.14, blue: 0.33)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.79, height: size * 0.79)
                .overlay { Circle().stroke(.white.opacity(0.2)) }
            ForEach(0..<5) { ring in
                Circle().stroke(.white.opacity(0.06), lineWidth: 1)
                    .frame(width: size * (0.42 + Double(ring) * 0.065),
                           height: size * (0.42 + Double(ring) * 0.065))
            }
            // A faint reflection makes the slow rotation visible on circular grooves.
            Circle().stroke(AngularGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.075), location: 0.14),
                .init(color: .clear, location: 0.26),
                .init(color: .clear, location: 1)
            ], center: .center), lineWidth: size * 0.13)
                .frame(width: size * 0.60, height: size * 0.60)
        }
        .rotationEffect(rotation)
    }

    private func artworkGlyph(_ glyph: String, size: CGFloat) -> some View {
        Image(systemName: glyph).font(.system(size: size * 0.07, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size * 0.18, height: size * 0.18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: size * 0.06))
            .overlay { RoundedRectangle(cornerRadius: size * 0.06).stroke(.white.opacity(0.22)) }
    }
}

/// Uses the same native sheet shell and standard secondary action as Feedback.
struct VibeCastSessionStartDialog: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            #if os(iOS)
            ScrollView {
                dialogContent
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.center, for: .alignment)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620, idealHeight: 620)
            .accessibilityIdentifier("vibecast-session-start-scroll")
            #else
            dialogContent
            #endif
        }
        .tint(djConnectAccent)
        .accentColor(djConnectAccent)
        .interactiveDismissDisabled(true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("vibecast-session-start-dialog")
    }

    private var dialogContent: some View {
        VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 18) {
                    DJConnectHeroGlyph(systemImage: "tv.badge.wifi")
                    Text(localizedKey(model.language, "ui.vibecast.handoff.title"))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .djConnectHeroCard()
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("vibecast-session-start-hero")
                VibeCastHandoffForm(model: model)
                DJConnectNotNowLinkButton(language: model.language, key: "ui.not.now.b1e535") {
                    resignPlatformFirstResponder()
                    dismiss()
                }
                .accessibilityIdentifier("session-handoff-not-now")
                .keyboardShortcut(.cancelAction)
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("vibecast-session-start-card")
    }
}

struct VibeCastHandoffForm: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var vibeCastHandoffCode = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localizedKey(model.language, "ui.vibecast.handoff.instructions"))
                .font(.callout).foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            VibeCastCodeEntry(code: $vibeCastHandoffCode,
                              accessibilityLabel: localizedKey(model.language, "ui.vibecast.handoff.code"))
                .frame(height: 64)
            Button(localizedKey(model.language, "ui.vibecast.handoff.approve")) {
                resignPlatformFirstResponder()
                Task { await model.approveVibeCastHandoff(code: vibeCastHandoffCode) }
            }
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
            .disabled(vibeCastHandoffCode.count != 6 || model.isLoadingVibeCastHandoff || model.isDemoMode || model.pairingStatus != .paired)
            .accessibilityIdentifier("vibecast-handoff-approve")
            if model.vibeCastHandoffApproved {
                Text(localizedKey(model.language, "ui.vibecast.handoff.approved"))
                    .font(.footnote).foregroundStyle(.green)
            }
            if model.vibeCastHandoffFailed {
                Text(localizedKey(model.language, model.vibeCastHandoffErrorKey ?? "ui.vibecast.handoff.failed"))
                    .font(.footnote).foregroundStyle(.red)
            }
            if let error = model.djSessionErrorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 0)
        #if os(macOS)
        .padding(.top, 16)
        .padding(.bottom, 16)
        #else
        .padding(.vertical, 16)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("vibecast-handoff-form")
    }
}

/// Six actual inputs, with one aggregate code for the existing backend command.
#if os(iOS)
private struct VibeCastCodeEntry: UIViewRepresentable {
    @Binding var code: String
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator { Coordinator(code: $code) }

    func makeUIView(context: Context) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 6
        for index in 0..<6 {
            let field = DigitField()
            field.tag = index
            field.delegate = context.coordinator
            field.keyboardType = .numberPad
            field.textContentType = index == 0 ? .oneTimeCode : nil
            field.textAlignment = .center
            field.font = .monospacedDigitSystemFont(ofSize: 26, weight: .semibold)
            field.textColor = .white
            field.tintColor = .systemPurple
            field.layer.cornerRadius = 14
            field.layer.borderWidth = 1
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            field.accessibilityLabel = "\(accessibilityLabel), \(index + 1) / 6"
            field.accessibilityIdentifier = "vibecast-handoff-digit-\(index)"
            field.emptyDelete = { [weak coordinator = context.coordinator] in coordinator?.deleteBefore(index) }
            stack.addArrangedSubview(field)
            context.coordinator.fields.append(field)
        }
        context.coordinator.sync(code)
        return stack
    }

    func updateUIView(_ uiView: UIStackView, context: Context) {
        context.coordinator.code = $code
        // Playback updates must not recreate inputs or move the first responder.
        if code != context.coordinator.lastEmittedCode { context.coordinator.sync(code) }
        for (index, field) in context.coordinator.fields.enumerated() {
            field.accessibilityLabel = "\(accessibilityLabel), \(index + 1) / 6"
        }
    }

    final class DigitField: UITextField {
        var emptyDelete: (() -> Void)?
        override func deleteBackward() {
            if (text ?? "").isEmpty { emptyDelete?() }
            else { super.deleteBackward() }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var code: Binding<String>
        var fields: [DigitField] = []
        var digits = Array(repeating: "", count: 6)
        var lastEmittedCode = ""
        init(code: Binding<String>) { self.code = code }

        func sync(_ value: String) {
            let clean = Array(value.filter { $0.isASCII && $0.isNumber }.prefix(6)).map(String.init)
            digits = (0..<6).map { $0 < clean.count ? clean[$0] : "" }
            lastEmittedCode = value
            refresh()
        }
        func refresh() {
            for (index, field) in fields.enumerated() {
                if field.text != digits[index] { field.text = digits[index] }
                field.backgroundColor = UIColor.white.withAlphaComponent(field.isFirstResponder ? 0.18 : 0.10)
                field.layer.borderColor = (field.isFirstResponder ? UIColor.systemPurple : UIColor.white.withAlphaComponent(0.28)).cgColor
            }
        }
        func emit() {
            lastEmittedCode = digits.joined()
            code.wrappedValue = lastEmittedCode
            refresh()
        }
        func deleteBefore(_ index: Int) {
            guard index > 0 else { return }
            digits[index - 1] = ""
            fields[index - 1].becomeFirstResponder()
            emit()
        }
        func textFieldDidBeginEditing(_ textField: UITextField) { refresh() }
        func textFieldDidEndEditing(_ textField: UITextField) { refresh() }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let index = textField.tag
            if string.isEmpty {
                digits[index] = ""
                emit()
                return false
            }
            let clean = Array(string.filter { $0.isASCII && $0.isNumber }).map(String.init)
            guard !clean.isEmpty else { return false }
            // Full-code paste/autofill replaces all six, even from a later cell.
            let start = clean.count >= 6 ? 0 : index
            for (offset, digit) in clean.prefix(6 - start).enumerated() { digits[start + offset] = digit }
            fields[min(5, start + clean.count)].becomeFirstResponder()
            emit()
            return false
        }
    }
}
#else
private struct VibeCastCodeEntry: View {
    @Binding var code: String
    let accessibilityLabel: String
    @State private var digits = Array(repeating: "", count: 6)
    @FocusState private var focusedDigit: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { index in
                TextField("", text: Binding(get: { digits[index] }, set: { input in
                    let clean = input.filter { $0.isASCII && $0.isNumber }
                    if clean.count >= 6 {
                        digits = clean.prefix(6).map(String.init)
                        focusedDigit = 5
                    } else {
                        digits[index] = clean.last.map(String.init) ?? ""
                        if !clean.isEmpty { focusedDigit = min(5, index + 1) }
                    }
                    code = digits.joined()
                }))
                .textFieldStyle(.plain)
                .font(.title.monospacedDigit().weight(.semibold))
                .multilineTextAlignment(.center)
                .focused($focusedDigit, equals: index)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(focusedDigit == index ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(focusedDigit == index ? Color.purple : .white.opacity(0.28)).allowsHitTesting(false))
                .onKeyPress(.delete) {
                    guard digits[index].isEmpty, index > 0 else { return .ignored }
                    digits[index - 1] = ""
                    code = digits.joined()
                    focusedDigit = index - 1
                    return .handled
                }
                .accessibilityLabel("\(accessibilityLabel), \(index + 1) / 6")
                .accessibilityIdentifier("vibecast-handoff-digit-\(index)")
            }
        }
    }
}
#endif

#if os(iOS)
private struct IOSNowPlayingView: View {
    @ObservedObject var model: DJConnectAppModel
    var openQueueAction: () -> Void
    @State private var statusToast: DJConnectVisualNotice?

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        IOSTrackHero(model: model, openQueueAction: openQueueAction)
                        OutputSelectorView(model: model)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.clear)
                .refreshable {
                    if !model.isDemoMode, model.pairingStatus == .paired {
                        await refreshNowPlayingWithToast()
                    }
                }
            }
            .djStatusToastOverlay(statusToast, screenImage: "music.note")
            .navigationTitle(screenTitle(model.language, key: "Now Playing", isDemoMode: model.isDemoMode))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if model.shouldShowAppleWatchPairingReminder {
                    ToolbarItem(placement: .topBarLeading) {
                        AppleWatchPairingReminderButton(model: model)
                    }
                }
                ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                    RefreshButton(model: model) {
                        Task { await refreshNowPlayingWithToast() }
                    }
                }
                ConnectionStatusToolbar(model: model)
            }
            .djUserNoticeToast(model: model, screenImage: "music.note")
        }
    }

    private func refreshNowPlayingWithToast() async {
        let didRefresh = await model.refreshNowPlaying()
        showStatusToast(
            didRefresh ? localizedKey(model.language, "appModel.now.playing.updated") : localizedKey(model.language, "appModel.now.playing.update.failed"),
            systemImage: "music.note"
        )
    }

    private func showStatusToast(_ text: String, systemImage: String) {
        let notice = DJConnectVisualNotice(text: text, systemImage: systemImage)
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = notice
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast?.id == notice.id else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }
}

struct IOSConnectionCard: View {
    @ObservedObject var model: DJConnectAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: model.connectionPresentation.icon)
                    .font(.headline)
                    .foregroundStyle(model.connectionPresentation.color)
                    .frame(width: 28, height: 28)
                    .background(model.connectionPresentation.color.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedKey(model.language, model.connectionPresentation.key))
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
                .djConnectGradientCard()
            }

            if let updateRequiredMessage = model.updateRequiredMessage {
                Label(updateRequiredMessage, systemImage: "arrow.down.app")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !model.backendAvailable {
                Label(
                    model.backendUnavailableRecoveryText,
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
    var openQueueAction: () -> Void
    @State private var cardTint = Color(red: 0.22, green: 0.52, blue: 0.92)

    private var playback: DJConnectPlayback? {
        model.playback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnimatedAlbumArtworkView(playback: playback, maxWidth: 300)

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
            IOSPlaybackSurface(model: model, openQueueAction: openQueueAction)
        }
        .padding(14)
        .background {
            NowPlayingArtworkCardBackground(tint: cardTint)
                .clipShape(RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius, style: .continuous))
        }
        .modifier(DJConnectCardOutline())
        .task(id: nowPlayingTrackKey(for: playback)) {
            cardTint = await sampledArtworkTint(for: playback)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(nowPlayingAccessibilityLabel)
    }

    private var nowPlayingAccessibilityLabel: String {
        [
            playback?.trackName,
            playback?.artistName,
            model.selectedOutput
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        .joined(separator: ", ")
    }
}

private struct IOSPlaybackSurface: View {
    @ObservedObject var model: DJConnectAppModel
    var openQueueAction: () -> Void
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }

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

                QueueNavigationButton(model: model, action: openQueueAction)

                FavoriteTrackButton(model: model)
                    .disabled(!canUsePlayback)

                TrackInsightIconButton(model: model)
                    .disabled(!canUsePlayback)

                RepeatModeButton(model: model)
                    .disabled(!canUsePlayback)
            }
        }
        .opacity(canUsePlayback ? 1 : 0.55)
        .padding(14)
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
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: prominent ? .primary : .secondary, shape: .icon, iconDiameter: size))
        .disabled(!canUsePlayback)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct QueueNavigationButton: View {
    @ObservedObject var model: DJConnectAppModel
    var action: () -> Void

    var body: some View {
        Button {
            DJConnectHaptics.selection()
            action()
        } label: {
            Image(systemName: "music.note.list")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 44, height: 44)
        }
        .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
        .help(localizedKey(model.language, "ui.queue"))
        .accessibilityLabel(localizedKey(model.language, "ui.queue"))
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
                        Text(localizedKey(model.language, model.connectionPresentation.key))
                            .foregroundStyle(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: model.connectionPresentation.icon)
                            .foregroundStyle(model.connectionPresentation.color)
                    }
                    .layoutPriority(1)
                    Spacer()
                }

                if let updateRequiredMessage = model.updateRequiredMessage {
                    Label(updateRequiredMessage, systemImage: "arrow.down.app")
                        .foregroundStyle(.orange)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !model.backendAvailable {
                    Label(
                        model.backendUnavailableRecoveryText,
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

}

struct TrackSummaryView: View {
    @ObservedObject var model: DJConnectAppModel
    @State private var cardTint = Color(red: 0.22, green: 0.52, blue: 0.92)

    private var playback: DJConnectPlayback? {
        model.playback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AnimatedAlbumArtworkView(playback: playback, maxWidth: 320)

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
        .background {
            NowPlayingArtworkCardBackground(tint: cardTint)
                .clipShape(RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius, style: .continuous))
        }
        .modifier(DJConnectCardOutline())
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
                    .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
            }
            .help(localizedKey(model.language, "ui.forward.15.seconds"))
            .accessibilityLabel(localizedKey(model.language, "ui.forward.15.seconds"))
        }
        .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
        .disabled(!canSeek)
        .opacity(canSeek ? 1 : 0.45)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct TrackInsightIconButton: View {
    @ObservedObject var model: DJConnectAppModel

    private var helpText: String {
        if model.isLoadingTrackInsight {
            return localizedKey(model.language, "ui.refresh.track.insight")
        }
        if model.currentTrackInsight != nil {
            return localizedKey(model.language, "ui.open.track.insight")
        }
        return localizedKey(model.language, "ui.sends.the.current.track.to.the.backend.for.analysis.and")
    }

    var body: some View {
        Button {
            model.analyzeCurrentTrack(open: true)
        } label: {
            if model.isLoadingTrackInsight {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: "waveform.path.ecg")
                    .symbolRenderingMode(.monochrome)
                    .font(DJConnectButtonAppearance.iconFont)
                    .foregroundStyle(model.currentTrackInsight == nil ? .white.opacity(0.68) : djConnectAccent)
                    .frame(width: 44, height: 44)
            }
        }
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: model.currentTrackInsight != nil ? .selected : .secondary, shape: .icon))
        .disabled(model.isLoadingTrackInsight || !model.canStartTrackInsightAnalysis)
        .opacity(model.canStartTrackInsightAnalysis ? 1 : 0.45)
        .accessibilityLabel(localizedKey(model.language, "ui.open.track.insight"))
        .accessibilityHint(localizedKey(model.language, "ui.sends.the.current.track.to.the.backend.for.analysis.and"))
        .help(helpText)
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
                        .font(DJConnectButtonAppearance.iconFont)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                }
                .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                .help(localizedKey(model.language, "ui.previous.track"))
                .accessibilityLabel(localizedKey(model.language, "ui.previous.track"))
                .disabled(!canUsePlayback)

                Button {
                    DJConnectHaptics.impact()
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(DJConnectButtonAppearance.iconFont)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                }
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, shape: .icon))
                .help(model.isPlaying ? localizedKey(model.language, "ui.pause") : localizedKey(model.language, "ui.play"))
                .accessibilityLabel(model.isPlaying ? localizedKey(model.language, "ui.pause") : localizedKey(model.language, "ui.play"))
                .disabled(!canUsePlayback)

                Button {
                    DJConnectHaptics.impact()
                    model.sendPlaybackCommand("next")
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(DJConnectButtonAppearance.iconFont)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                }
                .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                .help(localizedKey(model.language, "ui.next.track"))
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

struct FavoriteTrackButton: View {
    @ObservedObject var model: DJConnectAppModel
    var identifier = "now-playing-favorite-button"
    var sessionContext: DJConnectSessionRuntime? = nil

    private var isFavorite: Bool {
        model.playback?.currentTrackFavoriteStatus == true
    }

    private var label: String {
        isFavorite
            ? localizedKey(model.language, "ui.remove.from.favorites")
            : localizedKey(model.language, "ui.add.to.favorites")
    }

    private var helpText: String {
        model.isSavingCurrentTrack ? localizedKey(model.language, "appModel.favorite.status.updated") : label
    }

    var body: some View {
        Button {
            DJConnectHaptics.selection()
            if let sessionContext { model.toggleSessionFavorite(sessionContext) }
            else { model.toggleCurrentTrackFavorite() }
        } label: {
            if model.isSavingCurrentTrack {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isFavorite ? djConnectAccent : .white)
                    .frame(width: 44, height: 44)
            }
        }
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: isFavorite ? .selected : .secondary, shape: .icon, usesLiveGlass: false))
        .tint(isFavorite ? djConnectAccent : .white)
        .help(helpText)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
        .disabled(model.isSavingCurrentTrack || (sessionContext.map { !model.canToggleSessionFavorite($0) } ?? false))
    }
}

/// Shared queue/archive row surface; their leading glyph and trailing action remain distinct.
struct DJConnectMediaRowSurface: ViewModifier {
    static let cornerRadius: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .djSessionFrostedSurface(cornerRadius: Self.cornerRadius)
    }
}

struct DJConnectMediaRowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let shape = RoundedRectangle(cornerRadius: DJConnectMediaRowSurface.cornerRadius, style: .continuous)
        configuration.label
            .contentShape(shape)
            .overlay { shape.fill(djConnectAccent.opacity(pressed ? 0.14 : 0)).allowsHitTesting(false) }
            .overlay { shape.stroke(djConnectAccent.opacity(pressed ? 0.60 : 0), lineWidth: 1.5).allowsHitTesting(false) }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: pressed)
    }
}

private struct QueueItemRow: View {
    let item: DJConnectQueueItem
    var isLoading = false

    private var subtitle: String? {
        Self.trimmedNonEmpty(item.displaySubtitle)
    }

    var body: some View {
        HStack(spacing: 12) {
            QueueArtworkView(url: item.albumImageURL)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
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
        .modifier(DJConnectMediaRowSurface())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.displayTitle)
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
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

    private var sortedOutputs: [DJConnectOutputDevice] {
        model.availableOutputs.sorted { left, right in
            let order = left.name.localizedStandardCompare(right.name)
            return order == .orderedSame ? left.id < right.id : order == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localizedKey(model.language, "ui.output.device"))
                    .font(.headline)
                Spacer()
                Button { model.loadOutputs() } label: {
                    if model.isLoadingOutputs {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise").foregroundStyle(.white)
                    }
                }
                    .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                    .tint(.white)
                    .help(localizedKey(model.language, "ui.output.refresh"))
                    .disabled(!canUsePlayback || model.isLoadingOutputs)
                    .accessibilityLabel(localizedKey(model.language, "ui.output.refresh"))
                    .accessibilityIdentifier("output-devices-refresh")
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
                    ForEach(sortedOutputs) { output in
                        OutputDeviceChoiceRow(
                            language: model.language,
                            output: output,
                            title: output.name,
                            isActive: output.active == true,
                            isPending: model.pendingOutputSelectionID == output.id,
                            isEnabled: canUsePlayback,
                            action: {
                                guard canUsePlayback else {
                                    return
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
        .task(id: canUsePlayback) {
            if model.canUsePlaybackFeatures {
                model.loadOutputs()
            }
        }
        #if os(iOS)
        .padding(14)
        #endif
    }
}

private struct OutputDeviceChoiceRow: View {
    let language: String
    let output: DJConnectOutputDevice?
    let title: String
    let isActive: Bool
    var isPending: Bool = false
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
        if isPending { return localizedKey(language, "ui.output.switching") }
        if output?.isCachedSpotifyOutput == true {
            return localizedKey(language, "ui.output.recently.seen")
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

                if isPending {
                    ProgressView().controlSize(.small).tint(activeColor)
                } else if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(activeColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Color.clear
                    .djSessionFrostedSurface(cornerRadius: 14)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(activeColor.opacity(isActive ? 0.28 : (isPending ? 0.10 : 0)))
                    }
                    .allowsHitTesting(false)
            }
            .overlay {
                if isActive || isPending {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(activeColor.opacity(0.65), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .djConnectPlainButtonStyle()
        .disabled(!isEnabled || isPending)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("output-device-\(output?.id ?? "none")")
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

    private var helpText: String {
        let state = isShuffling ? localizedKey(model.language, "ui.on") : localizedKey(model.language, "ui.off")
        return "\(localizedKey(model.language, "ui.shuffle")): \(state)"
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
                .frame(width: 44, height: 44)
        }
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: isShuffling ? .selected : .secondary, shape: .icon))
        .help(helpText)
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
                .frame(width: 44, height: 44)
        }
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: repeatState != .off ? .selected : .secondary, shape: .icon))
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
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.openURL) private var openURL
    var embedsNavigationStack = true
    var openTrackInsightAction: () -> Void = {}
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
    @State private var showingClearConfirmation = false
    @State private var feedbackMessage: DJConnectAskDJMessage?
    @State private var toast: String?
    @State private var isSearchVisible = false
    @State private var askDJSearchText = ""
    @State private var selectedSearchResultIndex = 0
    @State private var selectedSearchResultID: UUID?
    @State private var isAskDJAtTop = true
    @State private var isAskDJScrollToTopButtonSuppressed = false
    @State private var didScrollAskDJToInitialTop = false
    @State private var floatingComposerHeight: CGFloat = 96
    @State private var promptCaretRequest: UUID?
    @FocusState private var isInputFocused: Bool
    @FocusState private var isSearchFocused: Bool

    init(model: DJConnectAppModel, embedsNavigationStack: Bool = true,
         openTrackInsightAction: @escaping () -> Void = {}) {
        self.model = model
        self.history = model.sessionHistory
        self.embedsNavigationStack = embedsNavigationStack
        self.openTrackInsightAction = openTrackInsightAction
    }

    private var searchResultIDs: [UUID] {
        let query = askDJSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }
        return model.askDJMessages.sorted(by: askDJTimelineMessagePrecedes).reversed().compactMap { message in
            message.text.localizedCaseInsensitiveContains(query) ? message.id : nil
        }
    }

    private var activeSearchResultID: UUID? {
        if let selectedSearchResultID, searchResultIDs.contains(selectedSearchResultID) { return selectedSearchResultID }
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
        return Array(messages.sorted(by: askDJTimelineMessagePrecedes).reversed())
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
            && model.canUseAskDJFeatures
    }

    private var canUseVoiceInput: Bool {
        model.voiceEnabled
            && model.canUseAskDJFeatures
            && !model.isRefreshing
            && !model.isSendingAskDJText
            && model.voiceStatus != .processing
    }

    private var isAskDJHistoryStale: Bool {
        !model.isDemoMode && !model.canUseAskDJFeatures
    }

    private var chatTopPadding: CGFloat {
        let topInset = djConnectScreenVerticalPadding
        return topInset
            + (isSearchVisible ? 56 : 0)
    }

    private func shouldUseWideLayout(for size: CGSize) -> Bool {
        #if os(macOS)
        size.width >= 1_000
        #else
        horizontalSizeClass == .regular && size.width > size.height
        #endif
    }

    private func maxContentWidth(for size: CGSize) -> CGFloat {
        shouldUseWideLayout(for: size) ? djConnectMacDetailContentMaxWidth : djConnectContentMaxWidth
    }

    private var floatingControlTopPadding: CGFloat {
        #if os(macOS)
        -8
        #else
        10
        #endif
    }

    private var shouldShowAskDJScrollToTopButton: Bool {
        !askDJTimelineMessages.isEmpty && !isAskDJAtTop && !isAskDJScrollToTopButtonSuppressed
    }

    private var askDJScrollToTopButtonBottomPadding: CGFloat {
        #if os(macOS)
        28
        #else
        12
        #endif
    }

    private var usesFloatingComposer: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
    private var composer: some View {
        AskDJInputBar(model: model, canSend: canSend, canUseVoiceInput: canUseVoiceInput,
                      isInputFocused: $isInputFocused, caretRequest: promptCaretRequest,
                      floating: usesFloatingComposer)
    }

    @ViewBuilder private var navigationContent: some View {
        if embedsNavigationStack { NavigationStack { content } }
        else { content }
    }

    private var content: some View {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let contentWidth = min(maxContentWidth(for: geometry.size), geometry.size.width)
                    ScrollViewReader { proxy in
                        ZStack(alignment: .top) {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    #if !os(macOS)
                                    Color.clear.frame(height: 1).id("ask-dj-top")
                                    #endif
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
                                                promptCaretRequest = UUID()
                                                isInputFocused = true
                                            }
                                        )
                                    } else {
                                        ForEach(askDJTimelineMessages) { message in
                                            let isTransientMessage = isTransientAskDJMessage(message)
                                            let contextEntry = isTransientMessage || isAskDJHistoryStale ? nil : history.contextEntry(for: message)
                                            AskDJMessageBubble(
                                                message: message,
                                                language: model.language,
                                                isStaleHistory: isAskDJHistoryStale && !isTransientMessage,
                                                isAudioLoading: isTransientMessage ? false : model.isLoadingAskDJAudio(message.audioURL),
                                                isAudioPlaying: isTransientMessage ? false : model.isPlayingAskDJAudio(message.audioURL),
                                                isRetryDisabled: isTransientMessage || isAskDJHistoryStale || model.isSendingAskDJText,
                                                playingActionID: model.playingAskDJActionID,
                                                currentMood: model.confirmedSessionMoodInt,
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
                                                trackInsightAction: {
                                                    guard !isTransientMessage, !isAskDJHistoryStale else { return }
                                                    openTrackInsightAction()
                                                },
                                                openLink: { openURL($0.url) },
                                                feedbackAction: { feedbackMessage = $0 },
                                                setPromptAction: { text in
                                                    guard !isAskDJHistoryStale else { return }
                                                    model.askDJDraft = text
                                                    promptCaretRequest = UUID()
                                                    isInputFocused = true
                                                },
                                                historicalMatches: model.sessionHistory.historicalMatches[message.serverID ?? ""] ?? [],
                                                openHistoryAction: { action in Task { await model.sessionHistory.open(action) } },
                                                contextQuestionAction: contextEntry.map { entry in
                                                    {
                                                        guard let retained = history.contextEntry(for: message), retained.reference == entry.reference else { return }
                                                        history.selectedEntry = retained.reference
                                                        dismissAskDJSearch()
                                                        isInputFocused = true
                                                    }
                                                },
                                                contextQuestionSelected: contextEntry.map { history.selectedEntry == $0.reference } ?? false,
                                                contextQuestionID: "ask-answer-context-" + message.id.uuidString
                                            )
                                            .id(message.id)
                                        }
                                    }
                                    if usesFloatingComposer && isAskDJHistoryStale {
                                        AskDJOfflineNotice(language: model.language)
                                    }

                                }
                                #if os(macOS)
                                .background(alignment: .top) {
                                    Color.clear.frame(height: 1).id("ask-dj-top")
                                }
                                #endif
                                .padding(.horizontal, djConnectScreenHorizontalPadding)
                                .padding(.top, chatTopPadding)
                                .padding(.bottom, 16)
                                .frame(width: contentWidth, alignment: .top)
                                .frame(maxWidth: .infinity, alignment: .top)
                                .contentShape(Rectangle())
                            }
                            .contentMargins(.bottom, usesFloatingComposer && !isSearchVisible ? floatingComposerHeight + 16 : 0, for: .scrollContent)
                            .coordinateSpace(name: "askDJScroll")
                            .contentShape(Rectangle())
                            .onScrollGeometryChange(for: Bool.self) { scroll in
                                scroll.contentOffset.y + scroll.contentInsets.top <= 140
                            } action: { _, isAtTop in
                                isAskDJAtTop = isAtTop
                                if isAtTop { isAskDJScrollToTopButtonSuppressed = false }
                            }
                            .refreshable {
                                dismissAskDJKeyboard()
                                if !model.isDemoMode {
                                    await model.refreshAskDJHistory(showToast: true)
                                }
                            }
                            .scrollDismissesKeyboard(.interactively)
                            .overlay(alignment: .bottom) {
                                HStack {
                                    Spacer()
                                    if shouldShowAskDJScrollToTopButton {
                                        Button {
                                            isInputFocused = false
                                            isSearchFocused = false
                                            withAnimation(.easeOut(duration: 0.22)) {
                                                isAskDJScrollToTopButtonSuppressed = true
                                                isAskDJAtTop = true
                                                proxy.scrollTo("ask-dj-top", anchor: .top)
                                            }
                                        } label: {
                                            Image(systemName: "arrow.up")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 44, height: 44)
                                        }
                                        .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                                        .padding(.trailing, djConnectScreenHorizontalPadding)
                                        .padding(.bottom, askDJScrollToTopButtonBottomPadding + (usesFloatingComposer && !isSearchVisible ? floatingComposerHeight + 8 : 0))
                                        .help(localizedKey(model.language, "ui.session.history.back_top"))
                                        .accessibilityLabel(localizedKey(model.language, "ui.session.history.back_top"))
                                        .accessibilityIdentifier("ask-dj-jump-top")
                                    }
                                }
                                .frame(width: contentWidth, alignment: .trailing)
                                .frame(maxWidth: .infinity)
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
                                #if os(macOS)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .top)
                                #else
                                .padding(.horizontal, djConnectScreenHorizontalPadding)
                                .padding(.top, floatingControlTopPadding + 10)
                                .frame(width: contentWidth, alignment: .top)
                                .frame(maxWidth: .infinity, alignment: .top)
                                #endif
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if usesFloatingComposer && !isSearchVisible {
                                composer
                                    .djFloatingAskDJWidth(maximum: min(contentWidth, 1000))
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { floatingComposerHeight = $0 }
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 8)
                            }
                        }
                        .contentShape(Rectangle())
                        .onChange(of: model.askDJMessages) {
                            isAskDJScrollToTopButtonSuppressed = false
                            normalizeAskDJSearchSelection()
                            scrollAskDJToInitialTopIfNeeded(proxy: proxy)
                        }
                        .onAppear {
                            didScrollAskDJToInitialTop = false
                            scrollAskDJToInitialTopIfNeeded(proxy: proxy)
                        }
                        .onChange(of: model.isCheckingAskDJHistoryState) { _, isChecking in
                            guard !isChecking else {
                                return
                            }
                            scrollAskDJToInitialTopIfNeeded(proxy: proxy)
                        }
                        .onDisappear {
                            didScrollAskDJToInitialTop = false
                        }
                        .onChange(of: model.askDJScrollRequestID) {
                            guard !isSearchVisible else {
                                return
                            }
                            guard !askDJTimelineMessages.isEmpty else {
                                return
                            }
                            withAnimation(.easeOut(duration: 0.22)) {
                                isAskDJScrollToTopButtonSuppressed = true
                                isAskDJAtTop = true
                                proxy.scrollTo("ask-dj-top", anchor: .top)
                            }
                        }
                        .onChange(of: askDJSearchText) {
                            selectedSearchResultIndex = 0
                            selectedSearchResultID = nil
                            scrollToActiveAskDJSearchResult(proxy: proxy)
                        }
                    }
                }

                if isAskDJHistoryStale && !usesFloatingComposer {
                    AskDJOfflineNotice(language: model.language)
                        .padding(.horizontal, djConnectScreenHorizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                }

                if !isSearchVisible && !usesFloatingComposer {
                composer
                #if os(iOS)
                .padding(.bottom, 8)
                #endif
                }
            }
            .background(DJConnectCanvasBackground())
            .djStatusToastOverlay(text: toast, systemImage: "bubble.left.and.bubble.right")
            .navigationTitle(screenTitle(model.language, key: "Ask DJ", isDemoMode: model.isDemoMode))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("screen-ask-dj")
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        toggleAskDJSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(isSearchVisible ? djConnectAccent : .primary)
                    }
                    .help(localizedKey(model.language, "ui.search.ask.dj"))
                    .accessibilityLabel(localizedKey(model.language, "ui.search.ask.dj"))

                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if !model.askDJMessages.isEmpty {
                        Button {
                            isInputFocused = false
                            model.recordPresentationState("ask-dj-clear-confirmation")
                            DJConnectHaptics.selection()
                            showingClearConfirmation = true
                        } label: {
                            Image(systemName: model.isClearingAskDJHistory ? "hourglass" : "trash")
                                .foregroundStyle(.red)
                        }
                        .disabled(model.isClearingAskDJHistory)
                        .help(localizedKey(model.language, "ui.clear.chat"))
                    }
                    SessionConnectionToolbarButton(model: model)
                    askDJRefreshToolbarButton
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
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !model.askDJMessages.isEmpty {
                        Button {
                            isInputFocused = false
                            model.recordPresentationState("ask-dj-clear-confirmation")
                            DJConnectHaptics.selection()
                            showingClearConfirmation = true
                        } label: {
                            Image(systemName: model.isClearingAskDJHistory ? "hourglass" : "trash")
                                .foregroundStyle(.red)
                        }
                        .tint(.red)
                        .disabled(model.isClearingAskDJHistory)
                        .help(localizedKey(model.language, "ui.clear.chat"))
                        .accessibilityLabel(localizedKey(model.language, "ui.clear.chat"))

                    }
                    SessionConnectionToolbarButton(model: model)
                    askDJRefreshToolbarButton
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

    var body: some View {
        navigationContent
        .background(DJConnectCanvasBackground())
        .onAppear {
            model.presentMusicDNAOptInPromptIfNeeded()
        }
        .task {
            await model.runAskDJHistorySyncLoop()
        }
        .sheet(item: $feedbackMessage) { message in
            AskDJFeedbackPromptView(model: model, message: message)
            #if os(iOS)
                .presentationDetents([.large])
                .presentationSizing(.page)
            #endif
        }
        .onChange(of: model.askDJToast?.id) { _, _ in
            guard let text = model.askDJToast?.text else {
                return
            }
            showToast(text)
        }
    }

    private func dismissAskDJSearch() {
        withAnimation(.easeOut(duration: 0.18)) {
            isSearchVisible = false
        }
        askDJSearchText = ""
        selectedSearchResultIndex = 0
        selectedSearchResultID = nil
        isSearchFocused = false
    }

    private func dismissAskDJKeyboard() {
        isInputFocused = false
        isSearchFocused = false
        resignPlatformFirstResponder()
    }

    private var askDJRefreshToolbarButton: some View {
        Button {
            isInputFocused = false
            Task {
                if !model.isDemoMode, model.pairingStatus == .paired {
                    await model.refreshAskDJHistory(showToast: true)
                }
            }
        } label: {
            Image(systemName: model.isCheckingAskDJHistoryState ? "hourglass" : "arrow.clockwise")
                .foregroundStyle(.white.opacity(model.isDemoMode ? 0.4 : 1))
        }
        .tint(.white)
        .disabled(model.isDemoMode || model.pairingStatus != .paired || model.isClearingAskDJHistory || model.isCheckingAskDJHistoryState)
        .help(localizedKey(model.language, "ui.refresh.ask.dj"))
        .accessibilityLabel(localizedKey(model.language, "ui.refresh.ask.dj"))
    }

    private func toggleAskDJSearch() {
        dismissAskDJKeyboard()
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
        let results = searchResultIDs
        selectedSearchResultIndex = askDJSearchResultIndex(preserving: selectedSearchResultID,
                                                          fallback: selectedSearchResultIndex, in: results)
        selectedSearchResultID = results.indices.contains(selectedSearchResultIndex) ? results[selectedSearchResultIndex] : nil
    }

    private func moveAskDJSearchSelection(by delta: Int, proxy: ScrollViewProxy) {
        guard !searchResultIDs.isEmpty else {
            return
        }
        normalizeAskDJSearchSelection()
        let count = searchResultIDs.count
        selectedSearchResultIndex = (selectedSearchResultIndex + delta + count) % count
        selectedSearchResultID = searchResultIDs[selectedSearchResultIndex]
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

    private func scrollAskDJToInitialTopIfNeeded(proxy: ScrollViewProxy) {
        guard !didScrollAskDJToInitialTop else {
            return
        }
        guard !isSearchVisible, !askDJTimelineMessages.isEmpty else {
            return
        }
        didScrollAskDJToInitialTop = true
        DispatchQueue.main.async {
            isAskDJAtTop = true
            proxy.scrollTo("ask-dj-top", anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            isAskDJAtTop = true
            proxy.scrollTo("ask-dj-top", anchor: .top)
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

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}


struct AskDJSearchBar: View {
    let language: String
    var scopeName: String = "Ask DJ"
    var promptKey: String? = nil
    var fieldIdentifier = "ask-dj-search-field"
    var countIdentifier = "ask-dj-search-count"
    var isLoading = false
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let resultCount: Int
    let selectedIndex: Int
    let previousAction: () -> Void
    let nextAction: () -> Void
    let closeAction: () -> Void
    var submitAction: (() -> Void)? = nil

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
                .focusEffectDisabled()
                .tint(djConnectAccent)
                .accessibilityIdentifier(fieldIdentifier)
                .onSubmit {
                    if let submitAction {
                        submitAction()
                    } else if resultCount > 0 {
                        nextAction()
                    }
                }
            if isLoading { ProgressView().controlSize(.small) }
            Text(resultLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))
                .frame(minWidth: 44, alignment: .trailing)
                .accessibilityIdentifier(countIdentifier)
            Button(action: previousAction) {
                Image(systemName: "chevron.up")
            }
            .disabled(resultCount == 0)
            .help(localizedKey(language, "ui.previous.result"))
            .accessibilityLabel(localizedKey(language, "ui.previous.result"))
            Button(action: nextAction) {
                Image(systemName: "chevron.down")
            }
            .disabled(resultCount == 0)
            .help(localizedKey(language, "ui.next.result"))
            .accessibilityLabel(localizedKey(language, "ui.next.result"))
            Button(action: closeAction) {
                Image(systemName: "xmark")
            }
            .help(localizedKey(language, "ui.close.search"))
            .accessibilityLabel(localizedKey(language, "ui.close.search"))
        }
        .djConnectPlainButtonStyle()
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.05, green: 0.05, blue: 0.13).opacity(0.82))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(djConnectAccent.opacity(isFocused.wrappedValue ? 0.80 : 0.40), lineWidth: 1)

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
        Text(promptKey.map { localizedKey(language, $0) } ?? localizedKey(language, "ui.search.value", arguments: scopeName))
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
            hero

            VStack(alignment: .leading, spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    Button {
                        selectExample(example)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.54))
                                .frame(width: 18)
                            Text(example)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.86))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.50))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .frame(maxWidth: 480, alignment: .leading)
                        .background {
                            DJConnectCardAppearance.shape
                                .fill(.white.opacity(0.09))
                        }
                        .overlay {
                            DJConnectCardAppearance.shape
                                .stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
                        }
                    }
                    .djConnectPlainButtonStyle()
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

    private var hero: some View {
        VStack(spacing: 16) {
            DJConnectHeroGlyph(systemImage: "bubble.left.and.bubble.right")
            Text(localizedKey(language, "ui.ask.dj"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text(localizedKey(language, "ui.ask.about.the.music.or.give.your.dj.a.request"))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, minHeight: 190)
        .djConnectHeroCard()
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
            DJConnectCardAppearance.shape
                .fill(Color.white.opacity(0.10))
        }
        .overlay {
            DJConnectCardAppearance.shape
                .stroke(Color.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
        }
        .padding(.horizontal, 4)
    }
}

/// Native conversation rendering shared with Session timelines.
struct AskDJMessageBubble: View {
    let message: DJConnectAskDJMessage
    let language: String
    let isStaleHistory: Bool
    let isAudioLoading: Bool
    let isAudioPlaying: Bool
    let isRetryDisabled: Bool
    let playingActionID: String?
    let currentMood: Int?
    let isSearchResult: Bool
    let isActiveSearchResult: Bool
    let searchText: String
    let retryAction: () -> Void
    let playAction: (DJConnectAskDJPlaybackAction) -> Void
    let audioAction: () -> Void
    let trackInsightAction: () -> Void
    let openLink: (DJConnectResponseLink) -> Void
    let feedbackAction: (DJConnectAskDJMessage) -> Void
    let setPromptAction: (String) -> Void
    var isReadOnly = false
    var allowsSessionPlaybackActions = false
    var serverHighlights: [DJConnectHistoryHighlight]? = nil
    var historicalMatches: [DJConnectHistoryEntry] = []
    var openHistoryAction: ((DJConnectSessionOpenAction) -> Void)? = nil
    var contextQuestionAction: (() -> Void)? = nil
    var contextQuestionSelected = false
    var contextQuestionID = ""

    private var renderedMessageText: some View {
        Group {
            if let serverHighlights { SessionHighlightedText(text: displayText, highlights: serverHighlights) }
            else { AskDJMarkdownText(text: displayText, highlight: searchText) }
        }
        .contextMenu {
            if !isReadOnly && canSetPrompt && !isStaleHistory {
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
        !isReadOnly && !isUser && !isSystemMessage && !isStaleHistory
    }

    private var shouldShowGeneratedTextIcon: Bool {
        !isUser
            && !isSystemMessage
            && message.isGeneratedText == true
            && message.textSource?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "fallback"
    }

    private var hasPlayableAudio: Bool {
        guard let audioURL = message.audioURL else {
            return false
        }
        return !audioURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var assistantMood: Int? {
        guard !isUser && !isSystemMessage else {
            return nil
        }
        return (message.mood ?? currentMood).map { max(0, min(100, $0)) }
    }

    private var assistantMoodColors: [Color]? {
        guard let assistantMood else {
            return nil
        }
        switch assistantMood {
        case ...24:
            return [
                Color(red: 0.24, green: 0.25, blue: 0.63),
                Color(red: 0.38, green: 0.24, blue: 0.58),
                Color(red: 0.58, green: 0.30, blue: 0.48)
            ]
        case 25...59:
            return [
                Color(red: 0.02, green: 0.47, blue: 0.55),
                Color(red: 0.12, green: 0.34, blue: 0.82),
                Color(red: 0.49, green: 0.25, blue: 0.86)
            ]
        case 60...84:
            return [
                Color(red: 0.11, green: 0.45, blue: 1.00),
                Color(red: 0.44, green: 0.28, blue: 0.98),
                Color(red: 0.84, green: 0.18, blue: 0.90)
            ]
        default:
            return [
                Color(red: 1.00, green: 0.46, blue: 0.26),
                Color(red: 0.94, green: 0.20, blue: 0.55),
                Color(red: 0.70, green: 0.18, blue: 0.86)
            ]
        }
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

    private var shouldShowTrackInsightShortcut: Bool {
        guard !isReadOnly, !isUser, !isSystemMessage, !isStaleHistory else {
            return false
        }
        return message.origin?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "play_now"
    }

    private var shouldShowAudioReplayShortcut: Bool {
        !isReadOnly && !isStaleHistory && !isUser && hasPlayableAudio
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 42)
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 10) {
                    if let systemMessageLabel {
                        Label(systemMessageLabel, systemImage: "info.circle")
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
                                renderedMessageText
                            }
                        } else if shouldShowGeneratedTextIcon {
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(djConnectIconGradient)
                                renderedMessageText
                            }
                        } else {
                            renderedMessageText
                        }
                    }
                    if !isUser, let trackInsight = message.trackInsight {
                        AskDJTrackInsightSummary(insight: trackInsight, language: language)
                    }
                    if !isUser, !message.items.isEmpty {
                        AskDJItemList(items: message.items)
                    }
                    ForEach(historicalMatches.filter { $0.isRetained() }) { match in
                        SessionHistoryMatchCard(entry: match, language: language) { action in openHistoryAction?(action) }
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
                    if (!isReadOnly || allowsSessionPlaybackActions), !isStaleHistory, !isUser, !renderablePlaybackActions.isEmpty {
                        AskDJPlaybackActionStack(
                            actions: renderablePlaybackActions,
                            language: language,
                            playingActionID: playingActionID,
                            playAction: playAction
                        )
                    }
                    if shouldShowAudioReplayShortcut || shouldShowTrackInsightShortcut {
                        AskDJResponseShortcutStack(
                            language: language,
                            showAudioReplay: shouldShowAudioReplayShortcut,
                            isAudioLoading: isAudioLoading,
                            isAudioPlaying: isAudioPlaying,
                            audioAction: audioAction,
                            showTrackInsight: shouldShowTrackInsightShortcut,
                            trackInsightAction: trackInsightAction
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .padding(.trailing, contextQuestionAction == nil ? 0 : 36)
                .frame(minHeight: contextQuestionAction == nil ? 0 : 44)
                .overlay(alignment: .topTrailing) {
                    if let contextQuestionAction {
                        Button { DJConnectHaptics.selection(); contextQuestionAction() } label: {
                            Image(systemName: contextQuestionSelected ? "checkmark.bubble" : "bubble.left.and.bubble.right")
                                .font(.system(size: 16))
                                .foregroundStyle(contextQuestionSelected ? djConnectAccent : .secondary)
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .djConnectPlainButtonStyle().padding(.trailing, 4)
                        .accessibilityLabel(localizedKey(language, "ui.session.history.ask_entry"))
                        .accessibilityValue(contextQuestionSelected ? localizedKey(language, "ui.session.history.selected_context") : "")
                        .accessibilityIdentifier(contextQuestionID)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(bubbleStrokeStyle, lineWidth: isActiveSearchResult ? DJConnectCardAppearance.searchFocusWidth : 1)
                }
                .djSessionFrostedSurface(cornerRadius: DJConnectCardAppearance.conversationCornerRadius)
                HStack(spacing: 8) {
                    if isUser {
                        Text(localizedKey(language, "ui.chat.you"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.60))
                            .accessibilityIdentifier("ask-dj-user-label")
                    }
                    Text(messageMetadataText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.46))
                    if !isReadOnly, isUser, message.status == .failed {
                        Button { DJConnectHaptics.impact(); retryAction() } label: {
                            Label(localizedKey(language, "ui.retry"), systemImage: "arrow.clockwise")
                                .font(.caption2.weight(.semibold))
                        }
                        .djConnectPlainButtonStyle()
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
                        .djConnectPlainButtonStyle()
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
            AnyShapeStyle(DJConnectCardAppearance.searchFocusGradient)
        } else if isSearchResult {
            AnyShapeStyle(Color.white.opacity(0.36))
        } else if isStaleHistory {
            AnyShapeStyle(Color.white.opacity(0.16))
        } else if let assistantMoodColors {
            AnyShapeStyle(LinearGradient(
                colors: [
                    assistantMoodColors[0].opacity(0.42),
                    assistantMoodColors[min(2, assistantMoodColors.count - 1)].opacity(0.52),
                    Color.white.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else {
            AnyShapeStyle(Color.white.opacity(isUser ? 0.12 : isSystemMessage ? 0.14 : 0.18))
        }
    }


}

private struct AskDJResponseShortcutStack: View {
    let language: String
    let showAudioReplay: Bool
    let isAudioLoading: Bool
    let isAudioPlaying: Bool
    let audioAction: () -> Void
    let showTrackInsight: Bool
    let trackInsightAction: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                shortcuts
            }
            VStack(alignment: .leading, spacing: 10) {
                shortcuts
            }
        }
    }

    @ViewBuilder
    private var shortcuts: some View {
        if showAudioReplay {
            AskDJAudioReplayButton(
                language: language,
                isLoading: isAudioLoading,
                isPlaying: isAudioPlaying,
                action: audioAction
            )
        }
        if showTrackInsight {
            AskDJTrackInsightButton(
                language: language,
                isLoading: false,
                action: trackInsightAction
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
        Button { DJConnectHaptics.impact(); action() } label: {
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
        .djConnectPlainButtonStyle()
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

private struct AskDJTrackInsightButton: View {
    let language: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button { DJConnectHaptics.impact(); action() } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(.white.opacity(0.18))
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 28, height: 28)
                Text(localizedKey(language, "ui.track.insight"))
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
        .djConnectPlainButtonStyle()
        .disabled(isLoading)
        .help(localizedKey(language, "ui.sends.the.current.track.to.the.backend.for.analysis.and"))
        .accessibilityLabel(localizedKey(language, "ui.open.track.insight"))
    }
}

private struct AskDJTrackInsightSummary: View {
    let insight: TrackInsight
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Track Insight", systemImage: "waveform.path.ecg")
                .font(.caption.weight(.semibold))
                .foregroundStyle(djConnectIconGradient)
            Text(insight.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(insight.displaySummary(language: language))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(3)
            HStack(spacing: 8) {
                if let genre = insight.genre {
                    Text(genre)
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(10)
        .background(.white.opacity(0.08), in: DJConnectCardAppearance.shape)
        .overlay {
            DJConnectCardAppearance.shape
                .stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
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

                }
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: action.responseValue?.lowercased() == "no" ? .tertiary : .primary))
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

        }
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .secondary))
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

                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .secondary))
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

                if action.isOutputAction {
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
                                DJConnectButtonAppearance.primaryGradient
                            )
                    }
                } else {
                    ZStack {
                        if playingActionID == action.id {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .offset(x: 1)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(DJConnectButtonAppearance.primaryGradient, in: Circle())
                    .fixedSize()
                    .accessibilityHidden(true)
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
        .djConnectPlainButtonStyle()
        .accessibilityLabel(action.title)
        .accessibilityHint(action.isOutputAction ? buttonLabel(for: action) : localizedKey(language, "ui.play.now"))
        .disabled(playingActionID != nil)
    }

    static func isSupportedAction(_ action: DJConnectAskDJPlaybackAction) -> Bool {
        if action.isSaveCurrentTrackControlAction {
            return true
        }
        if action.isAskDJMessageAction {
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
                .djConnectPlainButtonStyle()
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
                    .djConnectPlainButtonStyle()
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
            attributed[matchRange].backgroundColor = DJConnectCardAppearance.searchMatchBackground
            attributed[matchRange].foregroundColor = DJConnectCardAppearance.searchMatchForeground
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
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }

    private var isCompact: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 10
            let visibleCount = min(max(images.count, 1), 3)
            let availableWidth = max(1, geometry.size.width)
            let cardWidth = min(
                maxCardWidth,
                floor((availableWidth - spacing * CGFloat(visibleCount - 1)) / CGFloat(visibleCount))
            )
            let stripHeight = imageStripHeight(for: cardWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: spacing) {
                    ForEach(images) { image in
                        AskDJImageCard(image: image, width: cardWidth)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
            .frame(height: stripHeight)
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(height: reservedStripHeight)
    }

    private var reservedStripHeight: CGFloat {
        imageStripHeight(for: maxCardWidth)
    }

    private var maxCardWidth: CGFloat {
        isCompact ? 112 : 190
    }

    private func imageStripHeight(for cardWidth: CGFloat) -> CGFloat {
        let textHeight: CGFloat = images.contains { image in
            image.title?.isEmpty == false || image.subtitle?.isEmpty == false
        } ? 58 : 0
        return cardWidth + textHeight + 4
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
            .clipShape(DJConnectCardAppearance.shape)
            .overlay {
                DJConnectCardAppearance.shape
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

/// One native mood popover for every screen, including standalone Insight.
/// Selection still belongs to the caller's existing Session/UI-state owner.
struct SessionGlassChoiceSelector: View {
    let steps: [(label: String, value: Int)]
    let selectedIndex: Int
    let language: String
    var glyphs = ["moon.stars", "waveform", "bolt", "sparkles"]
    var titleKey = "ui.session.welcome.mood"
    var accessibilityLabelKey = "ui.session.select_mood"
    var optionIDs: [String]? = nil
    var onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizedKey(language, titleKey))
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                ForEach(steps.indices, id: \.self) { index in
                    Button { DJConnectHaptics.selection(); onSelect(index) } label: {
                        Image(systemName: glyphs[safe: index] ?? "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(index == selectedIndex ? djConnectAccent : .white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(
                        emphasis: index == selectedIndex ? .selected : .secondary,
                        shape: .segmented, expands: true, usesLiveGlass: false
                    ))
                    .accessibilityLabel(steps[index].label)
                    .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                    .accessibilityIdentifier(optionIDs?[safe: index] ?? ("session-mood-option-" + String(index)))
                }
            }
            .padding(DJConnectCardAppearance.segmentedContentInset)
            .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .djSessionFrostedSurface(cornerRadius: 32)
            Text(steps[safe: selectedIndex]?.label ?? "")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.90))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("session-popover-selected-mood")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localizedKey(language, accessibilityLabelKey))
        .accessibilityValue(steps[safe: selectedIndex]?.label ?? "")
    }
}

func askDJMoodIcon(for index: Int) -> String {
    switch index {
    case 0:
        return "moon.zzz.fill"
    case 1:
        return "waveform"
    case 2:
        return "bolt.fill"
    default:
        return "party.popper.fill"
    }
}

/// Shared native composer. A Session surface supplies context-bound actions;
/// the general Ask DJ surface continues using the existing model actions.
extension View {
    /// Use the actual container width, including iPad portrait and Split View.
    /// Scale the layout width, preserving readable text and44-point controls.
    @ViewBuilder func djFloatingAskDJWidth(maximum: CGFloat) -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.containerRelativeFrame(.horizontal) { width, _ in
                min(maximum, max(0, width - 24)) * 0.75
            }
        } else {
            self.frame(maxWidth: maximum)
        }
        #else
        self.frame(maxWidth: maximum)
        #endif
    }
}

struct AskDJInputBar: View {
    @ObservedObject var model: DJConnectAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    #if os(macOS)
    @State private var promptSelection: TextSelection?
    #endif
    let canSend: Bool
    let canUseVoiceInput: Bool
    var isInputFocused: FocusState<Bool>.Binding
    var sendAction: (() -> Void)? = nil
    var startVoiceAction: (() -> Void)? = nil
    var stopVoiceAction: (() -> Void)? = nil
    var toggleVoiceAction: (() -> Void)? = nil
    var cancelVoiceAction: (() -> Void)? = nil
    var caretRequest: UUID? = nil
    var floating = false
    var placeholderKey: String? = nil
    let surfaceColors: [Color]?
    @State private var editorDraftValue: String
    #if os(iOS)
    @State private var isNativeEditorFocused = false
    #endif

    init(model: DJConnectAppModel, canSend: Bool, canUseVoiceInput: Bool,
         isInputFocused: FocusState<Bool>.Binding, sendAction: (() -> Void)? = nil,
         startVoiceAction: (() -> Void)? = nil, stopVoiceAction: (() -> Void)? = nil,
         toggleVoiceAction: (() -> Void)? = nil, cancelVoiceAction: (() -> Void)? = nil,
         caretRequest: UUID? = nil, floating: Bool = false, placeholderKey: String? = nil, surfaceColors: [Color]? = nil) {
        self.model = model; self.canSend = canSend; self.canUseVoiceInput = canUseVoiceInput
        self.isInputFocused = isInputFocused; self.sendAction = sendAction
        self.startVoiceAction = startVoiceAction; self.stopVoiceAction = stopVoiceAction
        self.toggleVoiceAction = toggleVoiceAction; self.cancelVoiceAction = cancelVoiceAction
        self.caretRequest = caretRequest; self.floating = floating; self.placeholderKey = placeholderKey
        self.surfaceColors = surfaceColors
        _editorDraftValue = State(initialValue: model.askDJDraft)
    }

    private var composerSurfaceTint: Color {
        surfaceColors?[safe: 1] ?? surfaceColors?.first ?? Color(red: 0.22, green: 0.25, blue: 0.40)
    }

    private var editorDraft: Binding<String> {
        Binding(get: { editorDraftValue }, set: { value in
            editorDraftValue = value
            model.setAskDJDraftFromEditor(value)
        })
    }

    private func send() {
        isInputFocused.wrappedValue = false
        #if os(iOS)
        // The UIKit multiline editor can become first responder before SwiftUI focus updates.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        if let sendAction { sendAction() } else { model.sendAskDJText() }
    }

    @ViewBuilder private var placeholderView: some View {
        Text(localizedKey(model.language, placeholderKey ?? "ui.session.chat.placeholder"))
    }

    private var isExpanded: Bool {
        #if os(iOS)
        isNativeEditorFocused
        #else
        isInputFocused.wrappedValue
        #endif
    }
    private var composerLayout: AnyLayout {
        isExpanded
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SessionComposerContext(model: model)
        // AnyLayout keeps the same native editor mounted during focus changes,
        // preserving first responder, selection and the unsent draft.
        composerLayout {
            ZStack(alignment: isExpanded ? .topLeading : .leading) {
                if model.askDJDraft.isEmpty {
                    placeholderView
                        .foregroundStyle(.white.opacity(0.74))
                        .padding(.horizontal, 14)
                        .padding(.top, isExpanded ? 11 : 0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                #if os(iOS)
                AskDJPromptTextView(text: editorDraft, isInputFocused: isInputFocused,
                                    isEditing: $isNativeEditorFocused, replacementRevision: model.askDJDraftRevision, replacementText: model.askDJDraft)
                    .frame(minHeight: 44)
                #else
                TextField("", text: editorDraft, selection: $promptSelection, axis: .vertical)
                    .lineLimit(isExpanded ? 2...4 : 1...4)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Ask DJ")
                    .focused(isInputFocused)
                    .onChange(of: caretRequest) { _, request in
                        guard let request else { return }
                        let draft = model.askDJDraft
                        // Apply after the native editor's initial focus selection.
                        // Subsequent typing and deliberate text selection stay untouched.
                        DispatchQueue.main.async {
                            guard caretRequest == request, isInputFocused.wrappedValue, model.askDJDraft == draft else { return }
                            promptSelection = TextSelection(insertionPoint: model.askDJDraft.endIndex)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .onSubmit {
                        if canSend {
                            send()
                        }
                    }
                #endif
            }
            .accessibilityIdentifier("ask-dj-composer-input")
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            .background {
                if !isExpanded {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(reduceTransparency ? 0.12 : 0.06))
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.06, green: 0.43, blue: 1.00).opacity(0.08),
                                        Color(red: 0.84, green: 0.22, blue: 0.96).opacity(0.06)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(isExpanded ? 0 : 0.20), lineWidth: 1)
            }

            HStack(spacing: 10) {
            if isExpanded { Spacer(minLength: 0) }
            AskDJVoiceInputButton(model: model, isEnabled: canUseVoiceInput,
                                 startAction: startVoiceAction, stopAction: stopVoiceAction,
                                 toggleAction: toggleVoiceAction, cancelAction: cancelVoiceAction)

            Button {
                send()
            } label: {
                if model.isSendingAskDJText {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(djConnectAccent)
                }
            }
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .selected, shape: .icon, usesLiveGlass: false))
            .disabled(!canSend)
            .help(localizedKey(model.language, "ui.send"))
            .accessibilityLabel(localizedKey(model.language, "ui.send"))
            .accessibilityIdentifier("ask-dj-composer-send")
            }
            .fixedSize(horizontal: !isExpanded, vertical: false)
        }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isExpanded)
        .onChange(of: model.askDJDraftRevision) { _, _ in
            let value = model.askDJDraft
            if editorDraftValue != value { editorDraftValue = value }
        }
        .padding(.horizontal, floating ? 12 : djConnectScreenHorizontalPadding)
        .padding(.top, floating ? 12 : 18)
        #if os(macOS)
        .padding(.bottom, 12)
        #else
        .padding(.bottom, floating ? 12 : 18)
        #endif
        #if os(iOS)
        .background(AskDJOutsideTapDismissal(isInputFocused: isInputFocused))
        #endif
        .background {
            if floating {
                // Frost the content without the lens effect that magnifies text underneath.
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(composerSurfaceTint.opacity(reduceTransparency ? 1 : 0.14))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.24), lineWidth: 0.75)
                    }
            } else {
                #if os(macOS)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(reduceTransparency ? 1 : 0.85)
                    .ignoresSafeArea(.container, edges: .bottom)
                #else
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    .opacity(reduceTransparency ? 1 : 0.85)
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
                        .fill(Color(red: 0.08, green: 0.06, blue: 0.14).opacity(reduceTransparency ? 0.70 : 0.35))
                }
                #if os(macOS)
                .ignoresSafeArea(.container, edges: .bottom)
                #endif
                #endif
            }
        }
        .overlay(alignment: .top) {
            if !floating {
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
}

#if os(iOS)
/// Observe taps without putting a hit-testing layer over the conversation.
/// The window recognizer also covers empty space beside a narrow iPad composer.
private struct AskDJOutsideTapDismissal: UIViewRepresentable {
    var isInputFocused: FocusState<Bool>.Binding

    func makeUIView(context: Context) -> OutsideTapView {
        let view = OutsideTapView()
        view.isUserInteractionEnabled = false
        view.focus = isInputFocused
        return view
    }

    func updateUIView(_ view: OutsideTapView, context: Context) {
        view.focus = isInputFocused
    }

    static func dismantleUIView(_ view: OutsideTapView, coordinator: ()) {
        view.detach()
    }

    final class OutsideTapView: UIView, UIGestureRecognizerDelegate {
        var focus: FocusState<Bool>.Binding?
        private weak var observedWindow: UIWindow?
        private lazy var outsideTap: UITapGestureRecognizer = {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissInput))
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            return gesture
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            if let window {
                observedWindow = window
                window.addGestureRecognizer(outsideTap)
            }
        }

        func detach() {
            observedWindow?.removeGestureRecognizer(outsideTap)
            observedWindow = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let window,
                  !convert(bounds, to: window).contains(touch.location(in: window)),
                  let editor = firstResponder(in: window) as? UITextView,
                  convert(bounds, to: window).intersects(editor.convert(editor.bounds, to: window)) else { return false }
            // Leave fields and native controls in charge of their own focus.
            var target = touch.view
            while let view = target {
                if view is UIControl || view is UITextView { return false }
                target = view.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

        private func firstResponder(in view: UIView) -> UIView? {
            if view.isFirstResponder { return view }
            for child in view.subviews {
                if let responder = firstResponder(in: child) { return responder }
            }
            return nil
        }

        @objc private func dismissInput() {
            focus?.wrappedValue = false
            // The UIKit editor owns native focus; an unbound SwiftUI FocusState
            // alone does not reliably resign it after a background tap.
            observedWindow?.endEditing(true)
        }
    }
}

private struct AskDJPromptTextView: UIViewRepresentable {
    @Binding var text: String
    var isInputFocused: FocusState<Bool>.Binding
    @Binding var isEditing: Bool
    let replacementRevision: Int
    let replacementText: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.accessibilityLabel = "Ask DJ"
        textView.textColor = .white
        textView.tintColor = UIColor(djConnectAccent)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 11, left: 10, bottom: 11, right: 10)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Native typing owns the current text; only an explicit app replacement writes it back.
        if context.coordinator.lastReplacementRevision != replacementRevision {
            if textView.text != replacementText {
                textView.text = replacementText
                context.coordinator.moveCaretToEnd(in: textView)
            }
            context.coordinator.lastReplacementRevision = replacementRevision
        }

        let requestedFocus = isInputFocused.wrappedValue
        defer {
            context.coordinator.lastRequestedFocus = requestedFocus
        }

        if requestedFocus {
            if !textView.isFirstResponder {
                textView.becomeFirstResponder()
                context.coordinator.moveCaretToEnd(in: textView)
            }
        } else if textView.isFirstResponder, context.coordinator.lastRequestedFocus {
            textView.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 240
        let fittingSize = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let maximumHeight = max(104, (uiView.font?.lineHeight ?? 20) * 3 + uiView.textContainerInset.top + uiView.textContainerInset.bottom)
        let minimumHeight = isEditing
            ? max(44, (uiView.font?.lineHeight ?? 20) * 2 + uiView.textContainerInset.top + uiView.textContainerInset.bottom)
            : 44
        return CGSize(width: width, height: min(max(fittingSize.height, minimumHeight), maximumHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isInputFocused: isInputFocused, isEditing: $isEditing)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var isInputFocused: FocusState<Bool>.Binding
        @Binding var isEditing: Bool
        var lastRequestedFocus = false
        var lastReplacementRevision: Int?

        init(text: Binding<String>, isInputFocused: FocusState<Bool>.Binding, isEditing: Binding<Bool>) {
            _text = text
            self.isInputFocused = isInputFocused
            _isEditing = isEditing
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            setInputFocus(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            setInputFocus(false)
        }

        func moveCaretToEnd(in textView: UITextView) {
            let end = textView.endOfDocument
            textView.selectedTextRange = textView.textRange(from: end, to: end)
            textView.scrollRangeToVisible(NSRange(location: textView.text.utf16.count, length: 0))
        }

        private func setInputFocus(_ isFocused: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.isEditing != isFocused { self.isEditing = isFocused }
                if self.isInputFocused.wrappedValue != isFocused { self.isInputFocused.wrappedValue = isFocused }
            }
        }
    }
}
#endif

private struct AskDJVoiceInputButton: View {
    @ObservedObject var model: DJConnectAppModel
    let isEnabled: Bool
    var startAction: (() -> Void)? = nil
    var stopAction: (() -> Void)? = nil
    var toggleAction: (() -> Void)? = nil
    var cancelAction: (() -> Void)? = nil
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
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: isActive ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: isActive)
                }
            }
        }
        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: isActive ? .destructive : .secondary, shape: .icon))
        .disabled(!isEnabled && !isActive)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled, !isPressing else {
                        return
                    }
                    isPressing = true
                    DJConnectHaptics.impact()
                    if let startAction { startAction() } else { model.startVoiceRecording() }
                }
                .onEnded { _ in
                    guard isPressing else {
                        return
                    }
                    isPressing = false
                    DJConnectHaptics.selection()
                    stop()
                }
        )
        .onDisappear {
            isPressing = false
            if let cancelAction { cancelAction() } else { model.cancelVoiceRecording() }
        }
        .help(helpText)
        .accessibilityLabel(helpText)
        .accessibilityHint(localizedKey(model.language, model.isDemoMode ? "demo.session.voice_hint" : "ui.hold.to.record.a.voice.request.for.ask.dj"))
        .accessibilityIdentifier("ask-dj-composer-microphone")
        .accessibilityAction {
            DJConnectHaptics.impact()
            if let toggleAction { toggleAction() } else { model.toggleVoiceRecording() }
        }
    }

    private func stop() {
        if let stopAction { stopAction() } else { model.stopVoiceRecordingAndUpload() }
    }


    private var helpText: String {
        if model.isDemoMode { return localizedKey(model.language, "demo.session.voice_hint") }
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
    @State private var statusToast: DJConnectVisualNotice?
    @State private var isSearchVisible = false
    @State private var queueSearchText = ""
    @State private var selectedSearchResultIndex = 0
    @FocusState private var isSearchFocused: Bool
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }
    private var areQueueItemsDisabled: Bool {
        !canUsePlayback || model.isRefreshing || model.isLoadingQueue || model.loadingQueueItemIndex != nil
    }
    private var queueSearchQuery: String {
        queueSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var indexedQueueItems: [(index: Int, item: DJConnectQueueItem)] {
        Array(model.queueItems.enumerated()).map { (index: $0.offset, item: $0.element) }
    }
    private var filteredQueueItems: [(index: Int, item: DJConnectQueueItem)] {
        guard !queueSearchQuery.isEmpty else {
            return indexedQueueItems
        }
        return indexedQueueItems.filter { _, item in
            queueSearchMatches(item)
        }
    }
    private var queueSearchResultIDs: [String] {
        guard !queueSearchQuery.isEmpty else {
            return []
        }
        return filteredQueueItems.map(\.item.id)
    }
    private var activeQueueSearchResultID: String? {
        guard queueSearchResultIDs.indices.contains(selectedSearchResultIndex) else {
            return nil
        }
        return queueSearchResultIDs[selectedSearchResultIndex]
    }
    private var shouldShowFilteredEmptyQueueState: Bool {
        !queueSearchQuery.isEmpty && model.queueItems.isEmpty == false && filteredQueueItems.isEmpty
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
    private var canOpenQueueSearch: Bool {
        !shouldShowEmptyQueueState
    }
    private var queueSearchButtonForeground: Color {
        if isSearchVisible {
            return djConnectAccent
        }
        return canOpenQueueSearch ? .primary : .secondary
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 10) {
                    if isSearchVisible {
                        AskDJSearchBar(
                            language: model.language,
                            scopeName: localizedKey(model.language, "ui.queue.1b6dc1"),
                            text: $queueSearchText,
                            isFocused: $isSearchFocused,
                            resultCount: queueSearchResultIDs.count,
                            selectedIndex: selectedSearchResultIndex,
                            previousAction: { moveQueueSearchSelection(by: -1, proxy: proxy) },
                            nextAction: { moveQueueSearchSelection(by: 1, proxy: proxy) },
                            closeAction: { dismissQueueSearch() }
                        )
                        .padding(.horizontal, djConnectSearchContentHorizontalPadding)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    #if os(macOS)
                    queueScrollContent(proxy: proxy)
                    #else
                    List {
                        if shouldShowEmptyQueueState || shouldShowFilteredEmptyQueueState {
                            DJConnectEmptyState(
                                title: shouldShowFilteredEmptyQueueState
                                    ? localizedKey(model.language, "ui.no.search.results")
                                    : localizedKey(model.language, "ui.no.queue"),
                                systemImage: shouldShowFilteredEmptyQueueState ? "magnifyingglass" : "music.note.list"
                            )
                            .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(filteredQueueItems, id: \.item.id) { index, item in
                                Button {
                                    showStatusToast(localizedKey(model.language, "ui.track.is.starting"), systemImage: "play.fill")
                                    model.startQueueItem(item, at: index)
                                } label: {
                                    QueueItemRow(item: item, isLoading: model.loadingQueueItemIndex == index)
                                        .opacity(areQueueItemsDisabled || !model.canStartQueueItem(item) ? 0.45 : 1)
                                }
                                .buttonStyle(DJConnectMediaRowButtonStyle())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(djConnectListRowInsets)
                                .disabled(areQueueItemsDisabled || !model.canStartQueueItem(item))
                                .allowsHitTesting(!areQueueItemsDisabled && model.canStartQueueItem(item))
                                .accessibilityLabel(item.displayTitle)
                                .id(item.id)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.visible)
                    #endif
                }
                .onChange(of: queueSearchText) {
                    selectedSearchResultIndex = 0
                    scrollToActiveQueueSearchResult(proxy)
                }
                .onChange(of: queueSearchResultIDs) {
                    selectedSearchResultIndex = min(selectedSearchResultIndex, max(queueSearchResultIDs.count - 1, 0))
                    scrollToActiveQueueSearchResult(proxy)
                }
            }
            .refreshable {
                guard !model.isDemoMode, canUsePlayback else {
                    showStatusToast(localizedKey(model.language, "appModel.no.connection.to.home.assistant"), systemImage: "exclamationmark.triangle.fill")
                    return
                }
                await refreshQueueWithToast()
            }
            .navigationTitle(screenTitle(model.language, key: "Queue", isDemoMode: model.isDemoMode))
            .accessibilityIdentifier("screen-queue")
            .scrollContentBackgroundIfAvailable(.hidden)
            .background(DJConnectCanvasBackground())
            #if os(iOS)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            #else
            .contentMargins(.horizontal, djConnectScreenHorizontalPadding, for: .scrollContent)
            #endif
            .djStatusToastOverlay(statusToast, screenImage: "music.note.list")
            .toolbar {
                #if os(macOS)
                queueRefreshToolbar
                #endif
                ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                    Button {
                        toggleQueueSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(queueSearchButtonForeground)
                    }
                    .disabled(!isSearchVisible && !canOpenQueueSearch)
                    .help(isSearchVisible ? localizedKey(model.language, "ui.close.search") : localizedKey(model.language, "ui.search.queue"))
                    .accessibilityLabel(isSearchVisible ? localizedKey(model.language, "ui.close.search") : localizedKey(model.language, "ui.search.queue"))
                }
                #if os(iOS)
                queueRefreshToolbar
                #endif
                ConnectionStatusToolbar(model: model)
            }
            .task {
                guard model.canUsePlaybackFeatures else {
                    return
                }
                model.loadQueue()
            }
            .onChange(of: model.userNotice?.id) { _, _ in
                if let text = model.userNotice?.text {
                    showStatusToast(text, systemImage: "exclamationmark.triangle.fill")
                }
            }
        }
        .background(DJConnectCanvasBackground())
    }

    #if os(macOS)
    private func queueScrollContent(proxy: ScrollViewProxy) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 10) {
                if shouldShowEmptyQueueState || shouldShowFilteredEmptyQueueState {
                    DJConnectEmptyState(
                        title: shouldShowFilteredEmptyQueueState
                            ? localizedKey(model.language, "ui.no.search.results")
                            : localizedKey(model.language, "ui.no.queue"),
                        systemImage: shouldShowFilteredEmptyQueueState ? "magnifyingglass" : "music.note.list"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                } else {
                    ForEach(filteredQueueItems, id: \.item.id) { index, item in
                        Button {
                            showStatusToast(localizedKey(model.language, "ui.track.is.starting"), systemImage: "play.fill")
                            model.startQueueItem(item, at: index)
                        } label: {
                            QueueItemRow(item: item, isLoading: model.loadingQueueItemIndex == index)
                                .opacity(areQueueItemsDisabled || !model.canStartQueueItem(item) ? 0.45 : 1)
                        }
                        .buttonStyle(DJConnectMediaRowButtonStyle())
                        .disabled(areQueueItemsDisabled || !model.canStartQueueItem(item))
                        .allowsHitTesting(!areQueueItemsDisabled && model.canStartQueueItem(item))
                        .accessibilityLabel(item.displayTitle)
                        .id(item.id)
                    }
                }
            }
            .padding(.horizontal, djConnectScreenHorizontalPadding)
            .padding(.vertical, djConnectScreenVerticalPadding)
        }
    }
    #endif

    private func queueSearchMatches(_ item: DJConnectQueueItem) -> Bool {
        let searchable = [
            item.displayTitle,
            item.title,
            item.artist,
            item.album,
            item.displaySubtitle,
            item.uri
        ]
        return searchable.contains { value in
            value?.localizedCaseInsensitiveContains(queueSearchQuery) == true
        }
    }

    private func showQueueSearch() {
        guard canOpenQueueSearch else {
            return
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isSearchVisible = true
        }
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    @ToolbarContentBuilder private var queueRefreshToolbar: some ToolbarContent {
        ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
            Button {
                Task { await refreshQueueWithToast() }
            } label: {
                if model.isLoadingQueue {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.white)
                }
            }
            .disabled(model.isDemoMode || !canUsePlayback || model.isLoadingQueue)
            .tint(.white)
            .help(localizedKey(model.language, "ui.reload.queue"))
            .accessibilityLabel(localizedKey(model.language, "ui.reload.queue"))
        }
    }

    private func toggleQueueSearch() {
        if isSearchVisible {
            dismissQueueSearch()
        } else {
            showQueueSearch()
        }
    }

    private func dismissQueueSearch() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isSearchVisible = false
        }
        queueSearchText = ""
        selectedSearchResultIndex = 0
        isSearchFocused = false
    }

    private func moveQueueSearchSelection(by offset: Int, proxy: ScrollViewProxy) {
        guard !queueSearchResultIDs.isEmpty else {
            return
        }
        selectedSearchResultIndex = (selectedSearchResultIndex + offset + queueSearchResultIDs.count) % queueSearchResultIDs.count
        scrollToActiveQueueSearchResult(proxy)
    }

    private func scrollToActiveQueueSearchResult(_ proxy: ScrollViewProxy) {
        guard let activeQueueSearchResultID else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(activeQueueSearchResultID, anchor: .center)
            }
        }
    }

    private func refreshQueueWithToast() async {
        guard !model.isDemoMode, canUsePlayback else {
            showStatusToast(localizedKey(model.language, "appModel.no.connection.to.home.assistant"), systemImage: "exclamationmark.triangle.fill")
            return
        }
        let didRefresh = await model.refreshQueue()
        showStatusToast(
            didRefresh ? localizedKey(model.language, "appModel.queue.updated") : localizedKey(model.language, "appModel.queue.update.failed"),
            systemImage: "music.note.list"
        )
    }

    private func showStatusToast(_ text: String, systemImage: String) {
        let notice = DJConnectVisualNotice(text: text, systemImage: systemImage)
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = notice
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast?.id == notice.id else {
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
    @State private var statusToast: DJConnectVisualNotice?
    @State private var isSearchVisible = false
    @State private var playlistSearchText = ""
    @State private var selectedSearchResultIndex = 0
    @FocusState private var isSearchFocused: Bool
    private var canUsePlayback: Bool { model.canUsePlaybackFeatures }
    private var arePlaylistItemsDisabled: Bool {
        !canUsePlayback || model.isRefreshing || model.isLoadingPlaylists || model.loadingPlaylistID != nil
    }
    private var playlistSearchQuery: String {
        playlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var filteredPlaylistItems: [DJConnectPlaylist] {
        guard !playlistSearchQuery.isEmpty else {
            return model.playlistItems
        }
        return model.playlistItems.filter(playlistSearchMatches)
    }
    private var playlistSearchResultIDs: [String] {
        guard !playlistSearchQuery.isEmpty else {
            return []
        }
        return filteredPlaylistItems.map(\.id)
    }
    private var activePlaylistSearchResultID: String? {
        guard playlistSearchResultIDs.indices.contains(selectedSearchResultIndex) else {
            return nil
        }
        return playlistSearchResultIDs[selectedSearchResultIndex]
    }
    private var shouldShowFilteredEmptyPlaylistState: Bool {
        !playlistSearchQuery.isEmpty && model.playlistItems.isEmpty == false && filteredPlaylistItems.isEmpty
    }
    private var canOpenPlaylistSearch: Bool {
        !model.playlistItems.isEmpty
    }
    private var playlistSearchButtonForeground: Color {
        if isSearchVisible {
            return djConnectAccent
        }
        return canOpenPlaylistSearch ? .primary : .secondary
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 10) {
                    if isSearchVisible {
                        AskDJSearchBar(
                            language: model.language,
                            scopeName: localizedKey(model.language, "ui.playlists.5e5f2e"),
                            text: $playlistSearchText,
                            isFocused: $isSearchFocused,
                            resultCount: playlistSearchResultIDs.count,
                            selectedIndex: selectedSearchResultIndex,
                            previousAction: { movePlaylistSearchSelection(by: -1, proxy: proxy) },
                            nextAction: { movePlaylistSearchSelection(by: 1, proxy: proxy) },
                            closeAction: { dismissPlaylistSearch() }
                        )
                        .padding(.horizontal, djConnectSearchContentHorizontalPadding)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    #if os(macOS)
                    playlistsScrollContent(proxy: proxy)
                    #else
                    List {
                        if model.playlistItems.isEmpty || shouldShowFilteredEmptyPlaylistState {
                            DJConnectEmptyState(
                                title: shouldShowFilteredEmptyPlaylistState
                                    ? localizedKey(model.language, "ui.no.search.results")
                                    : localizedKey(model.language, "ui.no.playlists"),
                                systemImage: shouldShowFilteredEmptyPlaylistState ? "magnifyingglass" : "rectangle.stack"
                            )
                            .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(filteredPlaylistItems) { playlist in
                                Button {
                                    showStatusToast(localizedKey(model.language, "ui.playlist.is.starting"), systemImage: "play.fill")
                                    model.startPlaylist(playlist)
                                } label: {
                                    PlaylistRow(playlist: playlist, isLoading: model.loadingPlaylistID == playlist.id)
                                        .opacity(arePlaylistItemsDisabled ? 0.45 : 1)
                                }
                                .buttonStyle(DJConnectMediaRowButtonStyle())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(djConnectListRowInsets)
                                .disabled(arePlaylistItemsDisabled)
                                .allowsHitTesting(!arePlaylistItemsDisabled)
                                .id(playlist.id)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.visible)
                    #endif
                }
                .onChange(of: playlistSearchText) {
                    selectedSearchResultIndex = 0
                    scrollToActivePlaylistSearchResult(proxy)
                }
                .onChange(of: playlistSearchResultIDs) {
                    selectedSearchResultIndex = min(selectedSearchResultIndex, max(playlistSearchResultIDs.count - 1, 0))
                    scrollToActivePlaylistSearchResult(proxy)
                }
            }
            .refreshable {
                guard !model.isDemoMode, canUsePlayback else {
                    showStatusToast(localizedKey(model.language, "appModel.no.connection.to.home.assistant"), systemImage: "exclamationmark.triangle.fill")
                    return
                }
                await refreshPlaylistsWithToast()
            }
            .navigationTitle(screenTitle(model.language, key: "ui.playlists", isDemoMode: model.isDemoMode))
            .accessibilityIdentifier("screen-playlists")
            .scrollContentBackgroundIfAvailable(.hidden)
            .background(DJConnectCanvasBackground())
            #if os(iOS)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            #else
            .contentMargins(.horizontal, djConnectScreenHorizontalPadding, for: .scrollContent)
            #endif
            .djStatusToastOverlay(statusToast, screenImage: "rectangle.stack")
            .toolbar {
                #if os(macOS)
                playlistRefreshToolbar
                #endif
                ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
                    Button {
                        togglePlaylistSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(playlistSearchButtonForeground)
                    }
                    .disabled(!isSearchVisible && !canOpenPlaylistSearch)
                    .help(isSearchVisible ? localizedKey(model.language, "ui.close.search") : localizedKey(model.language, "ui.search.playlists"))
                    .accessibilityLabel(isSearchVisible ? localizedKey(model.language, "ui.close.search") : localizedKey(model.language, "ui.search.playlists"))
                }
                #if os(iOS)
                playlistRefreshToolbar
                #endif
                ConnectionStatusToolbar(model: model)
            }
            .task {
                guard model.canUsePlaybackFeatures else {
                    return
                }
                model.loadPlaylists()
            }
            .onChange(of: model.userNotice?.id) { _, _ in
                if let text = model.userNotice?.text {
                    showStatusToast(text, systemImage: "exclamationmark.triangle.fill")
                }
            }
        }
    }

    #if os(macOS)
    private func playlistsScrollContent(proxy: ScrollViewProxy) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 10) {
                if model.playlistItems.isEmpty || shouldShowFilteredEmptyPlaylistState {
                    DJConnectEmptyState(
                        title: shouldShowFilteredEmptyPlaylistState
                            ? localizedKey(model.language, "ui.no.search.results")
                            : localizedKey(model.language, "ui.no.playlists"),
                        systemImage: shouldShowFilteredEmptyPlaylistState ? "magnifyingglass" : "rectangle.stack"
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                } else {
                    ForEach(filteredPlaylistItems) { playlist in
                        Button {
                            showStatusToast(localizedKey(model.language, "ui.playlist.is.starting"), systemImage: "play.fill")
                            model.startPlaylist(playlist)
                        } label: {
                            PlaylistRow(playlist: playlist, isLoading: model.loadingPlaylistID == playlist.id)
                                .opacity(arePlaylistItemsDisabled ? 0.45 : 1)
                        }
                        .buttonStyle(DJConnectMediaRowButtonStyle())
                        .disabled(arePlaylistItemsDisabled)
                        .allowsHitTesting(!arePlaylistItemsDisabled)
                        .id(playlist.id)
                    }
                }
            }
            .padding(.horizontal, djConnectScreenHorizontalPadding)
            .padding(.vertical, djConnectScreenVerticalPadding)
        }
    }
    #endif

    private func playlistSearchMatches(_ playlist: DJConnectPlaylist) -> Bool {
        let searchable = [
            playlist.name,
            playlist.subtitle,
            playlist.uri
        ]
        return searchable.contains { value in
            value?.localizedCaseInsensitiveContains(playlistSearchQuery) == true
        }
    }

    private func showPlaylistSearch() {
        guard canOpenPlaylistSearch else {
            return
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isSearchVisible = true
        }
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    @ToolbarContentBuilder private var playlistRefreshToolbar: some ToolbarContent {
        ToolbarItem(placement: djConnectRefreshToolbarPlacement) {
            Button {
                Task { await refreshPlaylistsWithToast() }
            } label: {
                if model.isLoadingPlaylists {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.white)
                }
            }
            .disabled(model.isDemoMode || !canUsePlayback || model.isLoadingPlaylists)
            .tint(.white)
            .help(localizedKey(model.language, "ui.reload.playlists"))
            .accessibilityLabel(localizedKey(model.language, "ui.reload.playlists"))
        }
    }

    private func togglePlaylistSearch() {
        if isSearchVisible {
            dismissPlaylistSearch()
        } else {
            showPlaylistSearch()
        }
    }

    private func dismissPlaylistSearch() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isSearchVisible = false
        }
        playlistSearchText = ""
        selectedSearchResultIndex = 0
        isSearchFocused = false
    }

    private func movePlaylistSearchSelection(by offset: Int, proxy: ScrollViewProxy) {
        guard !playlistSearchResultIDs.isEmpty else {
            return
        }
        selectedSearchResultIndex = (selectedSearchResultIndex + offset + playlistSearchResultIDs.count) % playlistSearchResultIDs.count
        scrollToActivePlaylistSearchResult(proxy)
    }

    private func scrollToActivePlaylistSearchResult(_ proxy: ScrollViewProxy) {
        guard let activePlaylistSearchResultID else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(activePlaylistSearchResultID, anchor: .center)
            }
        }
    }

    private func refreshPlaylistsWithToast() async {
        guard !model.isDemoMode, canUsePlayback else {
            showStatusToast(localizedKey(model.language, "appModel.no.connection.to.home.assistant"), systemImage: "exclamationmark.triangle.fill")
            return
        }
        let didRefresh = await model.refreshPlaylists()
        showStatusToast(
            didRefresh ? localizedKey(model.language, "appModel.playlists.updated") : localizedKey(model.language, "appModel.playlists.update.failed"),
            systemImage: "rectangle.stack"
        )
    }

    private func showStatusToast(_ text: String, systemImage: String) {
        let notice = DJConnectVisualNotice(text: text, systemImage: systemImage)
        withAnimation(.easeOut(duration: 0.18)) {
            statusToast = notice
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard statusToast?.id == notice.id else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                statusToast = nil
            }
        }
    }
}

struct DJConnectEmptyState: View {
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
            .allowsHitTesting(false)
    }
}

extension View {
    func djStatusToastOverlay(_ toast: DJConnectVisualNotice?, screenImage: String? = nil) -> some View {
        overlay(alignment: .top) {
            if let toast {
                StatusToast(text: toast.text, systemImage: screenImage ?? toast.systemImage)
                    .padding(.top, 12)
                    .padding(.horizontal, djConnectScreenHorizontalPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    func djStatusToastOverlay(text: String?, systemImage: String = "play.fill") -> some View {
        overlay(alignment: .top) {
            if let text {
                StatusToast(text: text, systemImage: systemImage)
                    .padding(.top, 12)
                    .padding(.horizontal, djConnectScreenHorizontalPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

private struct DJConnectUserNoticeToastModifier: ViewModifier {
    @ObservedObject var model: DJConnectAppModel
    @State private var toast: DJConnectUserNotice?
    let screenImage: String

    func body(content: Content) -> some View {
        content
            .djStatusToastOverlay(text: toast?.text, systemImage: toast?.systemImage ?? screenImage)
            .onChange(of: model.userNotice?.id) { _, _ in
                guard let notice = model.userNotice else {
                    return
                }
                show(notice)
            }
    }

    private func show(_ notice: DJConnectUserNotice) {
        withAnimation(.easeOut(duration: 0.18)) {
            toast = notice
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard toast?.id == notice.id else {
                return
            }
            withAnimation(.easeIn(duration: 0.18)) {
                toast = nil
            }
        }
    }
}

private extension View {
    func djUserNoticeToast(model: DJConnectAppModel, screenImage: String) -> some View {
        modifier(DJConnectUserNoticeToastModifier(model: model, screenImage: screenImage))
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
                    .foregroundStyle(.white)
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
        .modifier(DJConnectMediaRowSurface())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(playlist.name)
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

private struct DJConnectRedTrashLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon.foregroundStyle(.red)
            configuration.title
        }
    }
}

private struct GameHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private func gameHeightReader(_ component: String) -> some View {
    GeometryReader { proxy in
        Color.clear.preference(key: GameHeightPreferenceKey.self, value: [component: proxy.size.height])
    }
}

private struct GamesView: View {
    let language: String
    let isDemoMode: Bool
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
    @State private var selectedGame = LocalGameMode.pong
    @State private var measuredGameHeights: [String: CGFloat] = [:]

    private func contentMaxWidth(for size: CGSize) -> CGFloat {
        #if os(macOS)
        size.width >= 1_000 ? djConnectMacDetailContentMaxWidth : djConnectContentMaxWidth
        #else
        horizontalSizeClass == .regular && size.width > size.height ? 1_320 : djConnectContentMaxWidth
        #endif
    }

    private func pickerMaxWidth(for size: CGSize) -> CGFloat {
        min(contentMaxWidth(for: size), 760)
    }

    private func gameCanvasMaxHeight(for size: CGSize) -> CGFloat? {
        #if os(macOS)
        let pickerHeight = measuredGameHeights["picker"] ?? 60
        let surfaceHeight = measuredGameHeights["surface"] ?? 0
        let canvasHeight = measuredGameHeights["canvas"] ?? 0
        let chromeHeight = surfaceHeight > 0 ? max(0, surfaceHeight - canvasHeight) : 180
        // Measure the controls and localized help rather than estimating from width.
        // Small windows retain scrolling so the game remains usable.
        return max(170, size.height - pickerHeight - chromeHeight - 18 - 2 * djConnectScreenVerticalPadding - 2)
        #else
        guard horizontalSizeClass == .regular, size.width > size.height else {
            return nil
        }
        return min(560, max(360, size.height * 0.42))
        #endif
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
                            .background(gameHeightReader("picker"))

                        LocalGameSurface(
                            game: selectedGame,
                            language: language,
                            maxCanvasHeight: gameCanvasMaxHeight(for: proxy.size)
                        )
                            .frame(maxWidth: .infinity, alignment: .top)
                            .background(gameHeightReader("surface"))
                    }
                    .djConnectScreenPadding()
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(DJConnectCanvasBackground())
            }
            .navigationTitle(localizedKey(language, "ui.games"))
            .accessibilityIdentifier("screen-games")
            .onPreferenceChange(GameHeightPreferenceKey.self) { measuredGameHeights = $0 }
        }
        .id("games-\(isDemoMode)-\(language)")
    }
}

private struct GameModePicker: View {
    @Binding var selection: LocalGameMode
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }

    private var columns: [GridItem] {
        if horizontalSizeClass == .compact {
            return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 2)
        }
        return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: LocalGameMode.allCases.count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
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

                }
                .djConnectButtonStyle(DJConnectButtonStyle(emphasis: selection == game ? .selected : .tertiary, shape: .segmented, expands: true))
                .contentShape(DJConnectCardAppearance.segmentedItemShape)
                .accessibilityAddTraits(selection == game ? [.isSelected] : [])
            }
        }
        .padding(DJConnectCardAppearance.segmentedContentInset)
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
            in: DJConnectCardAppearance.shape
        )
        .overlay {
            DJConnectCardAppearance.shape
                .stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
        }
    }
}

private struct LocalGameSurface: View {
    let game: LocalGameMode
    let language: String
    var maxCanvasHeight: CGFloat? = nil
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
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
    @State private var pellets: Set<Int> = Set(0..<36)
    @State private var flashUntil = Date.distantPast
    @State private var isPlaying = false
    @FocusState private var isGameFocused: Bool
    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    private let gameAspectRatio: CGFloat = 320.0 / 170.0
    private var isCompactLayout: Bool { horizontalSizeClass == .compact }

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

    private var gameAccessibilityValue: String {
        [
            "game=\(game.rawValue)",
            "playing=\(isPlaying)",
            "score=\(score)",
            "paddle_y=\(Int(paddleY.rounded()))",
            "ship_x=\(Int(shipX.rounded()))",
            "plane_y=\(Int(planeY.rounded()))",
            "pacman_x=\(Int(pacmanX.rounded()))",
            "pacman_y=\(Int(pacmanY.rounded()))",
            "pacman_dx=\(Int(pacmanDX.rounded()))",
            "pacman_dy=\(Int(pacmanDY.rounded()))",
            "asteroid_bullet=\(asteroidBulletActive)",
            "fly_shot=\(flyShotActive)"
        ].joined(separator: ";")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(game.title, systemImage: gameIcon)
                    .font(.title2.bold())
                    .foregroundStyle(game.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Spacer()
                Text("\(localizedKey(language, "ui.score")) \(score)")
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text("\(localizedKey(language, "ui.high")) \(highScore)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
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
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary))
                    .controlSize(.large)
                }
            }
            .aspectRatio(gameAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: maxCanvasHeight)
            .background(gameHeightReader("canvas"))
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("games-surface")
            .accessibilityLabel(game.title)
            .accessibilityValue(gameAccessibilityValue)
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

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("games-state")
                .accessibilityLabel("Game state")
                .accessibilityValue(gameAccessibilityValue)
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
            in: DJConnectCardAppearance.shape
        )
        .overlay {
            DJConnectCardAppearance.shape
                .stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth)
        }
        .focusable(true)
        .focusEffectDisabled()
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
            .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
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
            .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
            .controlSize(.large)
        }
    }

    private func controlColumns(count: Int) -> [GridItem] {
        let compactCount = min(count, 2)
        let columnCount = isCompactLayout ? compactCount : count
        return Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10), count: columnCount)
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

    private var pacmanColumnCount: Int { 9 }
    private var pacmanRowCount: Int { 4 }
    private var pacmanPelletCount: Int { pacmanColumnCount * pacmanRowCount }
    private var pacmanPelletStartX: CGFloat { 48 }
    private var pacmanPelletStartY: CGFloat { 52 }
    private var pacmanPelletSpacing: CGFloat { 28 }
    private var pacmanMinX: CGFloat { pacmanPelletStartX }
    private var pacmanMaxX: CGFloat { pacmanPelletStartX + CGFloat(pacmanColumnCount - 1) * pacmanPelletSpacing }
    private var pacmanMinY: CGFloat { pacmanPelletStartY - 8 }
    private var pacmanMaxY: CGFloat { pacmanPelletStartY + CGFloat(pacmanRowCount - 1) * pacmanPelletSpacing + 8 }
    private var pacmanPowerPellets: Set<Int> {
        [
            0,
            pacmanColumnCount - 1,
            pacmanPelletCount - pacmanColumnCount,
            pacmanPelletCount - 1
        ]
    }
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
                let column = pellet % pacmanColumnCount
                let row = pellet / pacmanColumnCount
                let isPowerPellet = pacmanPowerPellets.contains(pellet)
                let pelletSize: CGFloat = isPowerPellet ? 8 : 4
                context.fill(
                    Path(ellipseIn: rect(pacmanPelletStartX + CGFloat(column) * pacmanPelletSpacing - pelletSize / 2, pacmanPelletStartY + CGFloat(row) * pacmanPelletSpacing - pelletSize / 2, pelletSize, pelletSize)),
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
            updatePong()
        case .asteroids:
            updateAsteroids()
        case .fly:
            updateFly()
        case .pacman:
            updatePacman()
        }
    }

    private func updatePong() {
        if paddleMissTicks > 0 {
            paddleMissTicks -= 1
            if paddleMissTicks == 0 { resetPaddleBall() }
            return
        }
        if paddleHitTicks > 0 { paddleHitTicks -= 1 }
        if ballWallBounceTicks > 0 { ballWallBounceTicks -= 1 }
        ballX += ballVX
        ballY += ballVY
        if ballY <= 42 || ballY >= 156 { bouncePongBallVertically() }
        if ballX >= 306 { bouncePongBallFromRightWall() }
        if ballX <= 30 { resolvePongPaddleContact() }
    }

    private func bouncePongBallVertically() {
        ballVY *= -1
        ballWallBounceTicks = 8
        DJConnectHaptics.selection()
        DJConnectGameSounds.play(.bounce)
    }

    private func bouncePongBallFromRightWall() {
        ballVX = -abs(ballVX)
        ballWallBounceTicks = 8
        DJConnectHaptics.selection()
        DJConnectGameSounds.play(.bounce)
    }

    private func resolvePongPaddleContact() {
        if ballY >= paddleY - 20 && ballY <= paddleY + 20 {
            ballVX = abs(ballVX)
            paddleHitTicks = 10
            DJConnectHaptics.impact()
            DJConnectGameSounds.play(.hit)
            setScore(score + 1)
            return
        }
        flash()
        DJConnectHaptics.error()
        DJConnectGameSounds.play(.gameOver)
        setScore(0)
        paddleMissTicks = 24
        ballVX = 0
        ballVY = 0
    }

    private func updateAsteroids() {
        if asteroidExplosionTicks > 0 { asteroidExplosionTicks -= 1 }
        meteorStarPhase = (meteorStarPhase + 0.08).truncatingRemainder(dividingBy: CGFloat.pi * 2)
        asteroidY += asteroidSpeed + CGFloat(min(score / 8, 3)) * 0.18
        updateAsteroidBullet()
        if asteroidY > 150 { finishAsteroidRun() }
    }

    private func updateAsteroidBullet() {
        guard asteroidBulletActive else { return }
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

    private func finishAsteroidRun() {
        flash()
        DJConnectHaptics.warning()
        DJConnectGameSounds.play(.gameOver)
        setScore(0)
        resetAsteroid()
    }

    private func updateFly() {
        if advanceSkyCrash() { return }
        if skyObstacleExplosionTicks > 0 { skyObstacleExplosionTicks -= 1 }
        spaceScroll = (spaceScroll + 4 + CGFloat(min(score / 8, 4))).truncatingRemainder(dividingBy: 302)
        obstacleX -= 4 + CGFloat(min(score / 6, 4))
        updateFlyShot()
        if obstacleX < 24 {
            setScore(score + 1)
            resetObstacle()
        }
        if obstacleX < 70 && obstacleX > 28 && abs(planeY - obstacleY) < 30 { crashFly() }
    }

    private func advanceSkyCrash() -> Bool {
        guard skyCrashTicks > 0 else { return false }
        skyCrashTicks -= 1
        if skyCrashTicks == 0 { resetObstacle() }
        return true
    }

    private func updateFlyShot() {
        guard flyShotActive else { return }
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

    private func crashFly() {
        flash()
        startSkyCrash()
        DJConnectHaptics.error()
        DJConnectGameSounds.play(.crash)
        setScore(0)
    }

    private func updatePacman() {
        if advancePacmanDeath() { return }
        movePacmanAndGhost()
        collectPacmanPellet()
        resetPacmanRoundIfNeeded()
        resolvePacmanGhostCollision()
    }

    private func advancePacmanDeath() -> Bool {
        guard pacmanDeathTicks > 0 else { return false }
        pacmanDeathTicks -= 1
        if pacmanDeathTicks == 0 { resetPacman() }
        return true
    }

    private func movePacmanAndGhost() {
        pacmanX = min(max(pacmanX + pacmanDX * 4, pacmanMinX), pacmanMaxX)
        pacmanY = min(max(pacmanY + pacmanDY * 4, pacmanMinY), pacmanMaxY)
        if ghostVulnerableTicks > 0 { ghostVulnerableTicks -= 1 }
        let ghostStep: CGFloat = (isGhostVulnerable ? 0.62 : 0.88) + CGFloat(min(score / 12, 3)) * 0.20
        if abs(ghostX - pacmanX) > 2 { ghostX += ghostX < pacmanX ? ghostStep : -ghostStep }
        if abs(ghostY - pacmanY) > 2 { ghostY += ghostY < pacmanY ? ghostStep : -ghostStep }
    }

    private func collectPacmanPellet() {
        for pellet in pellets {
            let column = pellet % pacmanColumnCount
            let row = pellet / pacmanColumnCount
            let pelletX = pacmanPelletStartX + CGFloat(column) * pacmanPelletSpacing
            let pelletY = pacmanPelletStartY + CGFloat(row) * pacmanPelletSpacing
            guard abs(pelletX - pacmanX) < 10 && abs(pelletY - pacmanY) < 10 else { continue }
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
            return
        }
    }

    private func resetPacmanRoundIfNeeded() {
        guard pellets.isEmpty else { return }
        pellets = Set(0..<pacmanPelletCount)
        ghostX = 250
        ghostY = 86
        ghostVulnerableTicks = 0
    }

    private func resolvePacmanGhostCollision() {
        guard abs(ghostX - pacmanX) < 14 && abs(ghostY - pacmanY) < 14 else { return }
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
        pellets = Set(0..<pacmanPelletCount)
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
    var requestedSection: DJConnectSection? = nil
    @State private var destinationSelection: DJConnectSection?
    var returnToNowPlaying: () -> Void
    @State private var showingFeedback = false
    @State private var showingPlayerQueue = false

    var body: some View {
        moreList
        .onAppear { routeRequestedSection() }
        .onChange(of: requestedSection) { routeRequestedSection() }
        .sheet(isPresented: $showingPlayerQueue) { QueueView(model: model) }
        .sheet(isPresented: $showingFeedback) {
            FeedbackPromptView(model: model)
        }
    }

    private var moreList: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    MoreNavigationRow(title: "Ask DJ", systemImage: "bubble.left.and.bubble.right") { destinationSelection = .askDJ }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.session.history.title"), systemImage: "clock.arrow.circlepath") { destinationSelection = .savedSessions }
                    MoreNavigationRow(title: "Music DNA", systemImage: "heart") { destinationSelection = .musicDNA }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.queue"), systemImage: "music.note.list") { destinationSelection = .queue }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.playlists"), systemImage: "rectangle.stack") { destinationSelection = .playlists }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.games"), systemImage: "gamecontroller") { destinationSelection = .games }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.settings"), systemImage: "gearshape") { destinationSelection = .settings }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.logs"), systemImage: "doc.text.magnifyingglass") { destinationSelection = .logs }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.about"), systemImage: "info.circle") { destinationSelection = .about }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.legal"), systemImage: "doc.text") { destinationSelection = .legal }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.privacy"), systemImage: "hand.raised") { destinationSelection = .privacy }
                    MoreNavigationRow(title: localizedKey(model.language, "ui.share.feedback"), systemImage: "bubble.left.and.bubble.right") { showingFeedback = true }
                }
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, djConnectScreenHorizontalPadding)
                .padding(.vertical, djConnectScreenVerticalPadding)
            }
            .background(DJConnectCanvasBackground())
            .navigationTitle(screenTitle(model.language, key: "More", isDemoMode: model.isDemoMode))
            .navigationDestination(item: $destinationSelection) { destination($0) }
        }
    }
    private func routeRequestedSection() {
        guard let requestedSection else { return }
        destinationSelection = requestedSection
    }

    @ViewBuilder private func destination(_ section: DJConnectSection) -> some View {
        switch section {
        case .nowPlaying: NowPlayingView(model: model) { showingPlayerQueue = true }
        case .askDJ: AskDJView(model: model, embedsNavigationStack: false) {
            model.performHomeScreenAction(.trackInsight)
            model.openTrackInsight()
        }
        case .queue: QueueView(model: model)
        case .savedSessions: SavedSessionsView(model: model, embedsNavigationStack: false)
        case .playlists: PlaylistsView(model: model)
        case .musicDNA: MusicDNAView(model: model)
        case .games: GamesView(language: model.language, isDemoMode: model.isDemoMode)
        case .settings: SettingsView(model: model, returnToNowPlaying: returnToNowPlaying)
        case .logs: LogsView(model: model)
        case .about: AboutView(model: model)
        case .legal: LegalNoticesView(language: model.language)
        case .privacy: PrivacyView(language: model.language)
        default: EmptyView()
        }
    }

}

private struct MoreNavigationRow: View {
    let title: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(djConnectAccent)
                    .frame(width: 44, height: 44)
                    .background(djConnectAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .djSessionFrostedSurface(cornerRadius: 24)
        }
        .djConnectPlainButtonStyle()
        .tint(djConnectAccent)
    }
}

private struct MusicDNAJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum MusicDNAExportStatus: Equatable {
    case idle
    case exporting
    case ready
    case saved
    case failed(String)
}

private enum MusicDNAImportStatus: Equatable {
    case ready
    case uploading
    case uploaded
    case failed(String)
}

private enum SettingsExportSheet: String, Identifiable {
    case askDJHistory
    case musicDNA

    var id: String { rawValue }
}

private struct AskDJHistoryExportSheet: View {
    var language: String
    var filename: String
    var status: MusicDNAExportStatus
    var saveAction: () -> Void
    var closeAction: () -> Void

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 18) {
                AboutBanner()
                statusIcon

                VStack(alignment: .leading, spacing: 10) {
                    Text(localizedKey(language, "ui.export.ask.dj.history"))
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(localizedKey(language, "ui.ask.dj.history.export.description"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedKey(language, "ui.filename"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.54))
                    Text(filename)
                        .font(.callout.monospaced().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if case let .failed(message) = status {
                    Label(message, systemImage: "xmark.octagon")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                } else if status == .exporting {
                    Label(localizedKey(language, "ui.ask.dj.history.exporting"), systemImage: "arrow.down.circle")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                } else if status == .saved {
                    Label(localizedKey(language, "ui.ask.dj.history.export.saved"), systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        saveAction()
                    } label: {
                        Label(localizedKey(language, "ui.save.json"), systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                    .controlSize(.large)
                    .disabled(!(status == .ready || status == .saved))

                    if status == .saved {
                        Button {
                            closeAction()
                        } label: {
                            Text(localizedKey(language, "ui.done"))
                                .frame(maxWidth: .infinity)
                        }
                        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .tertiary, expands: true))
                        .controlSize(.large)
                    } else {
                        DJConnectNotNowLinkButton(language: language) {
                            closeAction()
                        }
                    }
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620, minHeight: 420, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 50, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(status == .saved ? AnyShapeStyle(.green) : AnyShapeStyle(djConnectIconGradient))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var systemImage: String {
        switch status {
        case .idle, .ready:
            return "bubble.left.and.bubble.right"
        case .exporting:
            return "arrow.down.circle"
        case .saved:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }
}

private struct MusicDNAExportSheet: View {
    var language: String
    var filename: String
    var status: MusicDNAExportStatus
    var saveAction: () -> Void
    var closeAction: () -> Void

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 18) {
                AboutBanner()
                statusIcon

                VStack(alignment: .leading, spacing: 10) {
                    Text(localizedKey(language, "ui.music.dna.export"))
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(localizedKey(language, "ui.music.dna.export.description"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedKey(language, "ui.filename"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.54))
                    Text(filename)
                        .font(.callout.monospaced().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if case let .failed(message) = status {
                    Label(message, systemImage: "xmark.octagon")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                } else if status == .exporting {
                    Label(localizedKey(language, "ui.music.dna.exporting"), systemImage: "arrow.down.circle")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                } else if status == .saved {
                    Label(localizedKey(language, "ui.music.dna.export.saved"), systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        saveAction()
                    } label: {
                        Label(localizedKey(language, "ui.save.json"), systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                    .controlSize(.large)
                    .disabled(!canSave)

                    if status == .saved {
                        Button {
                            closeAction()
                        } label: {
                            Text(localizedKey(language, "ui.done"))
                                .frame(maxWidth: .infinity)
                        }
                        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .tertiary, expands: true))
                        .controlSize(.large)
                    } else {
                        DJConnectNotNowLinkButton(language: language) {
                            closeAction()
                        }
                    }
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 520, maxWidth: 620, minHeight: 420, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 50, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(status == .saved ? AnyShapeStyle(.green) : AnyShapeStyle(djConnectIconGradient))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var systemImage: String {
        switch status {
        case .idle, .ready:
            return "heart"
        case .exporting:
            return "arrow.down.circle"
        case .saved:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var canSave: Bool {
        status == .ready || status == .saved
    }
}

private struct MusicDNAImportSheet: View {
    @ObservedObject var model: DJConnectAppModel
    var preview: DJConnectMusicDNAImportPreview
    var canUpload: Bool
    var status: MusicDNAImportStatus
    var uploadAction: () -> Void
    var closeAction: () -> Void

    private var profile: DJConnectMusicDNAProfile {
        preview.profile.profile
    }

    private var updatedAt: Date? {
        preview.profile.updatedAt ?? profile.updatedAt ?? preview.exportedAt
    }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            VStack(alignment: .leading, spacing: 18) {
                AboutBanner()
                statusIcon

                VStack(alignment: .leading, spacing: 10) {
                    Text(localizedKey(model.language, "ui.music.dna.import"))
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(statusText)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MusicDNAStatPill(title: localizedKey(model.language, "ui.tracks"), value: statValue(profile.trackCount))
                    MusicDNAStatPill(title: localizedKey(model.language, "ui.artists"), value: statValue(profile.artistCount))
                    MusicDNAStatPill(title: localizedKey(model.language, "ui.genres"), value: statValue(profile.genreCount))
                    MusicDNAStatPill(title: localizedKey(model.language, "ui.generation"), value: statValue(preview.profile.generation))
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let updatedAt {
                        Label("\(localizedKey(model.language, "ui.updated")): \(formattedDate(updatedAt))", systemImage: "clock")
                    }
                    if let exportedAt = preview.exportedAt {
                        Label("\(localizedKey(model.language, "ui.exported")): \(formattedDate(exportedAt))", systemImage: "square.and.arrow.up")
                    }
                    if let client = preview.exportedByClientType {
                        Label(client, systemImage: "iphone.and.arrow.forward")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

                if case let .failed(message) = status {
                    Label(message, systemImage: "xmark.octagon")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.94))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        uploadAction()
                    } label: {
                        if status == .uploading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(localizedKey(model.language, "ui.upload.to.home.assistant"), systemImage: "arrow.up.circle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                    .controlSize(.large)
                    .disabled(!canUpload || status == .uploading || status == .uploaded)

                    Button {
                        closeAction()
                    } label: {
                        Text(localizedKey(model.language, status == .uploaded ? "ui.done" : "ui.cancel"))
                            .frame(maxWidth: .infinity)
                    }
                    .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .tertiary, expands: true))
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(minWidth: 360, idealWidth: 560, maxWidth: 660, minHeight: 520, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        let systemImage: String = {
            switch status {
            case .ready:
                return "doc.text.magnifyingglass"
            case .uploading:
                return "arrow.up.circle"
            case .uploaded:
                return "checkmark.circle.fill"
            case .failed:
                return "xmark.octagon.fill"
            }
        }()
        Image(systemName: systemImage)
            .font(.system(size: 50, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(statusColor)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var statusColor: AnyShapeStyle {
        switch status {
        case .ready, .uploading:
            return AnyShapeStyle(djConnectIconGradient)
        case .uploaded:
            return AnyShapeStyle(.green)
        case .failed:
            return AnyShapeStyle(.red)
        }
    }

    private var statusText: String {
        switch status {
        case .ready:
            return canUpload
                ? localizedKey(model.language, "ui.music.dna.import.ready.description")
                : localizedKey(model.language, "ui.music.dna.import.requires.connection")
        case .uploading:
            return localizedKey(model.language, "ui.music.dna.import.uploading")
        case .uploaded:
            return localizedKey(model.language, "ui.music.dna.import.uploaded")
        case .failed:
            return localizedKey(model.language, "ui.music.dna.import.failed")
        }
    }

    private func statValue(_ value: Int?) -> String {
        guard let value else {
            return "-"
        }
        return "\(value)"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct MusicDNAStatPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.54))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: DJConnectCardAppearance.shape)
    }
}

struct SettingsView: View {
    @ObservedObject var model: DJConnectAppModel
    var returnToNowPlaying: () -> Void = {}
    @Environment(\.openURL) private var openURL
    @State private var isShowingResetPairingConfirmation = false
    @State private var isShowingMusicDNADisableConfirmation = false
    @State private var isShowingMusicDNAClearConfirmation = false
    @State private var askDJHistoryExportDocument: MusicDNAJSONDocument?
    @State private var askDJHistoryExportFilename = "djconnect-ask-dj-history.json"
    @State private var askDJHistoryExportStatus: MusicDNAExportStatus = .idle
    @State private var activeExportSheet: SettingsExportSheet?
    @State private var isShowingMusicDNAFileImporter = false
    @State private var musicDNAExportDocument: MusicDNAJSONDocument?
    @State private var musicDNAExportFilename = "DJConnect-Music-DNA.json"
    @State private var musicDNAExportStatus: MusicDNAExportStatus = .idle
    @State private var isShowingSettingsFileExporter = false
    @State private var settingsFileExporterSheet: SettingsExportSheet?
    @State private var settingsFileExporterDocument = MusicDNAJSONDocument()
    @State private var settingsFileExporterFilename = "DJConnect-export.json"
    @State private var musicDNAImportPreview: DJConnectMusicDNAImportPreview?
    @State private var musicDNAImportStatus: MusicDNAImportStatus = .ready

    private var musicDNAEnabled: Bool {
        model.musicDNAProfileResponse?.enabled == true
    }

    private var canUseMusicDNAImport: Bool {
        musicDNAEnabled && !model.isDemoMode && model.pairingStatus == .paired && model.isConnected
    }

    private var canUseMusicDNAExport: Bool {
        musicDNAEnabled && !model.isDemoMode && model.pairingStatus == .paired && model.isConnected
    }

    private var hasAskDJHistoryMessages: Bool {
        !model.askDJMessages.isEmpty
    }

    private var canUseAskDJHistoryExport: Bool {
        hasAskDJHistoryMessages && !model.isDemoMode && model.pairingStatus == .paired && model.isConnected
    }

    private func djAnnouncementOutputTitle(_ output: DJAnnouncementOutput) -> String {
        switch output {
        case .clientDevice:
            return "Alleen dit apparaat"
        case .both:
            return "Dit apparaat + Home Assistant speaker"
        case .haSpeaker:
            return "Alleen Home Assistant speaker"
        case .textOnly:
            return "Alleen tekst"
        }
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

    private var canShowAutomaticTransportStatus: Bool {
        !model.isDemoMode && model.pairingStatus == .paired
    }

    private var connectionTransportTitle: String {
        if model.fastPathDiagnostics.websocketConnected {
            return localizedKey(model.language, "ui.fast.local.link.websocket")
        }
        return localizedKey(model.language, "ui.normal.link.http")
    }

    private var connectionTransportColor: Color {
        model.fastPathDiagnostics.websocketConnected ? .green : .secondary
    }

    private func prepareAskDJHistoryExport() {
        guard canUseAskDJHistoryExport else {
            askDJHistoryExportFilename = model.askDJHistoryExportFilename()
            askDJHistoryExportDocument = nil
            askDJHistoryExportStatus = .failed(localizedKey(model.language, "appModel.no.connection.to.home.assistant"))
            activeExportSheet = .askDJHistory
            return
        }
        askDJHistoryExportFilename = model.askDJHistoryExportFilename()
        askDJHistoryExportDocument = nil
        askDJHistoryExportStatus = .exporting
        activeExportSheet = .askDJHistory
        Task {
            do {
                let data = try await model.exportAskDJHistoryData()
                askDJHistoryExportDocument = MusicDNAJSONDocument(data: data)
                askDJHistoryExportStatus = .ready
            } catch {
                askDJHistoryExportDocument = nil
                askDJHistoryExportStatus = .failed(askDJHistoryExportErrorText(error))
            }
        }
    }

    private func prepareMusicDNAExport() {
        guard canUseMusicDNAExport else {
            musicDNAExportFilename = model.musicDNAExportFilename()
            musicDNAExportDocument = nil
            musicDNAExportStatus = .failed(localizedKey(model.language, "appModel.no.connection.to.home.assistant"))
            activeExportSheet = .musicDNA
            return
        }
        musicDNAExportFilename = model.musicDNAExportFilename()
        musicDNAExportDocument = nil
        musicDNAExportStatus = .exporting
        activeExportSheet = .musicDNA
        Task {
            do {
                let data = try await model.exportMusicDNAProfileData()
                musicDNAExportDocument = MusicDNAJSONDocument(data: data)
                musicDNAExportStatus = .ready
            } catch {
                musicDNAExportDocument = nil
                musicDNAExportStatus = .failed(musicDNATransferErrorText(error))
            }
        }
    }

    private func presentAskDJHistoryFileExporter() {
        guard let document = askDJHistoryExportDocument else {
            return
        }
        presentSettingsFileExporter(
            sheet: .askDJHistory,
            document: document,
            filename: askDJHistoryExportFilename
        )
    }

    private func presentMusicDNAFileExporter() {
        guard let document = musicDNAExportDocument else {
            return
        }
        presentSettingsFileExporter(
            sheet: .musicDNA,
            document: document,
            filename: musicDNAExportFilename
        )
    }

    private func presentSettingsFileExporter(
        sheet: SettingsExportSheet,
        document: MusicDNAJSONDocument,
        filename: String
    ) {
        settingsFileExporterSheet = sheet
        settingsFileExporterDocument = document
        settingsFileExporterFilename = filename
        activeExportSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isShowingSettingsFileExporter = true
        }
    }

    private func handleSettingsFileExportResult(_ result: Result<URL, Error>) {
        let sheet = settingsFileExporterSheet
        settingsFileExporterSheet = nil
        switch (sheet, result) {
        case (.askDJHistory, .success):
            askDJHistoryExportStatus = .saved
        case (.askDJHistory, let .failure(error)):
            askDJHistoryExportStatus = .failed(error.localizedDescription)
        case (.musicDNA, .success):
            musicDNAExportStatus = .saved
        case (.musicDNA, let .failure(error)):
            musicDNAExportStatus = .failed(error.localizedDescription)
        case (nil, .success):
            break
        case (nil, let .failure(error)):
            musicDNAExportStatus = .failed(error.localizedDescription)
        }
    }

    private func presentMusicDNAFileImporter() {
        guard canUseMusicDNAImport else {
            musicDNAImportStatus = .failed(localizedKey(model.language, "appModel.no.connection.to.home.assistant"))
            return
        }
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = localizedKey(model.language, "ui.import")
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            handleMusicDNAImportSelection(.success([url]))
        }
        #else
        isShowingMusicDNAFileImporter = true
        #endif
    }

    private func handleMusicDNAImportSelection(_ result: Result<[URL], Error>) {
        guard canUseMusicDNAImport else {
            musicDNAImportStatus = .failed(localizedKey(model.language, "appModel.no.connection.to.home.assistant"))
            return
        }
        do {
            guard let url = try result.get().first else {
                return
            }
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            musicDNAImportPreview = try model.previewMusicDNAImport(data: data)
            musicDNAImportStatus = .ready
        } catch {
            musicDNAImportPreview = nil
            musicDNAImportStatus = .failed(musicDNATransferErrorText(error))
        }
    }

    private func uploadMusicDNAImport(_ preview: DJConnectMusicDNAImportPreview) {
        guard canUseMusicDNAImport else {
            musicDNAImportStatus = .failed(localizedKey(model.language, "appModel.no.connection.to.home.assistant"))
            return
        }
        musicDNAImportStatus = .uploading
        Task {
            do {
                try await model.uploadMusicDNAImport(preview)
                musicDNAImportStatus = .uploaded
            } catch {
                musicDNAImportStatus = .failed(musicDNATransferErrorText(error))
            }
        }
    }

    private func musicDNATransferErrorText(_ error: Error) -> String {
        if let transferError = error as? DJConnectMusicDNATransferError {
            switch transferError {
            case .noProfileAvailable:
                return localizedKey(model.language, "ui.no.music.dna.profile.yet")
            case .invalidDocument:
                return localizedKey(model.language, "ui.music.dna.import.invalid.file")
            case .homeAssistantUnavailable:
                return localizedKey(model.language, "appModel.no.connection.to.home.assistant")
            }
        }
        if let djError = error as? DJConnectError {
            switch djError {
            case let .authStale(_, message),
                 let .backendUnavailable(message),
                 let .routeMissing(message),
                 let .notConfigured(message),
                 let .server(_, message),
                 let .pairingFailed(message),
                 let .trackInsightUnavailable(_, message),
                 let .profile(_, _, message):
                let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? localizedKey(model.language, "ui.music.dna.import.rejected") : trimmed
            case let .network(message), let .invalidConfiguration(message):
                return message
            case .missingToken:
                return localizedKey(model.language, "appModel.missing.djconnect.bearer.token.reset.pairing.to.set.up")
            case .invalidResponse, .decodingFailed, .versionMismatch, .clientTypeMismatch, .payloadTooLarge:
                return localizedKey(model.language, "ui.music.dna.import.rejected")
            }
        }
        return error.localizedDescription
    }

    private func askDJHistoryExportErrorText(_ error: Error) -> String {
        if let transferError = error as? DJConnectMusicDNATransferError {
            switch transferError {
            case .homeAssistantUnavailable:
                return localizedKey(model.language, "appModel.no.connection.to.home.assistant")
            case .noProfileAvailable, .invalidDocument:
                return localizedKey(model.language, "ui.ask.dj.history.export.failed")
            }
        }
        if let djError = error as? DJConnectError {
            switch djError {
            case let .authStale(_, message),
                 let .notConfigured(message),
                 let .server(_, message),
                 let .pairingFailed(message),
                 let .profile(_, _, message):
                let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? localizedKey(model.language, "ui.ask.dj.history.export.failed") : trimmed
            case let .network(message), let .invalidConfiguration(message):
                return message
            case .missingToken:
                return localizedKey(model.language, "appModel.missing.djconnect.bearer.token.reset.pairing.to.set.up")
            case .routeMissing, .backendUnavailable, .invalidResponse, .decodingFailed, .versionMismatch, .clientTypeMismatch, .trackInsightUnavailable, .payloadTooLarge:
                return Self.localizedAskDJHistoryExportFallback(language: model.language)
            }
        }
        return error.localizedDescription
    }

    private static func localizedAskDJHistoryExportFallback(language: String) -> String {
        localizedKey(language, "ui.ask.dj.history.export.failed")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                SettingsContentContainer {
                SettingsGlassSection(title: localizedKey(model.language, "ui.app")) {
                    LabeledContent(localizedKey(model.language, "ui.app.language")) {
                        Picker(localizedKey(model.language, "ui.app.language"), selection: $model.appLanguageSelectionCode) {
                            Text(localizedKey(model.language, "ui.system.language")).tag("")
                            ForEach(DJConnectLocalization.supportedLanguageCodes, id: \.self) { code in
                                Text(DJConnectLocalization.nativeLanguageName(for: code)).tag(code)
                            }
                        }
                        .labelsHidden()
                    }
                    .djMusicDNASettingsListRow()
                    if model.isDemoMode {
                        LabeledContent(localizedKey(model.language, "ui.demo.mode")) {
                            Button(localizedKey(model.language, "ui.stop.demo.mode"), role: .destructive) {
                                returnToNowPlaying()
                                model.stopDemoMode()
                            }
                            .accessibilityIdentifier("settings-stop-demo")
                        }
                        .djMusicDNASettingsListRow()
                    }
                    if !model.isDemoMode {
                        LabeledContent(localizedKey(model.language, "ui.pairing")) {
                            Button(role: .destructive) {
                                isShowingResetPairingConfirmation = true
                            } label: {
                                Text(localizedKey(model.language, "ui.pair.app.again"))
                            }
                        }
                        .djMusicDNASettingsListRow()
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
                    .djMusicDNASettingsListRow()
                    wakeWordPhraseField(model)
                        .djMusicDNASettingsListRow()
                    LabeledContent(localizedKey(model.language, "ui.wakeword.status")) {
                        Text(wakeWordStatusText(model))
                            .foregroundStyle(.secondary)
                    }
                    .djMusicDNASettingsListRow()
                    LabeledContent(localizedKey(model.language, "ui.log.level")) {
                        Picker(localizedKey(model.language, "ui.log.level"), selection: $model.logLevel) {
                            Text("Debug").tag("debug")
                            Text("Info").tag("info")
                            Text(localizedKey(model.language, "ui.warning")).tag("warning")
                            Text(localizedKey(model.language, "ui.error")).tag("error")
                        }
                        .labelsHidden()
                    }
                    .djMusicDNASettingsListRow()
                }
                .djSettingsListRowBackground()

                SettingsGlassSection(title: "DJ-aankondigingen") {
                    LabeledContent("Output") {
                        Picker("Output", selection: $model.djAnnouncementOutput) {
                            ForEach(DJAnnouncementOutput.allCases, id: \.self) { output in
                                Text(djAnnouncementOutputTitle(output))
                                    .tag(output)
                                    .disabled(!model.isDJAnnouncementOutputSelectable(output))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .djCompactSettingsListRow()

                    LabeledContent("Home Assistant speaker") {
                        Text(model.djAnnouncementCapabilities.isSpeakerConfigured ? model.djAnnouncementSpeakerDisplayName : "Niet geconfigureerd")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .djCompactSettingsListRow()

                    if !model.djAnnouncementCapabilities.isSpeakerConfigured {
                        Text("Configureer een speaker in de DJConnect opties in Home Assistant om de Home Assistant speaker-modi te gebruiken.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .djCompactSettingsListRow()
                    }

                    LabeledContent(localizedKey(model.language, "ui.chat.history")) {
                        Button {
                            prepareAskDJHistoryExport()
                        } label: {
                            Text(localizedKey(model.language, "ui.export"))
                                .foregroundStyle(djConnectAccent)
                        }
                        .foregroundStyle(djConnectAccent)
                        .tint(djConnectAccent)
                        .disabled(!canUseAskDJHistoryExport)
                    }
                    .djCompactSettingsListRow()
                }
                .djSettingsListRowBackground()

                SettingsGlassSection(title: "Music DNA") {
                    LabeledContent(localizedKey(model.language, "ui.how.it.works")) {
                        Text(musicDNAHowItWorksText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .djMusicDNASettingsListRow()

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
                    .djMusicDNASettingsListRow()

                    if musicDNAEnabled {
                        LabeledContent(localizedKey(model.language, "ui.listening.profile")) {
                            Button(role: .destructive) {
                                isShowingMusicDNAClearConfirmation = true
                            } label: {
                                Text(localizedKey(model.language, "ui.clear"))
                            }
                            .disabled(model.isUpdatingMusicDNA || (!model.isDemoMode && model.pairingStatus != .paired))
                        }
                        .djMusicDNASettingsListRow()
                    }

                    LabeledContent(localizedKey(model.language, "ui.listening.profile")) {
                        Button {
                            prepareMusicDNAExport()
                        } label: {
                            Text(localizedKey(model.language, "ui.export"))
                                .foregroundStyle(djConnectAccent)
                        }
                        .foregroundStyle(djConnectAccent)
                        .tint(djConnectAccent)
                        .disabled(!canUseMusicDNAExport)
                    }
                    .djMusicDNASettingsListRow()

                    LabeledContent(localizedKey(model.language, "ui.listening.profile")) {
                        Button {
                            presentMusicDNAFileImporter()
                        } label: {
                            Text(localizedKey(model.language, "ui.import"))
                                .foregroundStyle(djConnectAccent)
                        }
                        .foregroundStyle(djConnectAccent)
                        .tint(djConnectAccent)
                        .disabled(!canUseMusicDNAImport)
                    }
                    .djMusicDNASettingsListRow()
                }
                .djSettingsListRowBackground()

                if canShowAutomaticTransportStatus {
                    SettingsGlassSection(title: localizedKey(model.language, "ui.connection")) {
                        Text(localizedKey(model.language, "ui.transport.automatic"))
                            .font(.caption).foregroundStyle(.secondary)
                            .djCompactSettingsListRow()

                        LabeledContent(localizedKey(model.language, "ui.connection.speed")) {
                            Text(connectionTransportTitle)
                                .foregroundStyle(connectionTransportColor)
                        }
                        .djCompactSettingsListRow()
                    }
                    .djSettingsListRowBackground()
                }

                SettingsGlassSection(title: localizedKey(model.language, "ui.permissions")) {
                    PermissionStatusRow(
                        title: localizedKey(model.language, "ui.notifications"),
                        detail: localizedKey(model.language, "ui.needed.for.server.push.notifications.when.ask.dj.answers"),
                        status: model.notificationPermissionStatus,
                        language: model.language
                    )
                    .accessibilityIdentifier("settings-permission-notifications")
                    .djCompactSettingsListRow()
                    PermissionStatusRow(
                        title: localizedKey(model.language, "ui.microphone"),
                        detail: localizedKey(model.language, "ui.needed.for.push.to.talk.voice.requests"),
                        status: model.microphonePermissionStatus,
                        language: model.language
                    )
                    .accessibilityIdentifier("settings-permission-microphone")
                    .djCompactSettingsListRow()
                    PermissionStatusRow(
                        title: localizedKey(model.language, "ui.speech.recognition"),
                        detail: localizedKey(model.language, "ui.needed.for.the.foreground.wake.phrase"),
                        status: model.speechPermissionStatus,
                        language: model.language
                    )
                    .accessibilityIdentifier("settings-permission-speech")
                    .djCompactSettingsListRow()
                    if model.notificationPermissionStatus != .granted {
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
                        .djCompactSettingsListRow()
                    }
                }
                .djSettingsListRowBackground()

                }
                .scrollContentBackgroundIfAvailable(.hidden)
                .background(.clear)
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: 28)
                        .allowsHitTesting(false)
                }
                .djTransparentMacListBackground()
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(localizedKey(model.language, "ui.settings"))
            .accessibilityIdentifier("screen-settings")
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
            .sheet(item: $activeExportSheet) { sheet in
                Group {
                    switch sheet {
                    case .askDJHistory:
                        AskDJHistoryExportSheet(
                            language: model.language,
                            filename: askDJHistoryExportFilename,
                            status: askDJHistoryExportStatus,
                            saveAction: { presentAskDJHistoryFileExporter() },
                            closeAction: { activeExportSheet = nil }
                        )
                    case .musicDNA:
                        MusicDNAExportSheet(
                            language: model.language,
                            filename: musicDNAExportFilename,
                            status: musicDNAExportStatus,
                            saveAction: { presentMusicDNAFileExporter() },
                            closeAction: { activeExportSheet = nil }
                        )
                    }
                }
                .presentationBackground {
                    DJConnectCanvasBackground()
                }
            }
            .sheet(item: $musicDNAImportPreview) { preview in
                MusicDNAImportSheet(
                    model: model,
                    preview: preview,
                    canUpload: canUseMusicDNAImport,
                    status: musicDNAImportStatus,
                    uploadAction: { uploadMusicDNAImport(preview) },
                    closeAction: {
                        musicDNAImportPreview = nil
                        musicDNAImportStatus = .ready
                    }
                )
                .presentationBackground {
                    DJConnectCanvasBackground()
                }
            }
            .fileExporter(
                isPresented: $isShowingSettingsFileExporter,
                document: settingsFileExporterDocument,
                contentType: .json,
                defaultFilename: settingsFileExporterFilename
            ) { result in
                handleSettingsFileExportResult(result)
            }
            .fileImporter(
                isPresented: $isShowingMusicDNAFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleMusicDNAImportSelection(result)
            }
            .task {
                model.refreshPermissionStatuses()
                model.startPairingWait()
            }
        }
        .djConnectButtonStyle(DJConnectButtonStyle())
        .tint(.white)
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

    private var displayedLogLines: [DJConnectDiagnosticLogLine] {
        Array(model.diagnosticLogLines.reversed())
    }

    private var logSearchResultIDs: [UUID] {
        let query = logSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }
        return displayedLogLines.compactMap { line in
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

    private func numberedLogText(_ text: String, index: Int) -> String {
        let digits = logLineNumberDigits(total: displayedLogLines.count)
        let rawNumber = String(index + 1)
        let number = String(repeating: " ", count: max(0, digits - rawNumber.count)) + rawNumber
        return "\(number)  \(text)"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if displayedLogLines.isEmpty {
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
                                    ForEach(Array(displayedLogLines.enumerated()), id: \.element.id) { index, line in
                                        LogSearchText(
                                            text: numberedLogText(line.text, index: index),
                                            lineNumberWidth: logLineNumberDigits(total: displayedLogLines.count),
                                            highlight: logSearchText,
                                            isSearchResult: !logSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        )
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.88))
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(line.id)
                                        .accessibilityIdentifier("log-line-" + line.id.uuidString)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                            }
                            .coordinateSpace(name: "LogsScrollView")
                            .scrollIndicators(.visible)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .djTransparentMacListBackground()
                            .onAppear {
                                scrollLogsToTop(proxy)
                            }
                            .onChange(of: displayedLogLines.first?.id) {
                                if logSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    scrollLogsToTop(proxy)
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
            .padding(.vertical, 12)
            .djSessionFrostedSurface()
            .padding(.horizontal, 20)
            #if !os(macOS)
            .padding(.vertical, 16)
            #endif
            .background(DJConnectCanvasBackground())
            .navigationTitle(localizedKey(model.language, "ui.logs"))
            .accessibilityIdentifier("screen-logs")
            #if os(macOS)
            .djConnectMacDetailContent()
            #endif
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .navigation) {
                    logToolbarButtons
                }
                ToolbarItem(placement: .confirmationAction) {
                    clearLogToolbarButton
                }
                #else
                ToolbarItemGroup(placement: .topBarTrailing) {
                    logToolbarButtons
                    clearLogToolbarButton
                }
                #endif
            }
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

                }
            }
            .djStatusToastOverlay(text: statusToast, systemImage: "doc.on.doc")
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

    @ViewBuilder
    private var logToolbarButtons: some View {
        Button {
            toggleLogSearch()
        } label: {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isSearchVisible ? djConnectAccent : .primary)
        }
        .help(logSearchButtonTitle)
        .accessibilityLabel(logSearchButtonTitle)
        .disabled(displayedLogLines.isEmpty)

        Button {
            copyText(model.diagnosticExportText())
            showStatusToast(localizedKey(model.language, "ui.logs.copied.to.clipboard"))
        } label: {
            Image(systemName: "doc.on.doc")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white)
        }
        .tint(.white)
        .help(localizedKey(model.language, "ui.copy.logs"))
        .accessibilityLabel(localizedKey(model.language, "ui.copy.logs"))
        .disabled(displayedLogLines.isEmpty)

    }

    private var clearLogToolbarButton: some View {
        Button(role: .destructive) {
            showingClearConfirmation = true
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(.red)
        }
        .help(localizedKey(model.language, "ui.clear.logs"))
        .accessibilityLabel(localizedKey(model.language, "ui.clear.logs"))
        .disabled(displayedLogLines.isEmpty)
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
        guard !displayedLogLines.isEmpty else {
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

    private func scrollLogsToTop(_ proxy: ScrollViewProxy) {
        guard let firstLogID = displayedLogLines.first?.id else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(firstLogID, anchor: .top)
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
    @State private var showingPushStatus = false
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
    private let websiteURL = URL(string: "https://djconnect.dev")!

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? .infinity : 760
    }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AboutBanner()

                    SettingsSection(title: localizedKey(model.language, "ui.app"), showsDivider: false) {
                        AboutStackedRow(label: localizedKey(model.language, "ui.version")) {
                            SelectableValue("\(model.version) (\(DJConnectApplicationVersion.buildVersion))")
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
                        AboutStackedRow(label: localizedKey(model.language, "ui.updates")) {
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    model.checkForUpdates()
                                } label: {
                                    HStack(spacing: 8) {
                                        if model.isCheckingForUpdates {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                        }
                                        Text(localizedKey(model.language, "ui.check.for.updates"))
                                    }
                                }
                                .disabled(model.isCheckingForUpdates)
                                .djConnectLilacButton()

                                if let message = model.updateCheckMessage, !message.isEmpty {
                                    Text(message)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.device.id")) {
                            SelectableValue(model.identity.deviceID)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .djSessionFrostedSurface()

                    SettingsSection(title: localizedKey(model.language, "ui.connection"), showsDivider: false) {
                        AboutStackedRow(label: localizedKey(model.language, "ui.connection.status")) {
                            Label(localizedKey(model.language, model.connectionPresentation.key),
                                  systemImage: model.connectionPresentation.icon)
                                .foregroundStyle(model.connectionPresentation.color)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.connection.type")) {
                            SelectableValue(connectionModeTitle, foregroundStyle: connectionModeColor)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.connection.transport")) {
                            SelectableValue(connectionTransportTitle, foregroundStyle: connectionTransportColor)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.connection.address.active")) {
                            SelectableValue(activeConnectionAddress)
                        }
                        AboutStackedRow(label: localizedKey(model.language, "ui.push.notifications")) {
                            Button { showingPushStatus.toggle() } label: {
                                Label(pushNotificationStatusTitle, systemImage: "info.circle")
                                    .foregroundStyle(pushNotificationStatusColor)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("push-registration-status")
                            .popover(isPresented: $showingPushStatus) {
                                PushRegistrationDetailsView(model: model)
                                    .presentationCompactAdaptation(.popover)
                            }
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
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .djSessionFrostedSurface()

                    SettingsSection(title: localizedKey(model.language, "ui.notices"), showsDivider: false) {
                        AboutStackedRow(label: "Copyright") {
                            SelectableValue("2026 Peter van Tol")
                        }
                        AboutStackedRow(label: "GitHub") {
                            Link(destination: URL(string: "https://github.com/pcvantol/djconnect")!) {
                                Label("pcvantol/djconnect", systemImage: "arrow.up.right.square")
                                    .font(.body)
                                    .foregroundStyle(.white)
                            }
                            .djConnectLilacButton()
                            .accessibilityIdentifier("about-djconnect-github")
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .djSessionFrostedSurface()
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
        .accessibilityIdentifier("screen-about")
        .sheet(isPresented: $model.isShowingUpdateNotes) {
            UpdateNotesView(model: model)
        }
    }

    private var actualConnectionMode: DJConnectHAConnectionMode {
        guard model.pairingStatus == .paired, model.isConnected, !model.isOfflineModeActive else { return .offline }
        switch model.hybridConnectionDiagnostics?.state {
        case .localReady, .localDegraded: return .local
        case .remoteReady: return .remote
        case .recoveringOffline, .terminalAuthorityWithdrawn: return .offline
        case nil: return model.haConnectionMode
        }
    }

    private var connectionModeTitle: String {
        if model.isDemoMode { return localizedKey(model.language, "ui.local.demo.mode") }
        switch actualConnectionMode {
        case .local: return localizedKey(model.language, "ui.local.home.assistant")
        case .remote: return localizedKey(model.language, "ui.remote.home.assistant")
        case .offline: return localizedKey(model.language, "ui.not.active")
        }
    }

    private var connectionModeColor: Color { model.connectionPresentation.color }

    private var activeConnectionAddress: String {
        guard !model.isDemoMode, actualConnectionMode != .offline else {
            return localizedKey(model.language, "ui.not.active")
        }
        // Hybrid reports only an authenticated, installation-qualified origin.
        // Legacy routes do not provide that proof; do not call a configured URL active.
        guard let origin = model.hybridConnectionDiagnostics?.activeOrigin,
              var components = URLComponents(url: origin, resolvingAgainstBaseURL: false) else {
            return localizedKey(model.language, "ui.connection.address.unconfirmed")
        }
        components.user = nil; components.password = nil; components.query = nil; components.fragment = nil
        return components.url?.absoluteString ?? localizedKey(model.language, "ui.not.active")
    }

    private var connectionTransportTitle: String {
        if model.isDemoMode { return localizedKey(model.language, "ui.demo") }
        guard actualConnectionMode != .offline else { return localizedKey(model.language, "ui.not.active") }
        if let hybrid = model.hybridConnectionDiagnostics {
            return hybrid.transportDisplayName ?? localizedKey(model.language, "ui.not.active")
        }
        return model.fastPathDiagnostics.websocketConnected ? "WebSocket" : localizedKey(model.language, "ui.connection.address.unconfirmed")
    }

    private var connectionTransportColor: Color {
        actualConnectionMode == .offline ? .secondary : model.connectionPresentation.color
    }

    private var pushNotificationStatusTitle: String {
        let status = model.pushNotificationStatus
        switch status.state {
        case .registered:
            if let environment = status.environment {
                return "\(localizedKey(model.language, "ui.registered")) (\(pushEnvironmentTitle(environment)))"
            }
            return localizedKey(model.language, "ui.registered")
        case .unavailable:
            return localizedKey(model.language, "ui.not.supported")
        case .actionNeeded:
            return localizedKey(model.language, status.titleKey)
        case .inactive:
            return localizedKey(model.language, "ui.not.active")
        }
    }

    private var pushNotificationStatusColor: Color {
        switch model.pushNotificationStatus.state {
        case .registered:
            return .green
        case .unavailable:
            return .secondary
        case .actionNeeded:
            return .orange
        case .inactive:
            return .secondary
        }
    }

    private func pushEnvironmentTitle(_ environment: DJConnectPushEnvironment) -> String {
        switch environment {
        case .sandbox:
            return localizedKey(model.language, "ui.sandbox")
        case .production:
            return localizedKey(model.language, "ui.production")
        }
    }
}

private struct LegalNoticesView: View {
    let language: String
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? .infinity : 760
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        AboutBanner()

                        SettingsSection(title: localizedKey(language, "ui.legal"), showsDivider: false) {
                            SelectableValue(localizedKey(language, "ui.djconnect.is.not.affiliated.with.endorsed.by.or.sponsored.by"))
                            SelectableValue(localizedKey(language, "ui.spotify.is.a.trademark.of.spotify.ab.home.assistant.is"))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .djSessionFrostedSurface()

                        SettingsSection(title: "OSS", showsDivider: false) {
                            SelectableValue(localizedKey(language, "ui.djconnect.uses.apple.platform.frameworks.and.swift.package.manager.third"))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .djSessionFrostedSurface()
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
            .accessibilityIdentifier("screen-legal")
        }
    }
}

private struct PrivacyView: View {
    let language: String
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? .infinity : 760
    }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AboutBanner()
                    SettingsSection(title: localizedKey(language, "ui.privacy"), showsDivider: false) {
                        SelectableValue(localizedKey(language, "ui.djconnect.does.not.collect.sell.or.process.personal.data.in"))
                        SelectableValue(localizedKey(language, "ui.device.tokens.are.stored.locally.in.the.app.s.private"))
                        SelectableValue(localizedKey(language, "ui.push.notifications.are.only.used.for.djconnect.notifications.such.as"))
                        SelectableValue(localizedKey(language, "ui.music.playback.and.voice.requests.are.handled.through.your.own"))
                        SelectableValue(localizedKey(language, "ui.ai.and.assist.answers.can.be.incorrect.and.depend.on"))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .djSessionFrostedSurface()
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
        .accessibilityIdentifier("screen-privacy")
    }
}

private struct AskDJFeedbackPromptView: View {
    @ObservedObject var model: DJConnectAppModel
    let message: DJConnectAskDJMessage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }
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

    private var noteEditorHeight: CGFloat {
        isCompact ? 78 : 96
    }

    private var issueBodyEditorHeight: CGFloat {
        isCompact ? 150 : 220
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
                            .frame(height: noteEditorHeight)
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
                            .frame(height: issueBodyEditorHeight)
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
                .padding(.vertical, isCompact ? 18 : 28)
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
            .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
            .controlSize(.large)

            DJConnectNotNowLinkButton(language: model.language) {
                dismiss()
            }
        }
    }

    private func refreshIssueBody() {
        issueBody = model.askDJFeedbackIssueBody(for: message, userNote: userNote)
    }
}

#if DEBUG && os(iOS) && targetEnvironment(simulator)
#Preview("Ask DJ Feedback - Compact") {
    let model = DJConnectAppModel(startBackgroundTasks: false)
    model.language = "nl"
    let message = DJConnectAskDJMessage(
        role: .dj,
        text: "Ik koos dit nummer omdat de warme synths, de groove en de late-night energie goed aansluiten."
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
                VStack(spacing: 16) {
                    DJConnectHeroGlyph(systemImage: "bubble.left.and.bubble.right")
                    Text(localizedKey(model.language, "ui.share.feedback"))
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(localizedKey(model.language, "ui.open.a.github.issue.with.redacted.app.context.nothing.is"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

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
                        .djConnectButtonStyle(DJConnectButtonStyle(emphasis: .primary, expands: true))
                        .controlSize(.large)

                        DJConnectNotNowLinkButton(language: model.language, key: "ui.not.now.b1e535") {
                            dismiss()
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .djSessionFrostedSurface()
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
        DJConnectLaunchBanner(subtitle: localizedKey(language, "ui.music.control.with.character"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if os(macOS)
/// Keep native controls on a common trailing edge across every settings card.
private struct SettingsTrailingContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
            configuration.label
                .fixedSize(horizontal: true, vertical: true)
            Spacer(minLength: 24)
            configuration.content
                .multilineTextAlignment(.trailing)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

private struct SettingsContentContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 28) { content }
                .labeledContentStyle(SettingsTrailingContentStyle())
                .toggleStyle(.switch)
                .djConnectMacDetailContent(maxWidth: .infinity, alignment: .topLeading)
            #else
            DJSessionGlassGroup {
                VStack(alignment: .leading, spacing: 20) { content }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 960)
            .padding(.horizontal, djConnectScreenHorizontalPadding)
            .padding(.vertical, djConnectScreenVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .top)
            #endif
        }
    }
}

private struct SettingsGlassSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 18) { content }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .djSessionFrostedSurface()
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    var showsDivider: Bool = true
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
            if showsDivider {
                Divider()
            }
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
    @Environment(\.horizontalSizeClass) private var nativeHorizontalSizeClass
    @Environment(\.djConnectContentSizeClass) private var contentSizeClass
    private var horizontalSizeClass: UserInterfaceSizeClass? { contentSizeClass ?? nativeHorizontalSizeClass }

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
        #if os(iOS)
        .padding(.vertical, 4)
        #else
        .padding(.vertical, 2)
        #endif
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
            .frame(maxWidth: 320)
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

/// Render only known privacy claims, preserving false and unknown values.
/// Provider labels and diagnostic dictionaries remain data, not user-facing copy.
enum MusicDNAPrivacySummary {
    static func text(_ dashboard: DJConnectMusicDNAPrivacyDashboard, language: String) -> String {
        func localized(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }
        let values: [(String, Bool?)] = [
            ("enabled", dashboard.enabled),
            ("clear", dashboard.supportsClear ?? dashboard.controls["clear_supported"]),
            ("export", dashboard.supportsExport ?? dashboard.controls["export_supported"]),
            ("import", dashboard.supportsImport ?? dashboard.controls["import_supported"]),
            ("audio", dashboard.storesRawAudio),
            ("credentials", dashboard.storesOAuthTokens),
            ("questions", dashboard.storesFullPrompts)
        ]
        let lines = values.compactMap { key, value in
            value.map { localized("ui.music.dna.privacy." + key + ($0 ? ".yes" : ".no")) }
        }
        return lines.isEmpty ? localized("ui.music.dna.privacy.unknown") : lines.joined(separator: "\n")
    }
}

// Search selection belongs to the visible message, not its shifting list position.
func askDJSearchResultIndex(preserving selectedID: UUID?, fallback: Int, in results: [UUID]) -> Int {
    if let selectedID, let index = results.firstIndex(of: selectedID) { return index }
    return min(max(fallback, 0), max(results.count - 1, 0))
}


private struct PushRegistrationDetailsView: View {
    @ObservedObject var model: DJConnectAppModel
    private func text(_ key: String) -> String { localizedKey(model.language, key) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text("ui.push.notifications")).font(.headline)
            Text(text(model.pushNotificationStatus.titleKey)).font(.subheadline.bold())
            Text(text(model.pushNotificationStatus.explanationKey)).fixedSize(horizontal: false, vertical: true)
            if let error = model.pushNotificationStatus.lastError,
               !error.isEmpty, error.count < 96,
               error.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) {
                Text(error).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if [.denied, .restricted].contains(model.notificationPermissionStatus) {
                Text(text("ui.push.permission_detail"))
                Button(text("ui.push.open_settings")) { model.openNotificationSettings() }
                    .djConnectButtonStyle(DJConnectButtonStyle())
            }
            if model.pushNotificationStatus.state != .registered,
               model.pushNotificationStatus.failureKind != .configuration {
                Button(text("ui.retry")) { model.retryPushNotificationRegistration() }
                    .djConnectButtonStyle(DJConnectButtonStyle())
                    .disabled(model.pairingStatus != .paired || model.isDemoMode)
            }
        }
        .padding(20).frame(idealWidth: 360, maxWidth: 420)
        .accessibilityIdentifier("push-registration-details")
    }
}
