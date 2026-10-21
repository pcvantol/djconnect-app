import Foundation

/// Immutable build input for one reviewed fixed-QA run. Never loaded from user
/// defaults, QR content or a runtime host selector. The external run manifest
/// separately binds the final signed artifact, signature and installer readback.
struct RendezvousNativeRunPolicy: Codable, Equatable, Sendable {
    let identifier: String
    let bundleID: String
    let build: String
    let teamID: String
    let applicationIdentifier: String
    let environment: String
    let provisioningProfileSHA256: String
    let serviceOrigin: String
    let browserOrigin: String
    let validFromMS: Int64
    let validUntilMS: Int64

    func validate() throws {
        guard let id = UUID(uuidString: identifier), id.uuidString.lowercased() == identifier,
              bundleID == "dev.djconnect.ios.vibecastqa", teamID == "ZEML4LPXH4",
              applicationIdentifier == teamID + "." + bundleID, environment == "development",
              let number = Int(build), number >= 40407, String(number) == build,
              provisioningProfileSHA256.utf8.count == 64,
              provisioningProfileSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              serviceOrigin == "https://api-vibecast-qa.djconnect.dev", browserOrigin == "https://qa.vibecast.tv",
              validFromMS >= 0, validUntilMS > validFromMS,
              validUntilMS <= 9_007_199_254_740_991,
              validUntilMS - validFromMS <= 7_200_000 else { throw RendezvousNativeRunGate.Failure.notAdmitted }
    }
}

enum RendezvousNativeEffect: String, Codable, CaseIterable, Sendable {
    case generateKey, attestKey, generateAssertion
}

struct RendezvousNativeRunContext: Sendable {
    let bundleID: String
    let build: String
    let provisioningProfileSHA256: String
    let serviceOrigin: String
    let browserOrigin: String
    let physicalIOSDevice: Bool
    let foreground: Bool
}

/// Synchronous MainActor serialization and protected persist-before-effect.
/// Exactly one generate, one attest and one assert, in that order, within the
/// original ten-minute run. Restart, late completion or a failed SDK call never
/// refunds a reservation or grants another run.
@MainActor final class RendezvousNativeRunGate {
    enum Failure: Error, Sendable { case notAdmitted, invalidState, exhausted }
    private let policy: RendezvousNativeRunPolicy
    private let storage: any RendezvousRepairStorage
    init(policy: RendezvousNativeRunPolicy, storage: any RendezvousRepairStorage) throws {
        try policy.validate()
        self.policy = policy; self.storage = storage
    }
    func isEligible(_ context: RendezvousNativeRunContext, at now: Int64, uptime: TimeInterval,
                    newConnection: Bool) -> Bool {
        do {
            try validate(context, at: now, uptime: uptime)
            if let record = try read() {
                try record.validate(policy: policy, at: now, uptime: uptime)
                if newConnection && record.effects.count == 3 { return false }
            }
            return true
        } catch { return false }
    }
    func reserve(_ effect: RendezvousNativeEffect, context: RendezvousNativeRunContext,
                 at now: Int64, uptime: TimeInterval) throws {
        try validate(context, at: now, uptime: uptime)
        var record = try read() ?? Record(policyID: policy.identifier, startedAtMS: now,
            startedUptime: uptime, lastObservedMS: now, lastObservedUptime: uptime)
        try record.validate(policy: policy, at: now, uptime: uptime)
        guard record.effects.count < 3,
              RendezvousNativeEffect.allCases[record.effects.count] == effect else { throw Failure.exhausted }
        record.lastObservedMS = now; record.lastObservedUptime = uptime
        record.effects.append(effect)
        let data = try JSONEncoder().encode(record)
        guard data.count <= 4096 else { throw Failure.invalidState }
        // A commit-then-error remains consumed. Do not retry this write/effect.
        try storage.write(data)
    }
    private func validate(_ context: RendezvousNativeRunContext, at now: Int64, uptime: TimeInterval) throws {
        guard now >= policy.validFromMS, now < policy.validUntilMS,
              uptime.isFinite, uptime >= 0, context.physicalIOSDevice, context.foreground,
              context.bundleID == policy.bundleID, context.build == policy.build,
              context.provisioningProfileSHA256 == policy.provisioningProfileSHA256,
              context.serviceOrigin == policy.serviceOrigin, context.browserOrigin == policy.browserOrigin else {
            throw Failure.notAdmitted
        }
    }
    private func read() throws -> Record? {
        guard let data = try storage.read() else { return nil }
        guard !data.isEmpty, data.count <= 4096 else { throw Failure.invalidState }
        let record = try JSONDecoder().decode(Record.self, from: data)
        guard record.schemaVersion == 1, record.policyID == policy.identifier,
              (1...3).contains(record.effects.count),
              record.effects == Array(RendezvousNativeEffect.allCases.prefix(record.effects.count)) else { throw Failure.invalidState }
        return record
    }
    private struct Record: Codable {
        var schemaVersion = 1
        let policyID: String
        let startedAtMS: Int64
        let startedUptime: TimeInterval
        var lastObservedMS: Int64
        var lastObservedUptime: TimeInterval
        var effects: [RendezvousNativeEffect] = []
        func validate(policy: RendezvousNativeRunPolicy, at now: Int64, uptime: TimeInterval) throws {
            guard policyID == policy.identifier, startedAtMS >= policy.validFromMS,
                  startedAtMS < policy.validUntilMS, startedUptime.isFinite, startedUptime >= 0,
                  lastObservedMS >= startedAtMS, lastObservedUptime.isFinite,
                  lastObservedUptime >= startedUptime, now >= lastObservedMS, uptime >= lastObservedUptime,
                  now >= startedAtMS, now - startedAtMS < 600_000,
                  uptime >= startedUptime, uptime - startedUptime < 600 else { throw Failure.invalidState }
        }
    }
}
