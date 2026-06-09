import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceIcon = root
    .appendingPathComponent("Tools")
    .appendingPathComponent("IconSource")
    .appendingPathComponent("djconnect-icon-1024.png")
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

func loadSourceIcon() throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(sourceIcon as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(
            domain: "DJConnectIcon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not load source icon at \(sourceIcon.path)"]
        )
    }
    return image
}

func renderIcon(from source: CGImage, pixels: Int) throws -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "DJConnectIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context"])
    }

    let dimension = CGFloat(pixels)
    let rect = CGRect(x: 0, y: 0, width: dimension, height: dimension)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // Apple app icons should be square and opaque; the source brand mark has rounded transparent corners.
    context.setFillColor(CGColor(red: 0.06, green: 0.04, blue: 0.18, alpha: 1))
    context.fill(rect)
    context.draw(source, in: rect)

    guard let image = context.makeImage() else {
        throw NSError(domain: "DJConnectIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not render icon"])
    }
    return image
}

func writePNG(image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "DJConnectIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "DJConnectIcon", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not write PNG"])
    }
}

let source = try loadSourceIcon()
let uniquePixels = Set(images.map(\.pixels)).sorted()
for pixels in uniquePixels {
    try writePNG(image: try renderIcon(from: source, pixels: pixels), to: iconset.appendingPathComponent("icon-\(pixels).png"))
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
