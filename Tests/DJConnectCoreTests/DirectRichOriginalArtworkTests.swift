import Foundation
import CryptoKit
import CoreGraphics
import ImageIO
import Testing
@testable import DJConnectCore

@Suite struct DirectRichOriginalArtworkTests {
    @Test(.isolatedClientResources, arguments: ["image/png", "image/jpeg"])
    func preservesActualOriginalImageIOBytes(mime: String) throws {
        let bytes = try image(mime)
        let accepted = try DirectRichOriginalArtwork.validate(bytes, matching: expected(bytes, mime: mime))
        #expect(accepted.bytes == bytes && accepted.width == 2 && accepted.height == 3)
    }

    @Test(.isolatedClientResources, arguments: ["digest", "length", "mime", "width", "height", "uppercase-digest"])
    func rejectsMetadataSubstitution(fault: String) throws {
        let bytes = try image("image/png"), good = expected(bytes, mime: "image/png")
        let changed = DirectRichOriginalArtwork.Expected(
            sha256: fault == "digest" ? String(repeating: "0", count: 64) : fault == "uppercase-digest" ? good.sha256.uppercased() : good.sha256,
            byteLength: good.byteLength + (fault == "length" ? 1 : 0),
            mimeType: fault == "mime" ? "image/jpeg" : good.mimeType,
            width: good.width + (fault == "width" ? 1 : 0), height: good.height + (fault == "height" ? 1 : 0))
        #expect(throws: (any Error).self) { try DirectRichOriginalArtwork.validate(bytes, matching: changed) }
    }

    @Test(.isolatedClientResources, arguments: ["image/png", "image/jpeg"], ["trailing", "second-image", "truncated"])
    func rejectsIncompleteOrConcatenatedContainers(mime: String, fault: String) throws {
        let original = try image(mime)
        let bytes = fault == "trailing" ? original + Data([0, 1, 2])
            : fault == "second-image" ? original + original : Data(original.dropLast())
        // The digest agrees with the corrupt bytes: metadata equality alone
        // must not turn a malformed/trailing second image into accepted pixels.
        #expect(throws: (any Error).self) { try DirectRichOriginalArtwork.validate(bytes, matching: expected(bytes, mime: mime)) }
    }

    @Test(.isolatedClientResources)
    func exactOriginalByteCapIsInclusiveWithoutReencoding() throws {
        let original = try image("image/png")
        let maximum = DirectRichOriginalArtwork.maximumBytes
        let bytes = paddedPNG(original, to: maximum)
        let accepted = try DirectRichOriginalArtwork.validate(bytes, matching: expected(bytes, mime: "image/png"))
        #expect(bytes.count == maximum && accepted.bytes == bytes)
        let tooLarge = paddedPNG(original, to: maximum + 1)
        #expect(throws: (any Error).self) { try DirectRichOriginalArtwork.validate(tooLarge, matching: expected(tooLarge, mime: "image/png")) }
    }

    @Test(.isolatedClientResources)
    func malformedPNGLengthAndChecksumCannotReachImageDecoding() throws {
        let original = try image("image/png")
        var hugeLength = original; hugeLength.replaceSubrange(8..<12, with: [255, 255, 255, 255])
        var badCRC = original; badCRC[29] ^= 1
        for bytes in [hugeLength, badCRC] {
            #expect(throws: (any Error).self) { try DirectRichOriginalArtwork.validate(bytes, matching: expected(bytes, mime: "image/png")) }
        }
    }

    @Test(.isolatedClientResources)
    func takesOwnedCopyOfMutableHTTPInput() throws {
        let original = try image("image/png")
        let mutable = NSMutableData(data: original), incoming = Data(referencing: mutable)
        let accepted = try DirectRichOriginalArtwork.validate(incoming, matching: expected(original, mime: "image/png"))
        mutable.mutableBytes.assumingMemoryBound(to: UInt8.self).pointee ^= 1
        #expect(accepted.bytes == original)
    }

    @Test(.isolatedClientResources)
    func actualDimensionsAndPixelCapAreInclusive() throws {
        for (width, height, allowed) in [(4096, 1, true), (4097, 1, false),
                                         (4000, 4000, true), (4000, 4001, false)] {
            try autoreleasepool {
                let bytes = try image("image/jpeg", width: width, height: height)
                try #require(bytes.count <= DirectRichOriginalArtwork.maximumBytes,
                             "Synthetic dimension fixture must fit the independent byte cap: \(bytes.count)")
                let metadata = expected(bytes, mime: "image/jpeg", width: width, height: height)
                if allowed {
                    let value = try DirectRichOriginalArtwork.validate(bytes, matching: metadata)
                    #expect(value.width == width && value.height == height && value.bytes == bytes)
                } else {
                    #expect(throws: (any Error).self) { try DirectRichOriginalArtwork.validate(bytes, matching: metadata) }
                }
            }
        }
    }

    private func expected(_ bytes: Data, mime: String, width: Int = 2, height: Int = 3) -> DirectRichOriginalArtwork.Expected {
        .init(sha256: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
              byteLength: bytes.count, mimeType: mime, width: width, height: height)
    }
    private func image(_ mime: String, width: Int = 2, height: Int = 3) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage()), output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output,
            (mime == "image/png" ? "public.png" : "public.jpeg") as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
    private func paddedPNG(_ original: Data, to size: Int) -> Data {
        let padding = Data("padding\0".utf8) + Data(repeating: 120, count: size - original.count - 20)
        let typeAndBody = Data("tEXt".utf8) + padding
        var crc = UInt32.max
        for byte in typeAndBody {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xedb88320 : 0) }
        }
        crc ^= UInt32.max
        func bigEndian(_ value: UInt32) -> Data {
            Data([UInt8(truncatingIfNeeded: value >> 24), UInt8(truncatingIfNeeded: value >> 16),
                  UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)])
        }
        return Data(original.dropLast(12)) + bigEndian(UInt32(padding.count)) + typeAndBody + bigEndian(crc) + original.suffix(12)
    }
}
