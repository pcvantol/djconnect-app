import SwiftUI
import DJConnectCore

/// Transient conversation scope for closing stale Help; no visibility preference.
struct AskDJHelpScope: Equatable {
    var owner: String?
    var session: String?
    var conversation: UUID?
}
struct AskDJHelpOpenRequest: Equatable {
    let id = UUID()
    let surface: DJConnectAskDJCatalogue.Surface
}

enum AskDJHelpPanelLayout {
    static let coordinateSpace = "DJConnectConversationHelpViewport"
    static let gap: CGFloat = 12
    struct Placement: Equatable {
        var availableHeight: CGFloat = 0
        var composerHeight: CGFloat = 0
    }
}

/// One glass shell grows upward; both modes remain anchored to the composer.
struct AskDJHelpPanel<Compact: View, Catalogue: View>: View {
    @Binding var expanded: Bool
    let maximumHeight: CGFloat
    let title: String
    let backLabel: String
    let closeLabel: String
    let close: () -> Void
    @ViewBuilder let compact: () -> Compact
    @ViewBuilder let catalogue: () -> Catalogue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var compactHeight: CGFloat = 0
    private var headerHeight: CGFloat { min(44, max(0, maximumHeight)) }
    private var panelPadding: CGFloat { min(16, max(0, (maximumHeight - headerHeight) / 2)) }
    private var contentSpacing: CGFloat { maximumHeight >= 88 ? 12 : 0 }
    private var bodyHeight: CGFloat { max(0, maximumHeight - headerHeight - 2 * panelPadding - contentSpacing) }
    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            HStack {
                if expanded {
                    Button { expanded = false } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.plain).frame(width: 44, height: 44)
                        .accessibilityLabel(backLabel).accessibilityIdentifier("ask-dj-suggestions-back")
                }
                Text(title).font(.title2.bold()).foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .djConnectButtonStyle(DJConnectButtonStyle(shape: .icon))
                    .accessibilityLabel(closeLabel).accessibilityIdentifier("ask-dj-suggestions-close")
            }
            .frame(height: headerHeight)
            .foregroundStyle(.white)
            ZStack(alignment: .topLeading) {
                // Keep the original suggestion visit mounted while reading More.
                ScrollView {
                    compact().frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { compactHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .opacity(expanded ? 0 : 1).allowsHitTesting(!expanded).accessibilityHidden(expanded)
                if expanded { catalogue().transition(.opacity) }
            }
            .frame(height: expanded ? bodyHeight : min(compactHeight, bodyHeight))
        }
        .padding(panelPadding).frame(maxWidth: 580)
        .djConnectGlassPopoutSurface()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: expanded)
        .accessibilityElement(children: .contain)
    }
}

/// Anchored by the shared composer, independent of timeline/history emptiness.
struct AskDJComposerHelpPopout: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    let maximumHeight: CGFloat
    let close: () -> Void
    let expand: () -> Void
    let send: () -> Void
    let select: (String) -> Void
    @State private var expanded = false
    var body: some View {
        AskDJHelpPanel(expanded: $expanded, maximumHeight: maximumHeight,
            title: DJConnectLocalization.localized(key: expanded ? "ui.askdj.help.catalogue.title" : "ui.askdj.suggestions.title", language: model.language),
            backLabel: DJConnectLocalization.localized(key: "ui.askdj.suggestions.title", language: model.language),
            closeLabel: DJConnectLocalization.localized(key: "ui.close", language: model.language), close: close) {
                AskDJSuggestionStrip(model: model, surface: surface, reading: expanded,
                    more: { expand(); expanded = true }, select: select)
            } catalogue: {
                AskDJHelpContent(model: model, surface: surface,
                    presented: Binding(get: { expanded }, set: { if !$0 { close() } }), send: send)
            }
        .onChange(of: expanded) { _, value in model.askDJHelpIsPresented = value }
        .onDisappear { model.askDJHelpIsPresented = false }
        .accessibilityIdentifier("ask-dj-suggestions-popout-" + surface.rawValue)
    }
}

