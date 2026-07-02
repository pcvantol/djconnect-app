# DJConnect demo screenshots

Generated from simulators on 2026-07-02.

## iOS and iPadOS

Each iOS/iPadOS device folder contains:

1. `01-now-playing.png`
2. `02-queue.png`
3. `03-playlists.png`
4. `04-games.png`
5. `05-ask-dj.png`
6. `06-track-insight.png`
7. `07-music-dna.png`
8. `08-settings.png`
9. `09-logs.png`
10. `10-about.png`
11. `11-legal.png`
12. `12-privacy.png`

Device folders:

- `iphone-air-ios-27-0-1260x2736`
- `iphone-13-mini-ios-26-5-1080x2340`
- `iphone-17-pro-max-ios-27-0-1320x2868`
- `ipad-mini-a17-ios-26-5-1488x2266`
- `ipad-pro-13-m5-ios-27-0-2064x2752`

The iOS/iPadOS screenshot UI test removes existing `*.png` files from
`DJCONNECT_SCREENSHOT_DIR` before it writes a new set. This keeps removed or
renamed screens from surviving as stale files after a fresh capture run.

## watchOS

Watch screenshots are captured from the watch simulator with `Tools/capture_watch_screenshots.sh`.
Build the Watch app first:

```sh
xcodebuild build -scheme DJConnectWatch -destination 'generic/platform=watchOS Simulator'
./Tools/capture_watch_screenshots.sh
```

The script launches the Watch app in demo/monkey mode once per screen with
`--screenshot-screen=<screen>`, then writes the simulator PNG after the target
screen has rendered. This avoids saving stale navigation states and keeps the
PNG aligned with the filename.

Before capturing a device, the script removes existing `*.png` files from that
device's output folder. Non-PNG support files are left untouched.

Each watchOS device folder contains:

1. `01-now-playing.png`
2. `02-output.png`
3. `03-queue.png`
4. `04-ask-dj.png`
5. `05-track-insight.png`
6. `06-music-dna.png`
7. `07-playlists.png`
8. `08-settings.png`
9. `09-logs.png`
10. `10-about.png`
11. `11-legal.png`
12. `12-privacy.png`
13. `13-feedback.png`
14. `01-watch-launch-demo.png`
15. `02-watch-soak-demo.png`

The Watch app target reuses the existing `Localizable.strings` variant group as
an app resource so screenshot builds resolve the same localized strings as the
core package. Do not add duplicate Watch-only string files for these shared keys.

Device folders:

- `apple-watch-se-3-40mm-watchos-26-5-324x394`
- `apple-watch-ultra-3-49mm-watchos-27-0-410x502`
