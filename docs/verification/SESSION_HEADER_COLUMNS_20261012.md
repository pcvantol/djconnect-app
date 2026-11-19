# Session header columns refinement — 2026-10-12

Owner request: current album artwork and music context on the left, current DJ/quiet card on the right on Mac, iPad and iPhone. Keep the current header pinned and the timeline below it. This refinement follows completed source PR #99 and Finalization PR #100, from exact main `c045473a8a0eda05b0ad4824284ca50a46baf9d2`, with one reused Apple writer and the unrelated primary WIP preserved.

The shared native header uses two measured columns at every supported width. Music receives up to 180pt and one quarter of available width; the DJ card receives the remainder. Both measure full text height and retain the existing header scrolling. Read-only source, recovery and event semantics remain unchanged.

Spotify attribution is retained as the existing full white logo with its source link, reduced to 70pt width and 10pt clear space. Current Spotify guidelines require attribution and identify 70px as the minimum digital full-logo width. No new icon asset, logo alteration or local data lookup was introduced. Reference: https://developer.spotify.com/documentation/design (checked 2026-10-12).

## Native evidence

- iPhone: `testSessionCurrentMusicStaysLeftOfDJCard` PASS, `/private/tmp/djc-header-iphone-final.xcresult`; screenshot `/private/tmp/djc-header-iphone-final-images/96CF0BCC-A6EA-4D7C-A9C0-D42A436EA563.png`.
- iPad: same native test PASS, `/private/tmp/djc-header-ipad.xcresult`; screenshot `/private/tmp/djc-header-ipad-images/3E1D015D-6070-49FF-8734-8350EA22BB6A.png`.
- Both tests use the existing explicit Demo decode/state/native route and verify independent column bounds. Demo does not provide an artwork URL or Spotify-attributed current card, so this proves music/DJ placement, not live artwork retrieval or logo rendering.
- First iPhone attempt failed to expose independent accessibility groups; retained `/private/tmp/djc-header-iphone.xcresult` and log. Explicit contained groups and the existing two-launch Demo bootstrap fixed the test.
- Unsigned Mac build 40015 PASS: `/private/tmp/djc-header-mac-40015-final-build.log`. Owner-approved temporary ad-hoc Mac proof PASS for product candidate `998a5f97`: native Demo/AX music x600 versus DJ x804, top y244; screenshot `/private/tmp/djc-header-998-mac-test/mac-music-left-dj-right.png`. The isolated test PID708 was closed after proof; installed apps were not replaced. This proves music/DJ positions, not real provider imagery.
- Unsigned iOS simulator build 40015 PASS: `/private/tmp/djc-header-ios-40015-build.log`.
- Technical read-only review: source GO, no P1/P2. UX bounded iPhone/iPad/Mac screenshot GO; the compact badge hit area was increased to at least 44pt after review.

No publication, new physical installation, Store release or HA deployment is claimed for build 40015. Installed iPad/MacBook build 40014 remains the previous approved artifact. Larger accessibility sizes and long-language stress checks are not qualified by this narrow native frame test.