/// Manual entry only; More is an inline mode change in the existing panel.
struct AskDJHelpButton: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    var body: some View {
        Button { model.askDJHelpOpenRequest = .init(surface: surface) } label: {
            Image(systemName: "questionmark.circle")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
            .buttonStyle(.plain)
            .accessibilityLabel(DJConnectLocalization.localized(key: surface == .session ? "ui.askdj.help.session.entry" : "ui.askdj.help.global.entry", language: model.language))
            .accessibilityIdentifier("ask-dj-help-" + surface.rawValue)
    }
}

private struct AskDJHelpContent: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    @Binding var presented: Bool
    var send: (() -> Void)?
    @StateObject private var catalogueModel = AskDJHelpCatalogueModel()
    private var context: DJConnectAskDJCatalogue.Context { model.askDJExampleContext() }
    private func refresh() async -> [DJConnectAskDJCatalogue.CatalogueSection]? {
        await catalogueModel.read(catalogue: .bundled, surface: surface, language: model.language,
            context: { model.askDJExampleContext() }, reader: model.askDJHelpCatalogueReader)
    }
    private func choose(_ item: DJConnectAskDJCatalogue.HelpItem) async {
        guard item.isAvailable, !catalogueModel.busy, catalogueModel.isCurrent,
              model.canUseAskDJFeatures, !model.isSendingAskDJText, !model.isRecordingVoice,
              model.askDJDraft.isEmpty else { return }
        let edit = model.askDJDraftEditRevision, owner = context, language = model.language
        guard let fresh = await refresh(), presented, context == owner, model.language == language,
              model.canUseAskDJFeatures, !model.isSendingAskDJText, !model.isRecordingVoice,
              model.askDJDraftEditRevision == edit, model.askDJDraft.isEmpty,
              fresh.flatMap(\.items).contains(item), catalogueModel.isCurrent else { return }
        model.askDJDraft = item.prompt
        presented = false
        if item.requiresInput {
            model.askDJCatalogueInputSelection = item.inputRange
            model.askDJCatalogueFocusRequest = UUID()
        } else { if let send { send() } else { model.sendAskDJText() } }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AskDJFullCatalogueReference(sections: catalogueModel.sections, busy: catalogueModel.busy,
                enabled: catalogueModel.isCurrent && model.askDJDraft.isEmpty && model.canUseAskDJFeatures && !model.isSendingAskDJText && !model.isRecordingVoice,
                language: model.language, showsTitle: false) { item in Task { await choose(item) } }
            if !catalogueModel.isCurrent && !catalogueModel.busy {
                Button(DJConnectLocalization.localized(key: "ui.retry", language: model.language)) {
                    Task {
                        await model.refreshAskDJExampleCapabilities()
                        _ = await refresh()
                    }
                }
                .djConnectPlainButtonStyle()
                .accessibilityIdentifier("ask-dj-help-retry")
            }
        }
        .task {
            await model.refreshAskDJExampleCapabilities()
        }
        .task(id: context) { _ = await refresh() }
        .onChange(of: context) { _, next in catalogueModel.contextChanged(to: next) }
        .onChange(of: model.language) { _, _ in catalogueModel.contextChanged(to: context) }
        .onDisappear { catalogueModel.close() }
    }
}

/// Shared full catalogue renderer. The owner supplies freshly admitted values;
/// this view cannot discover capabilities, execute commands or invent templates.
struct AskDJFullCatalogueReference: View {
    let sections: [DJConnectAskDJCatalogue.CatalogueSection]
    let busy: Bool
    let enabled: Bool
    let language: String
    var showsTitle = true
    let select: (DJConnectAskDJCatalogue.HelpItem) -> Void
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if showsTitle {
                    Text(DJConnectLocalization.localized(key: "ui.askdj.help.catalogue.title", language: language))
                        .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                }
                Text(DJConnectLocalization.localized(key: "ui.askdj.help.catalogue.instructions", language: language))
                    .foregroundStyle(.secondary)
                if busy { ProgressView() }
                ForEach(sections) { section in
                    Text(section.title).font(.headline).accessibilityAddTraits(.isHeader)
                    ForEach(section.items) { item in
                        Button { select(item) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                AskDJHelpExampleLabel(prompt: item.prompt,
                                    actionSymbol: item.requiresInput ? "pencil" : "arrow.up.circle",
                                    maximumWidth: .infinity)
                                if !item.isAvailable {
                                    Text(DJConnectLocalization.localized(key: "ui.askdj.help.item.unavailable", language: language))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .opacity(item.isAvailable ? 1 : 0.55)
                        }
                        .djConnectPlainButtonStyle()
                        .disabled(busy || !enabled || !item.isAvailable)
                        .accessibilityIdentifier("ask-dj-catalogue-" + item.id)
                    }
                }
                if sections.isEmpty && !busy {
                    Text(DJConnectLocalization.localized(key: "ui.askdj.help.unavailable", language: language))
                        .foregroundStyle(.secondary)
                }
            }.padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("ask-dj-full-catalogue")
    }
}

