# Apple Validation and Release Profile

Use the native Apple profile: `swift test --no-parallel`, localization checks,
and unsigned `xcodebuild` validation for `DJConnectMac`, `DJConnectIOS` and
`DJConnectWatch` where the local toolchain/target permits. Run unit tests and
existing UI tests where configured; validate generated artifacts and signing
only on approved Apple release paths.

Artifacts are signed macOS, iOS/iPadOS and watchOS applications, distributed
through approved internal relay, TestFlight, App Store and/or notarized macOS
paths. Docker, Cloudflare Workers and HACS are not Apple deployment targets.
