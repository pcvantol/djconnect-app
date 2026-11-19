# Remove synthetic no-output choice

Owner explicitly requested removing the dummy/local/nonworking no-device option.
Apple40232 no longer prepends djconnect-output-none to real backend outputs on
Mac/iPhone/iPad or Watch. Legacy synthetic entries are filtered and selecting one
is rejected without changing active output flags. Empty output lists show a plain
localized no-devices status, not a selectable/disconnected pseudo-speaker.
The internal no-selection state still blocks playback start until a real output
is selected; removing a UI option does not fabricate an active playback device.

The existing dummy-select test was updated to test real devices only and stale
synthetic rejection. Another old test selected index0 expecting the former dummy;
it now leaves all real devices unselected and keeps its playback-block assertion.
The first regression run therefore failed that obsolete setup; final run is logged
separately. Both ordinary Mac/iOS builds and embedded Watch source compile pass.
No new backend contract or HA mutation; no Watch installed-runtime claim.

Final39output/volume regressions PASS, log
/private/tmp/djc-nooutput40232-tests-final.log. Mac40232 installed after confirming
closed, previous40225 retained. iPhone/iPad40232 installations completed with
fresh CoreDevice build-number readback. This closes this bounded UI correction;
no claim of closing the four larger audited product assignments.
