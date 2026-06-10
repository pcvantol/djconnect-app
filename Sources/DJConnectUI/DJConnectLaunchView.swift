import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct DJConnectLaunchContainer<Content: View>: View {
    @State private var showLaunch = true
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
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
        ZStack {
            Color(red: 0.09, green: 0.07, blue: 0.12)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                DJConnectAppIconView()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
                Text("DJConnect")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct DJConnectAppIconView: View {
    var body: some View {
        #if os(iOS)
        if let image = UIImage(named: "AppIcon") {
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
