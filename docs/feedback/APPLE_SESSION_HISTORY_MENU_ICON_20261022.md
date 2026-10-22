# Earlier Sessions navigation icon

Direct owner request: use the headphones icon for Earlier Sessions in the Mac menu/sidebar and on the iOS/iPadOS More page. Both navigation entries now use SF Symbols headphones. Existing navigation labels and destinations are unchanged. No new tests for this two-symbol presentation change; signed build and installation evidence follows separately.

Validation: signed macOS/iOS40443 builds and strict signaturesPASS; git diff --checkPASS.

Delivery checkpoint: implementation5c6864580a6b11acc951b71c9baa90c505d1025c;40443 installed/read back on iPad/iPhone, iPad launched. Both Macs remain40442 because normal app quit returned user-cancel -128 on each; signed40443 apps staged on both hosts, awaiting user closure. No force termination. Physical menu screenshot acceptance separate.

Later combined delivery40444: both Macs successfully quit normally and were updated/read back; includes this headphones-menu change. iPad/iPhone also40444. Previous Mac closure blocker resolved; no force termination used.
