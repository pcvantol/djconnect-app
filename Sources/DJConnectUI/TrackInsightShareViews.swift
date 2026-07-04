import DJConnectCore
import SwiftUI

struct TrackInsightSharePreviewView: View {
    let insight: TrackInsight
    let language: String
    let moodStepIndex: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var format: TrackInsightShareFormat = .story
    @State private var mediaKind: TrackInsightShareMediaKind = .staticImage
    @State private var payload: TrackInsightSharePayload?
    @State private var errorText: String?
    @State private var renderProgress: Double = 0
    @State private var isRendering = false
    @State private var renderTask: Task<Void, Never>?
    @State private var activeRenderID = UUID()

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 820 : 560
    }

    var body: some View {
        ZStack {
            DJConnectCanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localizedKey("trackInsight.share.share.track.insight"))
                            .font(.title.bold())
                        Text(localizedKey("trackInsight.share.create.a.share.card.or.short.animated.clip.from.this"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 14) {
                TrackInsightShareSegmentControl(
                    title: localizedKey("trackInsight.share.media"),
                    options: TrackInsightShareMediaKind.allCases,
                    selection: $mediaKind
                ) { mediaKind in
                    mediaKind.title(language: language)
                }

                TrackInsightShareSegmentControl(
                    title: localizedKey("trackInsight.share.format"),
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
                        Text(localizedKey("trackInsight.share.not.now"))
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
                .padding(.horizontal, 20)
                .padding(.top, horizontalSizeClass == .regular ? 8 : 20)
                .padding(.bottom, 20)
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .defaultScrollAnchor(.top)
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationSizing(.page)
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
            localizedKey("trackInsight.share.share.track.insight")
        case .animatedVideo:
            localizedKey("trackInsight.share.share.track.insight")
        }
    }

    @ViewBuilder
    private var renderStatus: some View {
        VStack(spacing: 12) {
            if mediaKind == .animatedVideo {
                TrackInsightShareExportProgress(progress: renderProgress)
                HStack(spacing: 12) {
                    Button(role: .cancel) {
                        cancelRender()
                    } label: {
                        Label(localizedKey("trackInsight.share.cancel.export"), systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DJConnectLilacPillButtonStyle())
                    .controlSize(.large)
                    .disabled(!isRendering || renderTask == nil)
                }
            } else {
                ProgressView()
                    .tint(djConnectAccent)
                Text(localizedKey("trackInsight.share.preparing.share.card"))
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
                        moodStepIndex: moodStepIndex,
                        animationPhase: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            } else {
                TrackInsightShareCardView(
                    insight: insight,
                    format: format,
                    language: language,
                    moodStepIndex: moodStepIndex,
                    animationPhase: 0
                )
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
                    language: language,
                    moodStepIndex: moodStepIndex
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
                errorText = localizedKey("trackInsight.share.export.cancelled")
            } catch let error as TrackInsightShareRenderer.RenderError {
                guard activeRenderID == taskID else { return }
                payload = nil
                errorText = localizedMessage(for: error)
            } catch {
                guard activeRenderID == taskID else { return }
                payload = nil
                errorText = localizedKey("trackInsight.share.share.media.could.not.be.generated")
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
        errorText = localizedKey("trackInsight.share.export.cancelled")
    }

    private func localizedKey(_ key: String, arguments: CVarArg...) -> String {
        DJConnectLocalization.localized(key: key, language: language, arguments: arguments)
    }

    private func localizedMessage(for error: TrackInsightShareRenderer.RenderError) -> String {
        switch error {
        case .imageRenderingFailed:
            localizedKey("trackInsight.share.the.share.image.could.not.be.rendered")
        case .videoWriterUnavailable:
            localizedKey("trackInsight.share.the.animated.share.video.could.not.be.prepared")
        case .videoFrameRenderingFailed:
            localizedKey("trackInsight.share.a.video.frame.could.not.be.rendered")
        case .videoEncodingFailed:
            localizedKey("trackInsight.share.the.animated.share.video.could.not.be.encoded")
        case .unsupportedVideoExport:
            localizedKey("trackInsight.share.animated.video.export.is.not.supported.on.this.platform")
        }
    }
}

private struct TrackInsightShareExportProgress: View {
    let progress: Double

    private let progressBlue = Color(red: 0.16, green: 0.56, blue: 1.0)
    private let progressPurple = Color(red: 0.84, green: 0.18, blue: 1.0)

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.14))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [progressBlue, progressPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, geometry.size.width * clampedProgress))
                    .shadow(color: progressPurple.opacity(0.28), radius: 8, y: 2)
            }
        }
        .frame(height: 8)
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Export progress")
        .accessibilityValue("\(Int((clampedProgress * 100).rounded()))%")
    }
}

