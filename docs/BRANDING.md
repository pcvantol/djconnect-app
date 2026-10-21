# Main brand tagline

The app uses one localized resource key, `brand.tagline`, from DJConnectCore.

| Language | Main brand tagline |
| --- | --- |
| Nederlands | Jouw muziek. Jouw DJ. |
| English | Your music. Your DJ. |
| Deutsch | Deine Musik. Dein DJ. |
| Français | Votre musique. Votre DJ. |
| Español | Tu música. Tu DJ. |

Apple #138 adopts the Core #1223 Brand V2 original headset and English slogan.
The five translations reuse the app's existing `ui.session.welcome.title` copy,
with its newline replaced by a space; French retains the existing formal “Votre”.

`DJConnectLaunchBanner` is shared by runtime launch and About/setup/service
sheets. It uses the icon image beside two native SwiftUI text lines: product
name and localized tagline. The two text lines stay within the icon height at
all widths. Text is not baked into a runtime wordmark PNG. Watch About retains
its existing localized slogan; no slogan is added to tiny surfaces.

The system-owned iOS launch storyboard is language-neutral: it contains only
`LaunchIcon` and the product name `DJConnect`. It has no localized tagline or
`LaunchScreen.strings` files. Runtime UI renders the localized tagline using the
existing app-language override. The retired captioned raster remains excluded
from shipped assets; historical artwork under Tools/BrandAssets must not be
reintroduced as launch copy.

After an approved translation edit:

```sh
python3 Tools/validate_brand_tagline.py
```

The validator checks exact translations, duplicate/parity errors, the language-neutral
system launch, active legacy source references and the retired captioned
raster. The Swift localization regression reads the actual shared module resources.

Community/Personal tier propositions remain separate copy. Functional help,
error descriptions, product capabilities and historical release evidence are
not rewritten. App Store subtitle metadata remains a separate constrained field;
do not abbreviate the main sentence into an unapproved slogan to fit it.

## Brand V2 handoff

Source, Finalization pins, exact source manifest, license and generator mapping
are recorded in [source provenance](../Tools/IconSource/BrandV2/README.md).
The retained legacy app icon catalogs use the earlier headset/glass size rule.
They are historical fallbacks, not the selected app icon. LaunchIcon
retains the exact producer transparency. Runtime and Watch avoid a second glass
frame around that artwork. Living Persona/state avatars, functional music symbols,
Spotify attribution, album/artist art and historical release evidence are unchanged.

The [preflight](feedback/APPLE_BRAND_V2_PREFLIGHT_20261019.md) and
[scale review](feedback/APPLE_BRAND_NATIVE_SCALE_REVIEW_20261019.md) are historical
receipts predating source merge; they do not describe current source adoption.

## Adaptive headphone app icon — 21 October 2026

The owner requested the simpler purple headphone previously made in ESP32,
without the blue glass tile, and backgrounds that follow system icon appearance.
`Apps/Shared/AppIconAdaptive.icon` now supplies the native app icon for iPhone,
iPad, Mac and Watch. iOS/macOS support default, dark, clear and tinted rendering;
Watch uses the circular system mask. Xcode compiles the layered document, and the
system selects the appearance. No app setting or alternate-icon API is involved.

The foreground is the exact transparent ESP32 PR #69 PNG, pinned at
`c49d49186951ed3a4eaf3cc50778e48e04cbbef9`, SHA256
`f69eb72b882f08c0dacbd3efa7e83165a56a01763aaa18e48557c03b65e11322`.
The purple headphone, magenta ring, navy center and waveform are retained.
There is no baked outer glass tile, outer canvas or wordmark. Icon Composer
positions the unmodified source at 64% scale with separate pale default and
charcoal dark background fills; the system derives mono/clear/tinted variants.
The inner navy disc remains part of the foreground drawing, not the outer tile.
Source provenance is in `Tools/IconSource/AdaptiveHeadphone/provenance.json`.

`GenerateAppIcon.swift` and the October 20 manifest describe the retained legacy
catalogs only. They do not generate or overwrite `AppIconAdaptive.icon`. Runtime
brand cards continue to use their existing image and native text; this request
changes the installed app icon only.

Reference: [Apple Icon Composer documentation](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).
Run `python3 Tools/validate_brand_assets.py` and compile the document with
`actool` for each app platform after an icon change. Native renderer exports
are visual review artifacts, not physical-device screenshots or installation
acceptance.
