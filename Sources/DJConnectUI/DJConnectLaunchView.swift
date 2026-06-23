import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private func launchLocalized(english: String, dutch: String) -> String {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("nl") == true ? dutch : english
}

enum DJConnectVersionInfo {
    static var displayVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.1.46"
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
            try? await Task.sleep(for: .milliseconds(950))
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
            let bannerWidth = min(max(proxy.size.width - 48, 300), 760)

            ZStack {
                DJConnectLaunchCanvasBackground()
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        DJConnectLaunchBanner()
                            .frame(width: bannerWidth)
                        Text("v\(DJConnectVersionInfo.displayVersion)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
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
                Text(launchLocalized(english: "Music control with character.", dutch: "Muziekbediening met karakter."))
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
