# Game controls use ordinary glass

The game controls already use the shared secondary circular glass button style. Its custom3point white focus overlay inherited the game surface focus state, making all four direction controls appear strongly outlined together. Scope showsFocusIndicator=false to both game control grids (Pacman directions and the other games' movement/fire controls). Ordinary interactive glass, its subtle1point edge, pressed feedback, target size, actions, labels and haptics remain unchanged. Other buttons keep their focus indication. No gameplay/model/network logic changes.

Validation and preview40447 installation are recorded below. This is a bounded presentation change, so no implementation-mirroring unit test was added.
