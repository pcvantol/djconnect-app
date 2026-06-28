import DJConnectCore
import Foundation
import SwiftUI

#if canImport(AVFoundation)
import AVFoundation
#endif
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public enum TrackInsightShareRenderer {
    public static let outputDirectoryName = "DJConnectTrackInsightShare"

    public enum RenderError: LocalizedError, Equatable {
        case imageRenderingFailed
        case videoWriterUnavailable
        case videoFrameRenderingFailed
        case videoEncodingFailed(String)
        case unsupportedVideoExport

        public var errorDescription: String? {
            switch self {
            case .imageRenderingFailed:
                "The share image could not be rendered."
            case .videoWriterUnavailable:
                "The animated share video could not be prepared."
            case .videoFrameRenderingFailed:
                "A video frame could not be rendered."
            case .videoEncodingFailed(let message):
                message
            case .unsupportedVideoExport:
                "Animated video export is not supported on this platform."
            }
        }
    }

    public static func renderImage(
        insight: TrackInsight,
        format: TrackInsightShareFormat,
        language: String
    ) throws -> URL {
        try cleanupTemporaryExports()
        let view = TrackInsightShareCardView(insight: insight, format: format, language: language, animationPhase: 0)
            .frame(width: format.size.width, height: format.size.height)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(format.size)
        renderer.scale = 1

        guard let data = try pngData(from: renderer) else {
            throw RenderError.imageRenderingFailed
        }

        let fileURL = try makeOutputURL(insight: insight, format: format, mediaKind: .staticImage, extension: "png")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    public static func renderVideo(
        insight: TrackInsight,
        format: TrackInsightShareFormat,
        language: String,
        progress: @escaping @MainActor (Double) -> Void = { _ in }
    ) async throws -> URL {
        #if canImport(AVFoundation)
        try Task.checkCancellation()
        try cleanupTemporaryExports()
        let fileURL = try makeOutputURL(insight: insight, format: format, mediaKind: .animatedVideo, extension: "mp4")
        try? FileManager.default.removeItem(at: fileURL)

        do {
            let size = normalizedVideoSize(format.size)
            let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height)
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: Int(size.width),
                    kCVPixelBufferHeightKey as String: Int(size.height)
                ]
            )
            guard writer.canAdd(input) else {
                throw RenderError.videoWriterUnavailable
            }
            writer.add(input)
            guard writer.startWriting() else {
                throw RenderError.videoEncodingFailed(writer.error?.localizedDescription ?? "Video encoding could not start.")
            }
            writer.startSession(atSourceTime: .zero)

            let frameRate = 24
            let durationSeconds = 6
            let frameCount = frameRate * durationSeconds
            progress(0)
            for frame in 0..<frameCount {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 10_000_000)
                }
                let phase = Double(frame) / Double(frameRate)
                guard let pixelBuffer = try pixelBuffer(for: insight, format: format, language: language, size: size, animationPhase: phase) else {
                    throw RenderError.videoFrameRenderingFailed
                }
                let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate))
                guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                    throw RenderError.videoEncodingFailed(writer.error?.localizedDescription ?? "Video frame encoding failed.")
                }
                progress(Double(frame + 1) / Double(frameCount))
                await Task.yield()
            }
            input.markAsFinished()
            await finishWriting(writer)
            guard writer.status == .completed else {
                throw RenderError.videoEncodingFailed(writer.error?.localizedDescription ?? "Video encoding did not complete.")
            }
            progress(1)
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
        #else
        throw RenderError.unsupportedVideoExport
        #endif
    }

    public static func cleanupTemporaryExports(
        olderThan interval: TimeInterval = 24 * 60 * 60,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws {
        let directory = temporaryOutputDirectory(fileManager: fileManager)
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        for url in urls {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) > interval {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private static func makeOutputURL(
        insight: TrackInsight,
        format: TrackInsightShareFormat,
        mediaKind: TrackInsightShareMediaKind,
        extension pathExtension: String
    ) throws -> URL {
        let directory = temporaryOutputDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeTitle = insight.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
        return directory.appendingPathComponent("DJConnect-\(safeTitle)-\(format.rawValue)-\(mediaKind.rawValue)-\(UUID().uuidString).\(pathExtension)")
    }

    public static func temporaryOutputDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.temporaryDirectory.appendingPathComponent(outputDirectoryName, isDirectory: true)
    }

    private static func normalizedVideoSize(_ size: CGSize) -> CGSize {
        CGSize(width: Int(size.width) / 2 * 2, height: Int(size.height) / 2 * 2)
    }

    private static func pngData<Content: View>(from renderer: ImageRenderer<Content>) throws -> Data? {
        #if os(iOS)
        return renderer.uiImage?.pngData()
        #elseif os(macOS)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }

    #if canImport(AVFoundation)
    private static func finishWriting(_ writer: AVAssetWriter) async {
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }
    }

    private static func pixelBuffer(
        for insight: TrackInsight,
        format: TrackInsightShareFormat,
        language: String,
        size: CGSize,
        animationPhase: Double
    ) throws -> CVPixelBuffer? {
        let view = TrackInsightShareCardView(insight: insight, format: format, language: language, animationPhase: animationPhase)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1

        #if os(iOS)
        guard let cgImage = renderer.uiImage?.cgImage else {
            return nil
        }
        #elseif os(macOS)
        guard let image = renderer.nsImage else {
            return nil
        }
        var rect = CGRect(origin: .zero, size: size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return nil
        }
        #else
        return nil
        #endif

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return pixelBuffer
    }
    #endif
}
