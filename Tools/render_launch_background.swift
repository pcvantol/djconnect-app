// Render the app's blue-purple canvas for UIKit's static launch storyboard.
// Usage: swift Tools/render_launch_background.swift <output.png>
import AppKit

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: 1, y: -1)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}
func gradient(_ colors: [CGColor], _ stops: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops)!
}
context.drawLinearGradient(gradient([color(0.02,0.03,0.09), color(0.07,0.04,0.15), color(0.03,0.08,0.18)], [0,0.5,1]),
                           start: .zero, end: CGPoint(x: size, y: size), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
func glow(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat, _ center: CGPoint, _ radius: CGFloat) {
    context.drawRadialGradient(gradient([color(r,g,b,alpha), color(r,g,b,0)], [0,1]),
                              startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                              options: [.drawsAfterEndLocation])
}
glow(0.22,0.43,0.98,0.42, CGPoint(x: size,y: 0), 1075)
glow(0.64,0.12,0.92,0.34, CGPoint(x: 0,y: size), 1024)
glow(0.10,0.18,0.52,0.26, .zero, 922)
context.drawLinearGradient(gradient([color(0,0,0,0.16), color(0,0,0,0), color(0,0,0,0.26)], [0,0.5,1]),
                           start: .zero, end: CGPoint(x: 0,y: size), options: [])
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
