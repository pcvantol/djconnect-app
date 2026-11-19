import Foundation
import Testing
@testable import DJConnectCore

private final class NativeRunStore: RendezvousRepairStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: Data?
    var failWrite = false
    var commitBeforeFailure = false
    func read() throws -> Data? { lock.withLock { bytes } }
    func write(_ data: Data) throws {
        try lock.withLock {
            if failWrite {
                if commitBeforeFailure { bytes = data }
                throw NSError(domain: "synthetic-store", code: 1)
            }
            bytes = data
        }
    }
}
@MainActor @Suite struct RendezvousNativeRunGateTests {
    private var policy: RendezvousNativeRunPolicy {
        .init(identifier: "00000000-0000-4000-8000-000000000001", bundleID: "dev.djconnect.ios.vibecastqa",
            build: "40407", teamID: "ZEML4LPXH4", applicationIdentifier: "ZEML4LPXH4.dev.djconnect.ios.vibecastqa",
            environment: "development", provisioningProfileSHA256: String(repeating: "a", count: 64),
            serviceOrigin: "https://api-vibecast-qa.djconnect.dev", browserOrigin: "https://qa.vibecast.tv",
            validFromMS: 1000, validUntilMS: 7201000)
    }
    private func context(bundle: String = "dev.djconnect.ios.vibecastqa", build: String = "40407",
                         hash: String = String(repeating: "a", count: 64),
                         service: String = "https://api-vibecast-qa.djconnect.dev",
                         browser: String = "https://qa.vibecast.tv", device: Bool = true, foreground: Bool = true) -> RendezvousNativeRunContext {
        .init(bundleID: bundle, build: build, provisioningProfileSHA256: hash,
              serviceOrigin: service, browserOrigin: browser, physicalIOSDevice: device, foreground: foreground)
    }
    @Test func exactFiniteRunReservesBeforeThreeOrderedEffectsAndNeverRefunds() throws {
        let store = NativeRunStore(), gate = try RendezvousNativeRunGate(policy: policy, storage: store)
        var effects = 0
        for (index, action) in RendezvousNativeEffect.allCases.enumerated() {
            try gate.reserve(action, context: context(), at: 2000 + Int64(index), uptime: 10 + Double(index))
            #expect(try store.read() != nil)
            effects += 1 // Synthetic callback/provider, no hardware effect.
        }
        #expect(effects == 3)
        #expect(!gate.isEligible(context(), at: 3000, uptime: 13, newConnection: true))
        #expect(gate.isEligible(context(), at: 3000, uptime: 13, newConnection: false)) // Original submit may finish.
        let restored = try RendezvousNativeRunGate(policy: policy, storage: store)
        for action in RendezvousNativeEffect.allCases {
            #expect(throws: (any Error).self) { try restored.reserve(action, context: context(), at: 3000, uptime: 13) }
        }
        #expect(effects == 3)
    }
    @Test func wrongSignatureTupleRealmDeviceOrForegroundCannotStart() throws {
        for wrong in [context(bundle: "dev.djconnect.ios"), context(build: "40406"), context(hash: String(repeating: "b", count: 64)),
                      context(service: "https://api.djconnect.dev"), context(browser: "https://vibecast.tv"),
                      context(device: false), context(foreground: false)] {
            let store = NativeRunStore(), gate = try RendezvousNativeRunGate(policy: policy, storage: store)
            #expect(!gate.isEligible(wrong, at: 2000, uptime: 10, newConnection: true))
            #expect(throws: (any Error).self) { try gate.reserve(.generateKey, context: wrong, at: 2000, uptime: 10) }
            #expect(try store.read() == nil)
        }
    }
    @Test func wrongOrderNoNewWindowAndBothClocksAreBound() throws {
        let store = NativeRunStore(), gate = try RendezvousNativeRunGate(policy: policy, storage: store)
        #expect(throws: (any Error).self) { try gate.reserve(.generateAssertion, context: context(), at: 2000, uptime: 10) }
        #expect(try store.read() == nil)
        try gate.reserve(.generateKey, context: context(), at: 2000, uptime: 10)
        for (now, up) in [(Int64(1999), 11.0), (3000, 9.0), (602000, 11.0), (3000, 610.0), (3000, Double.nan)] {
            #expect(!gate.isEligible(context(), at: now, uptime: up, newConnection: false))
            #expect(throws: (any Error).self) { try gate.reserve(.attestKey, context: context(), at: now, uptime: up) }
        }
        #expect(!gate.isEligible(context(), at: 7201000, uptime: 11, newConnection: false))
    }
    @Test(arguments: [false, true]) func failedReservationNeverStartsAnEffect(commitFirst: Bool) throws {
        let store = NativeRunStore(), gate = try RendezvousNativeRunGate(policy: policy, storage: store)
        store.failWrite = true; store.commitBeforeFailure = commitFirst
        var effects = 0
        do { try gate.reserve(.generateKey, context: context(), at: 2000, uptime: 10); effects += 1 } catch {}
        #expect(effects == 0)
        if commitFirst {
            store.failWrite = false
            #expect(throws: (any Error).self) { try gate.reserve(.generateKey, context: context(), at: 2001, uptime: 11) }
        }
    }
    @Test func malformedOrBroadenedPoliciesAreNotSelectable() throws {
        let original = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(policy)) as? [String: Any])
        for (key, value) in [("environment", "production" as Any), ("teamID", "OTHERTEAM" as Any),
                             ("bundleID", "dev.djconnect.ios" as Any), ("provisioningProfileSHA256", "short" as Any),
                             ("validUntilMS", 7201001 as Any), ("build", "040407" as Any)] {
            var changed = original; changed[key] = value
            let decoded = try JSONDecoder().decode(RendezvousNativeRunPolicy.self, from: JSONSerialization.data(withJSONObject: changed))
            #expect(throws: (any Error).self) { try RendezvousNativeRunGate(policy: decoded, storage: NativeRunStore()) }
        }
    }
    @Test func malformedProtectedStateOrDifferentRunCannotBeReused() throws {
        let store = NativeRunStore(), gate = try RendezvousNativeRunGate(policy: policy, storage: store)
        try gate.reserve(.generateKey, context: context(), at: 2000, uptime: 10)
        var fields = try #require(JSONSerialization.jsonObject(with: store.read()!) as? [String: Any])
        let original = fields
        for (key, value) in [("schemaVersion", 2 as Any), ("policyID", "another-run" as Any), ("effects", ["generateAssertion"] as Any)] {
            fields = original; fields[key] = value; try store.write(JSONSerialization.data(withJSONObject: fields))
            #expect(!gate.isEligible(context(), at: 3000, uptime: 11, newConnection: false))
        }
    }
}
