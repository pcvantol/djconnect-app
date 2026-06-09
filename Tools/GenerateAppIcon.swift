import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root
    .appendingPathComponent("Apps")
    .appendingPathComponent("Shared")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let images: [(idiom: String, size: String, scale: String, pixels: Int)] = [
    ("mac", "16x16", "1x", 16),
    ("mac", "16x16", "2x", 32),
    ("mac", "32x32", "1x", 32),
    ("mac", "32x32", "2x", 64),
    ("mac", "128x128", "1x", 128),
    ("mac", "128x128", "2x", 256),
    ("mac", "256x256", "1x", 256),
    ("mac", "256x256", "2x", 512),
    ("mac", "512x512", "1x", 512),
    ("mac", "512x512", "2x", 1024),
    ("iphone", "20x20", "2x", 40),
    ("iphone", "20x20", "3x", 60),
    ("iphone", "29x29", "2x", 58),
    ("iphone", "29x29", "3x", 87),
    ("iphone", "40x40", "2x", 80),
    ("iphone", "40x40", "3x", 120),
    ("iphone", "60x60", "2x", 120),
    ("iphone", "60x60", "3x", 180),
    ("ipad", "20x20", "1x", 20),
    ("ipad", "20x20", "2x", 40),
    ("ipad", "29x29", "1x", 29),
    ("ipad", "29x29", "2x", 58),
    ("ipad", "40x40", "1x", 40),
    ("ipad", "40x40", "2x", 80),
    ("ipad", "76x76", "1x", 76),
    ("ipad", "76x76", "2x", 152),
    ("ipad", "83.5x83.5", "2x", 167),
    ("ios-marketing", "1024x1024", "1x", 1024)
]

func drawIcon(pixels: Int) throws -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "DJConnectIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context"])
    }

    let dimension = CGFloat(pixels)
    let rect = CGRect(x: 0, y: 0, width: dimension, height: dimension)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.setFillColor(CGColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1))
    context.fill(rect)

    let gradientColors = [
        CGColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1),
        CGColor(red: 0.00, green: 0.36, blue: 0.52, alpha: 1),
        CGColor(red: 0.12, green: 0.74, blue: 0.64, alpha: 1)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 0.56, 1]) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: dimension, y: dimension),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }

    let inset = dimension * 0.105
    let innerRect = rect.insetBy(dx: inset, dy: inset)
    let innerRadius = dimension * 0.18
    context.setFillColor(CGColor(gray: 1, alpha: 0.10))
    context.addPath(CGPath(roundedRect: innerRect, cornerWidth: innerRadius, cornerHeight: innerRadius, transform: nil))
    context.fillPath()

    let strokeWidth = max(dimension * 0.055, 2)
    let noteColor = CGColor(red: 0.96, green: 1.0, blue: 0.94, alpha: 1)
    context.setStrokeColor(noteColor)
    context.setFillColor(noteColor)
    context.setLineWidth(strokeWidth)
    context.setLineCap(.round)

    let stemX = dimension * 0.58
    let stemTop = dimension * 0.69
    let stemBottom = dimension * 0.34
    context.beginPath()
    context.move(to: CGPoint(x: stemX, y: stemBottom))
    context.addLine(to: CGPoint(x: stemX, y: stemTop))
    context.addLine(to: CGPoint(x: dimension * 0.76, y: dimension * 0.64))
    context.strokePath()

    let headRect = CGRect(
        x: dimension * 0.32,
        y: dimension * 0.25,
        width: dimension * 0.28,
        height: dimension * 0.20
    )
    context.fillEllipse(in: headRect)

    context.setStrokeColor(CGColor(red: 0.80, green: 1.0, blue: 0.98, alpha: 0.82))
    context.setLineWidth(max(dimension * 0.035, 1.5))
    context.beginPath()
    context.move(to: CGPoint(x: dimension * 0.28, y: dimension * 0.62))
    context.addCurve(
        to: CGPoint(x: dimension * 0.76, y: dimension * 0.38),
        control1: CGPoint(x: dimension * 0.42, y: dimension * 0.82),
        control2: CGPoint(x: dimension * 0.68, y: dimension * 0.72)
    )
    context.strokePath()

    context.setFillColor(CGColor(red: 0.92, green: 1.0, blue: 0.76, alpha: 1))
    for point in [
        CGPoint(x: dimension * 0.27, y: dimension * 0.62),
        CGPoint(x: dimension * 0.76, y: dimension * 0.38)
    ] {
        let dotSize = max(dimension * 0.075, 3)
        context.fillEllipse(in: CGRect(
            x: point.x - dotSize / 2,
            y: point.y - dotSize / 2,
            width: dotSize,
            height: dotSize
        ))
    }

    guard let image = context.makeImage() else {
        throw NSError(domain: "DJConnectIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not render icon"])
    }
    return image
}

func writePNG(image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "DJConnectIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "DJConnectIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not write PNG"])
    }
}

let uniquePixels = Set(images.map(\.pixels)).sorted()
for pixels in uniquePixels {
    try writePNG(image: try drawIcon(pixels: pixels), to: iconset.appendingPathComponent("icon-\(pixels).png"))
}

let imageEntries = images.map { entry -> [String: String] in
    [
        "idiom": entry.idiom,
        "size": entry.size,
        "scale": entry.scale,
        "filename": "icon-\(entry.pixels).png"
    ]
}

let contents: [String: Any] = [
    "images": imageEntries,
    "info": [
        "author": "xcode",
        "version": 1
    ]
]

let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconset.appendingPathComponent("Contents.json"), options: .atomic)
