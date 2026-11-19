import Foundation

typealias P = PreparedPushProof
typealias V = P.Value
let inputs = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [[String: Any]]
var passed = 0, failed = 0
@MainActor func check(_ id: String, _ accept: Bool = true, _ work: () throws -> Void) {
    var actual = true
    do { try work() } catch { actual = false }
    if accept == actual { passed += 1; print("PASS \(id)") }
    else { failed += 1; print("FAIL \(id): expected \(accept), actual \(actual)") }
}
func values(_ any: Any) throws -> [String: V] { try V.from(any).object! }
func envelope(_ t: [String: V], variant: String) -> [String: V] {
    let target = variant == "target_registration_assertion"
    let raw = Data(V.object(t).canonical.utf8)
    return ["contract_version": .integer(1), "request_id": .string("00000000-0000-4000-8000-000000000011"), "bootstrap_id": t["bootstrap_id"]!, "outcome": .string(target ? "target_proof_prepared" : "key_proof_prepared"), target ? "target_operation_id" : "key_operation_id": t["operation_id"]!, "proof_job_id": t["proof_job_id"]!, "proof_variant": .string(variant), "domain_prefix_utf8": .string(P.domains[variant]!), "canonical_transcript_b64": .string(raw.base64EncodedString()), "client_data_hash_sha256": .string(P.hash(Data(P.domains[variant]!.utf8) + raw)), "prepared_transcript_sha256": .string(P.hash(raw)), target ? "target_verification_handle" : "key_verification_handle": .string("AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE"), "bootstrap_deadline_unix_ms": t["bootstrap_deadline_unix_ms"]!, "original_grant_expires_at_unix_ms": t["original_grant_expires_at_unix_ms"]!]
}
func bytes(_ o: [String: V]) -> Data { Data(V.object(o).canonical.utf8) }
func expected(_ t: [String: V], variant: String) -> P.Expected {
    let target = variant == "target_registration_assertion"
    return .init(requestID: "00000000-0000-4000-8000-000000000011", variant: variant, known: t.filter { P.knownKeys.contains($0.key) }, nativeTarget: target ? t["native_target"] : nil, nativeTokenHash: target ? t["native_token_sha256"]?.string : nil, verifiedKeyRef: target ? t["verified_key_ref"]?.string : nil)
}
let variants = ["new_key_attestation", "existing_key_assertion", "target_registration_assertion"]
var controls: [String: [String: V]] = [:]
for x in inputs where (x["case_id"] as! String).hasSuffix("widget-control") || (x["case_id"] as! String).hasSuffix("causal-iOS-Activity-positive") {
    controls[x["case_id"] as! String] = try values(x["transcript"]!)
}
for x in inputs {
    let id = x["case_id"] as! String, variant = String(id.split(separator: "/")[0])
    let activity = id.contains("causal-") || id.contains("foreign-native-")
    let control = controls[variant + (activity ? "/causal-iOS-Activity-positive" : "/widget-control")]!
    let accept = id.hasSuffix("widget-control") || id.hasSuffix("causal-iOS-Activity-positive")
    check("API32/" + id, accept) {
        // Malformed maps may lack nonce but envelope never fills that inner field.
        let t = try values(x["transcript"]!), o = envelope(t, variant: variant)
        let p = try P.decode(bytes(o), expected: expected(control, variant: variant))
        if let b = x["byte_control"] as? [String: Any] {
            try P.require(p.originalBytes == Data((b["canonical_transcript_utf8"] as! String).utf8))
            try P.require(P.hash(Data((b["domain_prefix_utf8"] as! String).utf8) + p.originalBytes) == b["client_data_hash_sha256"] as? String)
        }
    }
}
let t = controls[variants[0] + "/widget-control"]!, e = expected(t, variant: variants[0]), good = envelope(t, variant: variants[0]), raw = bytes(good)
for k in good.keys.sorted() {
    check("outer-missing/" + k, false) { var o = good; o.removeValue(forKey: k); _ = try P.decode(bytes(o), expected: e) }
}
for k in ["request_id", "bootstrap_id", "proof_job_id", "key_operation_id"] {
    check("outer-foreign/" + k, false) { var o = good; o[k] = .string("00000000-0000-4000-8000-000000000099"); _ = try P.decode(bytes(o), expected: e) }
}
for (id, replacement) in [("duplicate", "\"contract_version\":1,\"contract_version\":1"), ("decoded-duplicate", "\"contract_version\":1,\"contract_vers\\u0069on\":1"), ("decimal", "\"contract_version\":1.0"), ("exponent", "\"contract_version\":1e0"), ("boolean", "\"contract_version\":true")] {
    check("outer-lexical/" + id, false) { _ = try P.decode(Data(String(decoding: raw, as: UTF8.self).replacingOccurrences(of: "\"contract_version\":1", with: replacement).utf8), expected: e) }
}
check("outer-unknown", false) { var o = good; o["authority"] = .string("yes"); _ = try P.decode(bytes(o), expected: e) }
check("outer-8193", false) { _ = try P.decode(raw + Data(repeating: 32, count: 8193 - raw.count), expected: e) }
check("outer-8192-control") { _ = try P.decode(raw + Data(repeating: 32, count: 8192 - raw.count), expected: e) }
check("outer-BOM", false) { _ = try P.decode(Data([239,187,191]) + raw, expected: e) }
check("domain-substitution", false) { var o = good; o["domain_prefix_utf8"] = .string(P.domains[variants[1]]!); _ = try P.decode(bytes(o), expected: e) }
for k in ["client_data_hash_sha256", "prepared_transcript_sha256"] {
    check("digest-substitution/" + k, false) { var o = good; o[k] = .string(String(repeating: "0", count: 64)); _ = try P.decode(bytes(o), expected: e) }
}
func replacedInner(_ inner: Data) -> Data {
    var o = good
    o["canonical_transcript_b64"] = .string(inner.base64EncodedString())
    o["prepared_transcript_sha256"] = .string(P.hash(inner))
    o["client_data_hash_sha256"] = .string(P.hash(Data(P.domains[variants[0]]!.utf8) + inner))
    return bytes(o)
}
let inner = Data(V.object(t).canonical.utf8)
for (id, d) in [("trailing-LF", inner + Data([10])), ("whitespace", Data([32]) + inner), ("BOM", Data([239,187,191]) + inner), ("bad-UTF8", Data([255])), ("4097", Data(repeating: 32, count: 4097))] {
    check("inner/" + id, false) { _ = try P.decode(replacedInner(d), expected: e) }
}
for (id, replacement) in [("duplicate", "\"contract_version\":1,\"contract_version\":1"), ("decimal", "\"contract_version\":1.0"), ("unicode-escape-noncanonical", "\"contract_vers\\u0069on\":1"), ("boolean", "\"contract_version\":true"), ("surrogate", "\"contract_version\":\"\\ud800\"")] {
    check("inner-lexical/" + id, false) { _ = try P.decode(replacedInner(Data(String(decoding: inner, as: UTF8.self).replacingOccurrences(of: "\"contract_version\":1", with: replacement).utf8)), expected: e) }
}
for b64 in ["e30", "e30=\n", "e31=", "____", String(repeating: "A", count: 5465)] {
    check("base64-reject/" + String(b64.prefix(12)), false) { var o = good; o["canonical_transcript_b64"] = .string(b64); _ = try P.decode(bytes(o), expected: e) }
}
check("handle-nonzero-pad-bits", false) { var o = good; o["key_verification_handle"] = .string("AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQF"); _ = try P.decode(bytes(o), expected: e) }
check("hash-valid-but-foreign-original", false) { var foreign = t; foreign["candidate_sha256"] = .string(String(repeating: "9", count: 64)); _ = try P.decode(bytes(envelope(foreign, variant: variants[0])), expected: e) }
check("canonical-unicode-control") {
    let d = Data("{\"a\":\"é😀/\\n\",\"b\":1}".utf8), o = try P.object(d, max: 4096)
    try P.require(Data(V.object(o).canonical.utf8) == d)
}
let target = controls[variants[2] + "/widget-control"]!, te = expected(target, variant: variants[2]), traw = bytes(envelope(target, variant: variants[2]))
@MainActor func readyFlow() throws -> P.ModelFlow {
    let f = P.ModelFlow(scope: "original-epoch", originalDeadline: 100, originalKey: e, originalTarget: te)
    _ = try f.consume(raw, expected: e, tick: 1)
    try f.observeSyntheticKeyVerification(ref: target["verified_key_ref"]!.string!, tick: 2)
    return f
}
check("flow-original-key-and-target") { let f = try readyFlow(); _ = try f.consume(traw, expected: te, tick: 3) }
check("flow-target-before-key", false) { _ = try P.ModelFlow(scope: "original-epoch", originalDeadline: 100, originalKey: e, originalTarget: te).consume(traw, expected: te, tick: 1) }
check("flow-key-without-verification", false) { let f = P.ModelFlow(scope: "original-epoch", originalDeadline: 100, originalKey: e, originalTarget: te); _ = try f.consume(raw, expected: e, tick: 1); _ = try f.consume(traw, expected: te, tick: 2) }
check("flow-duplicate-key", false) { let f = try readyFlow(); _ = try f.consume(raw, expected: e, tick: 3) }
check("flow-duplicate-target", false) { let f = try readyFlow(); _ = try f.consume(traw, expected: te, tick: 3); _ = try f.consume(traw, expected: te, tick: 4) }
check("flow-ABA", false) { let f = try readyFlow(); f.observeScope("foreign-epoch"); f.observeScope("original-epoch"); _ = try f.consume(traw, expected: te, tick: 3) }
check("flow-lost-reply", false) { let f = try readyFlow(); f.loseReply(); _ = try f.consume(traw, expected: te, tick: 3) }
check("flow-deadline-equality", false) { let f = try readyFlow(); _ = try f.consume(traw, expected: te, tick: 100) }
check("flow-no-arrival-renewal", false) { let f = try readyFlow(); _ = try f.consume(traw, expected: te, tick: 101) }
check("flow-backwards-logical-tick", false) { let f = try readyFlow(); _ = try f.consume(traw, expected: te, tick: 1) }
check("flow-foreign-job", false) { let f = try readyFlow(); var t = target; t["proof_job_id"] = .string("00000000-0000-4000-8000-000000000099"); _ = try f.consume(bytes(envelope(t, variant: variants[2])), expected: te, tick: 3) }
check("flow-opaque-policy-change", false) { let f = try readyFlow(); var t = target; t["identity_policy_sha256"] = .string(String(repeating: "9", count: 64)); _ = try f.consume(bytes(envelope(t, variant: variants[2])), expected: te, tick: 3) }
check("flow-keyref-substitution", false) { let f = try readyFlow(); var t = target; t["verified_key_ref"] = .string("00000000-0000-4000-8000-000000000099"); _ = try f.consume(bytes(envelope(t, variant: variants[2])), expected: te, tick: 3) }
check("first-job-not-preknown-is-only-correlation") {
    var changed = t; changed["proof_job_id"] = .string("00000000-0000-4000-8000-000000000099")
    let f = P.ModelFlow(scope: "original-epoch", originalDeadline: 100, originalKey: e, originalTarget: te)
    _ = try f.consume(bytes(envelope(changed, variant: variants[0])), expected: e, tick: 1)
    try P.require(f.job == changed["proof_job_id"]?.string)
}
check("closed-flow-never-revives-after-invalid-reply") {
    let f = try readyFlow()
    do { _ = try f.consume(Data("{}".utf8), expected: te, tick: 3) } catch {}
    try P.require(f.retired)
    var rejected = false
    do { _ = try f.consume(traw, expected: te, tick: 4) } catch { rejected = true }
    try P.require(rejected)
}
check("flow-cannot-replace-original-target-expectation", false) {
    let f = try readyFlow()
    var changed = target; changed["candidate_sha256"] = .string(String(repeating: "9", count: 64))
    _ = try f.consume(bytes(envelope(changed, variant: variants[2])), expected: expected(changed, variant: variants[2]), tick: 3)
}
for variant in variants {
    check("mac-widget-control/" + variant) {
        var widget = controls[variant + "/widget-control"]!; widget["client_type"] = .string("macos")
        _ = try P.decode(bytes(envelope(widget, variant: variant)), expected: expected(widget, variant: variant))
    }
}
func boundaryTarget(_ size: Int) throws -> [String: V] {
    var v = target, native = target["native_target"]!.object!
    for k in ["app_bundle_id", "extension_bundle_id", "widget_kind"] { native[k] = .string(String(repeating: "a", count: 200)) }
    v["native_target"] = .object(native); v["selected_ha_origin"] = .string("x")
    let count = size - bytes(v).count + 1
    try P.require((1...2048).contains(count))
    v["selected_ha_origin"] = .string(String(repeating: "x", count: count))
    try P.require(bytes(v).count == size)
    return v
}
check("inner-exact-4096-valid-shape") {
    let v = try boundaryTarget(4096)
    _ = try P.decode(bytes(envelope(v, variant: variants[2])), expected: expected(v, variant: variants[2]))
}
check("inner-exact-4097-only-one-byte-larger", false) {
    let v = try boundaryTarget(4097)
    _ = try P.decode(bytes(envelope(v, variant: variants[2])), expected: expected(v, variant: variants[2]))
}
check("known-string-byte-equality-not-Unicode-normalization", false) {
    var original = t; original["selected_ha_origin"] = .string("https://é.synthetic.invalid")
    var changed = original; changed["selected_ha_origin"] = .string("https://e\u{301}.synthetic.invalid")
    _ = try P.decode(bytes(envelope(changed, variant: variants[0])), expected: expected(original, variant: variants[0]))
}
check("canonical-decomposed-Unicode-is-preserved") {
    var original = t; original["selected_ha_origin"] = .string("https://e\u{301}.synthetic.invalid")
    let p = try P.decode(bytes(envelope(original, variant: variants[0])), expected: expected(original, variant: variants[0]))
    try P.require(p.originalBytes == bytes(original))
}
check("observed-scope-byte-change-is-terminal") {
    let f = P.ModelFlow(scope: "é", originalDeadline: 100, originalKey: e, originalTarget: te)
    f.observeScope("e\u{301}")
    try P.require(f.retired)
}
check("scope-byte-change-cannot-revive-after-return") {
    let f = P.ModelFlow(scope: "é", originalDeadline: 100, originalKey: e, originalTarget: te)
    f.observeScope("e\u{301}"); f.observeScope("é")
    try P.require(f.retired)
}
print("RESULT \(passed) PASS / \(failed) FAIL; pure parser + synthetic logical model, no native/provider/admission effects")
exit(failed == 0 ? 0 : 1)
