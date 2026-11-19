import SwiftUI
@preconcurrency import MetalKit

@MainActor fileprivate final class VibeScapeViewRenderer: NSObject, MTKViewDelegate {
    private let engine: VibeScapeMetalEngine
    private let visit: VisualDirectorVisit
    private var animation = VibeScapeAnimationState()
    private var quality = VibeScapeQualityBudget()
    var reduceMotion = false
    var isActive = true { didSet { if !isActive { animation.pause() } } }
    private let frames: VibeScapeFrameFence
    private let unavailable: @MainActor () -> Void

    init(device: MTLDevice, visit: VisualDirectorVisit, unavailable: @escaping @MainActor () -> Void) throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: VibeScapeViewRenderer.self)
        #endif
        let library = try device.makeDefaultLibrary(bundle: bundle)
        engine = try VibeScapeMetalEngine(device: device, library: library)
        self.visit = visit
        frames = VibeScapeFrameFence(visit: visit)
        self.unavailable = unavailable
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    private var systemLimited: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState == .serious
            || ProcessInfo.processInfo.thermalState == .critical
    }
    func configureDrawable(in view: MTKView) {
        let limited = systemLimited || quality.prefersReducedQuality
        view.preferredFramesPerSecond = limited ? 30 : 60
        #if os(iOS)
        let scale: CGFloat = 1.25
        #else
        let scale: CGFloat = 1.5
        #endif
        let width = max(1, view.bounds.width * scale), height = max(1, view.bounds.height * scale)
        guard width.isFinite, height.isFinite else { return }
        let cap: CGFloat = limited ? 800_000 : 1_600_000
        let adjustment = min(1, sqrt(cap / (width * height)))
        let size = CGSize(width: max(1, floor(width * adjustment)), height: max(1, floor(height * adjustment)))
        view.autoResizeDrawable = false
        if view.drawableSize != size { view.drawableSize = size }
    }
    func draw(in view: MTKView) {
        guard isActive, visit.isCurrent, let target = visit.scene, let ticket = visit.ticket else {
            animation.pause(); view.isPaused = true; return
        }
        configureDrawable(in: view)
        guard let drawable = view.currentDrawable else { return }
        let time = ProcessInfo.processInfo.systemUptime
        let frame = animation.update(target: target, dynamics: visit.dynamics, at: time, reduceMotion: reduceMotion)
        let limited = systemLimited || quality.prefersReducedQuality
        guard let command = engine.encode(texture: drawable.texture, frame: frame, reducedQuality: limited,
            touches: visit.touches, interactionUptime: time, reduceMotion: reduceMotion) else { return }
        // A crossfade is a real render of the currently visible mixture. ACK
        // only the final accepted target after phase/geometry/control settling.
        let reservation = frame.settled ? frames.begin(ticket) : nil
        command.addCompletedHandler { [weak self, weak view] completed in
            let success = completed.status == .completed
            let gpuTime = (completed.gpuEndTime - completed.gpuStartTime) * 1000
            Task { @MainActor in
                guard let self else { return }
                if self.isActive, self.visit.isCurrent { self.quality.observe(milliseconds: gpuTime) }
                if let reservation { _ = self.frames.complete(reservation, succeeded: success && self.isActive) }
                if !success, self.isActive, self.visit.isCurrent, self.visit.ticket == ticket {
                    view?.isPaused = true; self.unavailable()
                }
            }
        }
        command.present(drawable)
        command.commit()
        if reduceMotion || target.family == .neutral { view.isPaused = true }
    }

}

struct VibeScapeMetalView {
    let visit: VisualDirectorVisit
    let reduceMotion: Bool
    var isActive = true
    let unavailable: @MainActor () -> Void
    @MainActor final class Coordinator {
        fileprivate var renderer: VibeScapeViewRenderer?
    }
    @MainActor func makeCoordinator() -> Coordinator { Coordinator() }
    @MainActor private func makeView(_ coordinator: Coordinator) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        guard let device = view.device, let renderer = try? VibeScapeViewRenderer(device: device, visit: visit, unavailable: unavailable) else {
            Task { @MainActor in unavailable() }
            view.isPaused = true; return view
        }
        coordinator.renderer = renderer
        renderer.reduceMotion = reduceMotion
        renderer.isActive = isActive
        view.delegate = renderer
        view.preferredFramesPerSecond = 60
        view.isPaused = !isActive
        return view
    }
    @MainActor private func update(_ view: MTKView, coordinator: Coordinator) {
        coordinator.renderer?.reduceMotion = reduceMotion
        coordinator.renderer?.isActive = isActive
        view.isPaused = !isActive
        coordinator.renderer?.configureDrawable(in: view)
        if reduceMotion && isActive { view.draw() }
    }
}

#if os(iOS)
extension VibeScapeMetalView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView { makeView(context.coordinator) }
    func updateUIView(_ view: MTKView, context: Context) { update(view,coordinator: context.coordinator) }
    static func dismantleUIView(_ view: MTKView, coordinator: Coordinator) {
        coordinator.renderer?.isActive = false
        view.isPaused = true; view.delegate = nil; coordinator.renderer = nil
    }
}
#elseif os(macOS)
extension VibeScapeMetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView { makeView(context.coordinator) }
    func updateNSView(_ view: MTKView, context: Context) { update(view,coordinator: context.coordinator) }
    static func dismantleNSView(_ view: MTKView, coordinator: Coordinator) {
        coordinator.renderer?.isActive = false
        view.isPaused = true; view.delegate = nil; coordinator.renderer = nil
    }
}
#endif
