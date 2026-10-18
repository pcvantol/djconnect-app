# Ask DJ submission failure chat presentation

Owner reports failed Mac questions rendered as full-width question/error cards,
with misleading Session history unavailable copy. This is a separate pending-turn
view, not failure of normal user/assistant alignment.

Pending/failed questions now use the ordinary AskDJMessageBubble through the
current-conversation renderer: right alignment, width cap, original user identity,
timestamp, sending/failure metadata and voice-request presentation. Local delivery
status is a separate left-aligned bubble, labelled Ask DJ, without fake generated
response, speech/playback actions or backend persistence. In the newest-first flow
the status precedes its question; question identity remains the scroll target.

PendingTurn retains per-turn error keys and original creation date through retry;
rendering uses the original local user message when present and an identity-bound
fallback otherwise. Retry retains the same client_message_id/payload/context;
no automatic replay, new write or new prompt scope introduced.

Submission mapping is distinct from history operations:

- Generic HTTP/provider/invalid-response/decoding failures: Ask DJ cannot answer
  the question/request right now, in all five app languages.
- Network errors: same outcome with interrupted-connection explanation.
- HTTP409: changed Session context and review-before-send explanation.
- Hybrid uncertain/receipt outcomes retain their existing precise localization
  and explicit context/reconciliation behavior. Confirmed outcomes still read
  canonical conversation; authority withdrawal still clears owner content.

Actual list/timeline/search/history errors retain their existing history wording.
This fixes delivery UX, not the original backend reason for the owner's requests.
No personal question was replayed and no backend configuration was changed.

Qualification: three tests/seven cases PASS0.715s: actual composer network/403 owner
withdrawal; HTTP502/503/decoding/409 end-to-end mapping, exact payload/id and question
metadata preservation, one HTTP submit; direct network/uncertain error distinction.
Five-language brand/key validation PASS1261 matching keys. Native signed Mac40311
build PASS. Native signed iOS40311 and both strict deep signatures/ordinary-product
checks PASS. iPhone installed/read back40311 and launched. Owner explicitly lifted
the previous iPhone-only installation scope for this MacBook update: MacBook
mbpro-peter installed/read back40311, strict signature PASS, normal launch and
running process confirmed. All79 manifest entries (bytes/modes/framework symlinks)
match the qualified build. Prior Mac app retained as
`/Applications/DJConnect-recovery-20261017T222859Z.app`.
An initial remote orchestration script failed Python parsing before any install;
corrected script was locally syntax-checked before transfer and succeeded. Both
logs retained. No physical viewport test or full-suite PASS claimed.

Evidence: `/private/tmp/djc-ask-failure-40311/{source,targeted-tests.log}` and
`/private/tmp/djc-ask-failure-40311-{mac,ios}-build.log`.

Mac archive SHA256:
`76e7fa7f85ee55ff8570f45ee3582dd9af5c4e9de1084298532c6e0f18bf4d6a`.
Installation/readback receipts and launch logs are in the same private evidence
directory. iPad unchanged40290. Mac40311 also includes previously built40300–40310
layout/copy/toolbar changes; those earlier no-install boundaries were historical.
