# Historical track play control — preparation, not delivered

Peter requested a white one-tap play icon on current and archived DJ Moment/playback cards. With no selected/known output, the backend speaker question must appear inside the current Session, or in Ask DJ when starting from an archived Session.

The shared card now accepts an optional replay callback and busy state. A supplied callback adds a white 44pt play control beside the existing context-question control and reserves space for both. The live timeline supplies no replay callback yet, so unsupported playback is not exposed.

Core coordination was explicitly authorized by Peter and acknowledged by the existing Core owner. Core confirms there is no delivered owner-bound history-entry playback resolve/command action or speaker continuation. Historical display metadata and artwork subjects confer no playback authority. No new request schema, qualified pin, fixture or admission was supplied. Core has recorded the producer dependency; active Apple wiring remains blocked on that delivery.

Validation: native Mac build and two focused test functions PASS, 0 failures/skips. Four supplied-callback card renders were captured at widths 320/720 with current/archive presentation; current-320 and archive-720 were inspected and show the white icon without text overlap. The callback was a no-op; this is UI preparation, not genuine playback or speaker-routing acceptance. No HTTP command, physical tap, installation or publication was performed.

Next: adopt the qualified producer contract with exact owner/Session/entry/revision/source-account fencing, then wire both screen routes and test missing-output continuation, stale context, duplicate taps and uncertain outcomes. Preserve unsent drafts and reuse the backend-owned playback operation/recovery behavior.

Private log and render hashes are bound in the adjacent JSON. The request remains OPEN.
