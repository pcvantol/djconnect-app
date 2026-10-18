# Consistent Mac refresh/status edge and separate sidebar toggle

Owner requests every Mac screen place Refresh at the far right, beside connection
when available, and keep the sidebar show/hide control separate from other leading
icons. Presentation change only; no refresh/network operation changes.

- Shared Mac refresh placement changes navigation -> confirmationAction. Screen
  search uses a separate leading-placement token, preserving iOS primaryAction.
- Now Playing, Music DNA, Discover, Queue and Playlists place connection before
  refresh at the shared trailing placement. Idle Session does the same; Saved
  Sessions inherits trailing refresh without adding a connection control.
- Active Session keeps search/mood/presence/persona/voice/end leading, VibeCast a
  separate leading item with fixed native separation, and connection+refresh in
  one trailing group. Read-only archive refresh is trailing when supplied.
- Track Insight keeps mood/share leading, connection+refresh trailing. Ask DJ keeps
  search/clear leading and connection+refresh trailing. Other screens without a
  refresh action do not gain one; inline output-device refresh is unchanged.
- Root sidebar toggle is followed by a native fixed navigation ToolbarSpacer on
  macOS26+, separating its glass group from feature controls. Current Mac target
  deployment26.0 and SDK API availability were checked locally.

Diff/native signed Mac40310 build/strict deep signature/ordinary-product and
work-register checks PASS. No mirrored layout tests or new full-suite claim.
Physical cross-screen toolbar/overflow/fullscreen acceptance remains separate.
This Mac-only increment is not installed under standing iPhone-only scope;
iPhone40309/iPad40290/MacBook40292 remain the last installed readbacks.

Evidence: `/private/tmp/djc-toolbar-edges-40310-mac-build.log`.
