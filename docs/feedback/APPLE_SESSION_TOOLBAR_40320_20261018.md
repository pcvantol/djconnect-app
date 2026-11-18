# Session toolbar —40320,18October2026

Owner screenshot request: connection/refresh right; main controls left, More
first; Search under More. Compact iPhone toolbar now follows that arrangement.
More opens the existing anchored popover with Search before voice/VibeCast.
Refresh is directly on the right and no longer duplicated in More. Search waits
for native popover dismissal before showing/focusing its existing search field;
foreground/owner epoch and current search availability still fence execution.

Expanded iPad retains the earlier requested direct actions without an overflow
menu: Search and main controls left, Connection/Refresh right. Mac toolbar is
unchanged. Existing toolbar geometry/menu stability UI tests are updated for
these expectations; simulator/physical UI execution is not claimed here.

Validation: ordinary signed iOS40320 build (including Watch/widgets) and source
manifest/diff checks recorded in /private/tmp/djc-session-toolbar-40320.
No installation or physical visual acceptance. Prior40318/40319 receipts remain
historical build-time input records; their clean staging directory was reused
with this bounded source overlay.
