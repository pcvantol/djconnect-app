#if os(macOS)
import AppKit
#endif
import SwiftUI
import Testing
@testable import DJConnectUI

#if os(macOS)
/// App catalogs are not SPM resources. Load their exact PNGs into AppKit's named
/// image cache for this opt-in render of the real banner, without launching,
/// pairing, installing, or changing a user's app preferences.
@MainActor @Test func nativeBrandV2BannerReview() throws {
    guard let output = ProcessInfo.processInfo.environment["DJCONNECT_BRAND_REVIEW_OUTPUT"] else { return }
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let assets = root.appendingPathComponent("Apps/Shared/Assets.xcassets")
    var loaded: [NSImage] = []
    for name in ["LaunchIcon", "BrandWordmarkPrimaryDark", "BrandWordmarkCompactDark"] {
        let directory = assets.appendingPathComponent("\(name).imageset")
        let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("Contents.json"))) as! [String: Any]
        let rows = contents["images"] as! [[String: Any]]
        let filename = try #require(rows.first?["filename"] as? String)
        let image = try #require(NSImage(contentsOf: directory.appendingPathComponent(filename)))
        #expect(image.setName(name))
        loaded.append(image)
    }
    defer { for image in loaded { image.setName(nil) } }
    let directory = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let subtitles = ["en": "Your music. Your DJ.", "nl": "Jouw muziek. Jouw DJ.", "de": "Deine Musik. Dein DJ.", "fr": "Votre musique. Votre DJ.", "es": "Tu música. Tu DJ."]
    for (language, subtitle) in subtitles.sorted(by: { $0.key < $1.key }) {
        for width in [280, 600] {
            for largeText in [false, true] {
                let renderer = ImageRenderer(content:
                    DJConnectLaunchBanner(subtitle: subtitle)
                        .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large)
                        .environment(\.djConnectGlassEffectsEnabled, false)
                        .frame(width: CGFloat(width))
                        .background(Color(red: 0.05, green: 0.05, blue: 0.18))
                )
                let image = try #require(renderer.cgImage)
                #expect(image.width == width)
                #expect(image.height > 80 && image.height < 900)
                if width == 600 && !largeText {
                    // The icon and both native text lines share one compact row.
                    #expect(image.height < 240)
                }
                let bitmap = NSBitmapImageRep(cgImage: image)
                let data = try #require(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("\(language)-\(width)-\(largeText ? "accessibility" : "standard").png"))
            }
        }
    }
}
#endif
