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
    @State private var activeRenderID = UUID()

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localized("Share Track Insight", "Track Insight delen"))
                            .font(.title.bold())
                        Text(localized(
                            "Create a share card or short animated clip from this track analysis. Nothing is posted automatically.",
                            "Maak een deelkaart of korte animatie van deze trackanalyse. Er wordt niets automatisch geplaatst."
                        ))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 14) {
                TrackInsightShareSegmentControl(
                    title: localized("Media", "Media"),
                    options: TrackInsightShareMediaKind.allCases,
                    selection: $mediaKind
                ) { mediaKind in
                    mediaKind.title(language: language)
                }

                TrackInsightShareSegmentControl(
                    title: localized("Format", "Formaat"),
                    options: TrackInsightShareFormat.allCases,
                    selection: $format
                ) { format in
                    format.title(language: language)
                }

                previewCard

                VStack(spacing: 12) {
                    if let payload {
                        ShareLink(
                            item: payload.mediaURL,
                            subject: Text("\(insight.title) - \(insight.artist)"),
                            message: Text(payload.text)
                        ) {
                            Label(shareButtonTitle, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DJConnectLilacPillButtonStyle())
                        .controlSize(.large)
                    } else {
                        renderStatus
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(localized("Not Now", "Niet nu"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
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
            localized("Share Track Insight", "Track Insight delen")
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
                        cancelRender()
                    } label: {
                        Text(localized("Cancel export", "Export annuleren"))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isRendering || renderTask == nil)
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
        TrackInsightShareScaledPreview(format: format) {
            if mediaKind == .animatedVideo {
                TimelineView(.animation) { timeline in
                    TrackInsightShareCardView(
                        insight: insight,
                        format: format,
                        language: language,
                        animationPhase: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            } else {
                TrackInsightShareCardView(insight: insight, format: format, language: language, animationPhase: 0)
            }
        }
    }

    @MainActor
    private func startRender() {
        renderTask?.cancel()
        let taskID = UUID()
        activeRenderID = taskID
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
                    guard activeRenderID == taskID else { return }
                    renderProgress = min(1, max(0, progress))
                }
                try Task.checkCancellation()
                guard activeRenderID == taskID else { return }
                payload = renderedPayload
                renderProgress = 1
                errorText = nil
            } catch is CancellationError {
                guard activeRenderID == taskID else { return }
                payload = nil
                errorText = localized("Export cancelled.", "Export geannuleerd.")
            } catch let error as TrackInsightShareRenderer.RenderError {
                guard activeRenderID == taskID else { return }
                payload = nil
                errorText = localizedMessage(for: error)
            } catch {
                guard activeRenderID == taskID else { return }
                payload = nil
                errorText = localized("Share media could not be generated.", "Deelmedia kon niet worden gemaakt.")
            }
            guard activeRenderID == taskID else { return }
            isRendering = false
            renderTask = nil
        }
    }

    @MainActor
    private func cancelRender() {
        renderTask?.cancel()
        renderTask = nil
        activeRenderID = UUID()
        payload = nil
        renderProgress = 0
        isRendering = false
        errorText = localized("Export cancelled.", "Export geannuleerd.")
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

private struct TrackInsightShareScaledPreview<Content: View>: View {
    let format: TrackInsightShareFormat
    @ViewBuilder var content: Content

    private var aspectRatio: CGFloat {
        format.size.width / format.size.height
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let scale = min(
                    proxy.size.width / format.size.width,
                    proxy.size.height / format.size.height
                )

                content
                    .frame(width: format.size.width, height: format.size.height)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 460)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct TrackInsightShareSegmentControl<Option: Hashable & Identifiable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 92, alignment: .trailing)

            HStack(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(label(option))
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                            .background(selectionBackground(for: option))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(option == selection ? .white : .white.opacity(0.70))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityAddTraits(option == selection ? .isSelected : [])
                }
            }
            .padding(8)
            .frame(minHeight: 60)
            .frame(maxWidth: 390)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.03, blue: 0.13).opacity(0.96),
                        Color(red: 0.11, green: 0.05, blue: 0.24).opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1.5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func selectionBackground(for option: Option) -> some View {
        if option == selection {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.49, blue: 0.27),
                    Color(red: 0.74, green: 0.20, blue: 0.77)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.clear
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
                        .lineLimit(format == .linkPreview ? 1 : 2)
                        .minimumScaleFactor(0.72)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.24), in: Capsule())
                }
                TrackInsightShareMeters(insight: insight, profile: profile, language: language)
                Text(insight.summary)
                    .font(summaryFont)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(summaryLineLimit)
                    .minimumScaleFactor(0.66)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
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
            TrackInsightShareAnimatedArtworkFallback(
                profile: profile,
                animationPhase: animationPhase
            )
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
        switch format {
        case .story:
            .title.weight(.bold)
        case .square:
            .title2.weight(.bold)
        case .linkPreview:
            .headline.weight(.bold)
        }
    }

    private var summaryFont: Font {
        switch format {
        case .story:
            .callout.weight(.medium)
        case .square:
            .caption.weight(.medium)
        case .linkPreview:
            .caption2.weight(.medium)
        }
    }

    private var summaryLineLimit: Int {
        switch format {
        case .story:
            5
        case .square:
            3
        case .linkPreview:
            2
        }
    }

    private var cardSpacing: CGFloat {
        switch format {
        case .story:
            10
        case .square:
            8
        case .linkPreview:
            6
        }
    }

    private var cardPadding: CGFloat {
        switch format {
        case .story:
            28
        case .square:
            22
        case .linkPreview:
            20
        }
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

private struct TrackInsightShareAnimatedArtworkFallback: View {
    let profile: TrackVibeProfile
    let animationPhase: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let pulse = sin(animationPhase * profile.pulseSpeed * 1.7) * 0.5 + 0.5
            let beat = sin(animationPhase * 8.0) * 0.5 + 0.5
            let accent = profile.colors.last ?? djConnectAccent

            ZStack {
                profile.gradient

                AngularGradient(
                    colors: [
                        .white.opacity(0.0),
                        .white.opacity(0.38 + pulse * 0.20),
                        accent.opacity(0.18 + beat * 0.22),
                        .white.opacity(0.0)
                    ],
                    center: .center,
                    angle: .degrees(animationPhase * 42)
                )
                .blendMode(.screen)
                .blur(radius: size * 0.03)

                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                        .stroke(.white.opacity(0.16 - Double(index) * 0.035), lineWidth: max(1, size * 0.012))
                        .scaleEffect(0.68 + CGFloat(index) * 0.16 + CGFloat(pulse) * 0.06)
                        .rotationEffect(.degrees(animationPhase * (index.isMultiple(of: 2) ? 10 : -8)))
                }

                TrackInsightShareHeartbeatLine(phase: animationPhase, intensity: profile.waveform)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.38),
                                .white,
                                accent.opacity(0.96),
                                .white.opacity(0.48)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: max(4, size * 0.035), lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: size * 0.50, height: size * 0.30)
                    .shadow(color: accent.opacity(0.72), radius: size * (0.05 + pulse * 0.03))
                    .scaleEffect(1 + CGFloat(beat) * 0.10)

                Circle()
                    .fill(accent.opacity(0.34 + pulse * 0.18))
                    .frame(width: size * 0.22, height: size * 0.22)
                    .blur(radius: size * 0.10)
                    .offset(x: sin(animationPhase * 1.8) * size * 0.24, y: cos(animationPhase * 1.3) * size * 0.18)
                    .blendMode(.screen)
            }
        }
    }
}

