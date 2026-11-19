# Apple Brand V2 preflight — 19 October 2026

Read-only asset/generation preparation for Apple138 / Core1223. Inspected Apple
source 8db584e (PR142); current assets and generator were unchanged by that PR.
This is not acceptance of a new producer master or a Brand V2 implementation.
Core1223 is still open without the complete reviewed master/wordmark manifest.
No preliminary archive or unapproved translation was adopted.

## Native raster census

| Asset set | Declared slots | Unique PNGs | Pixel widths |
| --- | ---: | ---: | --- |
| iPhone/iPad, including dark/tinted | 20 | 15 | 20,29,40,58,60,76,80,87,120,152,167,180,1024 |
| Mac | 10 | 7 | 16,32,64,128,256,512,1024 |
| Watch | 11 | 11 | 48,55,58,80,87,88,100,172,196,216,1024 |

All declared size/scale combinations match their PNG headers. Together with the
1024px generator input and separate 1024px LaunchIcon, the census covers35 PNGs.
Per-path dimensions and SHA256 are retained under
build/qualification/brand-v2-preflight-20261019/asset-census.json.

Tools/GenerateAppIcon.swift reads Tools/IconSource/djconnect-icon-1024.png.
Two generations in an isolated temporary directory produced identical33 PNGs
and3 Contents.json files; every generated file matches the existing source
asset tree. The real tree was not regenerated or mutated. This proves current
generator reproducibility on this host, not visual acceptance of the new master.
The generator does not produce LaunchIcon; adoption must replace/check it
explicitly instead of assuming icon generation updates it.

## Active consumer map

- iOS system launch: LaunchIcon plus product name; no tagline or localized
  LaunchScreen.strings. The current branding document's obsolete description
  was corrected to match the actual storyboard and validator.
- Native launch/About/setup/permission banners: shared DJConnectLaunchBanner,
  DJConnectGlassBrandIcon and LaunchIcon, with a native glass wrapper. Review
  new artwork for double borders or clipped headphone ears after the handoff.
- Watch About/setup/service surfaces: DJConnectWatchGlassBrandIcon and the
  shared localized brand.tagline where already present. Compact surfaces gain
  no extra slogan.
- Session avatar, sidebar Session symbol, widgets, Live Activity and Dynamic
  Island: the live DJ vector represents persona/state, not a replacement raster
  brand master. Preserve that feature owner and its current palette semantics.
- SpotifyAttribution in shared/widget assets is third-party attribution and must
  remain unchanged. Album art, valid music/vinyl symbols, historical screenshots,
  evidence and old release notes are excluded from brand replacement.

## Copy and acceptance boundary

The current brand validator passes all5 locales with1337 matching keys and
language-neutral system launch. The existing brand.tagline test and validator
hard-code the currently shipped sentences; replace translations, expected values
and documentation together only after the Core handoff and translation approval.
English graphical wordmarks must use exactly `Your music. Your DJ.`. Localized
candidate translations in Apple138 are not approved by this preflight.

Remaining delivery: exact reviewed Core master+wordmarks+manifest; atomic native
source/outputs/copy adoption; actual16–40px, dark/tinted, Watch and native-screen
visual review; builds/independent review/protected merge and installed sign-off.
No release, device installation or producer delivery is claimed here.
