import Foundation

/// Foreground-only admission. Restoring a snapshot establishes a baseline;
/// scrolling/history reads never enqueue speech. Grants may arrive after text.
struct SessionSpeechAutoplayAdmission {
    private var sessionID: String?
    private var known = Set<String>()
    private var pending: [(id: String, at: Date)] = []

    mutating func reset() { self = .init() }

    mutating func observe(sessionID: String, momentIDs: [String], readyIDs: Set<String>,
                          enabled: Bool, now: Date = Date(), revokedIDs: Set<String> = []) -> [String] {
        guard self.sessionID == sessionID else {
            self.sessionID = sessionID; known = Set(momentIDs); pending = []
            return []
        }
        let new = momentIDs.filter { known.insert($0).inserted }
        if enabled { pending += new.map { ($0, now) } }
        else { pending = []; return [] }
        let visible = Set(momentIDs)
        pending.removeAll { !visible.contains($0.id) || revokedIDs.contains($0.id) || now.timeIntervalSince($0.at) >= 120 }
        let admitted = pending.filter { readyIDs.contains($0.id) }.map(\.id)
        pending.removeAll { readyIDs.contains($0.id) }
        if known.count > 512 { known = Set(momentIDs).union(pending.map(\.id)) }
        return admitted
    }
}