/// The same reference renderer for both surfaces. Original track expiry causes
/// local revalidation even while the owner reads without receiving new events.
/// Neither rendering nor expiry performs discovery or sends an Ask DJ command.
struct AskDJHelpReference: View {
    let catalogue: DJConnectAskDJCatalogue?
    let surface: DJConnectAskDJCatalogue.Surface
    let language: String
    let trackExpiresAt: Date?
    let context: (Date) -> DJConnectAskDJCatalogue.Context

    private func text(_ suffix: String) -> String {
        DJConnectLocalization.localized(key: "ui.askdj.help." + (surface == .session ? "session." : "global.") + suffix, language: language)
    }
    var body: some View {
        TimelineView(SessionEntryRefreshSchedule(deadlines: [trackExpiresAt].compactMap { $0 })) { clock in
            // A capability/owner update can arrive between scheduled ticks.
            // Never evaluate new observations against an earlier display tick.
            reference(at: max(clock.date, Date()))
        }
    }
    private func reference(at now: Date) -> some View {
        let sections = catalogue?.helpSections(context(now), surface: surface, language: language) ?? []
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(text("title")).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("ask-dj-help-title")
                Text(text("intro")).font(.body)
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(.headline).accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("ask-dj-help-group-" + section.id)
                        ForEach(section.examples, id: \.self) { example in
                            // Reference text can contain [artist]; it is never a send button.
                            Text("“" + example + "”").font(.body)
                                .accessibilityIdentifier("ask-dj-help-example-" + section.id)
                        }
                    }
                }
                if sections.isEmpty {
                    Text(catalogue?.unavailableText(language: language) ?? DJConnectLocalization.localized(key: "ui.askdj.help.unavailable", language: language))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ask-dj-help-unavailable")
                }
                Text(text("footer")).font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 440, alignment: .leading).padding(20)
        }
        .frame(idealWidth: 420, idealHeight: 500)
        .accessibilityIdentifier("ask-dj-help-reference")
    }
}

