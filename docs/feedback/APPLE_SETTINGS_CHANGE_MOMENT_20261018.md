# Narrative Moment after active Session settings changes

Owner requests a DJMoment bubble in the Session flow after changing mood,
persona or presence. Owner explicitly authorized implementation by the existing
Core writer; request successfully delivered to thread
01a120e2-b557-76c3-8568-129dbce2f2d2. This is a delivery receipt, not an
implementation/deployment/acceptance claim.

Required behavior:

- After a confirmed actual change, one durable, Session/Profile-bound Moment
  describes what changed and its real effect, in the Session language/persona.
- Include the primary shared Profile DJ Settings path, not only legacy Session
  mood/persona/presence endpoints. Apple delegates negotiated changes there.
- Publish through the ordinary admitted Moment/history/broadcast contracts so
  reopening and other devices retain the same content and stable identity.
- No duplicate on repeated delivery/no-op, and no success narrative for a denied,
  conflicted or unconfirmed change. Uncertain writes must not be replayed.
- Music-only presence may show the visual acknowledgement, while existing
  speech/presence/lifecycle admission still prevents unwanted spoken playback.
- Describe actual behavior; do not promise music changes the backend did not make.

Read-only Apple trace: changeActiveSessionMood/Persona use changeProfileDJSettings
when negotiated; legacy paths apply confirmed snapshots. Presence drain likewise
uses confirmed CAS and rereads uncertain outcomes without replay. Existing
MomentCard renderer renders admitted backend Moments. No locally synthesized
narrative, new producer, settings mutation or test user-session change introduced.

Status OPEN: Core implementation/tests and concrete consumer contract readback
required; then qualify any Apple gap and installed end-to-end acceptance. No
new build/install or false completion claimed for this handoff.
