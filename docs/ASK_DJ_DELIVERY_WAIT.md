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

Synthetic regressions cover more than three pending status reads, one execution
with unchanged IDs across all reads, the longer request timeout, original receipt
expiry, background cancellation, confirmed missing body, and separate conflict /
unknown-delivery copy and retry eligibility. No real user question, microphone,
provider call, playback action or HA write is performed by these tests. Real
on-device informational-answer delivery remains owner acceptance.
