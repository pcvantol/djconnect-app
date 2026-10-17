# Session cover routing and MacBook latest build — 40292

Owner reports: Session vinyl remains visible while Now Playing has real artwork;
install the latest build on the MacBook.

## Correction

Session headers previously resolved relative broadcast artwork against haLocalURL,
regardless of the confirmed route. Now Playing already uses resolvedArtworkURL
and DJConnectArtworkRoute. Session headers now use the same public-cover resolver:
paired HA image proxies follow the confirmed local/external origin. External
provider images and credentialed owner grants retain their existing admission;
no Now Playing image is borrowed for another Session recording. Demo stays vinyl.
The shared glass-card wrapper is retained for both image and placeholder; the
placeholder remains the missing/failed-image fallback.

Regression checks a local proxy over external HTTPS, query/path preservation,
relative proxy, return to local, unchanged provider URL, absent image and invalid
scheme/credentials/network-relative URL rejection without making network requests.
Targeted test PASS0.088s. First full suite787tests failed only two obsolete source
expectations in the old landscape game-cap test, whose requirement was superseded
by the owner's available-space request. Replaced that lexical test with exercised
viewport calculation cases proving control space, remaining height, minimum game
height/scroll fallback and unrestricted portrait height. The extracted helper
preserves the installed game formula. Full787tests/10suites PASS89.600s.

Source commit:9d54967452a09d862b0eea6c56209cedb0483678. Tests run from an exact
Git archive, excluding unrelated untracked duplicate source/test/tool/project
copies that appeared in the canonical checkout. Duplicates remain untouched.
Signed native Mac and iOS builds including embedded targets PASS. Private source,
logs and receipts: `/private/tmp/djc-artwork-routing-40292`. No public merge or
formal source Finalization is claimed.

## Actual MacBook installation

Existing SSH route resolves to mbpro-peter, macOS27.0.1, initial app40208.
Final archive SHA256:
`2771d006cbbd9002c28cbe9d7b897e53c9bf4d8036bf61401c77dafa913028a6`.
Complete79-entry bundle byte/mode/framework-symlink manifest matched on the remote
staging app and final installation; strict deep signatures PASS.

Normal app quit succeeded. The ordinary installer refuses active/uncertain
processes, copies with preserved executable bits/relative symlinks, and retained
`/Applications/DJConnect-recovery-20261017T203011Z.app` before installing40292.
Independent `/Applications/DJConnect.app` plist/signature/manifest readback PASS;
normal open and running-process readback PASS. No physical GUI/pairing/music
acceptance is inferred from the process result. Mac mini was not updated.

## iPhone/iPad boundary

The earlier reported artwork task remains included. iPhone ordinary40292 install,
independent apps-version readback and process launch PASS. iPad install failed
with CoreDevice4016 (usage assertion requirements unavailable); last confirmed
ordinary version remains40290. No retry/service reset or new iPad acceptance.
Actual same-track external artwork viewport has not been captured on hardware;
source/fixture routing proof and installed/launch proof remain distinct.
