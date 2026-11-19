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
    private var sourceSnapshot: [DJConnectHistoryEntry]?
    private var preparedSnapshot: [SessionTimelineRenderEntry] = []
    private var validFrom: Date?
    private var validUntil: Date?

    private struct FlowInput: Equatable {
        let retained: [SessionTimelineRenderEntry]
        let session: DJConnectBroadcastState.Session?
        let playbackState: String?
        let playbackItem: String?
        let delivery: DJConnectNativeMomentDelivery?
        let items: [DJConnectSessionFlowItem]
        let moments: [DJConnectMoment]
        let admitsLive: Bool
        let withdrawals: Set<String>
    }
    private var flowProjection: (input: FlowInput, from: Date, until: Date?, rows: [SessionTimelineLiveRow])?

    func flowRows(retained: [SessionTimelineRenderEntry], broadcast: DJConnectBroadcastState?,
                  admitsLive: Bool, withdrawals: Set<String>, deadlines: [Date], at date: Date,
                  prepare: () -> [SessionTimelineLiveRow]) -> [SessionTimelineLiveRow] {
        // Playback progress and unrelated broadcast fields do not affect admission.
        let input = FlowInput(retained: retained, session: broadcast?.session,
            playbackState: broadcast?.playback?.state, playbackItem: broadcast?.playback?.itemID,
            delivery: broadcast?.nativeDelivery, items: broadcast?.sessionFlow.items ?? [],
            moments: broadcast?.djMoments ?? [], admitsLive: admitsLive, withdrawals: withdrawals)
        if let cached = flowProjection, cached.input == input, date >= cached.from,
           cached.until.map({ date < $0 }) ?? true {
            return cached.rows
        }
        let rows = prepare()
        flowProjection = (input, date, deadlines.filter { $0 > date }.min(), rows)
        return rows
    }

    func snapshot(_ source: [DJConnectHistoryEntry], sessionID: String, epoch: UUID,
                  at date: Date = Date()) -> [SessionTimelineRenderEntry] {
        if self.sessionID != sessionID || self.epoch != epoch { clear() }
        self.sessionID = sessionID; self.epoch = epoch
        if sourceSnapshot == source, let validFrom, date >= validFrom,
           validUntil.map({ date < $0 }) ?? true {
            return preparedSnapshot
        }
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
        // Cache the whole preparation only while every input row is retained.
        // Do not keep an extra copy of expired/withdrawn input rows here.
        sourceSnapshot = result.count == source.count ? source : nil
        preparedSnapshot = sourceSnapshot == nil ? [] : result
        validFrom = date
        validUntil = result.flatMap { [$0.deadline, $0.artworkDeadline].compactMap { $0 } }
            .filter { $0 > date }.min()
        return result
    }
    func clear() {
        sessionID = nil; epoch = nil; entries.removeAll()
        sourceSnapshot = nil; preparedSnapshot = []; validFrom = nil; validUntil = nil
        flowProjection = nil
    }
}
