# Native VibeScape control qualification

The isolated host mounts the actual VibeScapeScreen and observes its real mode
flag, with only synthetic Profile/history/runtime/catalogue responses. Three
unchanged test fixtures are bundled; URLProtocol intercepts every app HTTP
request. It never pairs, contacts HA/provider/model services, plays audio or
submits a visual/Ask DJ command. Background transport is synthetic too.

Use the generator with an external destination, the pinned JOSESwift checkout,
`--platform iOS` and a fresh `--bundle-suffix` for each platform/run. The suffix
belongs only to this disposable host; no permission database is reset. Run the
generated NativeVibeScapeControl scheme serially on an owned simulator, with
external derived/result paths and `-collect-test-diagnostics never`.

One case taps the actual microphone twice, explicitly denies the OS request,
requires microphone=denied/speech=unknown/mode=active, then opens actual help
twice and checks freshly changed server text. Unknown alerts fail; no Allow
button is ever selected. The other case requires genuine background and owner
withdrawal to close the visit. Counters require zero POST/context/Ask DJ effects.
The host follows mode dismissal rather than keeping a ghost screen mounted.

This tests the denied-permission and public help UI components, not an
authorized microphone/STT/lease/directive/audio path, complete paired Root,
macOS UI, VoiceOver, physical GPU/energy, or actual provider/model acceptance.
