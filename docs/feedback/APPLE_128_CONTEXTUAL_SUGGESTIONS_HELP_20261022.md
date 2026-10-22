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
