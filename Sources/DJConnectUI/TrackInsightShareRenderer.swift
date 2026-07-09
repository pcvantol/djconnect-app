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
        language: String,
        moodStepIndex: Int = 2
    ) throws -> URL {
        try cleanupTemporaryExports()
        let designSize = format.cardDesignSize
        let view = TrackInsightShareCardView(
            insight: insight,
            format: format,
            language: language,
            moodStepIndex: moodStepIndex,
            animationPhase: 0
        )
            .frame(width: designSize.width, height: designSize.height)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(designSize)
        renderer.scale = format.size.width / designSize.width

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
        moodStepIndex: Int = 2,
        progress: @escaping @MainActor (Double) -> Void = { _ in }
    ) async throws -> URL {
        #if canImport(AVFoundation)
        try Task.checkCancellation()
        try cleanupTemporaryExports()
        let fileURL = try makeOutputURL(insight: insight, format: format, mediaKind: .animatedVideo, extension: "mp4")
        try? FileManager.default.removeItem(at: fileURL)
        var writer: AVAssetWriter?

        do {
            let size = normalizedVideoSize(format.size)
            let videoWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            writer = videoWriter
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
            guard videoWriter.canAdd(input) else {
                throw RenderError.videoWriterUnavailable
            }
            videoWriter.add(input)
            guard videoWriter.startWriting() else {
                throw RenderError.videoEncodingFailed(videoWriter.error?.localizedDescription ?? "Video encoding could not start.")
            }
            videoWriter.startSession(atSourceTime: .zero)

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
                guard let pixelBuffer = try pixelBuffer(
                    for: insight,
                    format: format,
                    language: language,
                    moodStepIndex: moodStepIndex,
                    size: size,
                    animationPhase: phase
                ) else {
                    throw RenderError.videoFrameRenderingFailed
                }
                let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate))
                guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                    throw RenderError.videoEncodingFailed(videoWriter.error?.localizedDescription ?? "Video frame encoding failed.")
                }
                progress(Double(frame + 1) / Double(frameCount))
                await Task.yield()
            }
            input.markAsFinished()
            try Task.checkCancellation()
            await finishWriting(videoWriter)
            try Task.checkCancellation()
            guard videoWriter.status == .completed else {
                throw RenderError.videoEncodingFailed(videoWriter.error?.localizedDescription ?? "Video encoding did not complete.")
            }
            progress(1)
            return fileURL
        } catch is CancellationError {
            writer?.cancelWriting()
            try? FileManager.default.removeItem(at: fileURL)
            throw CancellationError()
        } catch {
            writer?.cancelWriting()
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
        #else
        throw RenderError.unsupportedVideoExport
        #endif
    }

    public static func renderAirPlayVideo(
        insight: TrackInsight,
        language: String,
        moodStepIndex: Int = 2,
        fallbackArtworkURL: URL? = nil,
        progress: @escaping @MainActor (Double) -> Void = { _ in }
    ) async throws -> URL {
        #if canImport(AVFoundation)
        try Task.checkCancellation()
        try cleanupTemporaryExports()
        let format = TrackInsightShareFormat.linkPreview
        let fileURL = try makeOutputURL(insight: insight, format: format, mediaKind: .animatedVideo, extension: "mp4")
        try? FileManager.default.removeItem(at: fileURL)
        var writer: AVAssetWriter?

        do {
            let size = CGSize(width: 1920, height: 1080)
            let videoWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            videoWriter.shouldOptimizeForNetworkUse = true
            writer = videoWriter
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000,
                    AVVideoMaxKeyFrameIntervalKey: 48,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
                ]
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = false
            input.mediaTimeScale = 600
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: Int(size.width),
                    kCVPixelBufferHeightKey as String: Int(size.height)
                ]
            )
            guard videoWriter.canAdd(input) else {
                throw RenderError.videoWriterUnavailable
            }
            videoWriter.add(input)
            let audioInput = silentAACAudioInput()
            guard videoWriter.canAdd(audioInput) else {
                throw RenderError.videoWriterUnavailable
            }
            videoWriter.add(audioInput)
            guard videoWriter.startWriting() else {
                throw RenderError.videoEncodingFailed(videoWriter.error?.localizedDescription ?? "Video encoding could not start.")
            }
            videoWriter.startSession(atSourceTime: .zero)

            let frameRate = 24
            let durationSeconds = 90
            let frameCount = frameRate * durationSeconds
            let renderInsight = insight.withFallbackArtwork(fallbackArtworkURL)
            let renderedArtworkImage = await preloadedArtworkImage(for: renderInsight.artwork)
            let audioAppendTask = Task {
                try await appendSilentAudio(to: audioInput, durationSeconds: durationSeconds)
            }
            progress(0)
            for frame in 0..<frameCount {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 10_000_000)
                }
                let phase = Double(frame) / Double(frameRate)
                guard let pixelBuffer = try airPlayPixelBuffer(
                    for: renderInsight,
                    language: language,
                    moodStepIndex: moodStepIndex,
                    renderedArtworkImage: renderedArtworkImage,
                    size: size,
                    durationSeconds: durationSeconds,
                    animationPhase: phase
                ) else {
                    throw RenderError.videoFrameRenderingFailed
                }
                let time = CMTime(seconds: Double(frame) / Double(frameRate), preferredTimescale: 600)
                guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                    throw RenderError.videoEncodingFailed(videoWriter.error?.localizedDescription ?? "Video frame encoding failed.")
                }
                progress(Double(frame + 1) / Double(frameCount))
                await Task.yield()
            }
            input.markAsFinished()
            try await audioAppendTask.value
            try Task.checkCancellation()
            await finishWriting(videoWriter)
            try Task.checkCancellation()
            guard videoWriter.status == .completed else {
                throw RenderError.videoEncodingFailed(videoWriter.error?.localizedDescription ?? "Video encoding did not complete.")
            }
            progress(1)
            return fileURL
        } catch is CancellationError {
            writer?.cancelWriting()
            try? FileManager.default.removeItem(at: fileURL)
            throw CancellationError()
        } catch {
            writer?.cancelWriting()
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

    private final class LockedContinuation: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Error>?

        init(_ continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func resume() {
            resume(with: .success(()))
        }

        func resume(throwing error: Error) {
            resume(with: .failure(error))
        }

        private func resume(with result: Result<Void, Error>) {
            lock.lock()
            let continuation = continuation
            self.continuation = nil
            lock.unlock()

            switch result {
            case .success:
                continuation?.resume()
            case .failure(let error):
                continuation?.resume(throwing: error)
            }
        }
    }

    private static func silentAACAudioInput() -> AVAssetWriterInput {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 64_000
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        return input
    }

    private static func appendSilentAudio(
        to input: AVAssetWriterInput,
        durationSeconds: Int,
        sampleRate: Int32 = 44_100,
        channels: Int32 = 2
    ) async throws {
        var streamDescription = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(channels) * UInt32(MemoryLayout<Float32>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(channels) * UInt32(MemoryLayout<Float32>.size),
            mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 32,
            mReserved: 0
        )
        var formatDescription: CMAudioFormatDescription?
        let formatStatus = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &streamDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else {
            throw RenderError.videoEncodingFailed("Silent audio format could not be prepared.")
        }

        let totalFrames = Int(sampleRate) * durationSeconds
        let queue = DispatchQueue(label: "DJConnect.AirPlaySilentAudio")
        try await withCheckedThrowingContinuation { continuation in
            let appendState = SilentAudioAppendState(
                input: input,
                continuation: LockedContinuation(continuation),
                formatDescription: formatDescription,
                totalFrames: totalFrames,
                sampleRate: sampleRate,
                bytesPerFrame: Int(streamDescription.mBytesPerFrame)
            )
            input.requestMediaDataWhenReady(on: queue) {
                appendState.appendAvailableSamples()
            }
        }
    }

    private final class SilentAudioAppendState: @unchecked Sendable {
        private let input: AVAssetWriterInput
        private let continuation: LockedContinuation
        private let formatDescription: CMAudioFormatDescription
        private let totalFrames: Int
        private let sampleRate: Int32
        private let bytesPerFrame: Int
        private let framesPerBuffer = 1_024
        private var framePosition = 0

        init(
            input: AVAssetWriterInput,
            continuation: LockedContinuation,
            formatDescription: CMAudioFormatDescription,
            totalFrames: Int,
            sampleRate: Int32,
            bytesPerFrame: Int
        ) {
            self.input = input
            self.continuation = continuation
            self.formatDescription = formatDescription
            self.totalFrames = totalFrames
            self.sampleRate = sampleRate
            self.bytesPerFrame = bytesPerFrame
        }

        func appendAvailableSamples() {
            while input.isReadyForMoreMediaData {
                if framePosition >= totalFrames {
                    input.markAsFinished()
                    continuation.resume()
                    return
                }

                let frameCount = min(framesPerBuffer, totalFrames - framePosition)
                let byteCount = frameCount * bytesPerFrame
                var blockBuffer: CMBlockBuffer?
                let blockStatus = CMBlockBufferCreateWithMemoryBlock(
                    allocator: kCFAllocatorDefault,
                    memoryBlock: nil,
                    blockLength: byteCount,
                    blockAllocator: kCFAllocatorDefault,
                    customBlockSource: nil,
                    offsetToData: 0,
                    dataLength: byteCount,
                    flags: 0,
                    blockBufferOut: &blockBuffer
                )
                guard blockStatus == kCMBlockBufferNoErr, let blockBuffer else {
                    continuation.resume(throwing: RenderError.videoEncodingFailed("Silent audio buffer could not be prepared."))
                    return
                }
                CMBlockBufferFillDataBytes(with: 0, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: byteCount)

                var timing = CMSampleTimingInfo(
                    duration: CMTime(value: 1, timescale: sampleRate),
                    presentationTimeStamp: CMTime(value: CMTimeValue(framePosition), timescale: sampleRate),
                    decodeTimeStamp: .invalid
                )
                var sampleSize = bytesPerFrame
                var sampleBuffer: CMSampleBuffer?
                let sampleStatus = CMSampleBufferCreateReady(
                    allocator: kCFAllocatorDefault,
                    dataBuffer: blockBuffer,
                    formatDescription: formatDescription,
                    sampleCount: frameCount,
                    sampleTimingEntryCount: 1,
                    sampleTimingArray: &timing,
                    sampleSizeEntryCount: 1,
                    sampleSizeArray: &sampleSize,
                    sampleBufferOut: &sampleBuffer
                )
                guard sampleStatus == noErr, let sampleBuffer, input.append(sampleBuffer) else {
                    continuation.resume(throwing: RenderError.videoEncodingFailed("Silent audio buffer could not be encoded."))
                    return
                }
                framePosition += frameCount
            }
        }
    }

    private static func pixelBuffer(
        for insight: TrackInsight,
        format: TrackInsightShareFormat,
        language: String,
        moodStepIndex: Int,
        size: CGSize,
        animationPhase: Double
    ) throws -> CVPixelBuffer? {
        let designSize = format.cardDesignSize
        let view = TrackInsightShareCardView(
            insight: insight,
            format: format,
            language: language,
            moodStepIndex: moodStepIndex,
            animationPhase: animationPhase
        )
            .frame(width: designSize.width, height: designSize.height)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(designSize)
        renderer.scale = size.width / designSize.width

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

    private static func airPlayPixelBuffer(
        for insight: TrackInsight,
        language: String,
        moodStepIndex: Int,
        renderedArtworkImage: Image?,
        size: CGSize,
        durationSeconds: Int,
        animationPhase: Double
    ) throws -> CVPixelBuffer? {
        let playback = airPlayPlayback(for: insight, animationPhase: animationPhase, durationSeconds: durationSeconds)
        let view = VibeCastVisualizerSignalView(
            insight: insight,
            playback: playback,
            vibeCastItems: airPlayVibeCastItems(for: insight),
            genreBadge: airPlayGenreBadge(for: insight),
            language: language,
            moodStepIndex: moodStepIndex,
            reduceMotion: true,
            renderedArtworkImage: renderedArtworkImage
        )
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

    private static func preloadedArtworkImage(for url: URL?) async -> Image? {
        guard let url else {
            return nil
        }
        do {
            let data = try await DJConnectArtworkDataCache.shared.data(for: url)
            return makeArtworkImage(from: data)
        } catch {
            return nil
        }
    }

    private static func airPlayPlayback(for insight: TrackInsight, animationPhase: Double, durationSeconds: Int) -> DJConnectPlayback {
        let durationMS = 180_000
        let progressRatio = min(max(animationPhase / Double(durationSeconds), 0), 1)
        return DJConnectPlayback(
            hasPlayback: true,
            isPlaying: true,
            trackName: insight.title,
            artistName: insight.artist,
            albumImageURL: insight.artwork,
            progressMS: Int(progressRatio * Double(durationMS)),
            durationMS: durationMS,
            volumePercent: nil
        )
    }

    private static func airPlayGenreBadge(for insight: TrackInsight) -> DJConnectVibeCastResponse.Context.GenreBadge? {
        let label = [insight.genre, insight.subgenre]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let label else {
            return nil
        }
        return DJConnectVibeCastResponse.Context.GenreBadge(label: label, genre: insight.genre ?? label)
    }

    private static func airPlayVibeCastItems(for insight: TrackInsight) -> [DJConnectVibeCastResponse.Item] {
        var items: [DJConnectVibeCastResponse.Item] = []
        let summary = insight.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            items.append(DJConnectVibeCastResponse.Item(
                id: "airplay-summary",
                kind: .moodNote,
                tone: "insight",
                priority: 1,
                displaySeconds: 8,
                placementHint: "left",
                text: [.init(type: .strong, value: summary)]
            ))
        }
        let texture = [insight.mood, insight.vibe, insight.texture]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " • ")
        if !texture.isEmpty {
            items.append(DJConnectVibeCastResponse.Item(
                id: "airplay-texture",
                kind: .listeningTip,
                tone: "texture",
                priority: 2,
                displaySeconds: 8,
                placementHint: "right",
                text: [
                    .init(type: .emoji, value: "♪ "),
                    .init(type: .accent, value: texture)
                ]
            ))
        }
        return items
    }
    #endif
}

private extension TrackInsight {
    func withFallbackArtwork(_ fallbackArtworkURL: URL?) -> TrackInsight {
        guard artwork == nil, let fallbackArtworkURL else {
            return self
        }
        var copy = self
        copy.artwork = fallbackArtworkURL
        return copy
    }
}
