import DJConnectCore
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DJConnectVersionInfo {
    static var displayVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.2.14"
    }
}

public struct DJConnectLaunchContainer<Content: View>: View {
    @State private var showLaunch = true
    @State private var minimumLaunchTimeElapsed = false
    @State private var maximumLaunchTimeElapsed = false
    @State private var minimumLaunchTask: Task<Void, Never>?
    @State private var maximumLaunchTask: Task<Void, Never>?
    private let isBusy: Bool
    private let content: Content

    public init(isBusy: Bool = false, content: Content) {
        self.isBusy = isBusy
        self.content = content
    }

    public var body: some View {
        ZStack {
            content
            if showLaunch {
                DJConnectLaunchView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            showLaunchOverlay()
        }
        .onChange(of: isBusy) {
            updateLaunchVisibility()
        }
        .onDisappear {
            minimumLaunchTask?.cancel()
            maximumLaunchTask?.cancel()
        }
    }

    private func showLaunchOverlay() {
        minimumLaunchTask?.cancel()
        maximumLaunchTask?.cancel()
        minimumLaunchTimeElapsed = false
        maximumLaunchTimeElapsed = false
        showLaunch = true

        minimumLaunchTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            minimumLaunchTimeElapsed = true
            updateLaunchVisibility()
        }

        maximumLaunchTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }
            maximumLaunchTimeElapsed = true
            updateLaunchVisibility()
        }
    }

    private func updateLaunchVisibility() {
        guard showLaunch, minimumLaunchTimeElapsed, (!isBusy || maximumLaunchTimeElapsed) else {
            return
        }
        withAnimation(.easeOut(duration: 0.28)) {
            showLaunch = false
        }
    }
}

private struct DJConnectLaunchView: View {
    var body: some View {
        GeometryReader { proxy in
            let shortestSide = min(proxy.size.width, proxy.size.height)
            let heroSize = min(max(shortestSide * 0.30, 220), 360)
            let bannerWidth = min(max(proxy.size.width - 48, 300), max(340, heroSize * 1.55))

            ZStack {
                DJConnectLaunchCanvasBackground()
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        DJConnectLaunchBanner()
                            .frame(width: bannerWidth)
                    }
                    DJConnectLaunchHeroVisual(width: bannerWidth)
                        .frame(width: bannerWidth, height: bannerWidth * 0.72)
                        .accessibilityHidden(true)
                    Text("v\(DJConnectVersionInfo.displayVersion)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.white.opacity(0.86))
                        .accessibilityLabel("DJConnect laden")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -shortestSide * 0.04)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct DJConnectLaunchCanvasBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.09),
                    Color(red: 0.07, green: 0.04, blue: 0.15),
                    Color(red: 0.03, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.43, blue: 0.98).opacity(0.42),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 880
            )
            RadialGradient(
                colors: [
                    Color(red: 0.64, green: 0.12, blue: 0.92).opacity(0.34),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 820
            )
            LinearGradient(
                colors: [
                    .black.opacity(0.16),
                    .clear,
                    .black.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct DJConnectLaunchBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            DJConnectAppIconView()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
            VStack(alignment: .center, spacing: 7) {
                Text("DJConnect")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .layoutPriority(2)
                Text(DJConnectLocalization.localized(key: "launch.music.control.with.character"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .layoutPriority(1)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.12),
                    Color(red: 0.25, green: 0.08, blue: 0.42),
                    Color(red: 0.39, green: 0.12, blue: 0.62),
                    Color(red: 0.08, green: 0.10, blue: 0.23)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.34),
                            .clear,
                            .black.opacity(0.30)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blendMode(.multiply)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.multiply)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DJConnectLaunchHeroVisual: View {
    let width: CGFloat
    private let baseWidth: CGFloat = 280

    private var scale: CGFloat {
        width / baseWidth
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 72, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.20, green: 0.74, blue: 1.0).opacity(0.24),
                            Color(red: 0.56, green: 0.18, blue: 0.96).opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 190
                    )
                )
                .blur(radius: 20)
                .scaleEffect(x: 1.18, y: 0.82)

            DJConnectLaunchSignalRings()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.78, blue: 1.0).opacity(0.34),
                            Color(red: 0.54, green: 0.22, blue: 0.96).opacity(0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 250, height: 150)
                .offset(x: 44, y: -2)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.05, blue: 0.12),
                            Color(red: 0.13, green: 0.07, blue: 0.28),
                            Color(red: 0.06, green: 0.12, blue: 0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.18),
                                    Color(red: 0.18, green: 0.78, blue: 1.0).opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color(red: 0.18, green: 0.64, blue: 1.0).opacity(0.18), radius: 30, y: 16)
                .shadow(color: Color(red: 0.60, green: 0.16, blue: 0.90).opacity(0.18), radius: 24, y: 12)
                .frame(width: 280, height: 164)

            DJConnectLaunchRecord()
                .frame(width: 116, height: 116)
                .offset(x: -66, y: 6)

            DJConnectLaunchFeatureIcons()
                .frame(width: 120, height: 112)
                .offset(x: 64, y: 4)
        }
        .frame(width: baseWidth, height: baseWidth * 0.72)
        .scaleEffect(scale)
        .frame(width: width, height: width * 0.72)
    }
}

