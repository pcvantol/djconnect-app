# Apple Native Share Capability Assessment

**Decision:** `GO_CROSS_REPOSITORY_EVIDENCE_COMPLETE`

Existing Apple evidence is sufficient for the CMB-11 reference pair: Track
Insight is rendered locally through `TrackInsightShareRenderer`, coordinated by
`TrackInsightShareService`, and presented through SwiftUI `ShareLink`.

The Apple Renderer Host owns local image/video rendering, local share-format
selection, ShareLink lifecycle and user interaction. Track Insight remains the
backend-owned producer; DJ Intelligence, Runtime and Planner do not invoke
platform-native sharing. The user selects the action and destination; ShareLink
hands the already-rendered local item to the OS.

Only renderer-safe Track Insight content is eligible. Music DNA, Profile,
Performance Memory, Planner/Runtime context, provider payloads, Ask DJ history,
credentials and tokens are excluded. The current local renderer/service is the
Apple capability inventory required by PR #492; no new Apple capability is
needed before the bounded implementation decision in the main repository.

## Track Insight to Apple Native Sharing implementation

The bounded implementation uses only the existing Track Insight presentation,
`TrackInsightShareService`, `TrackInsightShareRenderer`, and SwiftUI
`ShareLink` path. Track Insight remains the sole producer and Apple remains the
sole Renderer Host. The service qualifies the share message from the already
visible title, artist, selected descriptors, and summary; it does not include
Music DNA, Profile, Performance Memory, Planner or Runtime context, provider
payloads, Ask DJ history, credentials, tokens, device identifiers, or
installation identifiers.

The renderer creates the local media only after the existing preview is opened.
The user then explicitly invokes `ShareLink`; Apple Share Sheet owns the
destination, sending, cancellation, and all subsequent user interaction. This
path records no share history, analytics, or payload logging and creates no
Runtime, Broadcast, API, or DJ Intelligence change.
