# Submitted question visible above Ask DJ composer — 40302

Owner requested the newly submitted question to land immediately above the Ask DJ
input bar, rather than requiring a manual search through the Session feed.

Session composer now explicitly captures the newly appended question's local ID
and client_message_id after a successful submit. One scroll controller follows
that exact question through pending, retained history and current-only reply
representations. Assistant messages, same-text unrelated questions, different
Sessions, invalid entries and expired retained entries cannot become its target.
The original send path, frozen payload and server authority remain unchanged.

The question uses a bottom scroll anchor; a transparent safe-area reservation
accounts for the measured floating composer and gap. Temporary leading scroll
room makes bottom alignment possible even with little content before the new
question. No timer or network refresh drives this positioning. Search, top-jump,
scope/lifecycle changes and user scroll gestures release question following;
ordinary background updates do not initiate a new question-follow request.

The standalone Ask DJ screen uses its submitted question UUID rather than the
generic top-of-feed scroll request. It repositions that same question after
answer/layout changes until the user scrolls or searches, and reserves the same
composer space. An answer cannot redirect the target to its own bubble.

Regression exercises pending-to-retained transition, temporary current-only
question identity, same-text/different-ID and assistant exclusion, Session scope,
invalid context and retention expiry. Native build/test/install evidence is
recorded below. This is not a physical viewport/keyboard acceptance
claim. Private receipts: `/private/tmp/djc-question-scroll-40302/` and
`/private/tmp/djc-question-scroll-40302-ios-build-final.log`.

Submitted-question identity regression PASS0.007s; Swift parse/diff checks and
native signed iOS40302 including embedded targets PASS. Strict deep signature and
ordinary-product checks PASS. No full-suite rerun or physical gesture/keyboard
viewport PASS is claimed. Existing pure-question tests use no backend requests.

Resource admission: reused the closed previous Swift scratch build instead of
creating another one. After build/test completion, removed only3 separately
closed reproducible scratch products after checking real build consumers and
open files. Source snapshots, logs and installation evidence retained; internal
free space read back6.4GiB. No Docker/HA-dev service or Core source changed.

iPhone40302 installed, independently version-read back and launched. iPad and
MacBook were not updated, retaining the existing installation scope.
