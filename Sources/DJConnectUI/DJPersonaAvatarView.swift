import SwiftUI
import Foundation
import Combine
import DJConnectCore

/// Repository-owned Session Pulse geometry shared by the rich identity and menu mark.
/// No state, timer, audio inference or network operation belongs in this shape.
struct DJPersonaMark: Shape {
    var includesWaveform = true
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        var mark = Path()
        var ring = Path()
        ring.addEllipse(in: CGRect(x: 22, y: 25, width: 56, height: 56))
        mark.addPath(ring.strokedPath(StrokeStyle(lineWidth: 4.5)))
        var headphones = Path()
        headphones.move(to: CGPoint(x: 13, y: 57))
        headphones.addCurve(to: CGPoint(x: 87, y: 57),
                            control1: CGPoint(x: 8, y: -4), control2: CGPoint(x: 92, y: -4))
        mark.addPath(headphones.strokedPath(StrokeStyle(lineWidth: 5, lineCap: .round)))
        for x: CGFloat in [7, 82] {
            mark.addRoundedRect(in: CGRect(x: x, y: 43, width: 11, height: 27), cornerSize: CGSize(width: 5, height: 5))
        }
        let heights: [CGFloat] = includesWaveform ? [12, 24, 34, 24, 12] : []
        for (index, height) in heights.enumerated() {
            mark.addRoundedRect(in: CGRect(x: 33 + CGFloat(index) * 7.5, y: 53 - height / 2, width: 4, height: height),
                                cornerSize: CGSize(width: 2, height: 2))
        }
        return mark.applying(CGAffineTransform(scaleX: side / 100, y: side / 100)
            .concatenating(CGAffineTransform(translationX: origin.x, y: origin.y)))
    }
}

/// Local presentation only, never a producer activity enum or passive wire field.
enum DJPersonaActivity: String, CaseIterable {
    case resting, listening, preparing, announcement, speaking, text
    var symbol: String? {
        switch self {
        case .resting: nil
        case .listening, .speaking: "mic.fill"
        case .preparing: "ellipsis"
        case .announcement: "music.note"
        case .text: "bubble.left.fill"
        }
    }
    static func isObservedAnnouncement(_ moment: DJConnectMoment) -> Bool {
        moment.type == "track" && moment.knowledgeIntent?["type"] == "track_context" &&
        moment.generationMetadata?["context_source"] == "observed_playback" &&
        moment.sourceReferences == ["spotify_playback_status"]
    }
    struct Evidence {
        var authorized = false
        var capturing = false
        var pending = false
        var announcementID: String?
        var speaking = false
        var spokenMomentID: String?
        var explicitReply = false
    }
    static func resolve(_ evidence: Evidence) -> Self {
        guard evidence.authorized else { return .resting }
        if evidence.capturing { return .listening }
        if evidence.pending { return .preparing }
        // A different spoken turn or newly accepted reply outranks an older
        // current-card announcement. Only the same announcement keeps its note.
        if evidence.speaking {
            if let id = evidence.announcementID, evidence.spokenMomentID == id { return .announcement }
            return .speaking
        }
        if evidence.explicitReply { return .text }
        if evidence.announcementID != nil { return .announcement }
        return .resting
    }
}

/// The shared identity defaults to rest on passive surfaces; only the foreground
/// owner supplies observed activity. Mood and activity remain independent.
struct DJPersonaAvatarView: View {
    let confirmedMood: String?
    let language: String
    var activity: DJPersonaActivity? = nil
    var speechIsPlaying = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var resourcesPermitMotion = Self.resourcesPermitMotionNow()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private static func resourcesPermitMotionNow() -> Bool {
        !ProcessInfo.processInfo.isLowPowerModeEnabled &&
            [.nominal, .fair].contains(ProcessInfo.processInfo.thermalState)
    }

    private var theme: DJConnectSessionMoodTheme {
        switch confirmedMood {
        case "chill": .chill
        case "groove": .groove
        case "energy": .energy
        case "party": .party
        default: .brand
        }
    }

