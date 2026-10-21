# Games restart in the toolbar

The existing selected-game reset button is now the primary action in the Games navigation toolbar, at the trailing/top-right position. Its localized label/help and original reset routine are retained. The button has identifier `games-restart`.

Reset buttons were removed from all game-card control grids. Grid column counts now match the remaining two Paddle Rally controls, three Meteor Run/Sky Dash controls and four Maze Chase controls. High-score storage and gameplay/reset behavior are unchanged.

The shared UI compiles for macOS and unsigned iOS/iPadOS; both builds PASS and diff whitespace validation PASS. This small presentation move adds no new tests. Native toolbar placement/tapping and physical devices were not exercised. No installation or external publication occurred. Adjacent JSON records log hashes.
