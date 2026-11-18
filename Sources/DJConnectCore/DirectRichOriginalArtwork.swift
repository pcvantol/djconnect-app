import Foundation
import CryptoKit
import ImageIO

/// Original-byte preflight for the successor rich association. This value is
/// neither source/display permission nor an authenticated transport receipt.
/// The owning receiver must separately check its original frame/slot/rights,
/// native clock and currentness before staging or publishing these bytes.
enum DirectRichOriginalArtwork {
    static let maximumBytes = 256_000
    static let maximumDimension = 4096
    static let maximumPixels = 16_000_000

    struct Expected: Sendable {
        let sha256: String
        let byteLength: Int
        let mimeType: String
        let width: Int
        let height: Int
    }
    struct Validated: Sendable {
        let bytes: Data
        let width: Int
        let height: Int
    }
    enum Invalid: Error { case bytes, image }

    static func validate(_ input: Data, matching expected: Expected) throws -> Validated {
        guard (1...maximumBytes).contains(input.count), input.count == expected.byteLength,
              expected.sha256.utf8.count == 64,
              expected.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              ["image/png", "image/jpeg"].contains(expected.mimeType),
              (1...maximumDimension).contains(expected.width),
              (1...maximumDimension).contains(expected.height),
              expected.width * expected.height <= maximumPixels else { throw Invalid.bytes }
        // Own the bytes even if a caller supplied a Data view of NSMutableData.
        let bytes = input.withUnsafeBytes { Data($0) }
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard digest == expected.sha256 else { throw Invalid.bytes }
        let raw = Array(bytes)
        guard expected.mimeType == "image/png" ? completePNG(raw) : completeJPEG(raw) else { throw Invalid.image }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(bytes as CFData, options),
              CGImageSourceGetCount(source) == 1, CGImageSourceGetStatus(source) == .statusComplete,
              let type = CGImageSourceGetType(source) as String?,
              type == (expected.mimeType == "image/png" ? "public.png" : "public.jpeg"),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue == expected.width,
              (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue == expected.height,
              let image = CGImageSourceCreateImageAtIndex(source, 0,
                  [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              image.width == expected.width, image.height == expected.height,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else { throw Invalid.image }
        return Validated(bytes: bytes, width: image.width, height: image.height)
    }

    private static func completePNG(_ bytes: [UInt8]) -> Bool {
        guard bytes.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else { return false }
        var offset = 8, sawHeader = false, sawData = false
        while offset <= bytes.count - 12 {
            let encodedLength = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
                | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
            guard encodedLength <= UInt32(bytes.count - offset - 12) else { return false }
            let length = Int(encodedLength)
            let type = Array(bytes[(offset + 4)..<(offset + 8)])
            guard type.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) }) else { return false }
            let end = offset + 8 + length
            var crc = UInt32.max
            for byte in bytes[(offset + 4)..<end] {
                crc ^= UInt32(byte)
                for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xedb88320 : 0) }
            }
            crc ^= UInt32.max
            let stored = UInt32(bytes[end]) << 24 | UInt32(bytes[end + 1]) << 16
                | UInt32(bytes[end + 2]) << 8 | UInt32(bytes[end + 3])
            guard crc == stored else { return false }
            if !sawHeader {
                guard type == Array("IHDR".utf8), length == 13 else { return false }
                sawHeader = true
            } else if type == Array("IHDR".utf8) { return false }
            if type == Array("IDAT".utf8) { sawData = true }
            if type == Array("IEND".utf8) { return length == 0 && sawData && end + 4 == bytes.count }
            // Prepared covers are a single static image, never an animation.
            if ["acTL", "fcTL", "fdAT"].contains(String(decoding: type, as: UTF8.self)) { return false }
            offset = end + 4
        }
        return false
    }

    private static func completeJPEG(_ bytes: [UInt8]) -> Bool {
        guard bytes.starts(with: [0xff, 0xd8]) else { return false }
        var offset = 2, sawFrame = false, sawScan = false
        while offset < bytes.count {
            guard bytes[offset] == 0xff else { return false }
            while offset < bytes.count && bytes[offset] == 0xff { offset += 1 }
            guard offset < bytes.count else { return false }
            let marker = bytes[offset]; offset += 1
            if marker == 0xd9 { return sawFrame && sawScan && offset == bytes.count }
            guard marker != 0 && marker != 0xd8 && !(0xd0...0xd7).contains(marker),
                  offset <= bytes.count - 2 else { return false }
            if marker == 0x01 { continue }
            let length = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
            guard length >= 2, length <= bytes.count - offset else { return false }
            if [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].contains(Int(marker)) {
                guard !sawFrame else { return false }; sawFrame = true
            }
            offset += length
            if marker == 0xda {
                sawScan = true
                // Scan entropy bytes without treating stuffed FF00 or restart
                // markers as a container end; progressive scans remain valid.
                while offset < bytes.count {
                    if bytes[offset] != 0xff { offset += 1; continue }
                    let start = offset
                    while offset < bytes.count && bytes[offset] == 0xff { offset += 1 }
                    guard offset < bytes.count else { return false }
                    if bytes[offset] == 0 || (0xd0...0xd7).contains(bytes[offset]) { offset += 1; continue }
                    offset = start; break
                }
            }
        }
        return false
    }
}
