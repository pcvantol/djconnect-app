# Archived Session header avatar

The detail screen now places the existing SavedSessionMoodAvatar to the left of the top summary text block. It uses the same admitted summary/mood-availability policy as the Session list; no mood is inferred from tracks or current playback. The detail avatar is64points with16point spacing, aligned to the top. The predominant mood text row is omitted via showsMood=false; dates/duration, interruption, counts and readonly label remain in the text column. Unknown/mixed mood retains the existing avatar fallback and accessibility description.

Source/diff/register inspection only. No build, compiled tests, native render or installation under explicit-build-only instruction. Pending changes stay in PR179 without merge; installed preview40447 is unchanged. Next requested build should verify long date summaries, phone narrow widths and Dynamic Type as well as Mac/iPad header appearance.
