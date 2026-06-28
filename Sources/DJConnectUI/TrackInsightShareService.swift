import CoreGraphics
import DJConnectCore
import Foundation

public enum TrackInsightShareFormat: String, CaseIterable, Identifiable, Sendable {
    case story
    case square
    case linkPreview

    public var id: String { rawValue }

    func title(language: String) -> String {
        switch self {
        case .story:
            DJConnectLocalization.localized(language: language, english: "Story", dutch: "Verhaal")
        case .square:
            DJConnectLocalization.localized(language: language, english: "Square", dutch: "Vierkant")
        case .linkPreview:
            DJConnectLocalization.localized(language: language, english: "Landscape", dutch: "Liggend")
        }
    }

    var size: CGSize {
        switch self {
        case .story:
            CGSize(width: 1080, height: 1920)
        case .square:
            CGSize(width: 1080, height: 1080)
        case .linkPreview:
            CGSize(width: 1200, height: 628)
        }
    }
}

public enum TrackInsightShareMediaKind: String, CaseIterable, Identifiable, Sendable {
    case staticImage
    case animatedVideo

    public var id: String { rawValue }

    func title(language: String) -> String {
        switch self {
        case .staticImage:
            DJConnectLocalization.localized(language: language, english: "Static", dutch: "Statisch")
        case .animatedVideo:
            DJConnectLocalization.localized(language: language, english: "Animated", dutch: "Geanimeerd")
        }
    }
}

public struct TrackInsightSharePayload: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var format: TrackInsightShareFormat
    public var mediaKind: TrackInsightShareMediaKind
    public var mediaURL: URL
    public var text: String
}

@MainActor
public enum TrackInsightShareService {
    public static func shareText(for insight: TrackInsight) -> String {
        let descriptors = [insight.mood, insight.vibe, insight.genre]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: ", ")
        let descriptorText = descriptors.isEmpty ? "Track Insight" : descriptors.lowercased()
        return """
        Currently vibing to \(insight.title) by \(insight.artist).

        DJConnect says: \(descriptorText) - \(insight.summary)

        Inspired by your Music DNA.

        #DJConnect #TrackInsight
        """
    }

    public static func makePayload(
        for insight: TrackInsight,
        format: TrackInsightShareFormat,
        mediaKind: TrackInsightShareMediaKind,
        language: String,
        progress: @escaping @MainActor (Double) -> Void = { _ in }
    ) async throws -> TrackInsightSharePayload {
        let mediaURL: URL
        switch mediaKind {
        case .staticImage:
            mediaURL = try TrackInsightShareRenderer.renderImage(insight: insight, format: format, language: language)
            progress(1)
        case .animatedVideo:
            mediaURL = try await TrackInsightShareRenderer.renderVideo(
                insight: insight,
                format: format,
                language: language,
                progress: progress
            )
        }
        return TrackInsightSharePayload(
            format: format,
            mediaKind: mediaKind,
            mediaURL: mediaURL,
            text: shareText(for: insight)
        )
    }
}
