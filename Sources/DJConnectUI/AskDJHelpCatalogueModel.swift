import Combine
import Foundation
import DJConnectCore

/// Presentation adapter seam, not a proposed HTTP contract. No production reader
/// is installed until Core delivers its qualified current-configuration contract.
@MainActor final class AskDJHelpCatalogueModel: ObservableObject {
    typealias Reader = @MainActor (DJConnectAskDJCatalogue.Context, DJConnectAskDJCatalogue.Surface, String) async throws -> Set<String>
    @Published private(set) var sections: [DJConnectAskDJCatalogue.CatalogueSection] = []
    @Published private(set) var busy = false
    private var generation = UUID()
    private var deadline: ContinuousClock.Instant?
    private var expiry: Task<Void, Never>?
    private let now: () -> ContinuousClock.Instant
    init(now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }) { self.now = now }

    func close() {
        generation = UUID(); deadline = nil
        expiry?.cancel(); expiry = nil
        sections = []; busy = false
    }

    /// Every open and every explicit catalogue click gets its own read. Renders,
    /// progress and expiry never poll or renew an observation.
    func read(catalogue: DJConnectAskDJCatalogue?, surface: DJConnectAskDJCatalogue.Surface,
              language: String, context: @escaping () -> DJConnectAskDJCatalogue.Context,
              reader: Reader?) async -> [DJConnectAskDJCatalogue.CatalogueSection]? {
        close()
        guard let catalogue, let reader else { return nil }
        let original = context(), captured = generation
        let limit = now().advanced(by: .seconds(15)); deadline = limit
        busy = true
        defer { if captured == generation { busy = false } }
        do {
            let ids = try await reader(original, surface, language)
            guard !Task.isCancelled, captured == generation, context() == original, now() < limit else {
                if captured == generation { close() }
                return nil
            }
            let result = catalogue.catalogueSections(original, surface: surface, language: language, eligibleIDs: ids)
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
