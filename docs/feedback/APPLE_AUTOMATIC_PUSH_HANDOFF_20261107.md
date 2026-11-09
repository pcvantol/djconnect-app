# Apple handoff for automatic push on HA-dev

The Apple app pairs through `POST /api/djconnect/v1/pair` and authenticates subsequent Core calls with the paired device credential. The proposed automatic service must verify the original relationship between the HA installation, paired Apple installation and current owner. Each physical device and push channel starts disabled and has its own consent, generation and revocation. Neither pairing, an OS permission, retained display consent nor consent to another channel can enable push.

The Apple review worktree now has separate WidgetKit and ActivityKit choices. The local choice binds to the original HA installation and paired credential, with an independent generation per channel. Turning a choice off closes that channel's in-flight registration and read custody before persistence. Re-pairing clears the choices. This local state supplies user intent only. The server contract still needs an authenticated consent/revocation operation and generation echo before the app can reconcile delivery state.

| Channel | Current Apple path | Needed from Core/API |
| --- | --- | --- |
| WidgetKit on Mac, iPad and iPhone | The WidgetKit token and signed environment feed a widget-specific owner. Its paired transport uses `/api/djconnect/v1/push/surface/context` and `/register` with v3 operation, exact widget target and APNs environment. An independent qualified admission provider is required. | Automatic issuer authorization joined to the exact paired installation, approved role, generation and original grant/clock. Return canonical registration and scoped read custody. Qualify a cold extension read for the large widget without extending the original grant. iPhone/iPad also need a qualified way to read the widget's signed environment at runtime. |
| Live Activities on iPhone and iPad | ActivityKit produces the actual Activity ID and update token. The local attributes and renderer exist. The v3 registration port accepts only WidgetKit. | Separate Activity update/end registration and APNs profile, signed environment, approved locked-display fields, artwork and original expiry. No remote-start or Mac-native route is implied. |
| App Moments | Ordinary app notifications use `/api/djconnect/v1/push/register` and `/unregister`. The Apple tap path validates the Moment locator and opens the exact retained entry. The Watch category is currently selected by a separate Watch opt-in. | Define category-specific acknowledgement and generation-based withdrawal without affecting ordinary notifications or the Watch. Retain Core #1439 and its separately signed Watch preference. |
| Watch Smart Stack | The current paired Watch route uses `/api/djconnect/v1/session/surface/authorize` and `/read` with `watch_widget`, v1 and foreground-only display consent. Local timeline reloads do not prove delivery. | Define a separate Watch push opt-in, the exact recipient and topic, eligible update payload, acknowledgement and withdrawal. Phone companion availability cannot substitute for independent Watch authority. |

## Enrollment ordering under review

Core draft #1530 and the API proposal at `697cbcc` distinguish installation bootstrap from push opt-in. During ordinary pairing, Core must verify durable storage of the first API installation credential before capturing the current PairJournal acknowledgement: saving the credential replaces the HA options mapping, which would invalidate a previously captured acknowledgement. The API proposal binds the challenge and proof commit to that same active credential. The app must keep the channel closed until authenticated acknowledgement for its current pairing and consent generation; a completed pairing alone grants no delivery. This is a proposal under review, not an available client contract.

API revision `4e1d6f8` adds a shared one-time challenge for Apple attestation and proof of possession of Core's new key. This is for fresh pairing; recovery needs independently authorized evidence outside the restored backup, with revocation of the prior generation and its scoped push rights before acknowledging the replacement. The Apple proof must use the app identity and original pairing for this operation; the iOS Host Wake or Rendezvous proofs cannot be replayed. Exact pairing derivation and recovery authority are still under review, so do not enable the existing Apple registration owners based on this proposal.

The WidgetKit first-key proposal in API #229 now binds the original PairJournal
acknowledgement to the current server-managed Device-to-Profile mapping. Core
already has a durable `Device.binding_generation` for that mapping. Core keeps
the generation private and includes it in the signed owner commitment. Apple
must use the accepted receipt for the current scope. The client cannot derive
or substitute Core's mapping revision. The remaining HA-dev test changes only
the owner while registration is pending, then checks that both registration
and status reject the original proof, including A→B→A with the same pairing
and credential. An isolated Home Assistant 2026.10.0 storage test also
reproduced a failed write that left the in-memory owner ahead of the persisted
owner. The proposed readback rejects both owners in that state and accepts the
new owner after a confirmed write. Core still needs to apply that check in the
actual enrollment flow before requesting a challenge or signing and revalidate
the owner and pairing after suspension points.

## Apple integration point for the first iPhone trial

