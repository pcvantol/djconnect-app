import Foundation
import ActivityKit
import DJConnectCore

/// Offline iOS-simulator codec probe. No Activity.request, token, SDK action,
/// network, paired profile or external-content admission is created.
@main struct ActivityStateWireProbe {
    static func main() throws {
        let observed = Date(timeIntervalSince1970: 1_792_753_200.123)
        let attributes = DJConnectSessionLiveActivityAttributes(presentationID: "synthetic-original-presentation")
        let encoder = JSONEncoder() // Default Date/null strategies, as ActivityKit requires.
        let decoder = JSONDecoder()
        var rows: [[String:Any]] = []
        for (name,theme) in [("minimal", Optional<DJConnectSessionMoodTheme>.none), ("update", .some(.energy)), ("end_final_state", .some(.brand))] {
            let state = DJConnectSessionSurfaceSnapshot(observedAt: observed, theme: theme)
            let encoded = try encoder.encode(state)
            let decoded = try decoder.decode(DJConnectSessionSurfaceSnapshot.self, from: encoded)
            precondition(decoded == state)
            let object = try JSONSerialization.jsonObject(with: encoded) as! [String:Any]
            precondition(object["rich"] == nil)
            var withNulls = object; withNulls["rich"] = NSNull()
            if theme == nil { withNulls["theme"] = NSNull() }
            let nullBytes = try JSONSerialization.data(withJSONObject:withNulls)
            let decodedNulls = try decoder.decode(DJConnectSessionSurfaceSnapshot.self,from:nullBytes)
            precondition(decodedNulls == state)
            rows.append(["case":name,"default_encoded_utf8":String(decoding:encoded,as:UTF8.self),
                "content_state":object,"explicit_optional_nulls_decode":true,
                "observed_at_ms":Int64(floor(state.observedAt.timeIntervalSince1970 * 1000)),
                "expires_at_ms":Int64(floor(state.expiresAt.timeIntervalSince1970 * 1000)),
                "external_content_admitted":false])
        }
        let root: [String:Any] = ["notice":"Expired synthetic codec vectors only; no APNs, enrollment, external rights or device delivery",
            "attributes_type":"DJConnectSessionLiveActivityAttributes", "content_state_type":"DJConnectSessionSurfaceSnapshot",
            "date_strategy":"Foundation default seconds since 2001-01-01; APS metadata is separately Unix time",
            "attributes_default_encoded_utf8":String(decoding:try encoder.encode(attributes),as:UTF8.self),
            "native_effects":false,"rows":rows]
        print(String(decoding:try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys,.prettyPrinted]),as:UTF8.self))
    }
}
