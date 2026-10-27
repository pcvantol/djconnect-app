import Combine
import Foundation
import DJConnectCore

/// Bounded presentation owner for the qualified Core Help observation reader.
/// An observation narrows examples; it never grants execution authority.
@MainActor final class AskDJHelpCatalogueModel: ObservableObject {
    struct Observation: Sendable {
        let ids: Set<String>
        let trackID: String?
    }
    typealias Reader = @MainActor (DJConnectAskDJCatalogue.Context, DJConnectAskDJCatalogue.Surface, String, ContinuousClock.Instant) async throws -> Observation
    @Published private(set) var sections: [DJConnectAskDJCatalogue.CatalogueSection] = []
    @Published private(set) var busy = false
    @Published private(set) var admittedContext: DJConnectAskDJCatalogue.Context?
    private var generation = UUID()
    private var originalContext: DJConnectAskDJCatalogue.Context?
    private var readTask: Task<Observation, Error>?
    private var deadline: ContinuousClock.Instant?
    private var expiry: Task<Void, Never>?
    private let now: () -> ContinuousClock.Instant
    init(now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }) { self.now = now }

    func close() {
        generation = UUID(); deadline = nil
        originalContext = nil
        readTask?.cancel(); readTask = nil
        expiry?.cancel(); expiry = nil
        sections = []; admittedContext = nil; busy = false
    }

    /// Compare the original BASE projection, never our published admitted mask.
    /// A delayed callback for the context already captured by a new read is a
    /// no-op; an observed change retires even a still-busy original read.
    func contextChanged(to next: DJConnectAskDJCatalogue.Context) {
        guard let originalContext, originalContext != next else { return }
        close()
    }

    /// Every open and every explicit catalogue click gets its own read. Renders,
    /// progress and expiry never poll or renew an observation.
    func read(catalogue: DJConnectAskDJCatalogue?, surface: DJConnectAskDJCatalogue.Surface,
              language: String, context: @escaping @MainActor () -> DJConnectAskDJCatalogue.Context,
              reader: Reader?) async -> [DJConnectAskDJCatalogue.CatalogueSection]? {
        close()
        guard let catalogue, let reader else { return nil }
        let original = context(), captured = generation
        originalContext = original
        let limit = now().advanced(by: .seconds(15)); deadline = limit
        busy = true
        defer { if captured == generation { busy = false; readTask = nil } }
        do {
            let task = Task { @MainActor in
                guard !Task.isCancelled, captured == self.generation,
                      context() == original, self.now() < limit else { throw CancellationError() }
                return try await reader(original, surface, language, limit)
            }
            readTask = task
            let observation = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            let ids = observation.ids
            guard !Task.isCancelled, captured == generation, context() == original, now() < limit else {
                if captured == generation { close() }
                return nil
            }
            guard observation.trackID == nil || observation.trackID == original.trackID else { close(); return nil }
            var admitted = original; admitted.serverEligibleIDs = ids
            admitted.trackID = observation.trackID
            if observation.trackID == nil {
                admitted.slots = [:]
                for key in ["current_track", "current_album", "forecast_ready"] { admitted.flags[key] = false }
            }
            let result = catalogue.catalogueSections(admitted, surface: surface, language: language, eligibleIDs: ids)
            admittedContext = admitted
            sections = result
            let remaining = now().duration(to: limit)
            expiry = Task { @MainActor [weak self] in
                try? await Task.sleep(for: remaining)
                guard !Task.isCancelled, let self, captured == self.generation else { return }
                self.close()
            }
            return result
        } catch {
            if captured == generation { close() }
            return nil
        }
    }

    var isCurrent: Bool { deadline.map { now() < $0 } == true }
}

/// Only material playback/context inputs; ordinary progress, artwork and fresh
/// timestamp updates do not churn Help. Both sides use the same observation time.
struct AskDJHelpPlaybackProjection: Equatable {
    let state: String?
    let item: String?
    let title: String?
    let artist: String?
    let album: String?
    let source: String?
    let currentTrack: Bool
    init(_ playback: DJConnectSessionPlayback?, at now: Date) {
        state = playback?.state; item = playback?.itemID; title = playback?.title
        artist = playback?.artist; album = playback?.album; source = playback?.sourceURL
        if let stamp = DJConnectSessionForecast.timestamp(playback?.updatedAt) {
            currentTrack = (0..<30).contains(now.timeIntervalSince(stamp)) &&
                ["playing", "paused"].contains(state ?? "") && item?.isEmpty == false &&
                title?.isEmpty == false && artist?.isEmpty == false
        } else { currentTrack = false }
    }
}