`DJConnectAppModel.observeNativePushToken` already scopes the WidgetKit token to
the active paired runtime, widget consent generation, exact widget target and
signed APNs environment. Keep that token in the existing surface registration
owner. Installation first-key enrollment belongs before surface admission and
must keep its own pairing lifetime; it must not be recreated for every session
or on token observation. The existing `DJConnectHostWakeFirstKeyOwner` is a
separate operator flow with no selected launch. Leave its selection untouched
and do not reuse its operator grant, token or receipt for the new enrollment.
Before connecting the two flows, use the implemented Core/API handoff to
obtain the receipt for the current pairing and bind only the WidgetKit role.
Check the current pairing again on completion before using the receipt. A
second pairing or a new consent generation while a request is suspended must
prevent stale admission or registration. The app currently constructs both
surface owners with `init(role:)`, which has no admission provider. The
existing `publicFactoryAndActivityRoleRemainClosedWithZeroWireCalls` test
observes `admissionUnavailable` for WidgetKit and `profileUnavailable` for
ActivityKit, with no request for either. It passed in the retained build
40507 candidate's macOS run (25 tests in two suites); that run did not test
the new first-key route.
The first iPhone trial must provide current WidgetKit admission separately
from the first-key receipt. Verify that a receipt alone still leaves WidgetKit
closed and that adding WidgetKit admission does not open ActivityKit.

API #229 at `4e2af70c` expects the `apple_proof` object to contain
`kind`, `key_id_b64` and `proof_b64`. First-key registration now accepts
only a fresh attestation; an assertion from an existing key is rejected.
The key identifier decodes to exactly 32 bytes, the proof has a 16 KiB
decoded cap, and the register request has a 32 KiB cap. The iPhone trial
must use `attestKey` for this operation. The existing iOS SDK wrapper calls
App Attest with raw `clientDataHash` bytes. For the new route, the hash must
come from the same retained Core register transcript that API reconstructs.
The existing Host Wake transcript and key selection are scoped to that
operator flow; they cannot be carried over. The previous API commit’s 59 successful checks
include local Worker/D1 coverage with a synthetic verifier, not a physical
App Attest response or push delivery.

## Apple review of the Core pair-witness candidate

All four candidate routes are POSTs under
`/api/djconnect/v1/push/native/pair-witness`. The request body for each
contains integer `contract_version: 1`, `device_id` and `client_type`.
Apple already has the paired HA bearer and the exact
`X-DJConnect-Device-ID` and `X-DJConnect-Client-Type` header values.
The candidate accepts `ios`, which is the existing client type on
both iPhone and iPad. The first physical qualification remains iPhone. Core
captures the WidgetKit authority at challenge time, so the separate consent
must already be active before Apple requests a challenge.

| Operation | Additional request fields | Apple handling |
| --- | --- | --- |
| `bootstrap` | None | Call with the ordinary paired HA bearer once the pairing has settled. Require `contract_version: 1` and `ready: true`; this confirms Core has read back its installation credential. |
| `challenge` | None | Capture the original `operation_id` and `expires_at_ms`. Decode canonical standard Base64 `client_data_hash_b64` to exactly 32 bytes and pass those bytes to App Attest unchanged. |
| `register` | `operation_id`, `apple_proof` | Use a fresh App Attest key and send `kind: "attestation"`, `key_id_b64` and `proof_b64`. Check that the receipt binds to the original operation and transcript digest. |
| `status` | `operation_id` | Reconcile the original registration under the same pairing and deadline. |

The existing Apple SDK code already calls `generateKey` and `attestKey`
with raw hash bytes. Its Host Wake and Rendezvous key selection, hash
derivation and journals belong to those operations. This flow requires its
own pairing-bound operation and must check the original pairing before and
after asynchronous steps. The existing automatic surface client is GET-only. The candidate bootstrap
POST accepts exactly the three shared fields. Core obtains the one-time
proof through its private machine identity, exchanges it while the original
pairing is current, and checks the durable credential before returning ready.
Apple neither supplies nor handles that proof or credential. Bootstrap can
complete before WidgetKit consent. It leaves channel admission unchanged,
and challenge still requires WidgetKit consent. The source regression covers
repeated bootstrap and the rejection of challenge before consent.
Live issuer configuration and current-pairing verification still need
HA-dev qualification.

Core retains the original operation in memory after a valid register receipt
and after a recoverable Core-to-API failure. If Apple loses the register
response, it calls `status` with the same operation ID before the original
deadline. Core uses a fresh API status nonce and the original pairing,
credential and Core key for each lookup. Apple verifies the returned receipt
against the same operation and transcript digest. Apple serializes status
lookups for that operation. It does not replay register or allocate a new
App Attest key to resolve an ambiguous result. A missing receipt, including
after a Core restart, leaves the result unknown. The Core source regression
covers lost response, repeated status, replay rejection and local retirement.

