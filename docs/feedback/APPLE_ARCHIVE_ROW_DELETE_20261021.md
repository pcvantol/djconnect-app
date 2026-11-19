# Visible per-session trash in earlier Sessions

Peter requested a trash control directly in the earlier-session list. Each row
now has a separate destructive button beside the open action, conditional on the
existing `session_history_delete` capability. The buttons are siblings, never
nested. Existing owner/active-session/unknown-journal gates disable and visibly
dim trash. Minimum hit area44pt; existing five-locale delete label/help are reused.

Clicking prepares a fresh detail revision through `prepareSessionDeletion` before
the existing whole-session confirmation. No delete occurs during preparation.
View disappearance and epoch changes fence late preparation/confirmation. A
successful row deletion leaves the list open; detail-screen deletion retains its
existing dismiss behavior. Unknown outcomes retain the existing journal/notice.

Native Mac actual-list recorder plus four fresh-confirmation and two unknown
journal cases: three functions/seven cases PASS0fail1.742s. All four original
row renders inspected. After the final explicit disabled opacity adjustment,
native recorder PASS0fail1.508s and all four final renders inspected: visible
red trash before pending, dim trash with pending notice after503/read refresh,
including320pt wrapped row. Model gates, not an AX enabled assertion, qualify the
unknown block. The recorder invokes model deletion, not native trash/alert taps.
Unsigned isolated iOS build-for-testing PASS before and after opacity adjustment.

Private logs prefix `/private/tmp/djc-archive-row-delete-20261021`; images and
observations below the matching directory. Companion JSON hashes final production
source, logs and final observations. Historical native results remain preserved.
No live deletion, physical interaction, native alert acceptance, installation,
publication or backend changes. The new control is local source and is not yet in
the installed40402 app. Individual Moment/bubble contextmenu/swipe remains the
next separate increment against newly protected Core1253, capability/version-gated.
