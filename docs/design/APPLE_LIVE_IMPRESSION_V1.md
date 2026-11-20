# Apple Live-impressie V1

Assignment: `DJC-LIVE-IMPRESSION-V1-20261108`.
Canonical product and producer authority: [Core #1533](https://github.com/djconnect-music-dj/djconnect/issues/1533).
Native assignment: [Apple #87](https://github.com/djconnect-music-dj/djconnect-app/issues/87#issuecomment-6718384458).

## Existing owners and bounded changes

| Existing component | Disposition | Delta |
| --- | --- | --- |
| `DJConnectMoment` / native display admission | ADAPT | Recognize the versioned Live-impressie family and its qualified owner admission, without inheriting Spotify authority. |
| `DJConnectHistoryEntry` | ADAPT | Retain original event/photo identities and accepted story; transport grants remain response lifetime data. |
| `MomentCard` / `SessionEntryView` | ADAPT | Use one shared photo-first content subtree in current and retained Flow cards. |
| `DJConnectSessionArtworkTransport` | ADAPT | Reuse bounded credentialed managed-image reads, no redirects/cookies/disk cache; decode hero pixels at useful native resolution. |
| `SharedDJSpeechActions` | REUSE | Replay the original accepted text under its separate speech grant; autoplay is independent. |
| `exploreContribution` / selected entry and Moment references | REUSE | Preserve the original subject through track changes. |
| Native photo detail | NEW bounded view | Zoom the already admitted pixels, show caption/maker/license, and dismiss back to the same card. No new research, audio or playback. |
| Watch / passive surfaces / app model / research engine | UNCHANGED | No new image attachment, gallery, discovery or content ownership. |

## Interaction

Small existing DJ identity and localized Live-impressie label precede the hero.
A native width-adaptive layout keeps the photo above the story on compact widths
and alongside bounded text on wide layouts. Fit preserves the entire photo;
there is no forced crop, heavy filter or fake concert image. One photo is enough;
up to three distinct photos retain their supplied order and original event identity.
Visible credit and event artist/venue/date precede the story title and lead.
Read more expands the same accepted body. Listen and Ask about this reuse the
existing actions, with Sources always available. Opening a photo only presents
already admitted content; it never requests a new narrative or starts speech.

The photo view is a subtree with its own transient pixel state. A missing or
expired image leaves the story, controls, entry identity and reading position
intact and shows a localized temporary-unavailable message. Rights withdrawal
is distinct and removes unauthorized pixels. A late image completion must match
the original owner epoch, session, target, photo ID, revision and finite lease.
No Now Playing fallback is permitted. A refreshed URL must still describe the
same photo; history reopen does not generate another event or story.

## Contract integration

Core owns the versioned `live_impression` object, independent
`public_live_impression_v1` archive basis and managed media contract. This document
is a consumer delta, not a second product or wire specification. Exact fields,
fixtures and producer revisions are recorded by Core before runtime adoption.
A capability/fixture is source preparation; only an admitted authenticated
producer response authorizes native rendering. Original event/photo identities
are durable; short-lived transport credentials/URLs are not persisted by Apple.

## Validation and acceptance

Exercise valid and malformed optional payloads, unknown versions, one/three
photos, original event mismatch, precise dates versus year-only dates, missing
art and source expiry. Reject external/foreign managed-image paths and mismatched
photo revisions. Preserve ordinary Moments if optional media is malformed.
Test accepted current/retained content, original-subject Ask and unchanged speech
admission. Verify no render/open/reconnect starts generation or playback.
Native render coverage includes compact/wide and portrait/landscape, long
captions, Dynamic Type, VoiceOver, keyboard/focus, Reduce Motion and five locales.
Synthetic render checks do not prove real photo rights, research quality,
provider operation, physical installation or end-to-end product acceptance.

## Source validation — 19 November 2026

The candidate extends the existing models, strict native admission and shared
current/history renderer. Media prepare3 resolves only the original published
photo; it performs no discovery, narrative generation or photo substitution.
The exact owner/session/target/audience is checked again before dispatch and
after download. The response must bind the original photo ID and SHA-256;
static PNG/JPEG reads remain bounded to 2 MiB, 4096 pixels per edge and 16M pixels.
The Live hero decodes up to 2048 pixels; existing Spotify thumbnails retain their
512-pixel path. Pixels remain memory-only, clear at the original finite lease,
and cannot survive a replaced owner, Session, photo revision or task generation.

Source withdrawal uses the authenticated exact-target withdrawn envelope and
has distinct localized UI. A temporary image failure offers explicit retry
without erasing text. The pure shared photo/story presentation is tested with
explicitly synthetic pixels, including compact/wide layouts and credits; it is
separate from the owner/network adapter and confers no authorization.

Local results: full Swift suite reports 1,762 tests in 61 suites, zero failures,
with 15 explicitly gated skips. Unsigned Debug macOS and generic iOS builds
(including embedded Watch dependencies) pass. Localization validation passes
for 1,579 keys. The shared Core fixture comes from synthetic real-runtime
publication, SQLite history restart, managed media and manual speech; it verifies
cross-lane serialization rather than real public-source or physical acceptance.
Independent parent checks cover all nine normal checks; one initial test-helper
shebang failure from a temporary virtualenv path containing spaces is retained
and its unchanged 27-case suite passed using the host interpreter.

The source candidate has not been merged, signed, installed or deployed. Real
source/editorial quality, final full configured UI controls, audible speech,
physical iPhone/iPad/Mac interaction and actual producer-consumer product
acceptance remain distinct and unclaimed. No Watch/widget image scope was added.
