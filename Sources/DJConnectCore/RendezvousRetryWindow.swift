import Foundation

/// Install-local retry accounting, serialized with its owning operation. This
/// value belongs in the protected attempt journal, not Profile or HA settings.
/// Persist each reservation before calling the SDK/transport. Restoring an
/// in-flight reservation deliberately does not authorize another call.
public struct RendezvousRetryWindow: Codable, Sendable {
    private let schemaVersion = 1
    public enum Kind: String, Codable, Sendable {
        case appleAttestation, registration, recovery
    }
    public enum Outcome: Sendable {
        case succeeded, terminalFailure, appleServerUnavailable, responseLost
    }
    public enum Failure: Error, Sendable {
        case invalidState, expired, closed, inFlight, notYetEligible
    }

    public let kind: Kind
    public let startedAtMS: Int64
    public let deadlineMS: Int64
    public private(set) var callsStarted = 0
    public private(set) var reservation: UUID?
    public private(set) var isClosed = false
    private var notBeforeMS: Int64
    private var lastObservedMS: Int64
    private var lastCompletionMS: Int64?

    public init(kind: Kind, startedAtMS: Int64, deadlineMS: Int64) throws {
        guard startedAtMS >= 0, deadlineMS > startedAtMS,
              deadlineMS - startedAtMS <= 120_000 else { throw Failure.invalidState }
        self.kind = kind
        self.startedAtMS = startedAtMS
        self.deadlineMS = deadlineMS
        self.notBeforeMS = startedAtMS
        self.lastObservedMS = startedAtMS
    }

    /// Returned identity binds completion to this particular reserved call.
    /// No SDK call, fresh challenge, key creation or timer is performed here.
    public mutating func reserve(at nowMS: Int64) throws -> UUID {
        try observe(nowMS)
        guard nowMS < deadlineMS else { throw Failure.expired }
        guard !isClosed, callsStarted < 3 else { throw Failure.closed }
        guard reservation == nil else { throw Failure.inFlight }
        guard nowMS >= notBeforeMS else { throw Failure.notYetEligible }
        let id = UUID()
        callsStarted += 1
        reservation = id
        return id
    }

    public mutating func complete(
        _ id: UUID, outcome: Outcome, at nowMS: Int64, retryNotBeforeMS: Int64? = nil
    ) throws {
        guard reservation == id else { throw Failure.invalidState }
        guard retryNotBeforeMS.map({ $0 >= 0 }) ?? true else { throw Failure.invalidState }
        try observe(nowMS)
        lastCompletionMS = nowMS
        reservation = nil
        guard nowMS < deadlineMS else { isClosed = true; throw Failure.expired }
        guard callsStarted < 3 else { isClosed = true; return }
        let retryable: Bool
        switch (kind, outcome) {
        case (.appleAttestation, .appleServerUnavailable),
             (.registration, .responseLost), (.recovery, .responseLost): retryable = true
        default: retryable = false
        }
        guard retryable else { isClosed = true; return }
        let delay: Int64 = callsStarted == 1 ? 2_000 : 5_000
        let (eligible, overflow) = nowMS.addingReportingOverflow(delay)
        guard !overflow else { isClosed = true; return }
        notBeforeMS = max(eligible, retryNotBeforeMS ?? eligible)
        if notBeforeMS >= deadlineMS { isClosed = true }
    }

    private mutating func observe(_ nowMS: Int64) throws {
        guard nowMS >= lastObservedMS else { throw Failure.invalidState }
        lastObservedMS = nowMS
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, kind, startedAtMS, deadlineMS, callsStarted, reservation, isClosed, notBeforeMS, lastObservedMS, lastCompletionMS
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(Int.self, forKey: .schemaVersion) == 1 else { throw Failure.invalidState }
        kind = try c.decode(Kind.self, forKey: .kind)
        startedAtMS = try c.decode(Int64.self, forKey: .startedAtMS)
        deadlineMS = try c.decode(Int64.self, forKey: .deadlineMS)
        callsStarted = try c.decode(Int.self, forKey: .callsStarted)
        reservation = try c.decodeIfPresent(UUID.self, forKey: .reservation)
        isClosed = try c.decode(Bool.self, forKey: .isClosed)
        notBeforeMS = try c.decode(Int64.self, forKey: .notBeforeMS)
        lastObservedMS = try c.decode(Int64.self, forKey: .lastObservedMS)
        lastCompletionMS = try c.decodeIfPresent(Int64.self, forKey: .lastCompletionMS)
        guard startedAtMS >= 0, deadlineMS > startedAtMS,
              deadlineMS - startedAtMS <= 120_000,
              (0...3).contains(callsStarted), lastObservedMS >= startedAtMS,
              notBeforeMS >= startedAtMS,
              !(isClosed && reservation != nil),
              !(callsStarted == 0 && (reservation != nil || isClosed || notBeforeMS != startedAtMS)),
              !(callsStarted > 0 && !isClosed && reservation == nil && notBeforeMS <= startedAtMS),
              !(callsStarted == 3 && !isClosed && reservation == nil) else {
            throw Failure.invalidState
        }
        if let completion = lastCompletionMS {
            guard completion >= startedAtMS, completion <= lastObservedMS,
                  callsStarted > 0 else { throw Failure.invalidState }
        }
        guard !(isClosed && lastCompletionMS == nil),
              !(reservation != nil && ((callsStarted == 1) != (lastCompletionMS == nil))) else {
            throw Failure.invalidState
        }
        if !isClosed, reservation == nil, callsStarted > 0 {
            guard let completion = lastCompletionMS else { throw Failure.invalidState }
            let delay: Int64 = callsStarted == 1 ? 2_000 : 5_000
            let (minimumEligibility, overflow) = completion.addingReportingOverflow(delay)
            guard !overflow, notBeforeMS >= minimumEligibility,
                  lastObservedMS >= deadlineMS || notBeforeMS > lastObservedMS else {
                throw Failure.invalidState
            }
        }
    }
}