/// Stable values for a visit. Progress updates cannot rotate the selection.
struct AskDJSuggestionStrip: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    var reading = false
    let more: () -> Void
    let select: (String) -> Void
    @StateObject private var observation = AskDJHelpCatalogueModel()
    @State private var suggestions: [DJConnectAskDJCatalogue.Suggestion] = []
    @State private var selecting = false
    @State private var visit = UUID().uuidString
    private var context: DJConnectAskDJCatalogue.Context { model.askDJExampleContext() }
    private var frozen: Bool { reading || model.askDJHelpIsPresented || !model.askDJDraft.isEmpty || model.isRecordingVoice || model.isSendingAskDJText }
    private func read() async -> DJConnectAskDJCatalogue.Context? {
        _ = await observation.read(catalogue: .bundled, surface: surface, language: model.language,
            context: { model.askDJExampleContext() }, reader: model.askDJHelpCatalogueReader)
        return observation.admittedContext
    }
    private func open(refreshCapabilities: Bool = true) async {
        suggestions = []
        guard !frozen else { return }
        if refreshCapabilities { await model.refreshAskDJExampleCapabilities() }
        guard DJConnectAskDJCatalogue.bundled?.compatible(context) == true else { return }
        guard let admitted = await read(), !frozen else { return }
        suggestions = DJConnectAskDJCatalogue.bundled?.select(admitted, surface: surface, language: model.language, epoch: visit) ?? []
    }
    private func choose(_ item: DJConnectAskDJCatalogue.Suggestion) async {
        guard !selecting, !frozen, observation.isCurrent, suggestions.count == 3,
              suggestions.contains(item), model.canUseAskDJFeatures else { return }
        selecting = true; defer { selecting = false }
        let original = suggestions, owner = context, language = model.language, edit = model.askDJDraftEditRevision
        guard let fresh = await read(), !Task.isCancelled, context == owner, model.language == language,
              model.askDJDraftEditRevision == edit, model.askDJDraft.isEmpty, !frozen,
              model.canUseAskDJFeatures, observation.isCurrent,
              original.allSatisfy({ DJConnectAskDJCatalogue.bundled?.retains($0, context: fresh, surface: surface, language: language) == true }) else {
            suggestions = []; return
        }
        select(item.prompt) // The composer sends through its existing context-bound route.
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AskDJSuggestionRows(suggestions: observation.isCurrent ? suggestions : [], surface: surface,
                disabled: selecting || frozen || !model.canUseAskDJFeatures) { item in Task { await choose(item) } }
            if observation.busy {
                ProgressView()
            } else if suggestions.isEmpty || !observation.isCurrent {
                Text(DJConnectLocalization.localized(key: "ui.askdj.help.unavailable", language: model.language))
                    .font(.callout).foregroundStyle(.secondary)
                Button(DJConnectLocalization.localized(key: "ui.retry", language: model.language)) {
                    Task { await open() }
                }
                .djConnectPlainButtonStyle()
                .disabled(selecting || frozen)
                .accessibilityIdentifier("ask-dj-suggestions-retry")
            }
            Button(action: more) {
                Label(DJConnectLocalization.localized(key: "ui.more", language: model.language), systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("ask-dj-more-" + surface.rawValue)
        }
        .task { await model.refreshAskDJExampleCapabilities() }
        .task(id: context) { await open(refreshCapabilities: false) }
        .onChange(of: context) { _, next in observation.contextChanged(to: next); if !observation.isCurrent { suggestions = [] } }
        .onChange(of: model.language) { _, _ in observation.contextChanged(to: context); if !observation.isCurrent { suggestions = [] } }
        .onChange(of: observation.admittedContext) { _, value in if value == nil { suggestions = [] } }
        .onChange(of: model.askDJExampleRefreshEpoch) { _, _ in if !frozen { Task { await open() } } }
        .onChange(of: frozen) { _, value in if !value && suggestions.isEmpty { Task { await open() } } }
        .onDisappear { observation.close(); suggestions = [] }
    }
}

/// One visual treatment for compact suggestions and the expanded catalogue.
private struct AskDJHelpExampleLabel: View {
    let prompt: String
    let actionSymbol: String
    var maximumWidth: CGFloat = 480

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening").font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.54)).frame(width: 18).accessibilityHidden(true)
            Text(prompt).font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Image(systemName: actionSymbol).font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.50)).accessibilityHidden(true)
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .frame(maxWidth: maximumWidth, alignment: .leading)
        .background(DJConnectCardAppearance.shape.fill(.white.opacity(0.09)))
        .overlay(DJConnectCardAppearance.shape.stroke(.white.opacity(DJConnectCardAppearance.borderOpacity),
            lineWidth: DJConnectCardAppearance.borderWidth))
        .contentShape(DJConnectCardAppearance.shape)
    }
}

/// Presentation only. Eligibility and tap-time validation remain in the owner.
struct AskDJSuggestionRows: View {
    let suggestions: [DJConnectAskDJCatalogue.Suggestion]
    let surface: DJConnectAskDJCatalogue.Surface
    var disabled = false
    let select: (DJConnectAskDJCatalogue.Suggestion) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions) { suggestion in
                Button { select(suggestion) } label: {
                    AskDJHelpExampleLabel(prompt: suggestion.prompt, actionSymbol: "arrow.up.circle")
                }
                .djConnectPlainButtonStyle()
                .disabled(disabled)
                .accessibilityIdentifier("ask-dj-suggestion-" + surface.rawValue + "-" + suggestion.id)
            }
        }
    }
}

