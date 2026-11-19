# Prompt History: Track Insight to Apple Native Sharing Implementation

Implement only the authorized CMB-11 reference path: existing renderer-safe
Track Insight content through `TrackInsightShareService` and
`TrackInsightShareRenderer` to the existing SwiftUI `ShareLink`. Track Insight
is the sole producer and Apple the sole Renderer Host. Qualify the local
payload to exclude Music DNA, Profile, Performance Memory, Planner/Runtime
context, provider payloads, Ask DJ history, credentials, tokens, device IDs
and installation IDs. The user explicitly opens the native Apple Share Sheet;
Apple owns destination, sending, cancellation and interaction. No Runtime,
Broadcast, API, DJ Intelligence, analytics, persistence or share-history
change is authorized.
