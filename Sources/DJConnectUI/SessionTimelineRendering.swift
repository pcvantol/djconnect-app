import SwiftUI
import DJConnectCore

/// Ephemeral render preparation only. Core remains the history and retention authority.
struct SessionTimelineRenderEntry: Equatable, Identifiable {
    let entry: DJConnectHistoryEntry
    let occurredAt: Date?
    let deadline: Date?
    let artworkDeadline: Date?
    let message: DJConnectAskDJMessage
    var id: String { entry.id }
    func isRetained(at date: Date) -> Bool {
        !entry.entryID.isEmpty && !entry.sessionID.isEmpty && entry.order > 0 &&
        occurredAt != nil && deadline.map { $0 > date } == true
    }
}

@MainActor final class SessionTimelineRenderCache: ObservableObject {
    private var sessionID: String?
    private var epoch: UUID?
    private var entries: [String: SessionTimelineRenderEntry] = [:]

    func snapshot(_ source: [DJConnectHistoryEntry], sessionID: String, epoch: UUID,
                  at date: Date = Date()) -> [SessionTimelineRenderEntry] {
        if self.sessionID != sessionID || self.epoch != epoch { clear() }
        self.sessionID = sessionID; self.epoch = epoch
        var live: [String: SessionTimelineRenderEntry] = [:]
        let result = source.compactMap { entry -> SessionTimelineRenderEntry? in
            let prepared: SessionTimelineRenderEntry
            if let previous = entries[entry.id], previous.entry == entry {
                prepared = previous
            } else {
                let occurred = DJConnectHistoryEntry.date(entry.occurredAt)
                prepared = SessionTimelineRenderEntry(entry: entry, occurredAt: occurred,
                    deadline: DJConnectHistoryEntry.date(entry.retainedUntil),
                    artworkDeadline: entry.sessionMedia?.artwork.expiresAt.flatMap(DJConnectHistoryEntry.date),
                    message: DJConnectAskDJMessage(id: entries[entry.id]?.message.id ?? UUID(),
                        serverID: entry.originMessageID, clientMessageID: entry.clientMessageID,
                        role: entry.kind == .conversationUser ? .user : .dj,
                        text: entry.text ?? "", createdAt: occurred ?? .distantPast))
            }
            guard prepared.isRetained(at: date) else { return nil }
            live[entry.id] = prepared
            return prepared
        }
        entries = live // Drop removed/expired values immediately; no durable cache.
        return result
    }
    func clear() { sessionID = nil; epoch = nil; entries.removeAll() }
}

/// Fade once on lazy appearance, without a transition driven by every scroll frame.
struct SessionRowFade: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var selected: Bool
    func body(content: Content) -> some View {
        content.opacity(reduceMotion || selected || appeared ? 1 : 0)
            .onAppear {
                guard !appeared else { return }
                withAnimation(reduceMotion || selected ? nil : .easeOut(duration: 0.12)) { appeared = true }
            }
    }
}
