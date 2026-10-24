# Contextual Help component qualification

`prepare_native_help_tests.py <new-output-directory> --jose-checkout <pinned-clean-checkout> --platform iOS|macOS` generates an isolated Xcode project. Run scheme `NativeHelpUI` on an owned simulator or Mac test session. It does not change shipping targets, pairing, credentials or installed DJConnect.

The host defaults to the real byte-verified bundled catalogue, which currently advertises no command examples. `HELP_SYNTHETIC=1` decodes only the existing synthetic Core reference fixture from Tests; it is not a producer qualification or product switch. Neither the fixture nor this host is part of shipping resources.

The host renders production `AskDJHelpReference` with an injected context and clock deadline. It cannot create an AppModel, make requests, send a command or play audio. Probe buttons change only synthetic view state. Native tests cover idle original-context expiry, owner withdrawal, ended Session, empty shipping catalogue, both reference surfaces and five languages in normal/dark and accessibility/light presentations. Screenshots contain only the disposable test application; Mac screenshots target its window.

The focused interaction test uses the production native Help entry/popover and production suggestion rows, with three suggestions selected by the actual catalogue algorithm from the test-only fixture. It verifies exact selected-text forwarding to a probe label, opening/dismissing Help and stable row identity. This is not a command-send or paired-backend test.

These component tests do not exercise paired capability discovery, server-rendered typed `help`, physical VoiceOver output or real command execution. Those remain separate acceptance requirements. The 70 pending producer route/locale gates must not be changed by Apple or inferred from synthetic success.