A first-key receipt proves key registration. WidgetKit still requires the
independent consent, matching surface registration, provider acceptance and
native delivery evidence. The draft Core endpoints and genuine provider
admission are not yet available on HA-dev.

## WidgetKit consent write and readback (verified Core candidate)

The Settings WidgetKit toggle calls `setNativePushAllowed(_:for:)` with
`.widget`. It persists a UUID scoped to the HA installation, device identity
and current paired bearer in local defaults, then uses it to bind the local
surface owner. This path makes no Core consent request. Turning it off fences
local work and deletes the UUID, so Core cannot currently read or revoke that
generation. Retained display consent is a separate session operation.

The isolated Core candidate implements this Apple-to-Core contract. Use the paired HA bearer and
existing device and client headers on both operations. The scope is the
authenticated original device and pairing, with a fixed `widgetkit` channel.

- `POST /api/djconnect/v1/push/native/consent/widgetkit`: closed body
  `{contract_version: 1, enabled, operation_id, expected_revision}`. Core
  compares the revision, durably applies the transition, and returns the
  same operation ID plus current consent state and Core-issued revision.
  Use a canonical lowercase UUIDv4 for the operation ID. Every new accepted
  intent advances the revision, even an explicit off while already off.
  Replaying the same operation ID and body returns the original outcome,
  which can be older than the current state. A stale revision or mismatched
  replay returns HTTP 409.
- `GET /api/djconnect/v1/push/native/consent/widgetkit`: read the durable
  current `{contract_version: 1, enabled, revision}` for the same authenticated
  pairing. The initial state is off at revision 0. Read current state
  after POST, including when reconciling a missing write response.

Apple should keep the local generation as a cancellation guard and track
the last confirmed Core revision separately. An explicit on action in
`setNativePushAllowed` queues the write, and a matching Core readback is
required before challenge. Existing local-only choices do not prove a Core
grant. Off fences local work immediately, supersedes queued on work, and
keeps a pending withdrawal across restart until it is confirmed against
the same pairing. If an older on write raced the off write, read the current
revision and apply the still-current off intent. A stale on request cannot
reopen a later withdrawal. Core captures the acknowledged revision during
challenge and rechecks it before register and status. Any provider-level
retirement remains separately verifiable.

Apple acceptance cases: wrong device or pairing and other
channels are rejected, a failed durable write cannot permit challenge,
lost ACK and duplicate write converge, stale enable after withdrawal is
rejected, opt-out after challenge blocks register and status, and re-pairing
starts off. ActivityKit and Watch keep their independent consent paths.
Verified against Core's isolated `core-native-pair-enrollment.patch`
(SHA-256 `51846d8b57ce9a33bbd5fde1df2a4a5484c82008937dbb8f326f9f0f4c63b171`).
Core source tests cover replay after withdrawal, rejection of stale enable,
foreign devices, replacement pairing and blocking status after withdrawal.
The route is not confirmed deployed to HA-dev. On iPhone, a Debug launch
with `--widget-consent-trial` connects the Settings toggle to the candidate.
The client persists the intent and original write revision before sending.
An uncertain reply keeps the same operation ID. A stale opt-in is discarded
when Core confirms a newer revision. A stale opt-out is rebased and retried.
The local widget owner requires a matching current GET after first-key
enrollment before it can bind. If that read is unavailable, the intent stays
pending. A changed revision or disabled consent invalidates the local binding.
The foreground poll rechecks confirmed consent on the existing 30-second
throttle. A matching read preserves the binding without another first-key
operation. A failed read closes the local binding and leaves the intent
available for retry.
Provider delivery remains outside this trial.

The Apple candidate also implements the paired bootstrap and challenge
requests. It rejects an unexpected audience, schema or operation ID and
checks the SHA-256 of Core's canonical transcript before exposing the 32-byte
hash. The challenge keeps both its wall-clock expiry and the original
monotonic request deadline. The trial toggle calls this path after confirmed
Core consent on a physical Debug iPhone.
The Apple candidate can also submit a bounded fresh attestation and validate
the exact register/status receipt. The current Core/API candidate includes
`state: registered`. The receipt must match the original operation, pairing
generation, installation, credential, Core key, expiry and transcript digest.
The trial uses App Attest and persists a protected, backup-excluded operation
checkpoint before submission. An uncertain submission is recovered by reading
status for the same operation within the original deadline.

