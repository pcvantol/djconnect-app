import Foundation
import DJConnectCore

/// One ephemeral chronological projection. A Bulletin never becomes a history
/// entry or gains retention from a render, scroll or cache read.
enum SessionTimelineLiveRow: Identifiable {
    case history(SessionTimelineRenderEntry)
    case bulletin(DJConnectMoment)
    var id: String {
        switch self {
        case .history(let value): value.id
        case .bulletin(let value): "live-moment-" + value.id
        }
    }
    private var date: Date {
        switch self {
        case .history(let value): value.occurredAt ?? .distantPast
        case .bulletin(let value): DJConnectHistoryEntry.date(value.createdAt) ?? .distantPast
        }
    }
    static func merge(retained: [SessionTimelineRenderEntry], bulletins: [DJConnectMoment], at now: Date, omittingMomentIDs: Set<String> = []) -> [Self] {
        var seen = Set<String>()
        let unique = bulletins.filter { $0.isBulletinV1 && seen.insert($0.id).inserted }
        let published = Set(unique.map(\.id)).union(omittingMomentIDs)
        let history = retained.reversed().filter { $0.isRetained(at: now) && !($0.entry.momentID.map(published.contains) ?? false) }
            .map(Self.history)
        let rows = history + unique.map(Self.bulletin)
        return rows.enumerated().sorted {
            $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date > $1.element.date
        }.map(\.element)
    }
}