private struct TrackInsightShareScaledPreview<Content: View>: View {
    let format: TrackInsightShareFormat
    @ViewBuilder var content: Content

    private var designSize: CGSize {
        format.cardDesignSize
    }

    private var aspectRatio: CGFloat {
        format.size.width / format.size.height
    }

    var body: some View {
        GeometryReader { outerProxy in
            ZStack {
                GeometryReader { proxy in
                    let scale = min(
                        proxy.size.width / designSize.width,
                        proxy.size.height / designSize.height
                    )

                    content
                        .frame(width: designSize.width, height: designSize.height)
                        .scaleEffect(scale)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: maxPreviewHeight(in: outerProxy.size))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .frame(height: preferredContainerHeight)
    }

    private var preferredContainerHeight: CGFloat {
        switch format {
        case .story:
            640
        case .square:
            540
        case .linkPreview:
            360
        }
    }

    private func maxPreviewHeight(in size: CGSize) -> CGFloat {
        let availableHeight = max(size.height, preferredContainerHeight)
        let responsiveHeight = availableHeight * 0.92
        switch format {
        case .story:
            return min(720, max(460, responsiveHeight))
        case .square:
            return min(560, max(420, responsiveHeight))
        case .linkPreview:
            return min(420, max(260, responsiveHeight))
        }
    }
}

extension TrackInsightShareFormat {
    var cardDesignSize: CGSize {
        switch self {
        case .story:
            CGSize(width: 540, height: 960)
        case .square:
            CGSize(width: 540, height: 540)
        case .linkPreview:
            CGSize(width: 600, height: 314)
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
    let moodStepIndex: Int
    let animationPhase: Double

    private var profile: TrackVibeProfile {
        TrackVibeProfile.make(for: insight)
            .applyingTrackInsightMoodRenderOverride(stepIndex: moodStepIndex)
    }

    private var phase: TrackVibePlaybackPhase {
        TrackVibePlaybackPhase(shareProgress: animationPhase, duration: 6)
    }

    private var renderDate: Date {
        Date(timeIntervalSinceReferenceDate: animationPhase)
    }

    var body: some View {
        ZStack {
            TrackInsightPremiumBackground(profile: profile, phase: phase, date: renderDate)
            TrackInsightLightField(profile: profile, phase: phase, date: renderDate)
            TrackInsightPremiumSpectrum(profile: profile, phase: phase)
                .frame(height: spectrumHeight)
                .padding(.horizontal, spectrumHorizontalPadding)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, spectrumBottomPadding)
                .opacity(spectrumOpacity)
            VStack(spacing: cardSpacing) {
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
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(format == .linkPreview ? 1 : 2)
                        .minimumScaleFactor(0.72)
                        .multilineTextAlignment(.center)
                }
                TrackInsightShareMeters(insight: insight, profile: profile, format: format, language: language)
                Text(insight.summary)
                    .font(summaryFont)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(summaryLineLimit)
                    .minimumScaleFactor(0.66)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: format == .story ? 10 : 0)
                Text("#DJConnect #TrackInsight")
                    .font(hashtagFont)
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(cardPadding)
            .frame(maxWidth: contentMaxWidth)
        }
        .background(profile.gradient)
        .clipped()
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
        .shadow(color: .clear, radius: 0)
    }

    private var titleFont: Font {
        switch format {
        case .story:
            .largeTitle.weight(.bold)
        case .square:
            .title2.weight(.bold)
        case .linkPreview:
            .headline.weight(.bold)
        }
    }

    private var summaryFont: Font {
        switch format {
        case .story:
            .title3.weight(.medium)
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
            16
        case .square:
            10
        case .linkPreview:
            8
        }
    }

    private var cardPadding: CGFloat {
        switch format {
        case .story:
            38
        case .square:
            20
        case .linkPreview:
            18
        }
    }

    private var artworkSize: CGFloat {
        switch format {
        case .story:
            360
        case .square:
            220
        case .linkPreview:
            220
        }
    }

    private var hashtagFont: Font {
        switch format {
        case .story:
            .callout.weight(.semibold)
        case .square, .linkPreview:
            .caption.weight(.semibold)
        }
    }

    private var contentMaxWidth: CGFloat {
        switch format {
        case .story:
            470
        case .square:
            500
        case .linkPreview:
            560
        }
    }

    private var spectrumHeight: CGFloat {
        switch format {
        case .story:
            170
        case .square:
            112
        case .linkPreview:
            84
        }
    }

    private var spectrumHorizontalPadding: CGFloat {
        switch format {
        case .story:
            128
        case .square:
            112
        case .linkPreview:
            144
        }
    }

    private var spectrumBottomPadding: CGFloat {
        switch format {
        case .story:
            216
        case .square:
            92
        case .linkPreview:
            52
        }
    }

    private var spectrumOpacity: Double {
        switch format {
        case .story:
            0.72
        case .square:
            0.64
        case .linkPreview:
            0.52
        }
    }

    private var metricLine: String {
        [
            insight.genre
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
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func localizedKey(_ key: String, arguments: CVarArg...) -> String {
        DJConnectLocalization.localized(key: key, language: language, arguments: arguments)
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
        context.fill(Path(rect), with: .color(.black.opacity(0.30)))
    }
}

private struct TrackInsightShareMeters: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringGlowIsActive = false

    let insight: TrackInsight
    let profile: TrackVibeProfile
    let format: TrackInsightShareFormat
    let language: String

    var body: some View {
        HStack(spacing: meterSpacing) {
            meter(localizedKey("trackInsight.share.energy"), insight.energy)
            meter(localizedKey("trackInsight.share.danceability"), insight.danceability)
            meter(localizedKey("trackInsight.share.intensity"), insight.intensity)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                ringGlowIsActive = true
            }
        }
    }

    private func meter(_ title: String, _ value: Double?) -> some View {
        let value = normalizedMeterValue(value)
        let ringGradient = AngularGradient(colors: Self.liveMetricRingColors, center: .center)
        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: meterLineWidth)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.04, value)))
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: meterLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (Self.liveMetricRingColors.last ?? djConnectAccent).opacity(reduceMotion ? 0.18 : (ringGlowIsActive ? 0.34 : 0.16)), radius: reduceMotion ? 4 : (ringGlowIsActive ? 13 : 5), x: 0, y: 0)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.04, value)))
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: meterLineWidth + 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: reduceMotion ? 4 : (ringGlowIsActive ? 9 : 4))
                    .opacity(reduceMotion ? 0.14 : (ringGlowIsActive ? 0.22 : 0.08))
                Text(meterPercentText(value))
                    .font(meterValueFont)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
            }
            .frame(width: meterSize, height: meterSize)
            Text(title)
                .font(meterTitleFont)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: meterColumnWidth)
    }

    private func normalizedMeterValue(_ value: Double?) -> Double {
        min(1, max(0, value ?? 0))
    }

    private func meterPercentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var meterSize: CGFloat {
        switch format {
        case .story:
            92
        case .square:
            52
        case .linkPreview:
            44
        }
    }

    private var meterColumnWidth: CGFloat {
        switch format {
        case .story:
            128
        case .square:
            74
        case .linkPreview:
            64
        }
    }

    private var meterSpacing: CGFloat {
        switch format {
        case .story:
            34
        case .square:
            18
        case .linkPreview:
            12
        }
    }

    private var meterLineWidth: CGFloat {
        switch format {
        case .story:
            10
        case .square, .linkPreview:
            6
        }
    }

    private var meterValueFont: Font {
        switch format {
        case .story:
            .title3.weight(.bold)
        case .square:
            .caption.weight(.bold)
        case .linkPreview:
            .caption2.weight(.bold)
        }
    }

    private var meterTitleFont: Font {
        switch format {
        case .story:
            .callout.weight(.semibold)
        case .square, .linkPreview:
            .caption2.weight(.semibold)
        }
    }

    private func localizedKey(_ key: String, arguments: CVarArg...) -> String {
        DJConnectLocalization.localized(key: key, language: language, arguments: arguments)
    }

    private static let liveMetricRingColors: [Color] = [
        Color(red: 0.30, green: 0.63, blue: 1.0),
        Color(red: 0.82, green: 0.28, blue: 1.0),
        Color(red: 0.23, green: 0.91, blue: 0.84),
        Color(red: 0.30, green: 0.63, blue: 1.0)
    ]
}
