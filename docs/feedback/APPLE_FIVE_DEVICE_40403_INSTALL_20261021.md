# Five-device development installation — 21 October 2026

DJConnect **4.0.0 (40403)** from exact source `624e8aec24e321f4a7ca3846304367e560bd8996` was installed and started on the requested physical iPhone, iPad, Apple Watch, MacBook and Mac mini. Installed version readback passed on all five. The user explicitly requested this latest local development build and connected the devices after the availability question.

The signed iOS build includes the Watch application. Both physical-device provisioning coverage and strict artifact signatures passed. Both installed Mac executables match the signed candidate SHA-256 `d1d6cf30712ef1bd00b0756d1cea573f515f994a52a0a6c1cfbeee880fda0fa3`; complete Mac bundle bytes, modes and symlinks also matched. All 210 recorded source inputs were reverified against the source commit after installation. Build number 40403 was a command-line override; project defaults were unchanged.

| Device | Installed build | Version readback | App start |
| --- | --- | --- | --- |
| iPhone | 40403 | PASS | PASS, PID 29108 |
| iPad | 40403 | PASS | PASS, PID 1299 |
| Apple Watch | 40403 | PASS | PASS, PID 9095 |
| MacBook | 40403 | PASS | PASS, PID 56512 |
| Mac mini | 40403 | PASS | PASS, PID 20841 |

MacBook installation used the existing host-key-verified LAN SSH route after Bonjour/Tailscale routes were unavailable. No app uninstall, data wipe, pairing reset or credential transfer was performed. Only the existing ordinary Mac application processes were stopped for replacement.

Under the user's recovery-cleanup instruction, the two transient recovery applications created by these Mac installs were removed after fresh full-bundle duplicate verification against the retained 40402 product. The original 40402 product/archive, new 40403 products, prior work and unique evidence remain preserved.

This receipt qualifies development installation, version readback and process launch. Physical swipe/context-menu/delete-confirmation gestures, audio behavior and other feature acceptance remain separate. The source candidate remains local; this installation performed no PR, merge, TestFlight or App Store publication. Private device identifiers remain in private evidence, outside this portable report.

The adjacent JSON binds the source, five readbacks and private build/install/cleanup evidence hashes. Previous focused source and model qualification is documented in `APPLE_INDIVIDUAL_CONTENT_DELETE_20261021.md`.
