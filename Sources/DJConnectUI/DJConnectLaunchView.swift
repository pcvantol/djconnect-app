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
            let iconSize = min(max(shortestSide * 0.22, 132), 240)
            let titleSize = min(max(shortestSide * 0.075, 44), 76)

            ZStack {
                Color(red: 0.09, green: 0.07, blue: 0.12)
                    .ignoresSafeArea()
                VStack(spacing: max(20, iconSize * 0.16)) {
                    DJConnectAppIconView()
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous))
                        .shadow(color: .black.opacity(0.24), radius: iconSize * 0.13, y: iconSize * 0.07)
                    Text("DJConnect")
                        .font(.system(size: titleSize, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -shortestSide * 0.04)
                .accessibilityElement(children: .combine)
            }
        }
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
