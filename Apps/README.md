# DJConnect Native App Entrypoints

This folder contains the SwiftUI `@main` entrypoints for the native app targets:

- `DJConnectIOS/DJConnectIOSApp.swift`
- `DJConnectMac/DJConnectMacApp.swift`
- `DJConnectWatch/DJConnectWatchApp.swift`

iOS and macOS use the shared `DJConnectUI` package product, which keeps UI
screens separate from the `DJConnectCore` HTTP/client contract. watchOS uses a
compact standalone SwiftUI surface backed directly by `DJConnectCore`.

Ask DJ is the rich Apple-side chat/PTT experience across iOS, macOS, and
watchOS. Do not add a separate Now Playing DJ request surface; voice and text DJ
requests belong in Ask DJ.
