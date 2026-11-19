import Foundation
import Testing
@testable import DJConnectCore

/// Whitelist/negative privacy checks only. Decoding DATA never obtains the
/// genuine original source, native OS configuration or Activity handle.
@Suite struct StatusObservationProjectionTests {
    private let milliseconds: Int64 = 1_793_500_000_123
    private func data(_ state: String = "playing") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["playback_state": state, "observed_at_ms": milliseconds])
    }
    @Test(arguments: ["playing", "paused", "stopped", "unknown"])
    func exactWhitelistNeverExportsPrivateFieldsOrAnExpiry(_ state: String) throws {
        let snapshot = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: data(state))
        #expect(snapshot.rich == nil && snapshot.theme == nil)
        #expect(snapshot.playbackObservation?.playbackState.rawValue == state)
        #expect(snapshot.playbackObservation?.observedAtMilliseconds == milliseconds)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        #expect(Set(json.keys) == ["playback_state", "observed_at_ms"])
        #expect(json["observed_at_ms"] as? Int64 == milliseconds)
        #expect(!snapshot.isCurrent(at: snapshot.observedAt)) // No native/private clock grant.
        #expect(snapshot.neutral(at: .distantFuture) == snapshot)
    }
    @Test(arguments: ["title", "artist", "artwork", "rich", "theme", "expiresAt", "profile_id", "purpose_id", "is_current", "presence"])
    func mixedOrInjectedPrivateDataCannotBecomeAStatusProjection(_ field: String) throws {
        var object = try #require(JSONSerialization.jsonObject(with: data()) as? [String: Any])
        object[field] = "private value"
        let bytes = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { _ = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: bytes) }
    }
    @Test func malformedStateAndTimestampCannotCreateRenderableObservation() throws {
        let invalid: [[String: Any]] = [
            ["playback_state": "executing", "observed_at_ms": milliseconds],
            ["playback_state": "playing", "observed_at_ms": -1],
            ["playback_state": "playing", "observed_at_ms": "now"],
            ["playback_state": "playing"], ["observed_at_ms": milliseconds],
        ]
        for object in invalid {
            let bytes = try JSONSerialization.data(withJSONObject: object)
            #expect(throws: (any Error).self) { _ = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: bytes) }
        }
    }
    @Test func staleObservationRetainsOnlyItsOriginalTimestampAndBrand() throws {
        let snapshot = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: data())
        let name = "status-projection-" + UUID().uuidString, defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(try JSONEncoder().encode(snapshot), forKey: DJConnectSessionSurfaceSnapshot.storageKey)
        DJConnectSessionSurfaceSnapshot.suppressPrivateCacheFallback(in: defaults)
        #expect(DJConnectSessionSurfaceSnapshot.load(from: defaults, at: .distantFuture) == snapshot)
        #expect(snapshot.renderingTheme(at: .distantPast) == .brand)
        #expect(DJConnectSessionSurfaceSnapshot.widgetTheme(confirmedSession: snapshot, passiveMood: "party", fallback: .party, at: .distantFuture) == .brand)
        #expect(DJConnectSessionSurfaceSnapshot.needsWidgetReload(current: snapshot, previous: nil, lastReloadAt: Date(), at: Date()))
    }
    @Test func decodedDataAndLegacyWorkCannotReplaceOwnedStatusOrRestorePrivateFallback() throws {
        let status = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: data())
        let name = "status-write-denial-" + UUID().uuidString, defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(throws: (any Error).self) { _ = try DJConnectSessionSurfaceSnapshot.replace(status, in: defaults) }
        #expect(defaults.data(forKey: DJConnectSessionSurfaceSnapshot.storageKey) == nil)
        let bytes = try JSONEncoder().encode(status)
        defaults.set(bytes, forKey: DJConnectSessionSurfaceSnapshot.storageKey)
        DJConnectSessionSurfaceSnapshot.suppressPrivateCacheFallback(in: defaults)
        let legacy = DJConnectSessionSurfaceSnapshot(observedAt: Date(), theme: .party)
        #expect(throws: (any Error).self) { _ = try DJConnectSessionSurfaceSnapshot.replace(legacy, in: defaults) }
        #expect(throws: (any Error).self) { _ = try DJConnectSessionSurfaceSnapshot.replace(nil, in: defaults) }
        #expect(defaults.data(forKey: DJConnectSessionSurfaceSnapshot.storageKey) == bytes)
        // Corrupt/mixed data does not fall back to an old palette/rich snapshot.
        defaults.set(try JSONEncoder().encode(legacy), forKey: DJConnectSessionSurfaceSnapshot.storageKey)
        #expect(DJConnectSessionSurfaceSnapshot.load(from: defaults) == nil)
        #expect(DJConnectSessionSurfaceSnapshot.privateCacheFallbackSuppressed(in: defaults))
    }
    @Test func originalLegacySnapshotRoundTripIsUnchanged() throws {
        let original = DJConnectSessionSurfaceSnapshot(observedAt: Date(timeIntervalSince1970: 1_790_000_000), theme: .groove)
        let decoded = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: JSONEncoder().encode(original))
        #expect(decoded == original && decoded.playbackObservation == nil)
    }
}
