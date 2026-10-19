# Main brand tagline

The app uses one localized resource key, `brand.tagline`, from DJConnectCore.

| Language | Main brand tagline |
| --- | --- |
| Nederlands | Zet je muziek aan. DJConnect brengt die tot leven. |
| English | Play your music. DJConnect brings it to life. |
| Deutsch | Mach deine Musik an. DJConnect erweckt sie zum Leben. |
| Français | Lancez votre musique. DJConnect lui donne vie. |
| Español | Pon tu música. DJConnect le da vida. |

This implements `DJC-APPLE-NL-TAGLINE-ALIGNMENT-20261015` and the subsequent
owner instruction to apply the change in all five languages. Preserve the exact
sentence and punctuation. Wrap naturally rather than truncating the promise.

`DJConnectLaunchBanner` is shared by runtime launch and the About/setup/service
sheets through `AboutBanner`. Narrow and accessibility layouts stack vertically;
text has no maximum line count or tagline shrink factor. Runtime launch scrolls
when required. The default banner uses the existing five-language/app-override
resolver. Watch About uses the same key only where it already showed the tagline.
No tagline is added to widgets or other compact surfaces that did not have one.

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

Apple issue #138 tracks the approved headphones rebrand and the future English
slogan `Your music. Your DJ.`. The table above describes the currently shipped
resources, not the future Brand V2 translations. Consume only the reviewed Core
#1223 master/wordmark manifest and exact source pin. The preliminary icon-only
archive does not qualify the complete handoff; proposed localized translations
remain unapproved. See [native asset preflight](feedback/APPLE_BRAND_V2_PREFLIGHT_20261019.md).
