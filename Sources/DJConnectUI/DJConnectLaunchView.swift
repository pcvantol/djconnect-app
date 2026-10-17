import DJConnectCore
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DJConnectVersionInfo {
    static var displayVersion: String {
        DJConnectApplicationVersion.releaseVersion
    }
}

public struct DJConnectLaunchContainer<Content: View>: View {
    @State private var showLaunch = true
    @State private var mainControlsVisible = false
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
                .allowsHitTesting(!showLaunch)
                .accessibilityHidden(showLaunch)
            if showLaunch {
                DJConnectLaunchView()
                    .accessibilityIdentifier("launch-splash")
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        #if os(macOS)
        .toolbar(mainControlsVisible ? .visible : .hidden, for: .windowToolbar)
        #endif
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
        .djConnectGlassPreferences()
    }

    private var minimumLaunchDuration: Duration {
        #if DEBUG
        // Extend only the isolated UI probe so XCTest can observe the splash.
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           ProcessInfo.processInfo.environment["DJCONNECT_UITEST_HOLD_SPLASH"] == "1" {
            return .seconds(6)
        }
        #endif
        return .seconds(1.5)
    }

    private func showLaunchOverlay() {
        minimumLaunchTask?.cancel()
        maximumLaunchTask?.cancel()
        minimumLaunchTimeElapsed = false
        maximumLaunchTimeElapsed = false
        showLaunch = true
        mainControlsVisible = false

        minimumLaunchTask = Task { @MainActor in
            try? await Task.sleep(for: minimumLaunchDuration)
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
        withAnimation(.easeOut(duration: 0.28), completionCriteria: .removed) {
            showLaunch = false
        } completion: {
            mainControlsVisible = true
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
                compactLaunch(bannerWidth: bannerWidth, availableHeight: proxy.size.height)
            }
        }
    }

    private var launchStatus: some View {
        VStack(spacing: 16) {
            Text("v\(DJConnectVersionInfo.displayVersion)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            ProgressView()
                .controlSize(.regular)
                .tint(.white.opacity(0.86))
                .accessibilityLabel("DJConnect laden")
        }
    }

    private func compactLaunch(bannerWidth: CGFloat, availableHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                DJConnectLaunchBanner()
                    .frame(width: bannerWidth)
                VStack(spacing: 24) {
                    DJSessionWelcomeArtwork()
                        .frame(height: (bannerWidth - 36) * 0.72)
                        .accessibilityHidden(true)
                    launchStatus
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .djSessionFrostedSurface()
                .frame(width: bannerWidth)
                .accessibilityIdentifier("launch-content-card")
            }
            .frame(maxWidth: .infinity, minHeight: max(0, availableHeight - 48))
            .padding(.vertical, 24)
            .accessibilityElement(children: .combine)
        }
        .scrollIndicators(.hidden)
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

struct DJConnectLaunchBanner: View {
    var subtitle: String = DJConnectLocalization.localized(key: "brand.tagline")
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalContent
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        brandIcon
                        brandText.frame(minWidth: 220)
                    }
                    verticalContent
                }
            }
        }
        .padding(18)
        .djSessionFrostedSurface()
        .accessibilityElement(children: .combine)
    }

    private var verticalContent: some View {
        VStack(spacing: 14) {
            brandIcon
            brandText
        }
        .frame(maxWidth: .infinity)
    }

    private var brandIcon: some View {
        DJConnectGlassBrandIcon()
            .frame(width: 84, height: 84)
    }

    private var brandText: some View {
        VStack(alignment: .center, spacing: 7) {
            Text("DJConnect")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text(subtitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Keep the recognizable brand artwork inside one shared, beveled glass tile.
/// Launch, About and service sheets must not fall back to the bare app-icon image.
struct DJConnectGlassBrandIcon: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 23, style: .continuous)
        DJConnectAppIconView()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(6)
            .djSessionFrostedSurface(cornerRadius: 23)
            .overlay {
                shape.fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.24), location: 0),
                    .init(color: .white.opacity(0.04), location: 0.42),
                    .init(color: .clear, location: 0.52)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.strokeBorder(DJConnectCardAppearance.searchFocusGradient,
                                   lineWidth: DJConnectCardAppearance.borderWidth)
                    .blur(radius: 2).opacity(0.40)
                shape.strokeBorder(DJConnectCardAppearance.searchFocusGradient,
                                   lineWidth: DJConnectCardAppearance.borderWidth)
            }
            .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
            .accessibilityHidden(true)
    }
}

private struct DJConnectAppIconView: View {
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
        if let image = NSImage(named: "LaunchIcon") ?? NSImage(named: NSImage.applicationIconName) {
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
