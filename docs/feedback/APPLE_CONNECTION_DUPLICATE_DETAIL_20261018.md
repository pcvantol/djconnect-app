# Connection popover duplicate unavailable line

Owner reports generic Home Assistant unreachable detail repeating the status
heading in the Mac connection popover. Shared connectionPopoverDetail now omits
only the known localized generic unreachable message. Both Mac SetupStatusView
and IOSConnectionCard use this presentation value. Other actionable pairing
details, the connection heading and backend recovery explanation remain.
No connection state, error handling or pairing message storage changed.

Diff/native signed iOS40308/strict signature/ordinary-product checks PASS.
iPhone install, independent40308 readback and normal launch succeeded.
No new test for the small copy filter and no physical Mac viewport
claim. Standing installation scope remains iPhone only; Mac source change will
need a later Mac installation to appear there.

Evidence: `/private/tmp/djc-connection-detail-40308-ios-build.log` and
`/private/tmp/djc-connection-detail-40308/{install,apps,launch}.json`.
