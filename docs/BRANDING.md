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

The system-owned iOS launch storyboard cannot invoke Swift localization. Its
five `LaunchScreen.strings` files are generated from `brand.tagline`; the English
storyboard base is checked against that same source. The old captioned raster
asset is no longer shipped. The original artwork master remains under
Tools/BrandAssets as historical source and must not be reintroduced as launch copy.
The system launch uses the OS-selected app locale; runtime additionally honors
the existing explicit in-app language override.

After an approved translation edit:

```sh
python3 Tools/validate_brand_tagline.py --write
python3 Tools/validate_brand_tagline.py
```

The validator checks exact translations, duplicate/parity errors, generated
launch resources, active legacy source references and the retired captioned
raster. The Swift localization regression reads the actual shared module resources.

Community/Personal tier propositions remain separate copy. Functional help,
error descriptions, product capabilities and historical release evidence are
not rewritten. App Store subtitle metadata remains a separate constrained field;
do not abbreviate the main sentence into an unapproved slogan to fit it.