private struct DJConnectLaunchFeatureIcons: View {
    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.54, green: 0.22, blue: 0.98),
            Color(red: 0.20, green: 0.78, blue: 1.0),
            Color(red: 0.33, green: 0.96, blue: 0.72)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                icon("bubble.left.and.bubble.right")
                icon("waveform.path.ecg")
            }
            icon("point.3.connected.trianglepath.dotted")
        }
    }

    private func icon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 25, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(gradient)
            .frame(width: 48, height: 48)
            .background(.white.opacity(0.055), in: Circle())
            .overlay(
                Circle()
                    .stroke(gradient.opacity(0.70), lineWidth: 1.4)
            )
            .shadow(color: Color(red: 0.20, green: 0.78, blue: 1.0).opacity(0.22), radius: 12, y: 6)
    }
}

private struct DJConnectLaunchRecord: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.10, green: 0.14, blue: 0.28),
                            Color(red: 0.01, green: 0.02, blue: 0.06)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 76
                    )
                )
            ForEach(0..<4) { index in
                Circle()
                    .stroke(.white.opacity(index == 0 ? 0.18 : 0.10), lineWidth: 1)
                    .padding(CGFloat(index * 14 + 10))
            }
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.12, blue: 0.92),
                            Color(red: 0.16, green: 0.74, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 34)
            Circle()
                .fill(Color(red: 0.03, green: 0.04, blue: 0.11))
                .frame(width: 10, height: 10)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .stroke(Color(red: 0.36, green: 0.92, blue: 0.86), lineWidth: 3)
                .background(Circle().fill(Color(red: 0.05, green: 0.05, blue: 0.12)))
                .frame(width: 18, height: 18)
                .offset(x: -10, y: 12)
        }
    }
}

private struct DJConnectLaunchWaveform: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [CGPoint] = [
            CGPoint(x: 0.04, y: 0.55),
            CGPoint(x: 0.20, y: 0.55),
            CGPoint(x: 0.31, y: 0.28),
            CGPoint(x: 0.43, y: 0.82),
            CGPoint(x: 0.54, y: 0.18),
            CGPoint(x: 0.66, y: 0.60),
            CGPoint(x: 0.80, y: 0.55),
            CGPoint(x: 0.96, y: 0.55)
        ]
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        return path
    }
}

private struct DJConnectLaunchMixerLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let xs: [CGFloat] = [0.18, 0.50, 0.82]
        for (index, x) in xs.enumerated() {
            let y1 = CGFloat([0.18, 0.06, 0.26][index])
            let y2 = CGFloat([0.82, 0.70, 0.92][index])
            path.move(to: CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y1 * rect.height))
            path.addLine(to: CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y2 * rect.height))
        }
        return path
    }
}

private struct DJConnectLaunchSignalRings: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.minX + rect.width * 0.72, y: rect.midY)
        for index in 0..<2 {
            let inset = CGFloat(index) * 30
            let arcRect = CGRect(
                x: center.x - 52 - inset,
                y: center.y - 52 - inset,
                width: 104 + inset * 2,
                height: 104 + inset * 2
            )
            path.addArc(
                center: CGPoint(x: arcRect.midX, y: arcRect.midY),
                radius: arcRect.width / 2,
                startAngle: .degrees(-34),
                endAngle: .degrees(34),
                clockwise: false
            )
        }
        return path
    }
}

struct DJConnectAppIconView: View {
    var body: some View {
        #if os(iOS)
        if let image = UIImage(named: "LaunchIcon") ?? UIImage(named: "AppIcon") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            fallbackImage
        }
        #elseif os(macOS)
        if let image = NSImage(named: NSImage.applicationIconName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            fallbackImage
        }
        #else
        fallbackImage
        #endif
    }

    private var fallbackImage: some View {
        Image(systemName: "music.note")
            .font(.system(size: 48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.23, green: 0.18, blue: 0.42))
    }
}
