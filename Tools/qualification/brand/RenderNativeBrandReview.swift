import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Offscreen review only. Never writes asset catalogs or accepts a producer.
struct ReviewFailure: Error, CustomStringConvertible {
    let description: String
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ReviewFailure(description: message) }
}

func sha256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
}

struct Manifest: Decodable {
    struct Asset: Decodable {
        let sha256: String
        let bytes: Int
        let width: Int?
        let height: Int?
    }
    let files: [String: Asset]
}

struct Handoff: Decodable {
    let producer_commit: String
    let brand_manifest_sha256: String
    let files: [String: String]
}

func child(_ path: String, of root: URL) throws -> URL {
    try require(!path.hasPrefix("/") && !path.split(separator: "/").contains(".."), "Invalid asset path")
    let url = root.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
    try require(url.path.hasPrefix(root.path + "/"), "Asset escapes input directory")
    return url
}

func run() throws {
    let args = CommandLine.arguments
    try require(args.count == 5, "Usage: swift RenderNativeBrandReview.swift EXTRACTED_ROOT MANIFEST_SHA256 NEW_OUTPUT_DIRECTORY PRODUCER_SHA")
    let root = URL(fileURLWithPath: args[1]).resolvingSymlinksInPath().standardizedFileURL
    let expectedHash = args[2]
    let output = URL(fileURLWithPath: args[3]).resolvingSymlinksInPath().standardizedFileURL
    let producer = args[4]
    let hex = CharacterSet(charactersIn: "0123456789abcdef")
    try require(expectedHash.count == 64 && expectedHash.unicodeScalars.allSatisfy(hex.contains), "Expected manifest SHA256 required")
    try require(producer.count == 40 && producer.unicodeScalars.allSatisfy(hex.contains), "Exact producer SHA required")
    try require(!FileManager.default.fileExists(atPath: output.path), "Output must be a new directory")
    try require(!output.path.hasPrefix(root.path + "/") && output != root, "Output must be outside candidate input")
    let manifestURL = try child("assets/djconnect/brand-v2/manifest.json", of: root)
    let observedHash = try sha256(manifestURL)
    try require(observedHash == expectedHash, "Manifest SHA256 mismatch")
    let handoffURL = try child("handoff.json", of: root)
    let handoff = try JSONDecoder().decode(Handoff.self, from: Data(contentsOf: handoffURL))
    try require(handoff.producer_commit == producer && handoff.brand_manifest_sha256 == expectedHash,
                "Handoff producer/manifest mismatch")
    for (path, expected) in handoff.files {
        let observed = try sha256(child(path, of: root))
        try require(observed == expected, "Handoff hash mismatch: \(path)")
    }
    let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
    for (path, asset) in manifest.files {
        let url = try child(path, of: root)
        let bytes = try Data(contentsOf: url)
        try require(bytes.count == asset.bytes, "Byte length mismatch: \(path)")
        let hash = try sha256(url)
        try require(hash == asset.sha256, "Asset SHA256 mismatch: \(path)")
        if path.hasSuffix(".png") {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw ReviewFailure(description: "Native PNG decode failed: \(path)")
            }
            try require(image.width == asset.width && image.height == asset.height, "Dimension mismatch: \(path)")
        }
    }

    func image(_ name: String) throws -> NSImage {
        let path = "assets/djconnect/brand-v2/\(name).png"
        try require(manifest.files[path] != nil, "Required asset absent from verified manifest: \(path)")
        let url = try child(path, of: root)
        guard let value = NSImage(contentsOf: url) else { throw ReviewFailure(description: "Cannot load \(name)") }
        return value
    }

    let headset = try image("headset-master")
    let glass = try image("glass-master")
    let width = 1440, height = 1080
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw ReviewFailure(description: "Cannot create native review bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphics
    func label(_ text: String, _ x: CGFloat, _ y: CGFloat, _ color: NSColor = .white, size: CGFloat = 14) {
        (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: size), .foregroundColor: color
        ])
    }
    NSColor(srgbRed: 0.035, green: 0.04, blue: 0.09, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    label("CANDIDATE — native offscreen review, no installed acceptance", 20, 1040, size: 22)
    label("Output pixels shown directly. Pt × scale is labelled; this sheet itself is not a Retina screenshot.", 20, 1010)
    var mappings = [[String: Any]]()
    for (row, points) in [16, 20, 24, 32, 40].enumerated() {
        let y = CGFloat(810 - row * 155)
        label("\(points)pt", 20, y + 85, size: 20)
        for scale in 1...3 {
            let pixels = points * scale
            let x = CGFloat(150 + (scale - 1) * 430)
            // A is literal producer pixel threshold. B exposes the alternative
            // logical-size policy for Retina review; neither is adopted here.
            let pixelVariant = pixels <= 40 ? "headset" : "glass"
            let a = pixels <= 40 ? headset : glass
            let dimension = CGFloat(pixels)
            a.draw(in: NSRect(x: x, y: y, width: dimension, height: dimension))
            headset.draw(in: NSRect(x: x + 175, y: y, width: dimension, height: dimension))
            label("@\(scale)× = \(pixels)px", x, y + 124)
            label("A: \(pixelVariant)", x, y - 19)
            label("B: headset", x + 175, y - 19)
            mappings.append(["points": points, "scale": scale, "pixels": pixels,
                             "literalPixelPolicy": pixelVariant, "logicalSizeAlternative": "headset"])
        }
    }
    label("A: Core ≤40px rule. B: headset at ≤40pt, including Retina. Policy decision remains open.", 20, 25)
    // Publish the evidence directory only once every artifact is complete. Keep
    // staging on the destination filesystem so the final move is a rename.
    let staging = output.deletingLastPathComponent()
        .appendingPathComponent(".djc-brand-review-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: staging) }
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw ReviewFailure(description: "Cannot encode review PNG")
    }
    let matrix = staging.appendingPathComponent("native-scale-matrix.png")
    try png.write(to: matrix, options: .atomic)

    // Opaque treatments use the existing generator's flat base colours only.
    // No new artwork or implicit approval of an app-icon treatment is introduced.
    let treatments: [(String, NSColor)] = [
        ("default", NSColor(srgbRed: 0.06, green: 0.04, blue: 0.18, alpha: 1)),
        ("dark-base", NSColor(srgbRed: 0.012, green: 0.016, blue: 0.026, alpha: 1)),
        ("tinted-base", NSColor(srgbRed: 0.020, green: 0.022, blue: 0.028, alpha: 1))
    ]
    for (name, background) in treatments {
        guard let context = CGContext(data: nil, width: 1024, height: 1024,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw ReviewFailure(description: "Cannot create opaque treatment")
        }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        background.setFill()
        NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
        glass.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
        let url = staging.appendingPathComponent("opaque-\(name)-1024.png")
        guard let rendered = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ReviewFailure(description: "Cannot encode opaque treatment")
        }
        CGImageDestinationAddImage(destination, rendered, nil)
        try require(CGImageDestinationFinalize(destination), "Cannot write opaque treatment")
    }
    let report: [String: Any] = [
        "qualification": "candidate-only offscreen native image review; no catalog admission, protected acceptance or installation",
        "producerSHA": producer, "manifestSHA256": observedHash,
        "verifiedOutputs": manifest.files.count, "verifiedHandoffFiles": handoff.files.count,
        "handoffSHA256": try sha256(handoffURL), "mappingAlternatives": mappings,
        "renderer": "AppKit NSImage, deviceRGB NSBitmapImageRep",
        "matrixSHA256": try sha256(matrix),
        "opaqueTreatments": "existing flat base colours only; no dark overlay, tint transform or native system mask qualification"
    ]
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        .write(to: staging.appendingPathComponent("readback.json"), options: .atomic)
    try FileManager.default.moveItem(at: staging, to: output)
    print("PASS: \(manifest.files.count) verified outputs; native scale matrix and three opaque base previews. Candidate only.")
}

do { try run() } catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(1)
}
