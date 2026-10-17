// Native vector overlay for the OS-owned static launch screen. Runtime logos
// use DJConnectGlassBrandIcon; preserve the original brand artwork pixel-for-pixel.
import AppKit
import Foundation
let base = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let image = NSImage(contentsOf: base),
      let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let context = CGContext(data: nil, width: source.width, height: source.height,
        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Missing launch banner source") }
context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
// Original master artwork: icon rectangle179,134,269,269 in2048x538 top-left pixels.
let sx = CGFloat(source.width) / 2048, sy = CGFloat(source.height) / 538
let icon = CGRect(x: 179 * sx, y: CGFloat(source.height) - 403 * sy, width: 269 * sx, height: 269 * sy)
let width = 3 * icon.width / 84
let path = CGPath(roundedRect: icon.insetBy(dx: width / 2, dy: width / 2),
                  cornerWidth: 52 * sx, cornerHeight: 52 * sy, transform: nil)
let colors = [NSColor.white.withAlphaComponent(0.92).cgColor,
              NSColor(srgbRed: 0.16, green: 0.56, blue: 1, alpha: 1).cgColor,
              NSColor(srgbRed: 0.84, green: 0.22, blue: 0.96, alpha: 1).cgColor] as CFArray
context.addPath(path); context.setLineWidth(width); context.replacePathWithStrokedPath(); context.clip()
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: [0, 0.5, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: icon.minX, y: icon.maxY),
                          end: CGPoint(x: icon.maxX, y: icon.minY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
guard let rendered = context.makeImage(),
      let data = NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:]) else { fatalError("Cannot render launch banner") }
try data.write(to: output)
