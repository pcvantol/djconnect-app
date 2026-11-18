# Game controls use ordinary glass

The game controls already use the shared secondary circular glass button style. Its custom3point white focus overlay inherited the game surface focus state, making all four direction controls appear strongly outlined together. Scope showsFocusIndicator=false to both game control grids (Pacman directions and the other games' movement/fire controls). Ordinary interactive glass, its subtle1point edge, pressed feedback, target size, actions, labels and haptics remain unchanged. Other buttons keep their focus indication. No gameplay/model/network logic changes.

Validation and preview40447 installation are recorded below. This is a bounded presentation change, so no implementation-mirroring unit test was added.

Validation: signed macOS/iOS40447builds and strict signaturesPASS; actual shared style rendered natively in /private/tmp/djc-game-glass-40447.png and visually inspected (ordinary subtle edge, no thick white rings). Installed/read back40447 on Mac mini, MacBook, iPhone and iPad before the owner's new build restriction; iPad launched. Both installed Mac UI hashes match9178058c0c503c6cb202956a1c6ed44d1187df71fa921984c11d2c0a620a8bcd. Physical game-screen acceptance remains separate. Implementation9970a35.

Owner instruction22October after this delivery: stop making a build for each point; build only when explicitly requested. Subsequent source changes collect in the same PR without automatic builds/installations or merge.