    private var colors: [Color] {
        theme.colorValues.map { value in
            Color(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
        }
    }

    var body: some View {
        DJPersonaGraphic(colors: colors, highContrast: contrast == .increased, opaque: reduceTransparency,
                         activity: activity ?? .resting, speechIsPlaying: speechIsPlaying,
                         animatesActivity: scenePhase == .active && !reduceMotion && resourcesPermitMotion)
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
                .merge(with: NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification))
                .receive(on: RunLoop.main)) { _ in
                resourcesPermitMotion = Self.resourcesPermitMotionNow()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { resourcesPermitMotion = Self.resourcesPermitMotionNow() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(DJConnectLocalization.localized(key: "ui.session.avatar.label", language: language))
            .accessibilityValue(activity.map { DJConnectLocalization.localized(key: "ui.session.avatar.activity." + $0.rawValue, language: language) } ?? "")
            .accessibilityIdentifier("session-dj-avatar")
    }
}

/// Rendering policy is explicit; actual OS settings are read by the identity view.
struct DJPersonaGraphic: View {
    let colors: [Color]
    let highContrast: Bool
    let opaque: Bool
    var activity: DJPersonaActivity = .resting
    var speechIsPlaying = false
    var animatesActivity = false

    var body: some View {
        let gradient = LinearGradient(colors: highContrast ? [.white] : colors,
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                // A dark, feathered backing separates the entire headset from
                // the mood-colored card, including its outer band and earcups.
                // It belongs to this fixed canvas and never moves with activity.
                if !opaque {
                    Circle().fill(RadialGradient(stops: [
                        .init(color: .black.opacity(0.76), location: 0),
                        .init(color: .black.opacity(0.56), location: 0.60),
                        .init(color: .clear, location: 1)
                    ], center: .center, startRadius: 0, endRadius: side * 0.52))
                }
                Circle().fill(Color.black.opacity(opaque ? 1 : 0.82)).padding(side * 0.15)
                DJPersonaMark(includesWaveform: activity == .resting)
                    .fill(gradient)
                    .shadow(color: .black.opacity(0.85), radius: side * 0.035, y: side * 0.015)
                if animatesActivity && (activity == .listening || speechIsPlaying) {
                    // Inward capture and outward output are deliberately distinct.
                    // This is a lifecycle pulse, never a fabricated audio envelope.
                    Circle().stroke(gradient, lineWidth: 2)
                        .frame(width: side * 0.48, height: side * 0.48)
                        .offset(y: side * 0.03)
                        .keyframeAnimator(initialValue: CGFloat(0), repeating: true) { halo, phase in
                            halo.scaleEffect(activity == .listening ? 1 - phase * 0.5 : 0.5 + phase * 0.5)
                                .opacity(Double(1 - phase) * 0.5)
                        } keyframes: { _ in
                            LinearKeyframe(1, duration: 1.2)
                        }
                        .accessibilityHidden(true)
                }
                if let symbol = activity.symbol {
                    Image(systemName: symbol)
                        .resizable().scaledToFit()
                        .frame(width: side * 0.30, height: side * 0.30)
                        .foregroundStyle(gradient)
                        // Symbol replacement can slide the glyph outside its bounds on macOS.
                        // Activity changes keep a stable center; only the halo pulses.
                        .contentTransition(.identity)
                        .offset(y: side * 0.03)
                        .symbolEffect(.pulse, options: .repeating,
                                      isActive: animatesActivity && activity == .preparing)
                        .accessibilityHidden(true)
                }
            }
            // Fixed canvas isolates symbol/keyframe layout from the surrounding card.
            .frame(width: side, height: side)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Concrete menu content avoids opaque-view isolation at native ImageRenderer bridges.
struct DJPersonaMenuSymbol: View {
    var body: some View { DJPersonaMark().fill(.white).frame(width: 26, height: 26) }
}
