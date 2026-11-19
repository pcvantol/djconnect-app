# Manual content refresh audit — 2026-10-18

The iPhone/iPad pull gesture and its corresponding toolbar button call the same
function below. Mac uses that same screen function for its button. All functions
run through `DJConnectManualRefreshController`, which publishes `Bijwerken…` and
then the actual success/failure, shares callers and isolates work from cancelled
SwiftUI gesture tasks. A Profile epoch change suppresses private stale feedback.
Automatic reads remain quiet.

| Screen | Shared entry point | Data refreshed / result |
| --- | --- | --- |
| Now Playing (iOS and Mac) | `refreshNowPlayingWithToast` | Playback/status and existing backend collections |
| Active DJ Session | `refreshTimeline` | Playback, active Session, conversation and visible timeline; every required read must succeed |
| Earlier Sessions list | `refresh` | Authorized archive list and preparation |
| Earlier Session details / inline retry | `refreshTimeline` | Conversation and anchored/tail timeline windows |
| Track Insight | `refreshTrackInsightWithToast` | Current analysis, forced read |
| Explicit Moment Insight / retry | `refreshTrackInsightWithToast` | The pinned Moment analysis |
| Discover | `refreshMusicDiscoveryWithToast` | Backend regeneration, with existing feed fallback |
| Music DNA / unavailable retry | `refreshMusicDNAWithToast` | Profile read and bounded recovery; returns the actual read result |
| Ask DJ | `refreshAskDJWithToast` | Dismiss keyboard, sync retained history and existing idle suggestion read |
| Queue | `refreshQueueWithToast` | Queue read |
| Playlists | `refreshPlaylistsWithToast` | Playlist read |
| Output devices (button only) | Shared controller around `refreshOutputDevicesAndPlayback` | Inventory and existing playback confirmation |

No pull gesture is attached on an idle DJ Session or on empty Track Insight,
Discover, Ask DJ and Music DNA. Demo/unpaired content screens with disabled
refresh buttons do not expose an active pull gesture. Loading flags do not
change a ScrollView's identity midway through a running refresh.

Network reconnection, resetting choices, replaying a failed chat message and
updating a feedback draft are separate operations, not content-refresh pairs.
The Watch has no pull-to-refresh bindings; its independent Watch UI is outside
this screen-pair change.

Validation records distinguish controller/model regression tests, signed native
iOS/macOS compilation, and installed version readback. Compilation and model
checks do not establish physical pull-gesture acceptance or live HA/Spotify
availability. Native hosted CI may remain queued independently of the required
Trusted Delivery qualification.
