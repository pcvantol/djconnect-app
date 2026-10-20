# Apple Brand V2 source provenance

Consumes Core #1223 / source PR #1224 at source main
`7e14e5970b3f68d33d243ae6bab2b281fad59bb2`, candidate
`883cb9f3ff9de8ec7f5ae4c5f04f852e0d8bd866`, finalized by #1227 at
`baac22d771bf3141404001517f62a5e34f8c8644`.

The adjacent manifest is copied verbatim from `assets/djconnect/brand-v2/manifest.json`
(SHA256 `73cc408e10d88aa1fb8a1be2783b9c577aec398ce3dcd54c2f997ad1425984d2`).
All imported producer bytes were checked against immutable Git blob identities.
Only the approved original blue/purple/cyan headset artwork is consumed.

Mapping of immutable producer files:
- `mark-1024.png` -> `../djconnect-icon-1024.png` and LaunchIcon/launch-icon.png.
- `headset-master.png` -> this directory and BrandHeadset imageset.
- Four `wordmark-{primary,compact}-{light,dark}.png` files -> matching BrandWordmark imagesets.

Run `swift Tools/GenerateAppIcon.swift` from the repository root. All app icon
catalog PNGs are derived from these inputs. Output sizes <=40 pixels use the
headset master without its glass frame; larger output sizes use the glass mark.
The threshold is output pixels, not logical points. Apple system icons are
composited onto opaque backgrounds; iOS dark and tinted variants retain their
existing appearance transforms. Runtime LaunchIcon retains producer transparency.
No extra native glass rim is added over the already framed producer artwork.

Wordmarks are raster-backed producer graphics with outlined Inter 4.1 lettering,
not native text or editable vectors. `dark` has light lettering for dark canvases;
`light` has dark lettering for light backgrounds. LICENSE.txt and PROVENANCE.md
are the producer's unmodified Inter license and font provenance. No font binary
is shipped by Apple. The primary English slogan is used only with English copy;
other languages use the compact wordmark plus native localized text. Narrow and
large-text layouts use native product name and slogan with the glass mark.