#if os(iOS) || os(macOS)
#if os(iOS)
import UIKit
private typealias AskDJHelpNativeRegion = UIView
#else
import AppKit
private typealias AskDJHelpNativeRegion = NSView
#endif

/// Native regions preserve hit testing inside both the composer and its overlay.
/// Observe the owning window without adding a full-screen layer over its controls.
@MainActor final class AskDJHelpTapRegions: ObservableObject {
    fileprivate weak var composer: AskDJHelpNativeRegion?
    fileprivate weak var panel: AskDJHelpNativeRegion?

    fileprivate func contains(_ point: CGPoint, in window: AnyObject) -> Bool {
        [composer, panel].contains { view in
            guard let view, view.window === window else { return false }
            return view.convert(view.bounds, to: nil).contains(point)
        }
    }
}

#if os(iOS)
struct AskDJHelpTapRegion: UIViewRepresentable {
    let regions: AskDJHelpTapRegions
    let isPanel: Bool
    var enabled = false
    var close: () -> Void = {}

    func makeUIView(context: Context) -> RegionView { RegionView() }
    func updateUIView(_ view: RegionView, context: Context) {
        view.regions = regions; view.enabled = enabled; view.close = close
        if isPanel { regions.panel = view } else { regions.composer = view }
    }
    static func dismantleUIView(_ view: RegionView, coordinator: ()) { view.detach() }

    final class RegionView: UIView, UIGestureRecognizerDelegate {
        weak var regions: AskDJHelpTapRegions?
        var enabled = false
        var close: () -> Void = {}
        private weak var observedWindow: UIWindow?
        private lazy var tap: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(outsideTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            return tap
        }()
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            if let window { observedWindow = window; window.addGestureRecognizer(tap) }
        }
        func detach() {
            observedWindow?.removeGestureRecognizer(tap)
            observedWindow = nil
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard enabled, let window, let regions else { return false }
            return !regions.contains(touch.location(in: window), in: window)
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        @objc private func outsideTap() { if enabled { close() } }
    }
}
#else
struct AskDJHelpTapRegion: NSViewRepresentable {
    let regions: AskDJHelpTapRegions
    let isPanel: Bool
    var enabled = false
    var close: () -> Void = {}

    func makeNSView(context: Context) -> RegionView { RegionView() }
    func updateNSView(_ view: RegionView, context: Context) {
        view.regions = regions; view.enabled = enabled; view.close = close
        if isPanel { regions.panel = view } else { regions.composer = view }
    }
    static func dismantleNSView(_ view: RegionView, coordinator: ()) { view.detach() }

    final class RegionView: NSView {
        weak var regions: AskDJHelpTapRegions?
        var enabled = false
        var close: () -> Void = {}
        private var monitor: Any?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            detach()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.handle(event) ?? event
            }
        }
        func handle(_ event: NSEvent) -> NSEvent {
            guard enabled, let window, event.window === window, let regions else { return event }
            if !regions.contains(event.locationInWindow, in: window) { close() }
            return event
        }
        func detach() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
#endif
#endif


