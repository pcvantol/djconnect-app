# Apple #128 — contextual suggestions and compact Help

Source preparation on `codex/apple-avatar-focus-ring`, based on main
`8c349e7581a13c7700643df0fcf14366feb9e0ae`. Existing Watch, deletion, search,
branding and VibeScape WIP is preserved. No merge, release, installed-client
acceptance or producer qualification is claimed for this source change.

## Implementation

- Replace the examples inside Ask DJ's existing empty state and the active
  Session's existing first-play helper with one shared suggestion strip.
  Selection uses Core's reference algorithm: one preferred contextual example,
  then diverse intents/groups, with bounded six-ID RAM memory per surface.
  Exactly three or zero on selection; during editing/reading, revocation can
  temporarily leave fewer without refilling or rotating the remaining rows.
- Visits, explicit refreshes and semantic context/capability changes select;
  renders and playback position updates do not. Typing, recording, sending,
  reading Help and a hidden Session header freeze rotation. Track expiry only
  revokes; it does not request or select new material.
- Revalidate the displayed exact text, owner epoch, Session and relevant original
  track at tap time. Existing ordinary Ask DJ/composer guards and confirmation
  routes remain the only execution path. Unresolved templates cannot execute.
- Two question-mark entries, global and active Session, share one reference Help
  renderer. Maximum three groups of two examples; empty groups omitted. Reference
  placeholders are plain text, never executable buttons. Five translated
  introductions/footers distinguish the surfaces and explicit playback consent.
- The Session introduction points to suggestions/question-mark Help instead of
  making typed `help` the primary discovery route. Typed `help`/`hulp` still uses
  Core's ordinary Ask DJ handler and its same catalogue-backed grouped Help; no
  Apple-side command parser or separate example catalogue was added.
- A bounded existing capabilities GET at entry/refresh reads the additive
  descriptor/version map. Malformed descriptors fail closed without changing
  ordinary status/settings decoding. No network request happens during rendering.
- Hash/version/catalogue ID, global publication and each locale qualification are
  mandatory. The bundled JSON is byte-for-byte Core's source at SHA256
  `dfaa98a1659ef5673037da26f98136314b314beea8afe8e31af4ffd5bd6ac4e7`.

## Producer boundary and open acceptance

Core confirms the actual descriptor remains `qualified:false`, catalogue status
`draft_not_consumer_qualified`; all 70 locale/owner-route gates remain pending.
**Shipping behavior with this pin is zero executable chips and no reference
command groups**, with free text/voice still available and Help explaining the
unavailable qualification. Never relabel candidate rows as qualified in Apple.
A newly qualified Core catalogue requires a newly reviewed exact byte/hash pin.

Core also confirms `agent_available` is internal request-owned evidence, not yet
published in HTTP capabilities/status/WS. Apple treats it as false. Generic Ask
DJ or device-speech support cannot qualify an agent-dependent command. Current
track/artist evidence requires an owned active Session, original playback
updated_at within 30 seconds, item/title/artist, and playing/paused state. The
ordinary standalone playback DTO lacks that complete evidence; it is not used
to invent a current-track qualification. Forecast references require a matching
visible producer anchor. These conservative gaps must be resolved with Core
before any broader native command-coverage claim.

Source checks passed:

- `python3 Tools/validate_askdj_catalogue.py --core-root ../djconnect` — byte pin,
  equal producer bytes, qualification status, fixture schema and shared wiring.
- `python3 scripts/validate_localizations.py` — 1,441 keys in all five languages.
- `swiftc -frontend -parse` on new/changed catalogue, UI/model/client and test
  sources — syntax only, no typecheck/code generation.
- XcodeGen regenerated target/resource registration; `git diff --check` passed.

Five Swift test functions cover 70 Core-reference selection/Help vectors,
shipping draft/hash rejection, exact-three/intents, unsupported locale/contracts,
unsafe slots, frozen selection, owner invalidation and original-track/session
revocation. Synthetic qualification exists **only in Tests/Fixtures**, never in
shipping resources. The Swift tests have not run: no build was authorized for
#128. Native iPhone/iPad/Mac, VoiceOver/Dynamic Type and installed acceptance,
alongside Core's real 70-route qualification, remain required for joint closure.
Issue #128 remains open. A later owner request to install Watch 40449 is handled
from the preserved pre-#128 source snapshot; it does not deliver this change.


Validation update, night of22October: the preserved source now compiled and its software regressions ran in the full serial lane suite:1,164tests/24suites PASS121.521s. Log `/private/tmp/djc-apple-night-20261022/full-lane-tests-first.log`. Earlier no-build/unrun statements above describe the earlier checkpoint. This result is not native visual, installed-client, producer qualification or physical acceptance.


