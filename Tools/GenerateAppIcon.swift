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

struct IconImage {
    let idiom: String
    let size: String
    let scale: String
    let pixels: Int
    let role: String?
    let subtype: String?

    init(_ idiom: String, _ size: String, _ scale: String, _ pixels: Int, role: String? = nil, subtype: String? = nil) {
        self.idiom = idiom
        self.size = size
        self.scale = scale
        self.pixels = pixels
        self.role = role
        self.subtype = subtype
    }
}

enum IconAppearance: String, CaseIterable {
    case light
    case dark
    case tinted

    var filenameSuffix: String {
        switch self {
        case .light: ""
        case .dark: "-dark"
        case .tinted: "-tinted"
        }
    }

    var assetValue: String? {
        switch self {
        case .light: nil
        case .dark: "dark"
        case .tinted: "tinted"
        }
    }
}

let images: [IconImage] = [
    IconImage("mac", "16x16", "1x", 16),
    IconImage("mac", "16x16", "2x", 32),
    IconImage("mac", "32x32", "1x", 32),
    IconImage("mac", "32x32", "2x", 64),
    IconImage("mac", "128x128", "1x", 128),
    IconImage("mac", "128x128", "2x", 256),
    IconImage("mac", "256x256", "1x", 256),
    IconImage("mac", "256x256", "2x", 512),
    IconImage("mac", "512x512", "1x", 512),
    IconImage("mac", "512x512", "2x", 1024),
    IconImage("iphone", "20x20", "2x", 40),
    IconImage("iphone", "20x20", "3x", 60),
    IconImage("iphone", "29x29", "2x", 58),
    IconImage("iphone", "29x29", "3x", 87),
    IconImage("iphone", "40x40", "2x", 80),
    IconImage("iphone", "40x40", "3x", 120),
    IconImage("iphone", "60x60", "2x", 120),
    IconImage("iphone", "60x60", "3x", 180),
    IconImage("ipad", "20x20", "1x", 20),
    IconImage("ipad", "20x20", "2x", 40),
    IconImage("ipad", "29x29", "1x", 29),
    IconImage("ipad", "29x29", "2x", 58),
    IconImage("ipad", "40x40", "1x", 40),
    IconImage("ipad", "40x40", "2x", 80),
    IconImage("ipad", "76x76", "1x", 76),
    IconImage("ipad", "76x76", "2x", 152),
    IconImage("ipad", "83.5x83.5", "2x", 167),
    IconImage("ios-marketing", "1024x1024", "1x", 1024),
    IconImage("watch", "24x24", "2x", 48, role: "notificationCenter", subtype: "38mm"),
    IconImage("watch", "27.5x27.5", "2x", 55, role: "notificationCenter", subtype: "42mm"),
    IconImage("watch", "29x29", "2x", 58, role: "companionSettings"),
    IconImage("watch", "29x29", "3x", 87, role: "companionSettings"),
    IconImage("watch", "40x40", "2x", 80, role: "appLauncher", subtype: "38mm"),
    IconImage("watch", "44x44", "2x", 88, role: "appLauncher", subtype: "40mm"),
    IconImage("watch", "50x50", "2x", 100, role: "appLauncher", subtype: "44mm"),
    IconImage("watch", "86x86", "2x", 172, role: "quickLook", subtype: "38mm"),
    IconImage("watch", "98x98", "2x", 196, role: "quickLook", subtype: "42mm"),
    IconImage("watch", "108x108", "2x", 216, role: "quickLook", subtype: "44mm"),
    IconImage("watch-marketing", "1024x1024", "1x", 1024)
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

func renderIcon(from source: CGImage, pixels: Int, appearance: IconAppearance) throws -> CGImage {
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
    switch appearance {
    case .light:
        context.setFillColor(CGColor(red: 0.06, green: 0.04, blue: 0.18, alpha: 1))
    case .dark:
        context.setFillColor(CGColor(red: 0.012, green: 0.016, blue: 0.026, alpha: 1))
    case .tinted:
        context.setFillColor(CGColor(red: 0.020, green: 0.022, blue: 0.028, alpha: 1))
    }
    context.fill(rect)
    context.draw(source, in: rect)

    switch appearance {
    case .light:
        break
    case .dark:
        context.setBlendMode(.multiply)
        context.setFillColor(CGColor(red: 0.30, green: 0.34, blue: 0.42, alpha: 0.20))
        context.fill(rect)
        context.setBlendMode(.screen)
        context.setFillColor(CGColor(red: 0.10, green: 0.78, blue: 0.88, alpha: 0.12))
        context.fill(rect)
        context.setBlendMode(.normal)
    case .tinted:
        context.setBlendMode(.color)
        context.setFillColor(CGColor(red: 0.74, green: 0.74, blue: 0.76, alpha: 1.0))
        context.fill(rect)
        context.setBlendMode(.saturation)
        context.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.92))
        context.fill(rect)
        context.setBlendMode(.screen)
        context.setFillColor(CGColor(red: 0.92, green: 0.94, blue: 1.0, alpha: 0.10))
        context.fill(rect)
        context.setBlendMode(.normal)
    }

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
let imageEntries = images.flatMap { entry -> [[String: Any]] in
    let appearances: [IconAppearance]
    if entry.idiom == "iphone" || entry.idiom == "ipad" || entry.idiom == "ios-marketing" || entry.idiom == "mac" {
        appearances = IconAppearance.allCases
    } else {
        appearances = [.light]
    }

    return appearances.map { appearance -> [String: Any] in
        var imageEntry: [String: Any] = [
        "idiom": entry.idiom,
        "size": entry.size,
        "scale": entry.scale,
        "filename": "icon\(appearance.filenameSuffix)-\(entry.pixels).png"
        ]
        if let role = entry.role {
            imageEntry["role"] = role
        }
        if let subtype = entry.subtype {
            imageEntry["subtype"] = subtype
        }
        if let assetValue = appearance.assetValue {
            imageEntry["appearances"] = [
                [
                    "appearance": "luminosity",
                    "value": assetValue
                ]
            ]
        }
        return imageEntry
    }
}

let referencedIconFiles = Set(imageEntries.compactMap { $0["filename"] as? String })
for filename in referencedIconFiles.sorted() {
    let appearance: IconAppearance
    let pixelsText: String
    if filename.hasPrefix("icon-dark-") {
        appearance = .dark
        pixelsText = filename
            .replacingOccurrences(of: "icon-dark-", with: "")
            .replacingOccurrences(of: ".png", with: "")
    } else if filename.hasPrefix("icon-tinted-") {
        appearance = .tinted
        pixelsText = filename
            .replacingOccurrences(of: "icon-tinted-", with: "")
            .replacingOccurrences(of: ".png", with: "")
    } else {
        appearance = .light
        pixelsText = filename
            .replacingOccurrences(of: "icon-", with: "")
            .replacingOccurrences(of: ".png", with: "")
    }
    guard let pixels = Int(pixelsText) else {
        continue
    }
    try writePNG(
        image: try renderIcon(from: source, pixels: pixels, appearance: appearance),
        to: iconset.appendingPathComponent(filename)
    )
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
