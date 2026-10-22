import Foundation
@preconcurrency import Metal
import simd

/// One full-screen triangle, no CPU mesh generation, no image/video input and
/// no frame history. Renderer resources live only as long as the visible view.
final class VibeScapeMetalEngine {
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let permits = DispatchSemaphore(value: 3)
    private struct Uniforms {
        var resolutionTime: SIMD4<Float>
        var composition: SIMD4<Float>
        var paletteMotion: SIMD4<Float>
        var shape: SIMD4<Float>
        var secondary: SIMD4<Float>
        var accent: SIMD4<Float>
        var touch0: SIMD4<Float>
        var touch1: SIMD4<Float>
        var touch2: SIMD4<Float>
        var touch3: SIMD4<Float>
    }
    init(device: MTLDevice, library: MTLLibrary) throws {
        guard let queue = device.makeCommandQueue() else { throw Failure.unavailable }
        self.queue = queue
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vibeScapeVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "vibeScapeFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }
    enum Failure: Error { case unavailable }
    func encode(texture: MTLTexture, scene: VibeScapeScene, clock: Float,
                dynamics: Float, reducedQuality: Bool, touches: [VibeScapeTouch] = [],
                interactionUptime: TimeInterval = 0, reduceMotion: Bool = false) -> MTLCommandBuffer? {
        guard permits.wait(timeout: .now()) == .success else { return nil }
        guard let command = queue.makeCommandBuffer() else { permits.signal(); return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { permits.signal(); return nil }
        var impulses = [SIMD4<Float>](repeating: .zero, count: 4)
        for (index, touch) in touches.suffix(4).enumerated() {
            let elapsed = interactionUptime-touch.startedAt
            guard elapsed.isFinite, elapsed >= 0, elapsed < 2.6,
                  touch.strength.isFinite, (0.5...2.5).contains(touch.strength) else { continue }
            impulses[index] = SIMD4(touch.position.x, touch.position.y, reduceMotion ? 0.14 : Float(elapsed), touch.strength)
        }
        var uniforms = Uniforms(resolutionTime: SIMD4(Float(texture.width),Float(texture.height),clock,reducedQuality ? 0 : 1),
                                composition: scene.composition, paletteMotion: SIMD4(scene.palette,scene.motion),
                                shape: SIMD4(scene.depth,scene.roughness,min(0.95,scene.deformation*VibeScapeDynamics.deformation(dynamics)),dynamics),
                                secondary: SIMD4(scene.secondaryPalette, 0), accent: SIMD4(scene.accentPalette, 0),
                                touch0: impulses[0], touch1: impulses[1], touch2: impulses[2], touch3: impulses[3])
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.addCompletedHandler { [permits] _ in permits.signal() }
        return command
    }
}
