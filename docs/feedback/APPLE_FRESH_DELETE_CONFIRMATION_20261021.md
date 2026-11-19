# Fresh detail before archive deletion confirmation

Local successor to `64cfd46`, following the coordinated Core1251 consumer audit.
The archive trash action now first calls prepareSessionDeletion. It performs a
fresh existing authorized detail read, preserving loaded entries, then rechecks
the original epoch, owner and archived/deletable state. Only the fresh opaque
detail revision reaches confirmation. No delete POST occurs during preparation.
Failed preparation shows the existing localized failure notice. The UI blocks
repeated preparation taps and invalidates late UI completion on disappearance.
Existing confirmed deletion and receipt binding remain unchanged.

Core clarified the version question. Independently checked protected bbb7a23d
history_deletion_api.py and history_entry_contract.py: version is optional,
omission selects1, explicit1/2 accepted. A v2 detail revision does not require a
v2 delete representation. No guessed body field or revision conversion added.
Already confirmed ambiguous requests must keep their original exact body/ID.
Core will clarify the normative example in a subsequent source increment.

Validation completed: new archiveDeletionConfirmationRequiresFreshDetail covers
four synthetic cases (fresh changed revision;503 read failure; owner withdrawal
during read; target becoming ACTIVE). All four perform GET only and return a
confirmation revision only for the fresh valid archived case. The existing
seven-case sessionArchiveDeletionPreservesFailuresAndFencesStaleConfirmation
regression also passed. Total: two Swift Testing functions /11 parameter cases,
0 failures,0.580 seconds. iOS isolated unsigned build-for-testing PASS. Diff
check PASS. No native gestures/physical/current installed-HA acceptance inferred.

Still open: retain pending operation/body through uncertain outcomes, exact new
producer wirefixture adoption and same-operation recovery qualification. No new
ID may resolve an ambiguous effect after journal expiry. Individual content
deletion remains unoffered. Core Finalization and installed receipt remain live
qualification prerequisites. No installation, real deletion or publication.

Evidence:

- `/private/tmp/djc-fresh-delete-confirmation-20261021-mac.log`, SHA-256
  `b412e9df3cdd4e3be9ba12b25b79e87500a61f26637604944c0c007866ca3b7c`.
- `/private/tmp/djc-fresh-delete-confirmation-20261021-ios.log`, SHA-256
  `3ab3b45f606d9ebabff12787c27c7b775543cd3245e1fef764d41d375885df86`.
