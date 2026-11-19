# Glass hero cards

Local successor to `6fd4274`. The shared djConnectHeroCard helper now delegates
to djSessionFrostedSurface, exactly as the already accepted Feedback popup does.
Removed its opaque purple gradient and Track Insight's additional black/color
backplate. The unused background-color parameter was removed; Track Insight's
artwork, visualization and profile data remain intact.

All seven hero-style use sites now share this surface:

- Music DNA active and inactive hero cards.
- Introduction card shared by Discover and Ask DJ.
- Track Insight's populated hero and empty-state hero.
- Idle DJ-session welcome card.
- VibeCast session-start popup hero.

Geometry, glyphs, copy, actions and accessibility grouping remain unchanged.
The common surface retains its existing reduced-transparency/glass-disabled
fallback. General non-hero gradient cards and screen canvases are unchanged.

Validation: isolated unsigned iOS Simulator build-for-testing completed with
exit 0 / TEST BUILD SUCCEEDED. Native macOS DJConnectUI build completed with
exit 0 in 46.96 seconds. git diff --check passed. No runtime visual acceptance,
device installation or publication is claimed.

Build logs and SHA-256:

- `/private/tmp/djc-glass-hero-cards-20261021-ios.log`:
  `2234b50b9cee85838539622856d61ab7504a6125bd951719ee853e0d0198cd68`
- `/private/tmp/djc-glass-hero-cards-20261021-mac.log`:
  `7950694190fb02dd916a4c259f873f8daa8c9604e92a33e959de75ba298c42f5`
