# Ask DJ repeated contribution deletion — 22 October 2026

Peter clarified that deletion stops after one or two contributions in Ask DJ;
the whole-Session error text was a separate second defect (already repaired by
0c49424). This increment repairs original message context, not just the copy.
No build, installation or real deletion was performed.

## Confirmed client mismatch

Core main83744790 `content_deletion.py::_resolve` requires a message selector's
session_id to match that message's original session_turn.context.session_id.
The client only retained historical matches. If it could not find an own history
entry, it sent every server message as session_id="", even when its original
Session was known in the canonical wire. This affects user questions, replies
without retained own entries and remaining messages after readback/clear fences.
It is not a safe substitute for the current Session either.

The shared decoders now preserve original per-message contexts from canonical
history and live responses, including direct user/assistant objects. The owning
history model keeps them in RAM only, replaces them after each accepted history
readback, merges live messages by their own identity, and clears them with owner/
epoch invalidation. Different messages in a live response do not inherit that
response's newest turn context. Unknown message context yields no delete target;
no selected-entry, current-Session or guessed empty scope is substituted.
Canonical standalone messages still use their explicit empty scope.

## Verification boundary

The original Core resolver was executed in isolation with synthetic messages:
old blank selectors for Session-A and Session-B were rejected; their original
contexts and a standalone message without session_turn were accepted. No Core
imports, HA calls, database access or delete effects ran. Diff/register checks
pass. Added unexecuted Swift regression source covers three sequential prepared/
confirmed removals across increasing clear revisions and original contexts A/B/
standalone, without own retained-entry lookup; unknown-context refusal and mixed
history/live decoder identities are also covered. No Swift compilation, native
repeated menu/gesture acceptance or installed repair is claimed.

## Separate Core defect remains open

The same isolated resolver proves a second server mismatch: canonical standalone
messages may contain session_turn.context.session_id=null. The request contract
requires session_id as a string (empty for standalone), but Core compares empty
against null and rejects content_unavailable. The client must not invent a
Session or weaken the target/receipt fences to bypass this. Peter has been asked
for explicit permission to share this finding with the existing Core writer.
The Apple source repair alone does not close that standalone-null case.

## Contextual help status checked in this turn

Current Core main handles typed help with `_help_ask_dj_response` and the server
example catalogue. `eligible` filters current owner context, backend availability,
qualified routes, language and exact contracts; the client sends ordinary text
and adds no command list. VibeScape's glass popover fetches its server examples
fresh on open/retry, with no static voice fallback. These are source observations;
no new installed/native/help interaction was performed.
