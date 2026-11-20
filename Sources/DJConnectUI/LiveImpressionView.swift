import SwiftUI
import DJConnectCore

extension DJConnectAppModel {
    func liveImpressionIsCurrent(_ value: DJConnectLiveImpression, sessionID: String,
                                 target: DJConnectSessionMedia.Target) -> Bool {
        guard canRefreshSessionHistory, value.isValid else { return false }
        switch target {
        case .moment(let id):
            guard let session = activeDJSession, session.id == sessionID,
                  !sessionHistory.contentMomentWasWithdrawn(sessionID: sessionID, momentID: id) else { return false }
            if let requested = askDJMoments.currentResult?.moment, requested.id == id,
               requested.sessionID == sessionID, requested.liveImpression == value, requested.isLiveImpressionV1 { return true }
            return ([session.broadcast.nativeCurrentMoment(at: Date(), spotifyAttributionAvailable: spotifyAttributionLogo != nil)].compactMap { $0 }
                + session.broadcast.nativeFlowMoments(at: Date())).contains { $0.id == id && $0.liveImpression == value && $0.isLiveImpressionV1 }
        case .entry(let id):
            let matches: (DJConnectHistoryEntry) -> Bool = {
                $0.id == id && $0.sessionID == sessionID && $0.isContractValid && $0.isRetained() &&
                    $0.archiveBasis == "public_live_impression_v1" && $0.liveImpression == value
            }
            return sessionHistory.timelines[sessionID]?.entries.contains(where: matches) == true ||
                sessionHistory.containsHistoricalArtworkEntry(.init(sessionID: sessionID, entryID: id), matching: matches)
        }
    }

    func liveImpressionAudience(sessionID: String, target: DJConnectSessionMedia.Target) -> DJConnectSessionMedia.Audience? {
        switch target {
        case .moment(let id):
            guard let session = activeDJSession, session.id == sessionID else { return nil }
            if askDJMoments.currentResult?.moment.id == id { return .activeFlow }
            return session.broadcast.nativeCurrentMoment(at: Date())?.id == id ? .current : .activeFlow
        case .entry:
            guard let header = sessionHistory.timelines[sessionID]?.session ?? sessionHistory.sessions.first(where: { $0.id == sessionID }),
                  header.isContractValid else { return nil }
            return header.readOnly ? .history : .activeFlow
        }
    }

    func loadLiveImpressionPhoto(_ value: DJConnectLiveImpression, photo: DJConnectLiveImpression.Photo,
                                 sessionID: String, target: DJConnectSessionMedia.Target) async throws
        -> (DJConnectSessionArtworkImage, Date) {
        let epoch = sessionHistory.responseEpoch
        guard let audience = liveImpressionAudience(sessionID: sessionID, target: target) else { throw CancellationError() }
        let current: @MainActor @Sendable () -> Bool = { [weak self] in
            guard let self else { return false }
            return self.canRefreshSessionHistory && self.sessionHistory.responseEpoch == epoch &&
                self.liveImpressionIsCurrent(value, sessionID: sessionID, target: target) &&
                self.liveImpressionAudience(sessionID: sessionID, target: target) == audience
        }
        guard current(), value.photos.contains(photo) else { throw CancellationError() }
        return try await withHomeAssistantClient(allowsOperationReplay: false) { client in
            guard current() else { throw CancellationError() }
            let media = try await client.prepareLiveImpressionPhoto(sessionID: sessionID, target: target,
                                                                    photo: photo, audience: audience, isCurrent: current)
            guard current(), let deadline = media.artwork.expiresAt.flatMap(DJConnectHistoryEntry.date) else { throw CancellationError() }
            let image = try await client.liveImpressionPhoto(media, photo: photo, sessionID: sessionID,
                                                            target: target, audience: audience, isCurrent: current)
            return (image, deadline)
        }
    }
}

/// Keep the same photo and narrative mounted while native widths change.
struct LiveImpressionLayout: Layout {
    private func wide(_ width: CGFloat?) -> Bool { (width ?? 0) >= 700 }
    private func photoWidth(_ width: CGFloat) -> CGFloat { min(540, (width - 20) * 0.55) }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2, wide(proposal.width), let width = proposal.width else {
            let layout = AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            var cache = layout.makeCache(subviews: subviews)
            return layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
        }
        let photo = subviews[0].sizeThatFits(.init(width: photoWidth(width), height: nil))
        let narrative = subviews[1].sizeThatFits(.init(width: width - photoWidth(width) - 20, height: nil))
        return .init(width: width, height: max(photo.height, narrative.height))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2, wide(bounds.width) else {
            let layout = AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            var cache = layout.makeCache(subviews: subviews)
            layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
            return
        }
        let width = photoWidth(bounds.width)
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .init(width: width, height: nil))
        subviews[1].place(at: .init(x: bounds.minX + width + 20, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: bounds.width - width - 20, height: nil))
    }
}

