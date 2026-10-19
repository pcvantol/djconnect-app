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
sheets. Wide English layouts use the exact primary dark wordmark; other languages
use the compact dark wordmark and native localized slogan. Dark wordmarks have
light lettering for the app's dark canvases, even when system appearance is light.
Below 360 points or from XXXL text upward, native product name and slogan stack
with the approved glass mark. The slogan wraps rather than truncating. Watch
About retains its existing localized slogan; no slogan is added to tiny surfaces.

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
All three app icon catalogs use the approved headset artwork. Generated icon
output <=40 pixels uses only the maximally fitted headset; larger outputs use
the glass mark. This is the literal output-pixel rule, not the unapproved
logical-point alternative discussed in the historical scale review. LaunchIcon
retains the exact producer transparency. Runtime and Watch avoid a second glass
frame around that artwork. Living Persona/state avatars, functional music symbols,
Spotify attribution, album/artist art and historical release evidence are unchanged.

The [preflight](feedback/APPLE_BRAND_V2_PREFLIGHT_20261019.md) and
[scale review](feedback/APPLE_BRAND_NATIVE_SCALE_REVIEW_20261019.md) are historical
receipts predating source merge; they do not describe current source adoption.
