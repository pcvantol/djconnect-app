import SwiftUI
import DJConnectCore

/// Both surfaces use this renderer and the same byte-verified Core catalogue.
struct AskDJHelpButton: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    @State private var presented = false
    private var key: String { surface == .session ? "ui.askdj.help.session.entry" : "ui.askdj.help.global.entry" }
    var body: some View {
        Button { presented = true } label: { Image(systemName: "questionmark.circle") }
            .accessibilityLabel(DJConnectLocalization.localized(key: key, language: model.language))
            .help(DJConnectLocalization.localized(key: key, language: model.language))
            .accessibilityIdentifier("ask-dj-help-" + surface.rawValue)
            .onChange(of: presented) { _, value in model.askDJHelpIsPresented = value }
            .onDisappear { if presented { model.askDJHelpIsPresented = false } }
            .popover(isPresented: $presented) {
                AskDJHelpContent(model: model, surface: surface)
                    .presentationCompactAdaptation(.popover)
            }
    }
}

private struct AskDJHelpContent: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    private func text(_ suffix: String) -> String {
        DJConnectLocalization.localized(key: "ui.askdj.help." + (surface == .session ? "session." : "global.") + suffix, language: model.language)
    }
    var body: some View {
        let catalogue = DJConnectAskDJCatalogue.bundled
        let sections = catalogue?.helpSections(model.askDJExampleContext(), surface: surface, language: model.language) ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(text("title")).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text(text("intro")).font(.body)
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(section.examples, id: \.self) { example in
                            // Reference text can contain [artist]; it is never a send button.
                            Text("“" + example + "”").font(.body)
                        }
                    }
                }
                if sections.isEmpty {
                    Text(catalogue?.unavailableText(language: model.language) ?? DJConnectLocalization.localized(key: "ui.askdj.help.unavailable", language: model.language))
                        .foregroundStyle(.secondary)
                }
                Text(text("footer")).font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 440, alignment: .leading).padding(20)
        }
        .frame(idealWidth: 420, idealHeight: 500)
        .task { await model.refreshAskDJExampleCapabilities() }
    }
}

/// Stable values for a visit. Progress updates cannot rotate the selection.
struct AskDJSuggestionStrip: View {
    @ObservedObject var model: DJConnectAppModel
    let surface: DJConnectAskDJCatalogue.Surface
    var reading = false
    let select: (String) -> Void
    @State private var suggestions: [DJConnectAskDJCatalogue.Suggestion] = []
    private var context: DJConnectAskDJCatalogue.Context { model.askDJExampleContext() }
    private var frozen: Bool { reading || model.askDJHelpIsPresented || !model.askDJDraft.isEmpty || model.isRecordingVoice || model.isSendingAskDJText }
    private func update(visit: Bool = false, refresh: Bool = false, revokeOnly: Bool = false) {
        suggestions = model.updateAskDJSuggestions(surface: surface, frozen: frozen || revokeOnly, visit: visit, refresh: refresh)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions) { suggestion in
                Button {
                    guard model.askDJDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !model.isSendingAskDJText, !model.isRecordingVoice,
                          model.canUseAskDJFeatures,
                          DJConnectAskDJCatalogue.bundled?.retains(suggestion, context: context, surface: surface, language: model.language) == true else {
                        update(revokeOnly: true); return
                    }
                    select(suggestion.prompt)
                } label: {
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
                .disabled(frozen || !model.canUseAskDJFeatures)
                .accessibilityIdentifier("ask-dj-suggestion-" + surface.rawValue + "-" + suggestion.id)
            }
        }
        .onAppear { update(visit: true) }
        .onChange(of: context) { update() }
        .onChange(of: model.askDJExampleRefreshEpoch) { update(refresh: true) }
        .onChange(of: model.language) { update() }
        .onChange(of: frozen) { update() }
        // Expiry can only revoke. It never shuffles, refills or makes a request.
        .task(id: model.activeDJSession?.broadcast.playback?.updatedAt) {
            guard let date = DJConnectSessionForecast.timestamp(model.activeDJSession?.broadcast.playback?.updatedAt) else { return }
            let remaining = date.addingTimeInterval(30).timeIntervalSinceNow
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }; update(revokeOnly: true)
        }
    }
}
