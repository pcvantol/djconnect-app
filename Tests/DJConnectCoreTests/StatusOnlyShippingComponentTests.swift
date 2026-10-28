import Foundation
import Testing
import SwiftUI
@testable import DJConnectCore
@testable import DJConnectUI

private final class ShippingStatusFixtureBundle: NSObject {}

/// Real shipping modules, synthetic DATA only. No Activity/token/network calls.
@Suite(.serialized) @MainActor struct StatusOnlyShippingComponentTests {
    private struct Vectors: Decodable {
        struct Row: Decodable {
            let id: String
            let kind: String
            let wire_utf8: String
            let expected_source_raw_contract_acceptance: Bool
        }
        let cases: [Row]
    }
    private func rows() throws -> [Vectors.Row] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ShippingStatusFixtureBundle.self)
        #endif
        let url = try #require(bundle.url(forResource: "status-only-wire-vectors", withExtension: "json", subdirectory: "Fixtures")
                               ?? bundle.url(forResource: "status-only-wire-vectors", withExtension: "json"))
        return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url)).cases
    }
    private func bytes(_ id: String) throws -> Data {
        Data(try #require(rows().first { $0.id == id }).wire_utf8.utf8)
    }
    private func playing() throws -> DJConnectStatusActivityState {
        try .decodeOriginalWire(bytes("activity-active-playing"))
    }

    @Test func allFrozenOriginalWireVectorsUseShippingPreflight() throws {
        let rows = try rows(); #expect(rows.count == 33)
        for row in rows {
            let accepted: Bool
            do {
                let data = Data(row.wire_utf8.utf8)
                if row.kind == "activity" { _ = try DJConnectStatusActivityState.decodeOriginalWire(data) }
                else if row.kind == "widget" { _ = try DJConnectStatusWidgetResponse.decodeOriginalWire(data) }
                else { throw DJConnectError.invalidResponse }
                accepted = true
            } catch { accepted = false }
            #expect(accepted == row.expected_source_raw_contract_acceptance, "Original wire: \(row.id)")
        }
    }

    @Test func originalPreflightCannotBeReplacedByNativeValueDecoder() throws {
        for id in ["reject-float-version", "reject-float-observation", "reject-duplicate-phase-otherwise-positive"] {
            let data = try bytes(id)
            #expect(throws: (any Error).self) { _ = try DJConnectStatusActivityState.decodeOriginalWire(data) }
            let nativeValue = try JSONDecoder().decode(DJConnectStatusActivityState.self, from: data)
            #expect(nativeValue.phase == .active && nativeValue.playback_state != nil)
        }
        let data = try bytes("reject-widget-nested-duplicate-otherwise-positive")
        #expect(throws: (any Error).self) { _ = try DJConnectStatusWidgetResponse.decodeOriginalWire(data) }
        #expect(try JSONDecoder().decode(DJConnectStatusWidgetResponse.self, from: data).available)
    } // These remain actual Decoder counterexamples, not native raw-rejection claims.

    @Test func exactPresentationGenerationAndLegacySeparation() throws {
        let state = try playing()
        let identityWire = try JSONSerialization.data(withJSONObject: [
            "presentation_id": state.presentation_id, "presentation_generation": state.presentation_generation])
        let identity = try DJConnectStatusActivityIdentity.decodeOriginalWire(identityWire)
        #expect(state.matchesIdentity(identity))
        #expect(!state.matchesPresentation("00000000-0000-4000-8000-000000000099", generation: state.presentation_generation))
        #expect(!state.matchesPresentation(state.presentation_id, generation: "00000000-0000-4000-8000-000000000099"))
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: bytes("activity-active-playing"))
        }
        let legacy = DJConnectSessionSurfaceSnapshot(observedAt: Date(timeIntervalSince1970: 1_793_052_000))
        #expect(throws: (any Error).self) {
            _ = try DJConnectStatusActivityState.decodeOriginalWire(JSONEncoder().encode(legacy))
        }
    }

    @Test func endedNullOriginalObservationAndIndependentWidgetWitnesses() throws {
        let state = try DJConnectStatusActivityState.decodeOriginalWire(bytes("activity-neutral-ended"))
        let encoded = try JSONEncoder().encode(state)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object.count == 8 && object["playback_state"] is NSNull)
        #expect(try DJConnectStatusActivityState.decodeOriginalWire(encoded) == state)
        #expect(DJConnectStatusDisplayValue(activity: state).originalObservedMS == state.observed_at_unix_ms)
        let row = try #require(rows().first { $0.kind == "widget" && $0.expected_source_raw_contract_acceptance && $0.wire_utf8.contains("\"available\":true") })
        let response = try DJConnectStatusWidgetResponse.decodeOriginalWire(Data(row.wire_utf8.utf8))
        let observation = try #require(response.observation)
        #expect(DJConnectStatusDisplayValue(observation: observation).originalObservedMS == observation.observed_at_unix_ms)
        var altered = try #require(JSONSerialization.jsonObject(with: Data(row.wire_utf8.utf8)) as? [String: Any])
        var nested = try #require(altered["observation"] as? [String: Any])
        nested["target_generation"] = 1 // New-family integer generation cannot become an original UUID witness.
        altered["observation"] = nested
        #expect(throws: (any Error).self) {
            _ = try DJConnectStatusWidgetResponse.decodeOriginalWire(JSONSerialization.data(withJSONObject: altered))
        }
    }

    @Test func boundedOriginalBytesAndIdentityRejectMalformedInputs() throws {
        for data in [Data(), Data([0xc3, 0x28]), Data(repeating: 32, count: 4097)] {
            #expect(throws: (any Error).self) { _ = try DJConnectStatusActivityState.decodeOriginalWire(data) }
            #expect(throws: (any Error).self) { _ = try DJConnectStatusActivityIdentity.decodeOriginalWire(data) }
        }
        #expect(throws: (any Error).self) {
            _ = try DJConnectStatusWidgetResponse.decodeOriginalWire(Data(repeating: 32, count: 8193))
        }
    }

    @Test func fiveLanguageComponentsRetainOriginalTimestamp() throws {
        let state = try playing(), zone = try #require(TimeZone(secondsFromGMT: 0))
        let headings = ["nl": "Laatst waargenomen", "en": "Last observed", "de": "Zuletzt beobachtet",
                        "fr": "Dernière observation", "es": "Última observación"]
        #expect(DJConnectStatusLanguage.allCases.count == 5)
        for language in DJConnectStatusLanguage.allCases {
            #expect(language.heading == headings[language.rawValue])
            let view = DJConnectStatusLastObservedView(state: state, language: language, zone: zone)
            #expect(view.value.originalObservedMS == state.observed_at_unix_ms)
            let stamp = language.timestamp(state.observed_at_unix_ms, zone: zone)
            #expect(!stamp.isEmpty && stamp != language.timestamp(state.observed_at_unix_ms + 60_000, zone: zone))
            // Offscreen AppKit/UIKit rendering runs in the dedicated native component target,
            // separate from the contract suite's concurrent MainActor/URLProtocol fixtures.
        }
    }
}
