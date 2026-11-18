# Physical Watch installation — 40449

Owner request: “installeer 40449 op mijn watch”. Completed 22 October 2026,
18:53:44 UTC. The owner unlocked the Watch/iPhone after the first Watch
connection check reported disconnected; the next check reported connected.

The earlier 40449 artifact was simulator-only. Its pre-Apple-#128 source was
reconstructed from main `8c349e7581a13c7700643df0fcf14366feb9e0ae` plus the preserved
pre-#128 WIP snapshot, including untracked source/resources. All seven source
hashes from the successful simulator receipt match. The separate #128 catalogue,
UI and tests are absent from this isolated build source.

Required dependency preflight passed, with system tool upgrades skipped.
Signed physical Debug iOS build with embedded Watch application succeeded;
`codesign --verify --deep --strict` passed for both application bundles.

Physical installation and independent device application readbacks confirmed:

| Device | Bundle | Version |
| --- | --- | --- |
| Apple Watch Series 11 | `dev.djconnect.ios.watch` | 4.0.0 (40449) |
| Paired iPhone 17 Pro companion | `dev.djconnect.ios` | 4.0.0 (40449) |

No new #128 build, merge, Core deployment or HA operation was performed. The
physical Session flow, speech and push behavior were not tested in this
installation step. Earlier simulator qualification is documented separately.

Local evidence:
`/Volumes/Shared Data/tmp/pcvantol/djc-watch-physical-40449-20261022/`.
`installation-receipt.json` contains filtered independent version readbacks;
`artifact-receipt.json` contains executable hashes and bundle versions;
`source-provenance.json` contains the seven matching simulator-source hashes.
