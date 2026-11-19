#if os(macOS)
import AppKit
import Vision
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
    // Supply only the icon; the product name and tagline must be native Text.
    for name in ["LaunchIcon"] {
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
                let renderer = ImageRenderer(content:
                    DJConnectLaunchBanner(subtitle: subtitle)
                        .environment(\.djConnectGlassEffectsEnabled, false)
                        .frame(width: CGFloat(width))
                        .background(Color(red: 0.05, green: 0.05, blue: 0.18))
                )
                renderer.scale = 3
                let image = try #require(renderer.cgImage)
                #expect(image.width == width * 3)
                let bitmap = NSBitmapImageRep(cgImage: image)
                // Check the real rendered glyphs against the colored icon,
                // rather than merely allowing a large total card height.
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = [language]
                try VNImageRequestHandler(cgImage: image).perform([request])
                let rows = try #require(request.results)
                let name = try #require(rows.first { $0.topCandidates(1).first?.string == "DJConnect" })
                let normalized: (String) -> String = {
                    $0.lowercased().filter { $0.isLetter || $0.isNumber }
                }
                let slogan = try #require(rows.first {
                    $0.topCandidates(1).first.map { normalized($0.string) == normalized(subtitle) } == true
                })
                var icon = CGRect.null
                for y in stride(from: 0, to: image.height, by: 3) {
                    for x in stride(from: 0, to: image.width, by: 3) {
                        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                        let high = max(color.redComponent, color.greenComponent, color.blueComponent)
                        let low = min(color.redComponent, color.greenComponent, color.blueComponent)
                        if color.alphaComponent > 0.9, high > 0.5, high - low > 0.35 {
                            icon = icon.union(CGRect(x: x, y: image.height - y - 1, width: 1, height: 1))
                        }
                    }
                }
                #expect(!icon.isNull)
                let pixels = CGAffineTransform(scaleX: CGFloat(image.width), y: CGFloat(image.height))
                let nameBounds = name.boundingBox.applying(pixels)
                let sloganBounds = slogan.boundingBox.applying(pixels)
                let textBounds = nameBounds.union(sloganBounds)
                #expect(nameBounds.minX > icon.maxX)
                #expect(sloganBounds.minX > icon.maxX)
                #expect(nameBounds.minY > sloganBounds.maxY)
                #expect(textBounds.height <= icon.height)
                #expect(textBounds.minY >= icon.minY - 3)
                #expect(textBounds.maxY <= icon.maxY + 3)
                let data = try #require(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("\(language)-\(width)@3x.png"))
        }
    }
}
#endif
