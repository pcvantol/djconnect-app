# Session Voor jou: Apple implementation

## Source boundary

Implements Core `SESSION_FOR_YOU_V1.md` from Source PR1463
(`b8c07abd434abb06bed8fbedd1a7a3a10f3c32b5`), finalized by PR1464
(`2bcc36150544b044c6c48fa6690086debd6e9c4c`).
The checked-in JSON is Core's synthetic measured example, not a live Profile,
Spotify result, provider credential, or device authority. Backend-authored labels
and intro are rendered unchanged (the example includes an English intro).

The card is an iOS/iPadOS/macOS Session surface. It is not a Watch launcher or a
local recommendation engine. Capability versions 2/3 and an authenticated Profile
conversation owner must qualify before the cached Core offer is shown.

## Behavior

- Three compact genre choices above current artwork, including while music plays.
- Opening/polling reads only the cached active Session; no generation or playback.
- Selection carries the original opaque action and Session thread through Ask DJ,
  with audio response `never`. An output choice uses that same conversation route.
- Acknowledgement or unrelated playback does not locally hide the offer. Core's
  confirmed projection controls visibility. Unknown outcomes are not retried.
- Dismissal sends only the negative offer operation, without a fabricated user turn.
- Original wall/monotonic leases only shrink; setting, owner, origin and Session
  changes fence old choices. Renewal requires the server-supplied explicit prompt.
- Only the bounded visual recipe enters local Foundation Models. Actions, URIs,
  conversation and Profile data do not. An unavailable model uses an honestly
  labelled procedural illustration. The Session illustration cache is bounded.

## Validation

Contract/model tests exercise malformed/future offers, original thread and action
identity, no initial effect, music already playing, expiry, scope changes,
unknown outcomes, negative dismissal, and output-choice bubble dispatch without
legacy direct commands. The native iPhone simulator test checks three in-bounds,
hittable choices, no POST on opening, and exactly one dismissal POST.

Run the loopback-only rendering fixture explicitly:

```sh
python3 Tools/qualification/for-you/native_fixture.py
```

Then run the named UI test with `TEST_RUNNER_DJCONNECT_FOR_YOU_UI_FIXTURE=1`.
Without that explicit fixture flag the test is skipped, not accepted as native
qualification. The fixture has no playback effect adapter.

Unsigned builds and synthetic tests do not qualify live Core installation,
Spotify mix playback, local Foundation Models generation, physical Apple devices,
APNs, or real music output. These require separate integrated acceptance.