private struct TrackInsightShareHeartbeatLine: Shape {
    let phase: Double
    let intensity: Double

    var animatableData: Double {
        get { phase }
        set {}
    }

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.00, y: 0.52),
            CGPoint(x: 0.18, y: 0.52),
            CGPoint(x: 0.28, y: 0.23),
            CGPoint(x: 0.42, y: 0.86),
            CGPoint(x: 0.54, y: 0.34),
            CGPoint(x: 0.64, y: 0.52),
            CGPoint(x: 1.00, y: 0.52)
        ]
        let shimmer = CGFloat((sin(phase * 7.0) * 0.5 + 0.5) * 0.08 * intensity)

        var path = Path()
        for (index, point) in points.enumerated() {
            let yOffset = index == 3 ? -shimmer : shimmer * CGFloat(index.isMultiple(of: 2) ? 0.7 : -0.5)
            let resolved = CGPoint(
                x: rect.minX + point.x * rect.width,
                y: rect.minY + (point.y + yOffset) * rect.height
            )
            if index == 0 {
                path.move(to: resolved)
            } else {
                path.addLine(to: resolved)
            }
        }
        return path
    }
}

private struct TrackInsightShareBackground: View {
    let profile: TrackVibeProfile
    let animationPhase: Double

    var body: some View {
        Canvas { context, size in
            draw(context: &context, size: size)
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
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
