# Rich Session fragment preflight

This increment prepares the single existing rich Session widget and Live
Activity for the canonical `djconnect-session-rich-v1` successor. It adds no
WidgetBundle entry, Activity type, settings choice or active push factory.
Playback, artwork and static VibeScape presentation remain unchanged.

Normative Core contract: `RICH_SESSION_SURFACE_PUSH_CONTRACT_V1.md`, SHA256
`2a4a4a4f49e0f6d5a1015169ff63b27091f80d6d857423940a0381d955bbb499`,
delivered through Source #1395 and separate Final #1396. This client increment
does not widen status8, af201, background schema2 or the widget-only v3 runtime.

## Implemented boundary

`DJConnectRichSurfaceFragments` is an internal, pure DATA preflight. Its output
is not an admission or native owner. It retains the original attributes and
complete ContentState bytes without reserialization, alongside the existing
typed snapshot. No production caller, transport, cache write, SDK invocation or
positive factory is added.

The six-key carrier is closed and limited to 16,384 original bytes. Base64url
must be unpadded and canonical, including its trailing bits. Fragment structure
is checked recursively, with duplicate decoded keys, unknown struct fields,
missing fields, invalid UTF-8 and optional JSON null rejected. Dictionaries of
source attribution remain dictionaries of strings, not new permission fields.
Foundation Date numbers retain their default epoch and fractional encoding;
there is no conversion from a Unix timestamp heuristic. Integer-only fields
are validated from their original decimal tokens before conversion, preventing
fraction/exponent rounding from becoming an accepted integer.

Independent limits are enforced for original nested rich bytes (2,800) and
original attributes plus complete state (4,096), inclusive at the limit. The
complete APNs body limit is a separate producer responsibility; this parser
does not construct an APNs envelope or claim that limit has been qualified.
It does not truncate copy or attribution. Aggregate validity cannot override
the nested fields' own observation/expiry intervals, and cannot extend their
earliest expiry. These are necessary negative checks, not proof of original
permission, original source bounds or clock mapping.

`rich-surface-original-encoder-v1.json` packages the exact original 28 genuine
iOS encoder outputs and five original decoder-input counterexamples as base64,
with each member's SHA256 and the original manifest. Tests verify those hashes
before using the bytes. Unicode/escaping, fractional Dates, nil omission,
legacy omitted playbackState, exact byte boundaries and deliberately unsafe
unknown/null/empty/oversize/extended-deadline cases retain their original scope:
DATA evidence, never native/push acceptance.

## Required receiving interfaces for the next Core increment

These are semantic receiving requirements, not a selected new HTTP grammar,
signed envelope or callable permission constructor. Core must first deliver
and qualify its separately negotiated start/read/artwork contracts.

| Boundary | Required independent original input | Apple custody and current limitation |
| --- | --- | --- |
| Initial rich start | Actual accepted paired owner, source, Session, purpose/policy, field/display rights, settings revision and original immutable initial projection | Private native presentation generation and once/UNKNOWN inventory relation remain local. No source record, UUID, digest, token or status8 permission creates that relation. |
| Rich read | Actual independently authenticated successor read, exact source/field observations and UTC expiries, purpose bound, generation and sequence, cancellation/withdrawal and source/settings revisions | Read completion must still match the original owner and outstanding continuation. Existing widget schema2 credentials are not this interface. |
| Native clock mapping | Independently qualified original pre-await C0 plus original purpose/field remaining intervals and native clock-domain/rate/suspend/restore evidence | `ContinuousClock.now` can be captured in-process before an await. `ProcessInfo.systemUptime` and Date can also be sampled locally. None supplies a qualified boot/domain/rho/restore witness. No current rich factory implements that qualification; it stays closed. |
| Cache/render/update | The same still-current original source/purpose/Session/observer/settings, native target/generation and mapped per-field deadlines | Every actual cache/image/render/SDK boundary needs its own synchronous check after the last await/hop. Original receivedAt/receivedUptime must survive unchanged and cannot be used as a new C0 on delivery/restart. This DATA parser supplies no such owner. |
| Artwork | Asset-scoped authority, exact binding/generation/sequence/slot/subject/item/album/asset/media revision, rights/deadlines/attribution and five-language alt text | Stage only independently admitted matching pixels. Missing/late/wrong artwork clears its own association. Live Activity does not fetch a URL. Existing cover bytes alone confer no new transport rights. |
| Native target/update | Independently retained actual creation attributes bytes, actual returned Activity ID, private generation/withdrawal/restore witness, plus separately admitted delivery scope | Native identity and original raw attributes stay local until an exact qualified enrollment requires a commitment. No first-match adoption, second attribute UUID, token-family substitution or fabricated instance is introduced. |

There is currently no qualified concrete rich clock witness with an asserted
rho minimum, boot identity or restore delegation to export from Apple. Supplying
server C0/rate data cannot repair that absence. Cold extension/restart stays
closed until an independently qualified mapping and permission adapter exists.
Owner/clock/field comparison tests using synthetic inputs cannot be reported as
that concrete adapter. The old async Activity controller is not a positive port.

Source review/tests/CI/protected delivery and its separate documentary Final
remain distinct from provider/key/native setup, deployment, OS wake, APNs arrival
and physical-device acceptance. This source alone makes none of those claims.
