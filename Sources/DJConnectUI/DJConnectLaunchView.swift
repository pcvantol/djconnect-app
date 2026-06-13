import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct DJConnectLaunchContainer<Content: View>: View {
    @State private var showLaunch = true
    private let content: Content

    public init(content: Content) {
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
        .task {
            try? await Task.sleep(for: .milliseconds(950))
            withAnimation(.easeOut(duration: 0.28)) {
                showLaunch = false
            }
        }
    }
}

private struct DJConnectLaunchView: View {
    var body: some View {
        GeometryReader { proxy in
            let shortestSide = min(proxy.size.width, proxy.size.height)
            let bannerWidth = min(max(proxy.size.width - 48, 300), 760)

            ZStack {
                Color(red: 0.09, green: 0.07, blue: 0.12)
                    .ignoresSafeArea()
                VStack(spacing: 22) {
                    DJConnectLaunchBanner()
                        .frame(width: bannerWidth)
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
                Text("Muziekbediening met karakter.")
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.09, green: 0.07, blue: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
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
