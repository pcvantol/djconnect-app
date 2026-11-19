# Responsive brand card

Local successor to `8d23172`. The shared launch/about banner content expands to
the available width before its frosted background is applied. The wordmark
retains its bounded size inside the card. This fixes the narrow material card
inside a full-width About layout on iPad and macOS, and applies to all other
shared banner placements. The native localized tagline uses title3 semibold
instead of headline semibold. Native wrapping and accessibility layout remain;
the English wide wordmark's baked slogan is unchanged.

Validation: nativeBrandV2BannerReview completed 1 PASS / 0 FAIL, producing 20
renders covering five locales, widths 280/600 and standard/accessibility3 text.
Inspected Dutch 600 standard, 280 standard and 600 accessibility captures: the
card spans the rendered width and all slogan text is visible. The renderer uses
the existing explicit glass-disabled setting; these captures qualify layout,
not live glass appearance or physical-device acceptance. Unsigned isolated iOS
Simulator build-for-testing passed. git diff --check passed. No installation.

Evidence: `/private/tmp/djc-responsive-brand-20261021/observations/`.

- Mac log `/private/tmp/djc-responsive-brand-20261021-mac.log`, SHA-256
  `93178725c2cf87d6bd5f1fa2e7667c94af649ff1a4fc281faadb4d773e654fd3`.
- iOS log `/private/tmp/djc-responsive-brand-20261021-ios.log`, SHA-256
  `2f4d0e7d55bea62509cfde41c4a3b5c94766f4a024dc7ef7372834af0496638d`.