## Client continuation — open Help revalidation (23 October 2026)

Protected Apple base: `027354f31e1a3e46f726e2bd65ba1099947c9767`.
The sole-writer branch `codex/apple-contextual-help-client` is separate from
Bulletin PR186 and widget draft PR185; neither candidate is included here.
Canonical host verification returned MATCH/exit 0 before mutation.

An open Help reference previously evaluated time-sensitive track context only
when SwiftUI happened to redraw it. After the original 30-second observation
lifetime, an otherwise idle open reference could still display current-song
examples. Both existing Help surfaces now share `AskDJHelpReference`, which
joins the original observation deadline into the existing local refresh schedule.
Expiry revalidates context only: no capabilities request, suggestion rotation,
command dispatch or renewal. State updates between scheduled ticks are evaluated
against current time, never a previous display tick. Capability discovery remains
bounded to entry or owner/availability changes through the existing read key.

The Session footer previously contained fixed example questions outside the
canonical catalogue. Those examples are removed in all five locales; the footer
now explains conversation context and explicit playback choice only. All command
examples remain catalogue-owned plain reference text. The ordinary typed
`help`/`hulp` send route is unchanged; no client parser or local canned chat answer
was added.

The shipping catalogue still matches protected Core
`736378991f6ce54b9565f11314acf5863d3eb58b` byte for byte at SHA256
`dfaa98a1659ef5673037da26f98136314b314beea8afe8e31af4ffd5bd6ac4e7`.
All 70 producer locale/owner-route gates remain pending. The protected server
`_help_response` delegates to the same catalogue's `help_text`. Apple has not
promoted its qualification, supplied `agent_available`, changed a backend
contract, or replaced the unavailable state with unconfirmed commands.

Validation: seven targeted catalogue/Help functions PASS, including 70 existing
Core selection/reference vectors and new track/session/owner/availability
withdrawal checks in five locales. Full serial suite: 1,212 Swift Testing cases
in 24 suites PASS (142.109s); 86 XCTest cases, zero failures and five explicit
skips. Catalogue source validation with Core byte comparison PASS; localization
validation PASS for 1,447 keys in five languages. No ordinary app build/version
bump or physical installation was made.

The disposable host under `Tools/qualification/contextual-help/` uses the real
shared reference renderer. Its synthetic qualification exists only in the
existing test fixture and disposable host; the shipping catalogue is independently
checked to render zero examples. It creates no AppModel, HTTP, pairing, commands
or audio. Native component results, actual entry/popover navigation, paired typed
Help, physical VoiceOver and producer qualification must be reported separately.


Native iPhone 17 Pro/iOS 27 component run finished exit 0 / `TEST SUCCEEDED`:
three XCTest functions, zero failures, result summary `Passed`/3 passed.
Idle track expiry and owner withdrawal PASS (133.019s); 20 presentations
(5 languages × 2 surfaces × normal/dark or accessibility/light) PASS (224.976s);
ended Session plus both shipping-draft surfaces PASS (137.999s). These are not
all 40 possible appearance/text-size cross-combinations. Representative Dutch
normal/global and large/Session screenshots were inspected. The test-probe
controls are outside the production reference renderer and ship nowhere.

Native per-case teardown was slow (approximately 120 seconds); the first iPad
reuse attempt was queued before the iPhone run ended and was explicitly cancelled
(exit 75), not passed. A sequential iPad rerun is recorded separately. No Mac UI
acceptance, real popover/entry navigation, installed command availability or
VoiceOver audio is inferred from the iPhone component receipt.


The sequential iPad Pro 13/iOS 27 run reused the exact iOS test products and
finished exit 0 / `TEST EXECUTE SUCCEEDED`, summary `Passed`/1 passed:
idle original track expiry and owner withdrawal PASS (130.009s), zero failures.
It is a single behavior test, not the iPhone's 20-presentation layout matrix.
Only its optional post-test `simctl diagnose` collector was bounded after the
test completed; Xcode itself finalized successfully and the termination receipt
is retained. Both owned simulators were shut down after their completed runs.

Completed log copies, final result summaries and SHA256 readbacks are preserved
in `/Volumes/Shared Data/tmp/pcvantol/apple-contextual-help-client-20261023/`;
native result bundles and screenshots remain in the corresponding private
`apple-contextual-help-*20261023*` qualification paths. Current Mac UI,
entry/popover navigation, paired typed Help and physical VoiceOver acceptance
remain open, alongside Core's real producer qualification. Issue128 is not
closed by this bounded client continuation.
