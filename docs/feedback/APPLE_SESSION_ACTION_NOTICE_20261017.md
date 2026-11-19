# Session action notice

The owner's screenshot shows ui.transport.uncertain, the generic toast raised by
withHomeAssistantClient for a receipt-only/uncertain operation. It is not a crash
or proof that the operation failed. The screenshot alone does not establish the
exact operation, route or packet-loss cause.

Replace the internal page-refresh wording for uncertain and confirmed/no-body
outcomes in all five languages. Do not claim success or automatic recovery for
unrelated operations. For Session Start, suppress the generic transport toast;
on receipt-only/deliveryUnknown outcome read the canonical active Session before
showing a local failure. Never replay Start to obtain its missing body. Restore
loading/request ownership through the existing guarded read path and only show
first-run introduction after actual active-state recovery. Preserve terminal
trust/authority errors and normal failures.

40220 signed iOS/Mac builds PASS; 1241 localized keys PASS; targeted regression
sessionOwnedTransportRecoveryDoesNotLeakGenericToastOrReplay PASS. This proves
screen-owned transport errors remain errors without leaking the generic toast;
transport no-replay rules are preserved. It is not a simulated claim of actual
packet loss or real backend recovery on a physical device. No live session was
started/ended solely for this verification.
