# Paired surface-push v3 — data-only client codec

This internal immutable codec consumes the separately delivered Core outer-v3
context and registration response shapes. It constructs no clock/deadline,
original-owner witness, lifecycle permission, request builder, transport,
background credential publication or Activity admission. Decoded values are
DATA, including the variant named confirmed; they are not current authority.
No shipping caller adopts the new codec in this increment.

## Producer and exact original inputs

Core source `98f91ed0f1f407ce1fe7852b64a7da30fe73e131` and separate Final
`f0c4a1aa51c5758f985f8ddea16e1bffd8938a73` deliver the owning implementation.
The complete normative contract is `docs/product/SURFACE_CONTEXT_ORIGINAL_CLOCK_V3.md`,
SHA256 `c78cae89f3da760d08367709b01bdea1e0b01158dd2d81e6e03d6c01595742e8`.
The two copied test fixtures retain every original byte and synthetic boundary:

- `surface-push-v3-actual-ha-wire.json`: SHA256
  `1afee20c003919572729d955a61d8a9c334a7648e4503af7c406dd7fe4e40e75`;
  original `examples/client_contracts/surface_push_v1/actual-ha-wire.json`.
- `surface-push-v3-actual-ha-original-clock-context.json`: SHA256
  `1f3b56385a3c702a6ec3bf97acfe2d35d40212197236bdfd0e665f5c54d4c284`;
  original `examples/client_contracts/surface_push_v3/actual-ha-original-clock-context.json`.

These are actual isolated HA captures with disposable synthetic identities,
issuer-owner/RPC responses and zero external API/APNs calls. They are not
operational enrollment, native clock mapping, real key custody or delivery proof.
Protected Core blobs were independently hash-read back by Apple and API.

## Closed projection and comparisons

The v3 context has exactly eleven fields, strict true/3/true values, original
opaque coordinate grammar, safe integer expiry identities and private,no-store.
Purpose remaining is 1..28800000ms and context remaining is 1..30000ms, no larger
than purpose remaining. The decoder compares the caller's original operation.
It never subtracts client UTC or turns these fields into a local budget.

Confirmed register responses have exactly nine outer fields, unconfirmed eight.
The original operation, context handle and purpose reference must match the
original decoded context. Inner operation8, receipt9 and background5 shapes
remain separate; nullable fields must still exist. Confirmed data requires the
original purpose expiry and matching registered-widget background receipt,
never context submit expiry. The result_available field remains false, including
confirmed operations. Unconfirmed replies retain failure/old/absent-row meaning,
even when the retained operation says confirmed. They gain no background field.
The original closed two-field HTTP error family is rejected by these positive
codecs; no guessed error-to-success fallback is added.

The unchanged bounded lexical recognizer runs before Foundation projection,
rejecting duplicate decoded/escaped keys, invalid UTF8, fractional/exponent,
nonfinite/unsafe numbers, extra values and excessive nesting/size. Required
booleans and integers are decoded with distinct strict types. Immutable data
values do not implement the existing callable credential/lifecycle types.

## Preserved boundaries and qualification

The original v2 codec, transport, lifecycle, fixture history and original offset
RED144b remain unchanged. No v2 widening, version fallback, new UUID retry,
clock-rate assumption, local TTL, native-token rotation, issuer wirev1 change,
server change or product activation is part of this increment.

Ten draft tests passed with the original lexical helper and explicit probe-only
error/token dependencies; the independent API reviewer reproduced all ten.
A separate prepared package using the actual unchanged Core sources and exact
pinned JOSESwift also passed ten tests, parent exit0, unchanged original hashes.
Those preparation runs do not replace integrated full Swift/native project
checks, independent exact source review, normal protected Source delivery,
original own-main qualification and separate Finalization. Their actual results
must be recorded after execution rather than predicted here.

Remaining operative client work requires authentic original C0 and purpose
history, cross-context/token minimum, independently qualified rate/suspend/domain
mapping, conservative arithmetic and last-delivery guards. Unknown mapping
admits no positive lifetime. None of these rights follows from decode success.
Actual APNs/WidgetKit/Activity delivery and physical acceptance remain separate.