/// Shared current/history renderer. Only original-photo byte reads happen here.
struct LiveImpressionContentView: View {
    let impression: DJConnectLiveImpression
    let title: String
    let lead: String
    let story: String
    let language: String
    let sessionID: String
    let target: DJConnectSessionMedia.Target
    @ObservedObject var model: DJConnectAppModel
    var currentAvatar: AnyView? = nil
    var activity: ((AskDJMomentsPresentation.Hold, Bool) -> Void)? = nil
    @State private var selectedPhoto = 0
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.live_impression." + key, language: language) }
    var body: some View {
        LiveImpressionStoryView(impression: impression, title: title, lead: lead, story: story, language: language, avatar: currentAvatar, expansionChanged: { activity?(.expandedText, $0) }) { photo }
    }
    private var photo: some View {
        VStack(alignment: .leading, spacing: 8) {
            if impression.photos.indices.contains(selectedPhoto) {
                LiveImpressionPhotoView(impression: impression, photo: impression.photos[selectedPhoto],
                    language: language, sessionID: sessionID, target: target, model: model, photoChanged: { activity?(.photo, $0) })
            }
            if impression.photos.count > 1 {
                HStack {
                    ForEach(Array(impression.photos.enumerated()), id: \.element.id) { index, _ in
                        Button { selectedPhoto = index } label: {
                            Text(String(format: text("photo_number"), index + 1, impression.photos.count))
                                .font(.caption).frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedPhoto == index ? [.isSelected] : [])
                    }
                }
            }
        }
    }
 }

/// Pure shared presentation, independent of the owner/network pixel adapter.
struct LiveImpressionStoryView<PhotoContent: View>: View {
    let impression: DJConnectLiveImpression
    let title: String
    let lead: String
    let story: String
    let language: String
    var avatar: AnyView? = nil
    var expansionChanged: ((Bool) -> Void)? = nil
    @ViewBuilder let photo: () -> PhotoContent
    @State private var expanded = false
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.live_impression." + key, language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let avatar { avatar }
                else {
                    DJPersonaAvatarView(confirmedMood: nil, language: language)
                        .frame(width: 28, height: 28).accessibilityHidden(true)
                }
                Text(text("title")).font(.caption.weight(.semibold)).accessibilityAddTraits(.isHeader)
            }
            LiveImpressionLayout { photo(); narrative }
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("live-impression-content")
    }
    private var narrative: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(impression.event.displayLine).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            Text(expanded ? story : lead).font(.title3).fixedSize(horizontal: false, vertical: true)
            if story != lead {
                Button(text(expanded ? "read_less" : "read_more")) { expanded.toggle(); expansionChanged?(expanded) }
                    .frame(minHeight: 44).accessibilityIdentifier("live-impression-expand")
            }
        }
    }
}

/// Owns the generation and every pixel/sheet write, including cancellation cleanup.
struct LiveImpressionPhotoState {
    private(set) var generation = UUID()
    private(set) var pixels: DJConnectSessionArtworkImage?
    private(set) var isLoading = false
    private(set) var withdrawn = false
    var showsPhoto = false
    mutating func begin() -> UUID {
        generation = UUID(); pixels = nil; showsPhoto = false; isLoading = true; withdrawn = false
        return generation
    }
    mutating func complete(_ image: DJConnectSessionArtworkImage, generation token: UUID) {
        guard generation == token else { return }
        pixels = image; isLoading = false
    }
    mutating func fail(generation token: UUID, withdrawn: Bool) {
        guard generation == token else { return }
        pixels = nil; showsPhoto = false; isLoading = false; self.withdrawn = withdrawn
    }
    mutating func finish(generation token: UUID) {
        guard generation == token else { return }
        pixels = nil; showsPhoto = false; isLoading = false
    }
}

