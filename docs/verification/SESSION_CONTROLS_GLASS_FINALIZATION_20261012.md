# Apple session controls Finalization — PR #103

PR [#103](https://github.com/pcvantol/djconnect-app/pull/103) delivered reviewed source `65f7c3a23957edf368b6780a775f0e4c2f34cf34` by protected squash merge to main `48b6b74d7ad41a7137c74c07cc8f0f788d5ee75c`, parent `7900ec77455234879a35844b477c6d1e46412cef`. Main and candidate have the same tree `c4a98698aedc0a506b10a885b3ec76aa4359c438`. This Finalization records evidence only and changes no application code.

## Delivered source

Build 40016 introduces native iPad bottom Liquid Glass navigation; grouped glass conversation surfaces; shared hero/card geometry; toolbar mood and connection popovers; Session end confirmation; mandatory pairing on unpaired Demo exit; guarded refresh; playback time labels; corrected small Mac window layout and sidebar tint; and complete removal of the obsolete local AirPlay route/render/server path. Canonical backend-owned VibeCast remains distinct. Source behavior and its limits are described in [the source verification](SESSION_CONTROLS_GLASS_20261012.md).

## Exact delivery evidence

- [Pre-merge CI](https://github.com/pcvantol/djconnect-app/actions/runs/38270652708) and [exact Owner Authorization](https://github.com/pcvantol/djconnect-app/actions/runs/38270998193): PASS.
- [Main CI](https://github.com/pcvantol/djconnect-app/actions/runs/38271451974): PASS, including unsigned Apple builds and coverage evidence.
- [Post-merge reconciliation](https://github.com/pcvantol/djconnect-app/actions/runs/38272295348): `POST_MERGE_RELEASE_EVIDENCE_QUALIFIED`, no findings.
- [Durable internal qualification](https://github.com/pcvantol/djconnect-app/releases/tag/internal-ha-48b6b74d7ad41a7137c74c07cc8f0f788d5ee75c): exact main binding verified; asset SHA-256 `c8f425dcc947296fa8124663f961a82fbb6e589bcda74a25b95b5f809b2a628a`; canonical JSON integrity `8a18b32fe44a64511f68f3e855654f8795595b12d67fc635323e1b2789cb3f0a` independently checked. This internal evidence tag does not represent an HA deployment.
- Main coverage artifact SHA-256: `6c977b7c00bde8645e7cef0e1ecdc607e5f84213552f7c5c3af01d667903c440`.

## Native and acceptance boundaries

477 general Swift tests reported PASS; separately gated producer qualification retains its own boundary. Five languages have matching 1,053-key sets. Native iPhone and iPad tests pass for menu reachability, Demo exit/pairing/restart, mood, status, timing and contribution selection. Actual pinned-Core pairing/mood/recovery/history pull is separately exercised. Full-screen iPad portrait/landscape proof was reviewed; cropped app-screenshot rotation artifacts were excluded.

After a separately bound owner grant, only the temporary local Mac 65f test bundle was ad-hoc signed. Bounded Demo UI proof passed for mood change, confirm/cancel, small-window Ask DJ/sidebar, status popup, mandatory pairing after Escape, disabled refresh and Demo restart. No certificate or installed-app replacement was used. Independent source and bounded visual reviews found no open concrete P1/P2.

Physical 40016 installation, physical iPad scroll performance and VoiceOver acceptance remain NOT_RUN. Simulator performance variability and increased peak memory prevent a physical improvement claim. No Store, TestFlight or HA deployment occurred. The non-blocking TDE observer failed because its runner could not install a runtime requiring Python 3.11 or newer; required delivery checks and main reconciliation passed. That observer result is not recorded as PASS.

Later owner requests for pinned mood tint, right-aligned elapsed/total, mood-popup typography/localization and queue-style archive rows are a separate source candidate. They are not folded into this SHA-bound Finalization.
