# Apple surface-push integration continuation — 23 October 2026

This sole-writer continuation starts at frozen PR185/ea3afc27fecdc789a156c561ccecbf7de7162509, protected base027354f31e1a3e46f726e2bd65ba1099947c9767. Bulletin PR186 and Help PR187 are preserved separately. Canonical host verification MATCH/exit0 precedes changes. No ordinary installation build, version bump, operator enrollment, secret provisioning, public issuer/provider activation or APNs delivery is claimed.

## Original field expiry review correction

API independently reviewed the exact frozen ea3 V2 and found that a higher outer sequence plus wall rollback could reanchor an unchanged short contribution/now_playing expiry. The existing outer deadline did not constrain the shorter field. A new single causal test function with both fields and removal/ABA fails on unchanged ea3 with six issues, then passes after the fix. The initial invalid test variant combined a contribution with music_only and was correctly rejected earlier; that log is preserved and is not the causal deadline result.

Registration-local RAM history now retains the earliest monotonic deadline for each field/absolute expiry. An earlier expiry inherits the corresponding earlier deadline from an existing later pin. Removal/reappearance and higher sequences cannot reset it. A genuinely later supplied content expiry may get a new bounded field pin without renewing the registration. History is bounded to256 entries, never evicted to restore freshness, and scrubbed on terminal withdrawal. Overflow fails closed. The same treatment covers outer observation expiry. Existing same-sequence, owner, original-wall/monotonic, cancellation, withdrawal and unknown-read rules remain.

## Concrete HTTP implementation

`DJConnectClient` now implements exact paired Core POST context/register/revoke/status routes. The register body is captured once with the original UUIDv7 and token; the transport never creates an operation ID or performs WS/HTTP/origin fallback or automatic write retry. Status is metadata only and has no read credential or readiness restoration path. The original lifecycle still validates the returned coordinate, revision, role, expiry and winning ACK.

The separate `DJConnectSurfaceBackgroundHTTP` has no paired token store. Its fixed Core read request carries only the original djcsurface credential and contract_version/registration_id body, with no app identity/header borrowing. The captured credential expiry and owner are rechecked immediately before task resume. Both HTTP paths use the existing bounded dispatcher: redirects, cookies, ambient headers, URLCache and credential storage are disabled; a maximum of two transfers,16KiB request and64KiB reply apply. Privacy/media/encoding checks, UTF-8, duplicate decoded JSON keys, safe integer grammar and nesting limits precede Codable interpretation. No parsing error exposes raw private response data.

The requests support WidgetKit and update tokens for an already existing Activity. Remote start is never represented. Native role/platform/version, exact target field set, original coordinates and explicit distinct consent are validated before request encoding. Wire support for Activity export is not an operator/content-rights admission.

These methods are **not yet wired to a shipping registration factory or the WidgetKit provider**. The original server continuation and extension credential/pin custody are still absent; it would be incorrect to manufacture either from these DTOs. The current installed widget therefore cannot yet perform this background read.

## Qualification

Full serial suite:1,236 Swift Testing cases/25suites PASS129.111s;86XCTest cases,5explicit skips,0failures. Twenty-five targeted functions passed before the final suite, including the actual retained Core HTTP request/response fixture, paired/scoped header isolation, missing privacy/media/encoding, large payload, strict JSON, zero dispatch after withdrawal/expiry, role/consent separation, unchanged short-field deadlines/ABA and history exhaustion. The final suite places all shared URLProtocol tests in one serialized suite.

The offline iOS ActivityKit codec probe actually executed on an owned iOS27 simulator using the unchanged shared Attributes/ContentState sources. It creates no Activity, push token, HTTP request or external permission. See the separate codec handoff. Original failed test-macro, mock-body-stream and probe compile attempts remain retained alongside successful reruns; they are not provider or product failures.

## Actual joins still required

Core explicitly confirmed that current /push/surface/context returns only available/expiry/cache policy, without an original server continuation handle. Its new internal widget-only owner adoption does not supply that Apple join. Core owns the necessary SYNC/design/wire delta. Equal expiry, a local UUID, status, Profile name or an APNs token cannot fill the missing original purpose witness.

After the exact Core continuation contract is reviewed, Apple can bind its original foreground owner/Session/token generation to registration and the first read. Extension custody must retain that admitted original pin under a separately scoped credential and synchronous withdrawal; no app/issuer bearer enters shared defaults. API still has a closed public issuer/provider path and no admitted actual Activity profile. Actual enrollment, signer custody, content rights and provider configuration remain owning service work, even though API deployment succeeded.

Live Activity rich content also needs a separately reviewed remote codec/rights model: the current local rich DTO contains receiver uptime and foreground-only export rights. Background Session end requires an explicitly admitted terminal update/end path; synchronous purpose withdrawal must not be bypassed to send final content. The client cannot substitute HA uptime or promote widget consent into external-content permission.

Native receipt then requires the exact signed candidate and real original operator/Session enrollment: widget token registration/rotation/revoke, push-driven reload with app inactive and fresh read, Live Activity update/end with app inactive, owner/Session withdrawal, stale-push suppression, and no duplicate app window. Installed40450, local tests, neutral codec vectors and provider acceptance are not those receipts. Existing physical/native policies and captures are not renewed by this document.