private struct LiveImpressionPhotoView: View {
    let impression: DJConnectLiveImpression
    let photo: DJConnectLiveImpression.Photo
    let language: String
    let sessionID: String
    let target: DJConnectSessionMedia.Target
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    let photoChanged: ((Bool) -> Void)?
    @Environment(\.scenePhase) private var phase
    @State private var presentation = LiveImpressionPhotoState()
    @State private var zoom: CGFloat = 1
    @State private var retry = UUID()
    private struct Key: Equatable {
        let value: DJConnectLiveImpression
        let photo: DJConnectLiveImpression.Photo
        let owner: UUID
        let target: DJConnectSessionMedia.Target
        let sessionID: String
        let active: Bool
        let retry: UUID
        let audience: DJConnectSessionMedia.Audience?
    }
    init(impression: DJConnectLiveImpression, photo: DJConnectLiveImpression.Photo, language: String,
         sessionID: String, target: DJConnectSessionMedia.Target, model: DJConnectAppModel, photoChanged: ((Bool) -> Void)? = nil) {
        self.impression = impression; self.photo = photo; self.language = language
        self.sessionID = sessionID; self.target = target; self.model = model; history = model.sessionHistory; self.photoChanged = photoChanged
    }
    private var key: Key { .init(value: impression, photo: photo, owner: history.responseEpoch,
        target: target, sessionID: sessionID, active: phase == .active && model.liveImpressionIsCurrent(impression, sessionID: sessionID, target: target), retry: retry,
        audience: model.liveImpressionAudience(sessionID: sessionID, target: target)) }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.live_impression." + key, language: language) }
    var body: some View {
        LiveImpressionPhotoPresentation(photo: photo, pixels: key.active ? presentation.pixels : nil,
            isLoading: key.active && presentation.isLoading, allowsRetry: key.active && !presentation.withdrawn, language: language,
            isWithdrawn: presentation.withdrawn,
            open: { zoom = 1; presentation.showsPhoto = true }, retry: { retry = UUID() })
        .onChange(of: presentation.showsPhoto) { _, visible in photoChanged?(visible) }
        .sheet(isPresented: $presentation.showsPhoto) {
            NavigationStack {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 12) {
                        if key.active, let pixels = presentation.pixels {
                            Image(decorative: pixels.image, scale: 1).resizable().scaledToFit()
                                .frame(width: min(CGFloat(pixels.image.width), 800) * zoom)
                                .accessibilityLabel(photo.accessibilityText(language: language))
                        }
                        LiveImpressionPhotoCredit(photo: photo)
                    }.padding(20)
                }
                .toolbar {
                    ToolbarItemGroup {
                        Button(text("zoom_out"), systemImage: "minus.magnifyingglass") { zoom = max(1, zoom - 0.5) }.disabled(zoom <= 1)
                        Button(text("zoom_in"), systemImage: "plus.magnifyingglass") { zoom = min(4, zoom + 0.5) }.disabled(zoom >= 4)
                        Button(DJConnectLocalization.localized(key: "ui.close", language: language)) { presentation.showsPhoto = false }
                    }
                }
            }.frame(minWidth: 320, minHeight: 360)
        }
        .task(id: key) {
            let request = presentation.begin()
            let original = key
            defer { presentation.finish(generation: request) }
            guard original.active else { return }
            do {
                let (image, deadline) = try await model.loadLiveImpressionPhoto(impression, photo: photo,
                                                                             sessionID: sessionID, target: target)
                guard !Task.isCancelled, key == original else { return }
                presentation.complete(image, generation: request)
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            } catch {
                presentation.fail(generation: request, withdrawn: error as? DJConnectLiveImpressionMediaError == .withdrawn)
            }
        }
    }
 }

struct LiveImpressionPhotoPresentation: View {
    let photo: DJConnectLiveImpression.Photo
    let pixels: DJConnectSessionArtworkImage?
    let isLoading: Bool
    let allowsRetry: Bool
    let language: String
    var isWithdrawn = false
    var open: () -> Void = {}
    var retry: () -> Void = {}
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: "ui.live_impression." + key, language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let pixels {
                Button(action: open) {
                    Image(decorative: pixels.image, scale: 1).resizable().scaledToFit()
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(text("view_photo") + ". " + photo.accessibilityText(language: language))
                .accessibilityIdentifier("live-impression-hero")
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 100)
                    .accessibilityLabel(text("view_photo"))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text(isWithdrawn ? "photo_withdrawn" : "photo_unavailable")).font(.callout).foregroundStyle(.secondary)
                    if allowsRetry { Button(DJConnectLocalization.localized(key: "ui.retry", language: language), action: retry) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("live-impression-photo-unavailable")
            }
            LiveImpressionPhotoCredit(photo: photo)
        }
    }
}

struct LiveImpressionPhotoCredit: View {
    let photo: DJConnectLiveImpression.Photo
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(photo.caption).font(.caption).fixedSize(horizontal: false, vertical: true)
            if let source = DJConnectLiveImpression.sourceURL(photo.sourceURL) {
                Link(photo.credit + " · " + photo.author, destination: source).font(.caption).buttonStyle(.plain).foregroundStyle(.white)
            }
            if let license = DJConnectLiveImpression.sourceURL(photo.licenseURL) {
                Link(photo.license, destination: license).font(.caption).buttonStyle(.plain).foregroundStyle(.white)
            }
        }
    }
}
