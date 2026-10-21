# Visible Flow search

Local successor to `95b05ab`. Active-session Flow now presents a persistent
inline TextField below its current-track header, using the same plain field,
12-point padding and frosted surface as Forecast search. It replaces the active
session's toolbar search button, compact session-menu search action and old
conditionally inserted AskDJSearchBar. Archive search retains its existing UI.

The field uses the existing session-history query, debounce, capability gates,
retained matches, paging and error handling. A nonempty query activates search;
clearing it clears selection and search state. Result navigation is explicit
through Return or previous/next buttons, so new matches do not automatically
scroll the inline field away while typing. Clear/Escape restores the previous
reading position. Command-F is wired to focus and reveal the inline field,
without a visible toolbar button. No backend contract or localization changes.

Validation: final isolated unsigned iOS Simulator build-for-testing completed
with exit 0 / TEST BUILD SUCCEEDED. Final native macOS DJConnectUI build
completed with exit 0 in 18.79 seconds. git diff --check passed. Earlier build
logs also remain preserved. No runtime interaction, keyboard shortcut, visual
geometry or physical-device acceptance is inferred from compilation. No app
installation or publication performed.

Final logs and SHA-256:

- `/private/tmp/djc-visible-flow-search-20261021-ios-final.log`:
  `7ae212d27f6ad3b8a9fd97e2c02fc27ef39d4c761e8bb04c963554a9b68c58af`
- `/private/tmp/djc-visible-flow-search-20261021-mac-final.log`:
  `37a7de6299ca832febf0341901ec0fe3c50974fa9b7a64d6a177fbaa8381e3ea`
