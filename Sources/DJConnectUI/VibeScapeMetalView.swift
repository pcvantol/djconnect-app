import SwiftUI
@preconcurrency import MetalKit

@MainActor fileprivate final class VibeScapeViewRenderer: NSObject, MTKViewDelegate {
    private let engine: VibeScapeMetalEngine
    private let visit: VisualDirectorVisit
    private var displayed: VibeScapeScene?
    private var lastFrame: TimeInterval?
    private var visualClock: Float = 0
    private var displayedDynamics: Float = 0.5
    var reduceMotion = false
    private var acknowledged: VibeScapeRenderTicket?

    init(device: MTLDevice, visit: VisualDirectorVisit) throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: VibeScapeViewRenderer.self)
        #endif
        let library = try device.makeDefaultLibrary(bundle: bundle)
        engine = try VibeScapeMetalEngine(device: device, library: library)
        self.visit = visit
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard visit.isCurrent, let target = visit.scene, let ticket = visit.ticket,
              let drawable = view.currentDrawable else { view.isPaused = true; return }
        let time = ProcessInfo.processInfo.systemUptime
        let delta = min(1.0/15.0,max(0,time-(lastFrame ?? time)))
        lastFrame = time
        let alpha: Float = reduceMotion ? 1 : Float(1-exp(-delta/1.8))
        displayedDynamics += (visit.dynamics-displayedDynamics)*alpha
        if var current = displayed {
            current.composition = simd_mix(current.composition,target.composition,SIMD4(repeating:alpha))
            current.palette = simd_mix(current.palette,target.palette,SIMD3(repeating:alpha))
            current.motion += (target.motion-current.motion)*alpha
            current.depth += (target.depth-current.depth)*alpha
            current.roughness += (target.roughness-current.roughness)*alpha
            current.deformation += (target.deformation-current.deformation)*alpha
            displayed = current
        } else { displayed = target }
        if !reduceMotion {
            visualClock += Float(delta) * (displayed?.motion ?? target.motion) * (0.35 + displayedDynamics * 1.3)
        }
        let limited = ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
        view.preferredFramesPerSecond = limited ? 30 : 60
        guard let scene = displayed,
              let command = engine.encode(texture: drawable.texture, scene: scene, clock: visualClock,
                                          dynamics: displayedDynamics, reducedQuality: limited) else { return }
        // Acknowledge only after interpolation has converged and GPU completed.
        let settled = simd_distance(scene.composition,target.composition) < 0.01 && simd_distance(scene.palette,target.palette) < 0.01 && abs(scene.depth-target.depth) < 0.01 && abs(scene.deformation-target.deformation) < 0.01 && abs(scene.roughness-target.roughness) < 0.01 && abs(scene.motion-target.motion) < 0.01 && abs(displayedDynamics-visit.dynamics) < 0.01
        if settled && acknowledged != ticket {
            acknowledged = ticket
            command.addCompletedHandler { [weak visit] completed in
                let success = completed.status == .completed
                Task { @MainActor in
                    if success { _ = visit?.rendererCompleted(ticket) }
                }
            }
        }
        command.present(drawable)
        command.commit()
        if reduceMotion { view.isPaused = true }
    }
}

struct VibeScapeMetalView {
    let visit: VisualDirectorVisit
    let reduceMotion: Bool
    let unavailable: @MainActor () -> Void
    @MainActor final class Coordinator {
        fileprivate var renderer: VibeScapeViewRenderer?
    }
    @MainActor func makeCoordinator() -> Coordinator { Coordinator() }
    @MainActor private func makeView(_ coordinator: Coordinator) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        guard let device = view.device, let renderer = try? VibeScapeViewRenderer(device: device, visit: visit) else {
            Task { @MainActor in unavailable() }
            view.isPaused = true; return view
        }
        coordinator.renderer = renderer
        renderer.reduceMotion = reduceMotion
        view.delegate = renderer
        view.preferredFramesPerSecond = 60
        return view
    }
    @MainActor private func update(_ view: MTKView, coordinator: Coordinator) {
        coordinator.renderer?.reduceMotion = reduceMotion
        view.isPaused = false
        // Cap drawable pixels to protect mobile GPU budget at high DPI.
        #if os(iOS)
        let scale: CGFloat = 1.25
        #else
        let scale: CGFloat = 1.5
        #endif
        view.autoResizeDrawable = false
        view.drawableSize = CGSize(width: max(1,view.bounds.width*scale),height: max(1,view.bounds.height*scale))
        if reduceMotion { view.draw() }
    }
}

#if os(iOS)
extension VibeScapeMetalView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView { makeView(context.coordinator) }
    func updateUIView(_ view: MTKView, context: Context) { update(view,coordinator: context.coordinator) }
    static func dismantleUIView(_ view: MTKView, coordinator: Coordinator) {
        view.isPaused = true; view.delegate = nil; coordinator.renderer = nil
    }
}
#elseif os(macOS)
extension VibeScapeMetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView { makeView(context.coordinator) }
    func updateNSView(_ view: MTKView, context: Context) { update(view,coordinator: context.coordinator) }
    static func dismantleNSView(_ view: MTKView, coordinator: Coordinator) {
        view.isPaused = true; view.delegate = nil; coordinator.renderer = nil
    }
}
#endif