/// Retained across navigation. Reads never start music; only deliberate original choices do.
@MainActor final class SessionStartupModel: ObservableObject {
    struct Scope: Equatable {
        let session: String
        let owner: String
        let epoch: UUID
        let origin: String
        let language: String
        let settings: Data?
        var output: String?
    }
    enum Phase { case hidden, ready, loading, choices, finished }
    @Published private(set) var phase: Phase = .hidden
    @Published private(set) var catalogue: DJConnectSessionStartupActions?
    @Published private(set) var actions: [DJConnectAskDJPlaybackAction] = []
    @Published private(set) var message: String?
    private weak var host: DJConnectAppModel?
    private var captured: Scope?
    private var allowedOutput: String?
    private var generation = UUID()
    private var readCompleted = false
    private var expiryTask: Task<Void, Never>?
    var now: () -> Date = { Date() }
    var instant: () -> ContinuousClock.Instant = { ContinuousClock.now }
    private var consumedSessions = Set<String>()
    private var wallDeadline: Date?
    private var monotonicDeadline: ContinuousClock.Instant?
    init(host: DJConnectAppModel) { self.host = host }
    var scope: Scope? {
        guard let host, host.canRefreshSessionHistory, host.canUseProfileConversation, host.isConnected, host.backendAvailable,
              let session = host.activeDJSession, session.runtimeState == "active",
              let owner = host.sessionHistory.authorizedProfileID,
              host.playback?.isPlaying != true else { return nil }
        // Bind the original material settings, excluding continuously changing playback/planning.
        let settings = try? Self.settingsData(session)
        return Scope(session: session.id, owner: owner, epoch: host.sessionHistory.responseEpoch,
                     origin: host.homeAssistantURL + "|" + host.haLocalURL + "|" + host.haRemoteURL,
                     language: host.language, settings: settings, output: host.playback?.device?.id)
    }
    private static func settingsData(_ session: DJConnectSessionRuntime) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Settings(session: session))
    }
    private struct Settings: Encodable {
        let backend: String
        let mood: String
        let moodRevision: Int?
        let persona: DJConnectSessionPersonaValue?
        let personaRevision: Int?
        let presence: DJConnectSessionPresenceValue?
        let presenceRevision: Int?
        init(session: DJConnectSessionRuntime) {
            backend = session.musicBackend
            mood = session.selectedMood; moodRevision = session.moodRevision
            persona = session.selectedPersona; personaRevision = session.personaRevision
            presence = session.selectedPresence; presenceRevision = session.presenceRevision
        }
    }
    func reconcile() {
        let next = scope
        guard next != captured, !matchesOriginal(next) else { return }
        if let captured, wallDeadline != nil { consumedSessions.insert(captured.owner + ":" + captured.session) }
        expiryTask?.cancel(); expiryTask = nil
        captured = next; allowedOutput = nil; generation = UUID(); readCompleted = false
        catalogue = nil; actions = []; message = nil; phase = .hidden
        wallDeadline = nil; monotonicDeadline = nil
    }
    private func matchesOriginal(_ observed: Scope?) -> Bool {
        guard var observed, let captured else { return false }
        if let allowedOutput, observed.output == allowedOutput { observed.output = captured.output }
        return observed == captured
    }
    private func current(_ scope: Scope, _ token: UUID) -> Bool {
        matchesOriginal(self.scope) && captured == scope && generation == token
    }
    private var withinDeadline: Bool {
        guard let wallDeadline, let monotonicDeadline else { return false }
        return now() < wallDeadline && instant() < monotonicDeadline
    }
    func refresh() async {
        reconcile()
        guard !readCompleted, let host, let captured,
              !consumedSessions.contains(captured.owner + ":" + captured.session) else { return }
        readCompleted = true
        let token = generation
        do {
            let capabilities = try await host.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                try await $0.activeSessionMoodCapabilities()
            }
            guard current(captured, token), capabilities.sessionStartupAvailable else { return }
            let response = try await host.withHomeAssistantClient(allowsOperationReplay: false, notifiesTransportFailure: false) {
                try await $0.activeSession()
            }
            guard current(captured, token), response.success,
                  let session = response.resolvedSession, session.id == captured.session,
                  (try? Self.settingsData(session)) == captured.settings,
                  let menu = response.startupActions, menu.isSupported, menu.available else { return }
            catalogue = menu; phase = .ready
        } catch { /* A failed capability read creates no speculative startup choices. */ }
    }
    func selectPlaylist() {
        guard phase == .ready, let host, let captured, matchesOriginal(scope),
              catalogue?.items.last?.available == true else { return }
        host.performHomeScreenAction(.playlists)
    }
    func surprise() {
        guard phase == .ready, let captured, matchesOriginal(scope), let item = catalogue?.items.first,
              item.available, let prompt = item.copy(language: captured.language)?.prompt else { return }
        wallDeadline = now().addingTimeInterval(60)
        monotonicDeadline = instant().advanced(by: .seconds(60))
        armExpiry(after: 60)
        submit(text: prompt, choice: nil)
    }
    var canChoose: Bool { phase == .choices && withinDeadline && matchesOriginal(scope) && host?.isSendingAskDJText == false }
    func choose(_ action: DJConnectAskDJPlaybackAction) {
        guard canChoose, actions.contains(action),
              let result = action.resultSetID, let id = action.actionID else { return }
        if action.kind == "output" {
            if case .string(let output) = action.value { allowedOutput = output }
            else if let output = action.deviceID { allowedOutput = output }
        }
        submit(text: action.buttonLabel ?? action.title,
               choice: .init(resultSetID: result, actionID: id))
    }
    private func submit(text: String, choice: DJConnectConversationChoice?) {
        guard let host, let captured, matchesOriginal(scope), withinDeadline,
              !host.isSendingAskDJText else { return }
        let token = generation
        phase = .loading; actions = [] // Synchronous latch prevents duplicate taps.
        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await host.sessionHistory.sendStartupChoice(text: text, choice: choice,
                    sessionID: captured.session, isCurrent: { [weak self] in
                        self?.current(captured, token) == true && self?.withinDeadline == true
                    })
                guard current(captured, token) else { return }
                accept(response)
            } catch {
                guard current(captured, token) else { return }
                finish() // Unknown effects are never resent with a fresh ID.
            }
        }
    }
    private func finish() {
        if let captured { consumedSessions.insert(captured.owner + ":" + captured.session) }
        expiryTask?.cancel(); expiryTask = nil
        actions = []; phase = .finished
    }
    private func accept(_ response: DJConnectAskDJMessageResponse) {
        guard withinDeadline, let state = response.firstPlay, state.isSupported else { finish(); return }
        message = response.text ?? response.djText ?? response.message
        guard ["output", "genres"].contains(state.state), let result = response.resultSet else { finish(); return }
        let offered = result.admittedPlaybackActions
        guard !offered.isEmpty, offered.count <= 20,
              state.state != "genres" || (offered.count == 3 && offered.allSatisfy { $0.kind == "track_mix" }),
              state.state != "output" || offered.allSatisfy({ $0.kind == "output" && $0.command == "set_output" })
        else { finish(); return }
        guard let host, let lease = host.resolveConversationPresentationDeadline(response), lease > now() else { finish(); return }
        let remaining = min(state.expires_in, result.expiresIn, lease.timeIntervalSince(now()))
        wallDeadline = min(wallDeadline!, now().addingTimeInterval(remaining))
        monotonicDeadline = min(monotonicDeadline!, instant().advanced(by: .seconds(remaining)))
        guard withinDeadline else { finish(); return }
        actions = offered; phase = .choices
        armExpiry(after: max(0, wallDeadline!.timeIntervalSince(now())))
    }
    private func armExpiry(after delay: Double) {
        expiryTask?.cancel()
        let token = generation
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.generation == token else { return }
            self.finish()
        }
    }
}

