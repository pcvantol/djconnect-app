# DJConnect Native App Entrypoints

This folder contains the SwiftUI `@main` entrypoints for the future native app
targets:

- `DJConnectIOS/DJConnectIOSApp.swift`
- `DJConnectMac/DJConnectMacApp.swift`

Both apps use the shared `DJConnectUI` package product, which keeps UI screens
separate from the `DJConnectCore` HTTP/client contract. Add these files to real
iOS and macOS Xcode app targets when the Xcode project or workspace is created.
