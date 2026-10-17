import SwiftUI
import DJConnectCore

extension DJConnectAppModel {
    func sessionArtworkIsCurrent(_ media: DJConnectSessionMedia, target: DJConnectSessionMedia.Target,
                                 audience: DJConnectSessionMedia.Audience) -> Bool {
        guard canRefreshSessionHistory,
              media.admittedArtwork(session: media.sessionID, target: target, audience: audience) != nil else { return false }
        switch target {
        case .moment(let id):
            guard let session = activeDJSession, session.id == media.sessionID,
                  session.broadcast.sessionMedia.filter({ $0.target == target }).count == 1,
                  session.broadcast.sessionMedia.contains(media) else { return false }
            if audience == .current {
                return session.broadcast.nativeCurrentMoment(at: Date(), spotifyAttributionAvailable: spotifyAttributionLogo != nil)?.id == id
            }
            return audience == .activeFlow && session.broadcast.nativeFlowMoments(at: Date()).contains { $0.id == id }
        case .entry(let id):
            if audience != .history && activeDJSession?.id != media.sessionID { return false }
            let entries = sessionHistory.timelines.values.flatMap(\.entries)
                + sessionHistory.historicalMatches.values.flatMap { $0 } + sessionHistory.searchMatches
            return entries.contains { $0.id == id && $0.sessionID == media.sessionID && $0.isRetained() && $0.sessionMedia == media }
        }
    }

    /// Pure byte read over an already supplied owner grant. This never prepares
    /// media, renews history or changes the original semantic Moment.
    func loadSessionArtwork(_ media: DJConnectSessionMedia, target: DJConnectSessionMedia.Target,
                            audience: DJConnectSessionMedia.Audience) async throws -> DJConnectSessionArtworkImage {
        let epoch = sessionHistory.responseEpoch
        guard sessionArtworkIsCurrent(media, target: target, audience: audience) else { throw CancellationError() }
        let image = try await withHomeAssistantClient { client in
            try await client.sessionArtwork(media, sessionID: media.sessionID, target: target, audience: audience)
        }
        guard !Task.isCancelled, sessionArtworkIsCurrent(media, target: target, audience: audience), epoch == sessionHistory.responseEpoch else { throw CancellationError() }
        return image
    }
}

/// One ephemeral native artwork renderer. No URLCache, persisted pixels or
/// borrowing from Now Playing. Only the image subtree changes with media state.
struct SessionArtworkView: View {
    let media: DJConnectSessionMedia
    let target: DJConnectSessionMedia.Target
    let audience: DJConnectSessionMedia.Audience
    let language: String
    @ObservedObject var model: DJConnectAppModel
    @ObservedObject private var history: DJConnectSessionHistoryModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var pixels: DJConnectSessionArtworkImage?
    @State private var loadedKey: Key?
    @State private var generation = UUID()

    private struct Key: Equatable {
        let media: DJConnectSessionMedia
        let epoch: UUID
        let target: DJConnectSessionMedia.Target
        let audience: DJConnectSessionMedia.Audience
        let active: Bool
    }
    init(media: DJConnectSessionMedia, target: DJConnectSessionMedia.Target,
         audience: DJConnectSessionMedia.Audience, language: String, model: DJConnectAppModel) {
        self.media = media; self.target = target; self.audience = audience
        self.language = language; self.model = model; history = model.sessionHistory
    }
    private var key: Key {
        Key(media: media, epoch: history.responseEpoch, target: target, audience: audience,
            active: scenePhase == .active && model.sessionArtworkIsCurrent(media, target: target, audience: audience))
    }
    var body: some View {
        // Grant/task expiry already owns pixel withdrawal; no per-image 1Hz work.
        TimelineView(.explicit(([Date()] + [media.artwork.expiresAt.flatMap(DJConnectHistoryEntry.date)].compactMap { $0 }).sorted())) { clock in
            if key.active, loadedKey == key, let pixels,
               let grant = media.admittedArtwork(session: media.sessionID, target: target, audience: audience, at: clock.date),
               let source = grant.sourceURL.flatMap(URL.init(string:)), let logo = spotifyAttributionLogo {
                VStack(alignment: .leading, spacing: 8) {
                    // Preserve the source aspect ratio and round inside the glass inset.
                    Image(decorative: pixels.image, scale: 1)
                        .resizable().scaledToFit()
                        .frame(width: 100 * CGFloat(pixels.image.width) / CGFloat(max(pixels.image.width, pixels.image.height)),
                               height: 100 * CGFloat(pixels.image.height) / CGFloat(max(pixels.image.width, pixels.image.height)))
                        .clipShape(RoundedRectangle(cornerRadius: DJConnectCardAppearance.cornerRadius - 8, style: .continuous))
                        .accessibilityLabel(grant.altText?[language] ?? grant.altText?["en"] ?? "")
                        .accessibilityIdentifier("session-authorized-artwork")
                        .padding(8).djSessionFrostedSurface()
                    Link(destination: source) {
                        logo.resizable().scaledToFit().frame(width: 70, height: 20)
                            .padding(10).frame(minHeight: 44)
                    }
                    .accessibilityLabel("Spotify")
                    .accessibilityValue(source.absoluteString)
                }
            }
        }
        .task(id: key) {
            let currentKey = key
            let request = UUID(); generation = request
            pixels = nil; loadedKey = nil
            guard currentKey.active, spotifyAttributionLogo != nil,
                  let grant = media.admittedArtwork(session: media.sessionID, target: target, audience: audience),
                  let deadline = grant.expiresAt.flatMap(DJConnectHistoryEntry.date) else { return }
            defer {
                if generation == request { pixels = nil; loadedKey = nil }
            }
            do {
                let result = try await model.loadSessionArtwork(media, target: target, audience: audience)
                guard !Task.isCancelled, currentKey == key, generation == request else { return }
                pixels = result; loadedKey = currentKey
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            } catch {
                // Optional-image failure leaves original text, controls, pairing
                // and reading position intact. No implicit prepare/retry loop.
            }
        }
    }
}