struct SessionStartupCard: View {
    @ObservedObject private var startup: SessionStartupModel
    @ObservedObject private var model: DJConnectAppModel
    init(model: DJConnectAppModel) {
        self.model = model; self.startup = model.sessionStartup
    }
    var body: some View {
        Group {
            if startup.phase != .hidden && startup.phase != .finished {
                VStack(alignment: .leading, spacing: 12) {
                    if let message = startup.message { Text(message).fixedSize(horizontal: false, vertical: true) }
                    if startup.phase == .loading { ProgressView() }
                    if startup.phase == .ready, let menu = startup.catalogue {
                        ForEach(menu.items, id: \.id) { item in
                            if let copy = item.copy(language: model.language) {
                                Button(copy.label) {
                                    if item.kind == "navigation" { startup.selectPlaylist() } else { startup.surprise() }
                                }.disabled(!item.available || model.isSendingAskDJText)
                                .accessibilityIdentifier("session-startup-" + item.id)
                            }
                        }
                    }
                    ForEach(startup.actions) { action in
                        Button(action.buttonLabel ?? action.title) { startup.choose(action) }
                            .disabled(!startup.canChoose)
                    }
                }
                .buttonStyle(.bordered).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .task(id: startup.scope) { await startup.refresh() }
    }
}
