import Foundation
import Testing
import SwiftUI
import CryptoKit
@testable import DJConnectCore
#if os(iOS)
import UIKit
import ActivityKit
#elseif os(macOS)
import AppKit
#endif

private final class StatusOnlyFixtureBundle: NSObject {}
private struct StatusOnlyVectors: Decodable {
    struct Row: Decodable {
        let id: String
        let kind: String
        let wire_utf8: String
        let expected_source_raw_contract_acceptance: Bool
    }
    let cases: [Row]
}

@Suite(.serialized) @MainActor struct StatusOnlyCandidateTests {
    private func resource(_ name: String) throws -> Data {
        try Data(contentsOf: #require(Bundle(for: StatusOnlyFixtureBundle.self).url(forResource: name, withExtension: "json")))
    }
    private func vectors() throws -> [StatusOnlyVectors.Row] {
        try JSONDecoder().decode(StatusOnlyVectors.self, from: resource("status-only-wire-vectors")).cases
    }
    private func sourceRaw<T: Decodable>(_ type: T.Type, _ data: Data, limit: Int = 8192) throws -> T {
        guard data.count <= limit else { throw StatusOnlyCandidate.invalid() }
        try DJConnectSurfacePushJSON.validate(data) // Real original bytes, not a normalized dictionary.
        return try JSONDecoder().decode(type, from: data)
    } // MODEL producer/B-HTTP shape preflight only. Not an OS raw-payload hook.
    private func playing() throws -> StatusOnlyActivityState {
        let row = try #require(vectors().first { $0.id == "activity-active-playing" })
        return try sourceRaw(StatusOnlyActivityState.self, Data(row.wire_utf8.utf8), limit: 4096)
    }

    @Test func exactPrivateProfilePreimageAndSchemaHashes() throws {
        let tuple = try #require(JSONSerialization.jsonObject(with: resource("activity-status-profile-tuple")) as? [String: Any])
        let identity = try #require(tuple["identity"] as? [String: String])
        #expect(Set(identity.keys) == ["profile_id", "native_attributes_type", "attributes_schema_sha256", "content_state_schema_sha256"])
        #expect(identity["profile_id"] == StatusOnlyCandidate.profileID)
        #expect(identity["native_attributes_type"] == "DJConnectRemotePlaybackStatusActivityAttributesV1")
        func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        #expect(identity["attributes_schema_sha256"] == hash(try resource("activity-status-attributes-v1.schema")))
        #expect(identity["content_state_schema_sha256"] == hash(try resource("activity-status-v1.schema")))
        let preimage = try JSONSerialization.data(withJSONObject: identity, options: [.sortedKeys])
        let contract = try #require(tuple["hash_contract"] as? [String: String])
        #expect(String(decoding: preimage, as: UTF8.self) == contract["expected_canonical_preimage_utf8"])
        #expect(hash(preimage) == tuple["identity_sha256"] as? String)
        #expect(hash(preimage) == StatusOnlyCandidate.identitySHA256)
    } // Private exact-shape binding only, not a qualified runtime profile.

    @Test func allFrozenSourceRawShapeVectors() throws {
        let rows = try vectors(); #expect(rows.count == 33)
        for row in rows {
            let accepted: Bool
            do {
                let bytes = Data(row.wire_utf8.utf8)
                if row.kind == "activity" { _ = try sourceRaw(StatusOnlyActivityState.self, bytes, limit: 4096) }
                else if row.kind == "widget" { _ = try sourceRaw(StatusOnlyWidgetResponse.self, bytes) }
                else { throw StatusOnlyCandidate.invalid() }
                accepted = true
            } catch { accepted = false }
            #expect(accepted == row.expected_source_raw_contract_acceptance, "source raw vector: \(row.id)")
        }
    }
    @Test func actualDefaultDecoderDoesNotProveRawLexicalRejection() throws {
        let rows = try vectors()
        for id in ["reject-float-version", "reject-float-observation", "reject-duplicate-phase-otherwise-positive"] {
            let row = try #require(rows.first { $0.id == id })
            let bytes = Data(row.wire_utf8.utf8)
            #expect(throws: (any Error).self) { _ = try sourceRaw(StatusOnlyActivityState.self, bytes) }
            let decoded = try JSONDecoder().decode(StatusOnlyActivityState.self, from: bytes)
            #expect(decoded.phase == .active && decoded.playback_state != nil)
        }
        let nested = try #require(rows.first { $0.id == "reject-widget-nested-duplicate-otherwise-positive" })
        let value = try JSONDecoder().decode(StatusOnlyWidgetResponse.self, from: Data(nested.wire_utf8.utf8))
        #expect(value.available && value.observation != nil)
    } // Preserved counterexamples, not relabeled as native strict-wire PASS.

    @Test func exactNativeIdentityAndExplicitEndedNullRoundTrip() throws {
        let state = try playing()
        let identityBytes = try JSONSerialization.data(withJSONObject: ["presentation_id": state.presentation_id,
            "presentation_generation": state.presentation_generation])
        let identity = try sourceRaw(StatusOnlyActivityIdentity.self, identityBytes)
        #expect(state.matchesIdentity(identity))
        var wrong = try #require(JSONSerialization.jsonObject(with: identityBytes) as? [String: Any])
        wrong["presentation_generation"] = "00000000-0000-4000-8000-000000000003"
        #expect(!state.matchesIdentity(try sourceRaw(StatusOnlyActivityIdentity.self, JSONSerialization.data(withJSONObject: wrong))))
        wrong["artwork"] = "not permitted"
        #expect(throws: (any Error).self) { _ = try sourceRaw(StatusOnlyActivityIdentity.self, JSONSerialization.data(withJSONObject: wrong)) }
        let ended = try #require(vectors().first { $0.id == "activity-neutral-ended" })
        let closed = try sourceRaw(StatusOnlyActivityState.self, Data(ended.wire_utf8.utf8))
        let encoded = try JSONEncoder().encode(closed)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object.count == 8 && object["playback_state"] is NSNull)
        #expect(try sourceRaw(StatusOnlyActivityState.self, encoded) == closed)
        #if os(iOS)
        let native = try JSONDecoder().decode(DJConnectRemotePlaybackStatusActivityAttributesV1.self, from: identityBytes)
        #expect(native.presentation_id == identity.presentation_id)
        #expect(String(describing: DJConnectRemotePlaybackStatusActivityAttributesV1.self) == "DJConnectRemotePlaybackStatusActivityAttributesV1")
        let content = ActivityContent(state: state, staleDate: nil)
        #expect(content.state == state) // No Activity.request/update/end, token or notification operation.
        #endif
    }
    @Test func keysetsUUIDsSafeIntegersAndPayloadBoundsReject() throws {
        let bytes = try JSONEncoder().encode(playing())
        let original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        for (key, value) in [("contract_version", 2 as Any), ("observed_at_unix_ms", 0 as Any),
                             ("sequence", 9_007_199_254_740_992 as Any),
                             ("presentation_id", "00000000-0000-1000-8000-000000000001" as Any),
                             ("presentation_generation", "00000000-0000-4000-C000-000000000001" as Any),
                             ("display_mode", "live" as Any), ("phase", "missing" as Any),
                             ("playback_state", "unavailable" as Any), ("theme", "party" as Any)] {
            var altered = original; altered[key] = value
            #expect(throws: (any Error).self) { _ = try sourceRaw(StatusOnlyActivityState.self, JSONSerialization.data(withJSONObject: altered)) }
        }
        var missing = original; missing.removeValue(forKey: "playback_state")
        #expect(throws: (any Error).self) { _ = try sourceRaw(StatusOnlyActivityState.self, JSONSerialization.data(withJSONObject: missing)) }
        #expect(throws: (any Error).self) { _ = try sourceRaw(StatusOnlyActivityState.self, bytes + Data(repeating: 32, count: 8192)) }
        #expect(throws: (any Error).self) { _ = try sourceRaw(StatusOnlyActivityState.self, Data([0xff, 0xfe])) }
    }
    @Test func allFiveAppLanguagesFormatOriginalObservationWithoutArrivalOrExpiry() throws {
        let state = try playing(), zone = try #require(TimeZone(secondsFromGMT: 0))
        #expect(StatusOnlyLanguage.allCases.count == 5)
        #expect(StatusOnlyLanguage.nl.heading == "Laatst waargenomen")
        #expect(StatusOnlyLanguage.en.heading == "Last observed")
        for language in StatusOnlyLanguage.allCases {
            #expect(!language.heading.isEmpty)
            for playback in StatusOnlyCandidate.Playback.allCases { #expect(!language.label(playback).isEmpty) }
            let time = language.timestamp(state.observed_at_unix_ms, zone: zone)
            #expect(time.contains("2026"))
            #expect(language.timestamp(state.observed_at_unix_ms, zone: zone) == time)
        }
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        #expect(Set(object.keys) == ["contract_version", "presentation_id", "presentation_generation", "sequence",
            "observed_at_unix_ms", "display_mode", "phase", "playback_state"])
    }
    @Test func widgetAndActivityShareOnlyOriginalStatusAndTimestamp() throws {
        let rows = try vectors()
        let activityRow = try #require(rows.first { $0.id == "activity-active-paused" })
        let widgetRow = try #require(rows.first { $0.id == "widget-positive-status-shape" })
        let activity = try sourceRaw(StatusOnlyActivityState.self, Data(activityRow.wire_utf8.utf8))
        let widget = try sourceRaw(StatusOnlyWidgetResponse.self, Data(widgetRow.wire_utf8.utf8))
        let observation = try #require(widget.observation)
        #expect(StatusOnlyDisplayValue(activity: activity) == StatusOnlyDisplayValue(observation: observation))
        #expect(StatusOnlyDisplayValue(observation: observation).playback == .paused)
        let unavailableRow = try #require(rows.first { $0.id == "widget-closed-unavailable" })
        let unavailable = try sourceRaw(StatusOnlyWidgetResponse.self, Data(unavailableRow.wire_utf8.utf8))
        #expect(!unavailable.available && unavailable.observation == nil) // No synthesized unknown observation.
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DJCONNECT_STATUS_PROPOSAL_ARTIFACTS"] != nil))
    func offscreenNativeComponentRendersAllFiveLanguages() throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["DJCONNECT_STATUS_PROPOSAL_ARTIFACTS"]))
        try #require(folder.path.hasPrefix("/Volumes/Shared Data/tmp/pcvantol/"))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let state = try playing(), zone = try #require(TimeZone(secondsFromGMT: 0))
        for language in StatusOnlyLanguage.allCases {
            let view = StatusOnlyLastObservedView(state: state, language: language, zone: zone)
                .frame(width: 360, height: 160).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view); renderer.scale = 2
            #if os(iOS)
            let data = try #require(renderer.uiImage?.pngData())
            #elseif os(macOS)
            let tiff = try #require(renderer.nsImage?.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let data = try #require(bitmap.representation(using: .png, properties: [:]))
            #endif
            #expect(data.count > 1000)
            try data.write(to: folder.appendingPathComponent("status-" + language.rawValue + ".png"))
        }
    } // Offscreen component evidence only, never Lock Screen/Island/WidgetKit receipt acceptance.
}
