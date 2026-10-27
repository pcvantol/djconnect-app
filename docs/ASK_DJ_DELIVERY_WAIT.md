# Ask DJ delivery waiting

Slow information answers could outlive the client's 15-second HTTP or 30-second
action-socket execution timeout. The producer keeps the original task running,
but the client previously made only three status reads over roughly 750ms and
then marked the question uncertain. That is a confirmed consumer failure path;
it does not establish the exact outcome of the owner's photographed question.

Only `ask_dj/message` now gets a 120-second initial execution wait. After possible
delivery, status-only reconciliation uses the original operation ID/epoch for at
most another 120 seconds, capped by the original 300-second operation lifetime
and any earlier receipt expiry. Status reads back off to two seconds, validate
receipts even for HTTP202, and never contain a question payload. There is exactly
one execution. Ordinary playback/control operation timeouts remain unchanged.
Foreground, cancellation, installation and transport generation guards remain.

Accepted/sent-unknown is pending, not a context conflict. Confirmed/no-body uses
the existing authorized conversation-history refresh; the status endpoint never
replays a private answer. Truly unknown delivery is shown as question-specific
uncertainty with a Review question action. This only restores text to the draft;
it does not submit. Retry remains disabled for uncertain delivery. An actual
HTTP409 still uses the separate context-changed behavior. The conversation owns
its error presentation and disables outer automatic operation replay/toasts.
Draft review checks the original request epoch, current owner scope and continued
pending-turn membership before removing the turn or restoring its text. A stale
captured button after suspension, owner reset or an earlier review cannot write
an old question into a newer draft. Review itself performs no HTTP request.

Synthetic regressions cover more than three pending status reads, one execution
with unchanged IDs across all reads, the longer request timeout, original receipt
expiry, background cancellation, confirmed missing body, and separate conflict /
unknown-delivery copy and retry eligibility. No real user question, microphone,
provider call, playback action or HA write is performed by these tests. Real
on-device informational-answer delivery remains owner acceptance.


## Bounded original Ask DJ operation preparation (26 October 2026)

The current source increment follows the reviewed R2 proposal: Ask DJ chooses a qualified original-ID operation or one preselected supported legacy HTTP request before sending. Legacy WS uncertainty no longer triggers an HTTP execution. Wrappers disable replay for text and the existing `ask_dj_message` alias; the alias keeps its existing `command` payload/route rather than being inferred equivalent to a different wire envelope. Core source608bc7 confirms its hybrid wrapper bounds all operations, including this command alias, by the original receipt window. Its post-command delivery-fence capture adds no generation budget. Direct legacy HTTP is not covered by that backend guarantee.

The client conservatively observes one original monotonic ceiling of at most300 seconds, shortened by any earlier receipt expiry; a later receipt cannot renew it. Individual execute/status/resource waits and cancellation are bounded by remaining time. The status path observes the same ID/epoch, never executes again, and does not stop just because64 reads or an extra120-second continuation window elapsed. Original deadline/cancellation also bounds shared route-wait observation. Ephemeral metadata contains no private prompt/result cache.

Status confirmation is acknowledgement, not a full answer body. A separate short authorized history read may recover only retained content with the original client_message_id. Qualified catalogue history deliberately stores a caption; archived Session data may omit actions/media/audio, and privacy/clear/delete/trim/retention can remove content. Render only retained fields, never reconstruct lists, actions or media, never autoplay from recovery, and never claim that a caption is the full original answer. Missing retained content remains honestly unavailable; refresh does not resend.

The Watch companion is a separate legacy bearer/interactive route. Its local text-reply wait is bounded independently and does not fabricate hybrid identity/receipts or a shared cross-device monotonic clock. A Watch stop discards late replies; it does not assert cancellation of a Core task already executing. The ordinary source/native Watch compilation and logical reply lifecycle are separate from physical cross-device acceptance.

The Help wire catalogue/Reader remain closed until actual Core publication/configuration/new pin and its own reviewed adoption. This preparation does not claim live model/provider/APNs/device delivery or source/native acceptance before its own receipts.


For a configured older server, legacy compatibility is selected only before execution after an actually received404 from that exact origin's transport-context read. A fresh explicit submission requires a fresh absence observation; an old probe never supplies a new submission budget. Context/auth/TLS/redirect/426 failures, malformed replies or time-outs cannot select legacy. The original monotonic submission deadline is carried through the preflight to the single HTTP attempt. A configured hybrid coordinator alone must not be mistaken for support on an older server; conversely, an uncertain hybrid execution can never fall back to legacy.
