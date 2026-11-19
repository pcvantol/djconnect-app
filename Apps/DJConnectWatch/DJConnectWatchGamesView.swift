import DJConnectCore
import SwiftUI
import WatchKit

struct DJConnectWatchGamesView: View {
    @EnvironmentObject private var model: DJConnectWatchModel
    var body: some View {
        DJConnectWatchList {
            ForEach(DJConnectWatchArcadeGame.allCases) { game in
                NavigationLink {
                    DJConnectWatchGameView(game: game, language: model.language)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: game.symbol)
                            .foregroundStyle(DJConnectSessionMoodTheme(sessionMood: game.mood).watchIconGradient)
                            .frame(width: 24)
                        Text(game.title)
                    }
                }
                .accessibilityIdentifier("watch-game-" + game.rawValue)
            }
        }
        .navigationTitle(DJConnectLocalization.localized(key: "ui.games", language: model.language))
        .watchStandardBackground()
    }
}

struct DJConnectWatchGameView: View {
    let game: DJConnectWatchArcadeGame
    let language: String
    @State private var state: DJConnectWatchArcadeState
    @State private var crown = 0.0
    @FocusState private var focused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage private var highScore: Int

    init(game: DJConnectWatchArcadeGame, language: String) {
        self.game = game; self.language = language
        var initialState = DJConnectWatchArcadeState(game: game)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--screenshot-game-playing") { initialState.restart() }
        #endif
        _state = State(initialValue: initialState)
        _highScore = AppStorage(wrappedValue: 0, "djconnect.app.game.\(game.rawValue).high")
    }
    private var theme: DJConnectSessionMoodTheme { .init(sessionMood: game.mood) }
    private var tint: Color { theme.watchColors[0] }
    private var running: Bool { state.playing && scenePhase == .active }
    private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key, language: language) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label("\(state.score)", systemImage: game.symbol)
                    .foregroundStyle(tint)
                Spacer(minLength: 4)
                Text("\(text("ui.high")) \(max(highScore, state.score))").foregroundStyle(.secondary)
            }
            .font(.caption2.weight(.semibold)).monospacedDigit()
            GeometryReader { geometry in
                Canvas { context, size in draw(in: &context, size: size) }
                    .background(.black.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.24), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { event in
                        let point = CGPoint(x: event.location.x / max(1, geometry.size.width),
                                            y: event.location.y / max(1, geometry.size.height))
                        state.tap(at: point)
                        focused = true
                    })
                    .overlay {
                        if !state.playing {
                            Button { state.togglePlaying(); focused = true } label: {
                                Label(state.started && !state.gameOver ? text("watch.game.resume") : text("ui.tap.to.play"),
                                      systemImage: "play.fill")
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .padding(10)
                                    .foregroundStyle(.white)
                                    .background(tint.opacity(0.65), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(game.title)
                    .accessibilityValue("\(text("ui.score")) \(state.score)")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: state.moveCrown(by: game == .pacman ? 1 : 0.08)
                        case .decrement: state.moveCrown(by: game == .pacman ? -1 : -0.08)
                        @unknown default: break
                        }
                    }
                    .accessibilityAction {
                        state.tap(at: CGPoint(x: 0.5, y: 0.5))
                    }
            }
            if !state.playing {
                Text(text("watch.game.controls." + game.rawValue))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            Button { state.togglePlaying(); focused = true } label: {
                Image(systemName: state.playing ? "pause.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text(state.playing ? "ui.pause" : (state.started && !state.gameOver ? "watch.game.resume" : "watch.play")))
            .accessibilityIdentifier("watch-game-pause-resume")
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, watchListItemPadding)
        .padding(.top, watchListItemPadding)
        .padding(.bottom, watchRowInset)
        .ignoresSafeArea(.container, edges: .bottom)
        .background {
            LinearGradient(colors: theme.watchColors.map { $0.opacity(0.22) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
        .navigationTitle(game.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Button { highScore = max(highScore, state.score); state.restart(); focused = true } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel(text("watch.game.restart"))
                }.buttonStyle(.plain)
            }
        }
        .focusable(scenePhase == .active)
        .focusEffectDisabled()
        .focused($focused)
        .digitalCrownRotation(Binding(get: { crown }, set: { value in
            let delta = value - crown; crown = value
            state.moveCrown(by: game == .pacman ? delta : delta * 0.7)
        }), from: -1_000, through: 1_000, by: game == .pacman ? 0.12 : 0.01,
        sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: game == .pacman)
        .task { focused = true }
        .task(id: running) {
            guard running else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                guard !Task.isCancelled, running else { return }
                state.advance(by: 1.0 / 30)
            }
        }
        .onChange(of: state.soundSequence) { _, _ in
            guard scenePhase == .active else { return }
            DJConnectArcadeAudio.shared.play(state.sound, game: game)
        }
        .onChange(of: state.score) { _, score in
            if score > 0 { WKInterfaceDevice.current().play(.click) }
        }
        .onChange(of: state.playing) { _, playing in
            if !playing {
                highScore = max(highScore, state.score)
                if !state.gameOver { DJConnectArcadeAudio.shared.stop() }
            }
        }
        .onChange(of: state.gameOver) { _, over in
            if over { WKInterfaceDevice.current().play(.failure) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { state.pause(); focused = false; DJConnectArcadeAudio.shared.stop() }
            else { focused = true }
        }
        .onDisappear { highScore = max(highScore, state.score); state.pause(); focused = false; DJConnectArcadeAudio.shared.stop() }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        func point(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * size.width, y: point.y * size.height) }
        func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CGRect {
            CGRect(x: x * size.width, y: y * size.height, width: width * size.width, height: height * size.height)
        }
        // Spread particles over the entire responsive board, never a fixed-size center strip.
        if game != .pacman {
            for index in 0..<26 {
                let shift = reduceMotion ? 0 : state.elapsed * (game == .asteroids ? 0.045 : 0.08)
                let x = (Double(index * 47 % 101) / 101 + (game == .fly ? -shift : 0)).truncatingRemainder(dividingBy: 1)
                let y = (Double(index * 31 % 97) / 97 + (game == .asteroids ? shift : 0)).truncatingRemainder(dividingBy: 1)
                context.fill(Path(ellipseIn: rect(x < 0 ? x + 1 : x, y, 0.008, 0.008)), with: .color(.white.opacity(0.3)))
            }
        }
        switch game {
        case .pong:
            var center = Path(); center.move(to: point(CGPoint(x: 0.5, y: 0.05)))
            center.addLine(to: point(CGPoint(x: 0.5, y: 0.95)))
            context.stroke(center, with: .color(.white.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            context.fill(Path(roundedRect: rect(0.035, state.control - 0.12, 0.035, 0.24), cornerRadius: 3), with: .color(.purple))
            let ballCenter = point(state.ball), radius = min(size.width, size.height) * 0.025
            context.fill(Path(ellipseIn: CGRect(x: ballCenter.x - radius, y: ballCenter.y - radius, width: radius * 2, height: radius * 2)), with: .color(tint))
        case .asteroids:
            let ship = point(CGPoint(x: state.control, y: 0.91))
            var hull = Path()
            hull.move(to: CGPoint(x: ship.x, y: ship.y - 12))
            hull.addLine(to: CGPoint(x: ship.x + 12, y: ship.y + 8))
            hull.addLine(to: CGPoint(x: ship.x, y: ship.y + 4))
            hull.addLine(to: CGPoint(x: ship.x - 12, y: ship.y + 8))
            hull.closeSubpath()
            context.fill(hull, with: .color(tint))
            context.draw(Text(Image(systemName: "burst.fill")).font(.system(size: 24)).foregroundStyle(.orange), at: point(state.obstacle))
            if let shot = state.shot {
                context.fill(Path(roundedRect: rect(shot.x - 0.01, shot.y, 0.02, 0.04), cornerRadius: 1), with: .color(.white))
            }
        case .fly:
            context.draw(Text(Image(systemName: "airplane")).font(.system(size: 24)).foregroundStyle(.yellow),
                         at: point(CGPoint(x: 0.18, y: state.control)))
            context.fill(Path(roundedRect: rect(state.obstacle.x - 0.045, state.obstacle.y - 0.1, 0.09, 0.2), cornerRadius: 3), with: .color(.cyan))
            if let shot = state.shot {
                context.fill(Path(roundedRect: rect(shot.x, shot.y - 0.006, 0.045, 0.012), cornerRadius: 1), with: .color(.yellow))
            }
        case .pacman:
            func cell(_ index: Int) -> CGPoint {
                point(CGPoint(x: 0.08 + Double(index % 7) * 0.14, y: 0.08 + Double(index / 7) * 0.14))
            }
            for pellet in state.pellets {
                let p = cell(pellet), radius: CGFloat = [0, 6, 42, 48].contains(pellet) ? 3.5 : 1.5
                context.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)), with: .color(.white.opacity(0.9)))
            }
            let p = cell(state.player), radius = min(size.width, size.height) * 0.045
            let angle = Double(state.direction - 1) * Double.pi / 2
            var mouth = Path(); mouth.move(to: p)
            mouth.addArc(center: p, radius: radius, startAngle: .radians(angle + 0.45), endAngle: .radians(angle + 2 * .pi - 0.45), clockwise: false)
            mouth.closeSubpath()
            context.fill(mouth, with: .color(.pink))
            let g = cell(state.ghost)
            let ghostColor: Color = state.powerRemaining > 0 ? .white : .cyan
            var ghost = Path(roundedRect: CGRect(x: g.x - radius, y: g.y - radius, width: radius * 2, height: radius * 2), cornerRadius: radius)
            ghost.addRect(CGRect(x: g.x - radius, y: g.y, width: radius * 2, height: radius))
            context.fill(ghost, with: .color(ghostColor))
            for x in [-0.4, 0.4] {
                context.fill(Path(ellipseIn: CGRect(x: g.x + x * radius - 1, y: g.y - radius * 0.3, width: 2, height: 3)), with: .color(.black))
            }
        }
    }
}
