import DJConnectCore
import SwiftUI

struct TrackInsightSharePreviewView: View {
    let insight: TrackInsight
    let language: String
    @Environment(\.dismiss) private var dismiss
    @State private var format: TrackInsightShareFormat = .story
    @State private var mediaKind: TrackInsightShareMediaKind = .staticImage
    @State private var payload: TrackInsightSharePayload?
    @State private var errorText: String?
    @State private var renderProgress: Double = 0
    @State private var isRendering = false
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                DJConnectCanvasBackground()
                VStack(spacing: 14) {
                    Picker(localized("Media", "Media"), selection: $mediaKind) {
                        ForEach(TrackInsightShareMediaKind.allCases) { mediaKind in
                            Text(mediaKind.title(language: language)).tag(mediaKind)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(localized("Format", "Formaat"), selection: $format) {
                        ForEach(TrackInsightShareFormat.allCases) { format in
                            Text(format.title(language: language)).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    previewCard

                    if let payload {
                        ShareLink(
                            item: payload.mediaURL,
                            subject: Text("\(insight.title) - \(insight.artist)"),
                            message: Text(payload.text)
                        ) {
                            Label(shareButtonTitle, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        renderStatus
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(16)
                .frame(maxWidth: 560)
            }
            .navigationTitle(localized("Share Vibe", "Vibe delen"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
        .onAppear {
            startRender()
        }
        .onChange(of: renderID) { _, _ in
            startRender()
        }
        .onDisappear {
            renderTask?.cancel()
        }
    }

    private var renderID: String {
        "\(format.rawValue)-\(mediaKind.rawValue)"
    }

    private var shareButtonTitle: String {
        switch mediaKind {
        case .staticImage:
            localized("Share Vibe Card", "Vibe-kaart delen")
        case .animatedVideo:
            localized("Share Animated Vibe", "Geanimeerde vibe delen")
        }
    }

    @ViewBuilder
    private var renderStatus: some View {
        VStack(spacing: 10) {
            ProgressView(value: mediaKind == .animatedVideo ? renderProgress : nil)
                .progressViewStyle(.linear)
            if mediaKind == .animatedVideo {
                HStack(spacing: 12) {
                    Text("\(Int((renderProgress * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button(role: .cancel) {
                        renderTask?.cancel()
                    } label: {
                        Text(localized("Cancel export", "Export annuleren"))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isRendering)
                }
            } else {
                Text(localized("Preparing share card...", "Deelkaart voorbereiden..."))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var previewCard: some View {
        if mediaKind == .animatedVideo {
            TimelineView(.animation) { timeline in
                TrackInsightShareCardView(
                    insight: insight,
                    format: format,
                    language: language,
                    animationPhase: timeline.date.timeIntervalSinceReferenceDate
                )
            }
            .aspectRatio(format.size.width / format.size.height, contentMode: .fit)
            .frame(maxHeight: 460)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
        } else {
            TrackInsightShareCardView(insight: insight, format: format, language: language, animationPhase: 0)
                .aspectRatio(format.size.width / format.size.height, contentMode: .fit)
                .frame(maxHeight: 460)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
        }
    }

    @MainActor
    private func startRender() {
        renderTask?.cancel()
        payload = nil
        errorText = nil
        renderProgress = 0
        isRendering = true
        let currentFormat = format
        let currentMediaKind = mediaKind
        renderTask = Task { @MainActor in
            do {
                let renderedPayload = try await TrackInsightShareService.makePayload(
                    for: insight,
                    format: currentFormat,
                    mediaKind: currentMediaKind,
                    language: language
                ) { progress in
                    renderProgress = min(1, max(0, progress))
                }
                try Task.checkCancellation()
                payload = renderedPayload
                renderProgress = 1
                errorText = nil
            } catch is CancellationError {
                payload = nil
                errorText = localized("Export cancelled.", "Export geannuleerd.")
            } catch let error as TrackInsightShareRenderer.RenderError {
                payload = nil
                errorText = localizedMessage(for: error)
            } catch {
                payload = nil
                errorText = localized("Share media could not be generated.", "Deelmedia kon niet worden gemaakt.")
            }
            isRendering = false
        }
    }

    private func localized(_ english: String, _ dutch: String) -> String {
        DJConnectLocalization.localized(language: language, english: english, dutch: dutch)
    }

    private func localizedMessage(for error: TrackInsightShareRenderer.RenderError) -> String {
        switch error {
        case .imageRenderingFailed:
            localized("The share image could not be rendered.", "Deelafbeelding kon niet worden gerenderd.")
        case .videoWriterUnavailable:
            localized("The animated share video could not be prepared.", "Geanimeerde deelvideo kon niet worden voorbereid.")
        case .videoFrameRenderingFailed:
            localized("A video frame could not be rendered.", "Een videoframe kon niet worden gerenderd.")
        case .videoEncodingFailed:
            localized("The animated share video could not be encoded.", "Geanimeerde deelvideo kon niet worden gecodeerd.")
        case .unsupportedVideoExport:
            localized("Animated video export is not supported on this platform.", "Geanimeerde video-export wordt niet ondersteund op dit platform.")
        }
    }
}

struct TrackInsightShareCardView: View {
    let insight: TrackInsight
    let format: TrackInsightShareFormat
    let language: String
    let animationPhase: Double

    private var profile: TrackVibeProfile {
        TrackVibeProfile.make(for: insight)
    }

    var body: some View {
        ZStack {
            TrackInsightShareBackground(profile: profile, animationPhase: animationPhase)
            VStack(spacing: cardSpacing) {
                Label("DJCONNECT", systemImage: "circle.hexagongrid.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
                Text(localized("Now Playing", "Speelt nu"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                artwork
                VStack(spacing: 5) {
                    Text(insight.title)
                        .font(titleFont)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .multilineTextAlignment(.center)
                    Text(insight.artist)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Text(metricLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let vibeLine {
                    Text(vibeLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(profile.colors.last ?? djConnectAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.24), in: Capsule())
                }
                TrackInsightShareMeters(insight: insight, profile: profile, language: language)
                Text(insight.summary)
                    .font(summaryFont)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(format == .linkPreview ? 2 : 4)
                    .minimumScaleFactor(0.76)
                Spacer(minLength: 0)
                Label(localized("Rendered privately on your device", "Privé gerenderd op je apparaat"), systemImage: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                Text(localized("Track Insight powered by Music DNA", "Track Insight met Music DNA"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                Text("#DJConnect #TrackInsight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(cardPadding)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        CachedArtworkImage(url: insight.artwork, mode: .fill) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(profile.gradient)
                .overlay {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: artworkSize * 0.28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.70))
                }
        }
        .frame(width: artworkSize, height: artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(profile.colors.last?.opacity(0.72) ?? .white.opacity(0.28), lineWidth: 2)
        }
        .shadow(color: (profile.colors.last ?? djConnectAccent).opacity(0.46), radius: 26)
    }

    private var titleFont: Font {
        format == .linkPreview ? .title2.weight(.bold) : .title.weight(.bold)
    }

    private var summaryFont: Font {
        format == .linkPreview ? .caption.weight(.medium) : .callout.weight(.medium)
    }

    private var cardSpacing: CGFloat {
        format == .linkPreview ? 7 : 12
    }

    private var cardPadding: CGFloat {
        format == .linkPreview ? 22 : 28
    }

    private var artworkSize: CGFloat {
        switch format {
        case .story:
            166
        case .square:
            132
        case .linkPreview:
            112
        }
    }

    private var metricLine: String {
        [
            insight.genre,
            insight.bpm.map { "\(Int($0.rounded())) BPM" },
            insight.key
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "  -  ")
    }

    private var vibeLine: String? {
        let parts = [insight.mood, insight.vibe, insight.texture]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    private func localized(_ english: String, _ dutch: String) -> String {
        DJConnectLocalization.localized(language: language, english: english, dutch: dutch)
    }
}

private struct TrackInsightShareBackground: View {
    let profile: TrackVibeProfile
    let animationPhase: Double

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: profile.colors),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width, y: size.height)
            ))
            for index in 0..<5 {
                var path = Path()
                let baseY = size.height * (0.42 + CGFloat(index) * 0.08)
                path.move(to: CGPoint(x: -40, y: baseY))
                for step in 0...18 {
                    let x = size.width * CGFloat(step) / 18
                    let y = baseY + sin(CGFloat(step) * 0.8 + CGFloat(index) + CGFloat(animationPhase) * 1.4) * 22 * profile.waveform
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.05 + Double(index) * 0.018)), lineWidth: 2)
            }
            let pulse = sin(animationPhase * profile.pulseSpeed) * 0.5 + 0.5
            context.fill(
                Path(ellipseIn: CGRect(
                    x: size.width * (0.50 + CGFloat(sin(animationPhase * 0.7)) * 0.06) - size.width * 0.16,
                    y: size.height * 0.20 - size.width * 0.16,
                    width: size.width * (0.28 + CGFloat(pulse) * 0.08),
                    height: size.width * (0.28 + CGFloat(pulse) * 0.08)
                )),
                with: .color((profile.colors.last ?? djConnectAccent).opacity(0.14 + pulse * 0.10))
            )
            context.fill(Path(rect), with: .color(.black.opacity(0.30)))
        }
    }
}

private struct TrackInsightShareMeters: View {
    let insight: TrackInsight
    let profile: TrackVibeProfile
    let language: String

    var body: some View {
        HStack(spacing: 18) {
            meter(localized("Energy", "Energie"), insight.energy)
            meter(localized("Danceability", "Dansbaarheid"), insight.danceability)
            meter(localized("Intensity", "Intensiteit"), insight.intensity)
        }
    }

    private func meter(_ title: String, _ value: Double?) -> some View {
        let value = value ?? 0
        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.04, min(1, value))))
                    .stroke(
                        AngularGradient(colors: profile.colors, center: .center),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.2f", value))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 74)
    }

    private func localized(_ english: String, _ dutch: String) -> String {
        DJConnectLocalization.localized(language: language, english: english, dutch: dutch)
    }
}
