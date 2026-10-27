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

/// Anchored by the shared composer, independent of timeline/history emptiness.
struct AskDJComposerHelpPopout: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    let close: () -> Void
    let select: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(DJConnectLocalization.localized(key: "ui.askdj.suggestions.title", language: model.language))
                    .font(.headline).foregroundStyle(.white)
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).frame(width: 44, height: 44)
                    .accessibilityLabel(DJConnectLocalization.localized(key: "ui.close", language: model.language))
                    .accessibilityIdentifier("ask-dj-suggestions-close")
            }
            AskDJSuggestionStrip(model: model, surface: surface, reading: false, select: select)
        }
        .padding(16)
        .frame(maxWidth: 580)
        .fixedSize(horizontal: false, vertical: true)
        .background(DJConnectMaterial(.regular), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 0.6))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ask-dj-suggestions-popout-" + surface.rawValue)
    }
}

/// Both surfaces use this renderer and the same byte-verified Core catalogue.
struct AskDJHelpButton: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    var showsMoreLabel = false
    var send: (() -> Void)? = nil
    @State private var presented = false
    var body: some View {
        if showsMoreLabel {
        AskDJHelpEntry(surface: surface, language: model.language, presented: $presented, showsMoreLabel: showsMoreLabel, onDismissed: {
            if model.askDJCatalogueInputSelection != nil { model.askDJCatalogueFocusRequest = UUID() }
        }) {
            AskDJHelpContent(model: model, surface: surface, presented: $presented, send: send)
        }
        .onChange(of: presented) { _, value in model.askDJHelpIsPresented = value }
        .onDisappear { if presented { model.askDJHelpIsPresented = false } }
        } else {
            Button { model.askDJHelpOpenRequest = .init(surface: surface) } label: { Image(systemName: "questionmark.circle") }
                .accessibilityLabel(DJConnectLocalization.localized(key: surface == .session ? "ui.askdj.help.session.entry" : "ui.askdj.help.global.entry", language: model.language))
                .accessibilityIdentifier("ask-dj-help-" + surface.rawValue)
        }
    }
}

/// Native entry and popover shared by both existing conversation surfaces.
struct AskDJHelpEntry<Content: View>: View {
    let surface: DJConnectAskDJCatalogue.Surface
    let language: String
    @Binding var presented: Bool
    var showsMoreLabel = false
    var onDismissed: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    private var key: String { surface == .session ? "ui.askdj.help.session.entry" : "ui.askdj.help.global.entry" }
    var body: some View {
        Button { presented = true } label: {
            if showsMoreLabel { Label(DJConnectLocalization.localized(key: "ui.more", language: language), systemImage: "ellipsis.circle") }
            else { Image(systemName: "questionmark.circle") }
        }
            .accessibilityLabel(DJConnectLocalization.localized(key: key, language: language))
            .help(DJConnectLocalization.localized(key: key, language: language))
            .accessibilityIdentifier((showsMoreLabel ? "ask-dj-more-" : "ask-dj-help-") + surface.rawValue)
            .popover(isPresented: $presented) {
                VStack(alignment: .trailing, spacing: 0) {
                    Button { presented = false } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .padding(12)
                        .accessibilityLabel(DJConnectLocalization.localized(key: "ui.close", language: language))
                        .accessibilityIdentifier("ask-dj-help-close")
                    content()
                }
                .background(DJConnectMaterial(.regular))
                .djConnectPresentationSurface()
                .presentationCompactAdaptation(.popover)
                .onDisappear { onDismissed?() }
            }
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
        guard !catalogueModel.busy, catalogueModel.isCurrent,
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
        } else { if let send { send() } else { model.sendAskDJText() } }
    }
    var body: some View {
        AskDJFullCatalogueReference(sections: catalogueModel.sections, busy: catalogueModel.busy,
            enabled: catalogueModel.isCurrent && model.askDJDraft.isEmpty && model.canUseAskDJFeatures && !model.isSendingAskDJText && !model.isRecordingVoice,
            language: model.language) { item in Task { await choose(item) } }
        .task {
            await model.refreshAskDJExampleCapabilities()
            _ = await refresh()
        }
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
    let select: (DJConnectAskDJCatalogue.HelpItem) -> Void
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text(DJConnectLocalization.localized(key: "ui.askdj.help.catalogue.title", language: language))
                    .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text(DJConnectLocalization.localized(key: "ui.askdj.help.catalogue.instructions", language: language))
                    .foregroundStyle(.secondary)
                if busy { ProgressView() }
                ForEach(sections) { section in
                    Text(section.title).font(.headline).accessibilityAddTraits(.isHeader)
                    ForEach(section.items) { item in
                        Button { select(item) } label: {
                            HStack {
                                Text(item.prompt).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: item.requiresInput ? "pencil" : "arrow.up.circle")
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .djConnectPlainButtonStyle()
                        .disabled(busy || !enabled)
                        .accessibilityIdentifier("ask-dj-catalogue-" + item.id)
                    }
                }
                if sections.isEmpty && !busy {
                    Text(DJConnectLocalization.localized(key: "ui.askdj.help.unavailable", language: language))
                        .foregroundStyle(.secondary)
                }
            }.padding(24)
        }
        .frame(idealWidth: 620, maxWidth: 760, idealHeight: 560, maxHeight: 720)
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
    private func open() async {
        suggestions = []
        await model.refreshAskDJExampleCapabilities()
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
        select(item.prompt) // Chips only prepare the original draft; never send.
    }
    var body: some View {
        AskDJSuggestionRows(suggestions: observation.isCurrent ? suggestions : [], surface: surface,
            disabled: selecting || frozen || !model.canUseAskDJFeatures) { item in Task { await choose(item) } }
        AskDJHelpButton(model: model, surface: surface, showsMoreLabel: true)
        .task { await open() }
        .onChange(of: context) { _, next in observation.contextChanged(to: next); if !observation.isCurrent { suggestions = [] } }
        .onChange(of: model.language) { _, _ in observation.contextChanged(to: context); if !observation.isCurrent { suggestions = [] } }
        .onChange(of: observation.admittedContext) { _, value in if value == nil { suggestions = [] } }
        .onChange(of: model.askDJExampleRefreshEpoch) { _, _ in Task { await open() } }
        .onDisappear { observation.close(); suggestions = [] }
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
                    HStack(spacing: 8) {
                        Image(systemName: "quote.opening").font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.54)).frame(width: 18).accessibilityHidden(true)
                        Text(suggestion.prompt).font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.50)).accessibilityHidden(true)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 10).frame(maxWidth: 480, alignment: .leading)
                    .background(DJConnectCardAppearance.shape.fill(.white.opacity(0.09)))
                    .overlay(DJConnectCardAppearance.shape.stroke(.white.opacity(DJConnectCardAppearance.borderOpacity), lineWidth: DJConnectCardAppearance.borderWidth))
                }
                .djConnectPlainButtonStyle()
                .disabled(disabled)
                .accessibilityIdentifier("ask-dj-suggestion-" + surface.rawValue + "-" + suggestion.id)
            }
        }
    }
}