## Core credential retirement candidate

Core and API matched the retirement request and receipt bytes in a shared test
vector. In the isolated Core candidate, an unconfirmed retirement stays on disk
and resumes at HA startup; only the matching receipt clears it. This is a
private Core-to-API machine route, not an Apple endpoint. Apple still needs
independent evidence that the new pairing is admitted and that no later
publication updates the retired registration. Installation retirement and
withdrawal of consent for a single push channel are separate acceptance cases.
The live trial still needs a distinct Access machine identity and verification
of the current HA-dev pairing.

## Native proof boundaries

- **iPhone and iPad.** The existing Host Wake first-key owner is physical-iOS-only. It binds the original foreground paired runtime, App Attest operation and APNs token epoch before sending the proof. Genuine App Attest evidence exists for iPhone in the Rendezvous scope. iPad uses the same adapter but needs its own physical evidence. The operational Host Wake selection remains empty. The Rendezvous evidence and source preparation establish neither a verified Apple-to-HA pairing for automatic push nor admission for any of the four channels.
- **First HA-dev trial candidate.** The retained iPhoneOS Debug 40507 host in `apple-331-device-candidate.Fxuot0` passed strict signature verification. Its signed App ID is `ZEML4LPXH4.dev.djconnect.ios`; its APNs and App Attest environments are both `development`, and its signature and embedded profile both allow debugging. The profile authorizes development App Attest. The host executable SHA-256 is `3ece0ffb63f48b08af4065d7bca1e708f95b7551129a84abc3f04ccd71b959e8`. Use iPhone first for the bounded trial, subject to exact server admission and a qualifying runtime build. This is a local signing baseline only: the build is not an approved first-key client. Verify the final artifact again if new registration code requires rebuilding. API #229 at `6a274311` adds the four first-key HTTP handlers and atomic D1 storage to the isolated Worker. The checked-in entry selects no policy. Live admission still requires the exact isolated HTTPS origin, the isolated database and HA-dev credential issuance, real App Attest verification against the selected iPhone artifact, and current HA pairing proof. The first-key receipt records key registration only; surface admission and APNs delivery require separate evidence.
- **Native macOS.** The Mac mini runs macOS 27.2. Apple supports App Attest on eligible macOS 27+ processes and requires a runtime `isSupported` check. The installed build 40507 has development APNs entitlements, but neither its Mac host signature nor its embedded profile contains the App Attest entitlement. The current Apple first-key adapter is iOS-only. Qualify a properly provisioned signed Mac host with a genuine challenge, server verification of the Mac app identity and key policy, and proof of the original Core pairing. Keep the WidgetKit target and token as independent checks. Older macOS and unsupported processes need a separately accepted proof profile. [Apple WWDC26 App Attest availability and verification](https://developer.apple.com/videos/play/wwdc2026/201/).
- **Watch.** The Series 11 build 40506 device identity was correlated privately with exactly one active HA-dev pairing. That is pairing evidence. Its local ordinary registration flag and Moment preference do not establish delivery or an accepted Watch signing/recovery credential. Core #1439 and the independent signed preference remain required. The physical-iOS App Attest proof must not be reused as Watch proof.

## Physical Live Activity cover check

The local v3 probe confirms that a qualified original descriptor joins staged
pixels, pixel arrival does not renew playback or its lease, and the cover is
removed at its original deadline. It used synthetic pixels. For the physical
check, correlate a genuine now-playing observation, its cover descriptor and
original deadline, the matching staged pixels and the actual lock-screen and
expanded-island rendering on the iPhone. Use bounded metadata (presence,
matching revision and expiry), not tokens, URLs or raw image data. Keep this
foreground rendering check separate from evidence that APNs updated a Live
Activity while the app was in the background. A screenshot and a cache read
from different tracks cannot establish the cause of a missing cover.

For joint HA-dev acceptance, use a fresh ordinary pairing and observe each role's registration after that role's opt-in, a corresponding genuine publication and native receipt/rendering, then confirmed scoped revocation. Keep the Mac mini, iPad mini, iPhone and Series 11 receipts separate. Record WidgetKit delivery as separate evidence: the actual DJ publication and its revision, provider acceptance for the matching widget registration, and the same contribution becoming visible on the device while the app stays in the background. A foreground refresh or timeline reload is not evidence of push delivery. After withdrawal, confirm the registration is inactive on the server and that a later eligible publication does not update the withdrawn surface. The old manual Cloudflare pilot and its artifacts remain historical evidence. They cannot be used as a fallback for automatic enrollment.
