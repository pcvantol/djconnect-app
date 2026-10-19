# Apple Brand V2 native adoption — 2026-10-20

Scope: Apple #138, presentation-only consumer of Core #1223. Candidate branch
`codex/apple-brand-v2-adoption`, based on main `e106a467011b9ea84d301a81c4e07251314cc6dd`.
PR #155 remains a separate unmerged branch; this change does not absorb it.

## Producer readback

- Source candidate: `883cb9f3ff9de8ec7f5ae4c5f04f852e0d8bd866`.
- Source PR #1224 main: `7e14e5970b3f68d33d243ae6bab2b281fad59bb2`.
- Separate Finalization PR #1227 main: `baac22d771bf3141404001517f62a5e34f8c8644`.
- Exact manifest SHA256: `73cc408e10d88aa1fb8a1be2783b9c577aec398ce3dcd54c2f997ad1425984d2`.

The existing local producer export was verified against GitHub Contents/Git blob
identities at the finalized immutable commit: all 28 files under
`assets/djconnect/brand-v2`, plus the imported font license/provenance. This is a
fresh immutable-source readback, not a claim that the historical Actions archive
was downloaded again. Only the original blue/purple/cyan glass headset is used.

## Native asset/reference census

| Surface | Adoption or retained purpose |
| --- | --- |
| Generator input + iPhone/iPad icon catalog | New glass source; output <=40px uses headset only; dark/tinted preserved |
| Mac icon catalog | All 16/32/64/128/256/512/1024 outputs regenerated |
| Watch icon catalog | All declared outputs regenerated, roles/scales retained |
| LaunchIcon | Exact transparent producer mark; iOS system launch keeps only name + mark |
| Runtime launch, About/setup/service banner | English primary wordmark or localized compact wordmark; native text fallback |
| Watch welcome, permissions, About | New LaunchIcon, no extra glass rim; output-pixel micro selection |
| Native five-language slogan and spoken sample | New slogan; existing welcome translations reused, not new translation proposals |
| Persona/session avatar, live activity, phone/Mac widgets | Retained living state/avatar components, independent from corporate brand |
| Watch Session heading / complications | Retained functional Session optical-disc glyphs; state/avatar follow-up remains Apple #127, not corporate logo replacement |
| Album/artist artwork, functional music/vinyl placeholders, Spotify attribution | Retained semantic/third-party content |
| Historical Tool artwork, screenshots, release evidence | Retained archival content; not referenced by current launch assets |

The four exact primary/compact light/dark wordmarks are imported. Active app
panels use dark canvases and therefore the producer's `dark` (light lettering)
variant regardless of OS appearance. English wide banners use the primary
wordmark; other languages use compact + native slogan. Narrow layouts and XXXL
or larger text use native name/slogan with the glass mark. No duplicated mark,
baked English slogan in a localized banner, double glass rim, or ear clipping.
No slogan added to compact Watch/widget surfaces.

Translations are the exact existing `ui.session.welcome.title` resources with
newline replaced by a space: en `Your music. Your DJ.`, nl `Jouw muziek. Jouw DJ.`,
de `Deine Musik. Dein DJ.`, fr `Votre musique. Votre DJ.`, es `Tu música. Tu DJ.`.
French keeps the existing formal tone rather than adopting the unapproved “Ta”
proposal. Spoken preview samples use the same phrase; playback behavior is unchanged.

Inter 4.1 OFL license/provenance is preserved. No font binary is shipped. Wordmarks
remain producer raster graphics rather than editable vectors or installed fonts.

## Qualification

Local ignored evidence directory: `build/qualification/apple-brand-v2-adoption/`.

- Exact producer imports, manifest SHA, PNG alpha/dimensions, all three catalog
  slots, opaque RGB system icons, orphan assets and Inter license: PASS via
  `python3 Tools/validate_brand_assets.py`; now included in CI.
- Regeneration: 33 derived PNG hashes unchanged after a second generator run;
  `generated-icons.json` records per-file hashes.
- Five-language validation: 1337 matching keys; exact slogan and spoken sample;
  language-neutral system launch and absence of old active raster: PASS.
- Native app icon contact sheet inspected: 16/32/40 output pixels have no frame;
  larger glass, dark, tinted variants retain the original headset silhouette.

- Full local suite: 71 XCTest + 902 Swift Testing cases PASS. Following the final
  wordmark-loading refinement and preview copy alignment, the two affected brand
  tests were rebuilt/re-run and PASS.
- Actual native banner render: 20 cases (five languages x 280/600pt x standard/
  accessibility3) PASS. Wide English primary, localized compact, narrow native
  fallback, and large text were visually inspected. The harness explicitly loads
  actual app PNGs because SPM does not ship the application catalog. A wide
  layout-height regression rejects the missing-image square placeholder.
- macOS and iOS unsigned builds PASS; iOS includes the Watch application and
  complication targets. Final incremental builds repeat after the last UI edit.
- Language-neutral storyboard, generator/catalog metadata and active reference
  census reviewed; no old corporate raster is referenced by active native UI.
- `git diff --check` and Apple work-register validation PASS.
- Durable exact input/output hashes: [native manifest](../verification/APPLE_BRAND_V2_NATIVE_MANIFEST_20261020.json).

These are native source/build/offscreen-render results.
No installed-device, launcher/OS-mask, physical Watch, VoiceOver or owner acceptance
is inferred from unsigned builds and offscreen native rendering. No app installed,
signed, published or released. No Core mutation or protected merge performed.
