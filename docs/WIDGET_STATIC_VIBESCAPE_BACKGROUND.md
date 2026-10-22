# Static widget VibeScape and spacious large playback

The Session home widget now composites fixed liquid forms and thin waves over the accepted mood palette. WidgetKit rasterizes these SwiftUI shapes into its ordinary snapshot; there is no animation, clock, randomness, renderer loop, extra network request or additional timeline refresh. Small, medium and large share this subtle decoration. Live Activity layout is unchanged.

Large playback-only widgets use a separate vertical composition: centered artwork sized to available height, title2 bold track, body artist and secondary album below. With a contribution, the existing combined layout remains, with larger track/artist typography. Artwork retains the original passive slot/subject, expiry, rights and byte-size fences and uses scaledToFit. Missing or undecodable pixels show a quiet decorative music-note fallback, never another track's image.

Validation for preview40445: signed macOS and iOS builds PASS; native Mac artifact validator7/7 PASS. Native ImageRenderer exercised the actual widget background and fallback foreground at small/medium/large across brand/groove/chill. Four additional renders exercised actual large playback at320/364points with synthetic authorized pixels and missing pixels. Visual inspection confirms legible text, a large uncropped cover and bounded fallback. Standalone harness does not load the widget bundle's Spotify asset (its missing-resource marker is a harness limitation); the production target retains that existing asset and attribution code.

A repeated background-render byte-equality assertion did not pass: native rasterization varied by mean0..0.068754 channel values on0..255, max9. This is not claimed as exact pixel determinism. The source contains fixed geometry without temporal inputs. Pillow was unavailable; comparison used native ImageIO instead.

A read-only iPhone App Group metadata probe found an expired widget projection with now-playing metadata but no artwork slots/pixels. It does not establish the current server response or image availability. No private track data, URLs or pixels were printed, and the temporary copied plist was deleted. Missing server artwork is not solved by this presentation change.

Evidence: /private/tmp/djc-widget-large-40445-{mac,ios}-build.log; /private/tmp/djc-widget-static-40445-renders; /private/tmp/djc-widget-large-40445-renders; /private/tmp/djc-widget-static-40445-pixel-comparison.log. These are native local renders, not physical WidgetKit screenshots. Installed delivery and owner acceptance are recorded separately.
