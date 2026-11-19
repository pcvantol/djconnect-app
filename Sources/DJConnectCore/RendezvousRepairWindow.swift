import Foundation

/// Install-local accounting for the two explicit same-key recovery attempts
/// allowed during a paused 24h repair window. Persist before external work.
/// This is neither a Keychain store nor permission to generate a replacement.
public struct RendezvousRepairWindow: Codable, Sendable {
    public enum Outcome: String, Codable, Sendable { case recovered, paused }
    public enum Failure: Error, Sendable {
        case invalidState, resolved, windowEnded, exhausted, inFlight, notYetEligible
    }
    private struct Attempt: Codable, Sendable {
        let id: UUID
        let startedAtMS: Int64
        var completedAtMS: Int64?
        var outcome: Outcome?
    }

    private let schemaVersion = 1
    public let keyIdentifier: String
    public let pausedAtMS: Int64
    public let windowEndsAtMS: Int64
    private var attempts: [Attempt] = []
    private var serverNotBeforeMS: Int64
    private var lastObservedMS: Int64

    public var attemptsStarted: Int { attempts.count }
    public var isResolved: Bool { attempts.last?.outcome == .recovered }
    public var reservation: UUID? {
        guard let last = attempts.last, last.outcome == nil else { return nil }
        return last.id
    }

    public init(keyIdentifier: String, pausedAtMS: Int64) throws {
        let (end, overflow) = pausedAtMS.addingReportingOverflow(86_400_000)
        guard !keyIdentifier.isEmpty, pausedAtMS >= 0, !overflow else { throw Failure.invalidState }
        self.keyIdentifier = keyIdentifier
        self.pausedAtMS = pausedAtMS
        self.windowEndsAtMS = end
        self.serverNotBeforeMS = pausedAtMS
        self.lastObservedMS = pausedAtMS
    }

    /// A later server hint can delay work, never replenish or advance it.
    public mutating func delayRecovery(until notBeforeMS: Int64, at nowMS: Int64) throws {
        guard notBeforeMS >= 0 else { throw Failure.invalidState }
        try observe(nowMS)
        serverNotBeforeMS = max(serverNotBeforeMS, notBeforeMS)
    }

    /// Call only for an explicit user retry, never a scan/resume/background event.
    /// Conservatively wait 60s after first entering pause as well as between starts.
    public mutating func reserveExplicitRecovery(at nowMS: Int64) throws -> UUID {
        try observe(nowMS)
        guard !isResolved else { throw Failure.resolved }
        guard nowMS < windowEndsAtMS else { throw Failure.windowEnded }
        guard reservation == nil else { throw Failure.inFlight }
        guard attempts.count < 2 else { throw Failure.exhausted }
        let origin = attempts.last?.startedAtMS ?? pausedAtMS
        let (eligible, overflow) = origin.addingReportingOverflow(60_000)
        guard !overflow, nowMS >= max(eligible, serverNotBeforeMS) else { throw Failure.notYetEligible }
        let id = UUID()
        attempts.append(Attempt(id: id, startedAtMS: nowMS))
        return id
    }

    /// The caller must independently validate the original recovery challenge,
    /// returned original key expiry and owner context before reporting recovered.
    /// Finishing after this repair window does not extend that challenge/key.
    public mutating func complete(_ id: UUID, outcome: Outcome, at nowMS: Int64) throws {
        guard reservation == id else { throw Failure.invalidState }
        try observe(nowMS)
        let index = attempts.count - 1
        attempts[index].completedAtMS = nowMS
        attempts[index].outcome = outcome
    }

    private mutating func observe(_ nowMS: Int64) throws {
        guard nowMS >= lastObservedMS else { throw Failure.invalidState }
        lastObservedMS = nowMS
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, keyIdentifier, pausedAtMS, windowEndsAtMS, attempts, serverNotBeforeMS, lastObservedMS
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(Int.self, forKey: .schemaVersion) == 1 else { throw Failure.invalidState }
        keyIdentifier = try c.decode(String.self, forKey: .keyIdentifier)
        pausedAtMS = try c.decode(Int64.self, forKey: .pausedAtMS)
        windowEndsAtMS = try c.decode(Int64.self, forKey: .windowEndsAtMS)
        attempts = try c.decode([Attempt].self, forKey: .attempts)
        serverNotBeforeMS = try c.decode(Int64.self, forKey: .serverNotBeforeMS)
        lastObservedMS = try c.decode(Int64.self, forKey: .lastObservedMS)
        guard !keyIdentifier.isEmpty, pausedAtMS >= 0, windowEndsAtMS > pausedAtMS,
              windowEndsAtMS - pausedAtMS == 86_400_000,
              lastObservedMS >= pausedAtMS, serverNotBeforeMS >= pausedAtMS,
              attempts.count <= 2, Set(attempts.map(\.id)).count == attempts.count else {
            throw Failure.invalidState
        }
        var previousStart = pausedAtMS
        var previousCompletion = pausedAtMS
        for (index, attempt) in attempts.enumerated() {
            guard attempt.startedAtMS >= previousStart,
                  attempt.startedAtMS - previousStart >= 60_000,
                  attempt.startedAtMS >= previousCompletion,
                  attempt.startedAtMS < windowEndsAtMS,
                  attempt.startedAtMS <= lastObservedMS,
                  (attempt.completedAtMS == nil) == (attempt.outcome == nil) else {
                throw Failure.invalidState
            }
            if let completion = attempt.completedAtMS {
                guard completion >= attempt.startedAtMS, completion <= lastObservedMS else { throw Failure.invalidState }
                previousCompletion = completion
            } else {
                guard index == attempts.count - 1 else { throw Failure.invalidState }
            }
            if attempt.outcome == .recovered {
                guard index == attempts.count - 1 else { throw Failure.invalidState }
            }
            previousStart = attempt.startedAtMS
        }
    }
}
