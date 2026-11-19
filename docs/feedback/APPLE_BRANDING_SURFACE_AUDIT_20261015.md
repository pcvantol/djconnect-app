# Apple branding surface audit — 2026-10-15

Owner request: inspect all app popovers/sheets containing the DJConnect logo and
apply the shared glass treatment. Source writer remains the existing Apple lane.

## Shared iPhone / iPad / Mac UI

All sixteen AboutBanner call sites delegate to DJConnectLaunchBanner, which uses
DJConnectGlassBrandIcon. No sheet or popover directly renders the bare app icon.
The launchscreen uses the same banner. Source inventory:

| Surface | Result |
| --- | --- |
| Permission explanation | Shared glass banner |
| Pairing | Shared glass banner |
| Wake-word activation prompt | Shared glass banner |
| Possible-crash prompt | Shared glass banner |
| Welcome | Shared glass banner |
| What's New | Shared glass banner |
| Update notes | Shared glass banner |
| Music DNA opt-in | Shared glass banner |
| Ask DJ history export | Shared glass banner |
| Music DNA export | Shared glass banner |
| Music DNA import | Shared glass banner |
| About | Shared glass banner |
| Legal notices | Shared glass banner |
| Privacy | Shared glass banner |
| Ask DJ feedback | Shared glass banner |
| General feedback | Shared glass banner |

The remaining standalone demo album placeholder used the bare icon. It now uses
DJConnectGlassBrandIcon as well. The raw asset loader is private in the same file
as the glass wrapper, preventing accidental bare-icon use by other UI screens.
Provider attribution and album artwork are separate assets and are unchanged.

## Watch presentation

Found three bare LaunchIcon uses: pairing, Welcome sheet, and About. They now use
one Watch glass-logo component, scaled for the existing34/44-point layouts, with
a native glass surface, matching highlight/border and Reduce Transparency fallback.
The Watch target remains independent of the full phone/tablet UI target.

## Validation boundary

Build candidate40066: native signed Mac and iOS (including Watch target) build
results are recorded in APPLE_FEEDBACK_STATUS_20261015.md. Whitespace verification
PASS. No new behavioural tests are needed for this presentation-only reuse.

The previous physical iPad40065 screenshot verified the shared logo/banner in
an actual crash sheet. This audit establishes source coverage of all listed
surfaces; it does not claim that every sheet and Watch layout has been opened on
physical hardware. Physical Watch was unavailable during the preceding inventory.
No new permissions, pairing, diagnostics uploads or server changes are involved.
