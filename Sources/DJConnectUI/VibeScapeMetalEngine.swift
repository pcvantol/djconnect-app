import Foundation
@preconcurrency import Metal
import simd

/// One shared pass and two cached pipelines: procedural solid fields and bounded
/// filament points. No CPU meshes, image/video inputs, frame cache or compilation
/// while dragging/changing character. Resources belong only to the visible view.
final class VibeScapeMetalEngine {
    private let queue: MTLCommandQueue
    private let solidPipeline: MTLRenderPipelineState
    private let bloomPipeline: MTLRenderPipelineState
    private let permits = DispatchSemaphore(value: 3)
    private struct SceneUniforms {
        var composition: SIMD4<Float>
        var paletteMotion: SIMD4<Float>
        var shape: SIMD4<Float>
        var secondary: SIMD4<Float>
        var accent: SIMD4<Float>
        var style: SIMD4<Float>
        init(_ scene: VibeScapeScene, dynamics: Float, family: VibeScapeFamily) {
            let curve = VibeScapeDynamics.sample(dynamics, family: family)
            composition = scene.composition
            paletteMotion = SIMD4(scene.palette, scene.motion)
            shape = SIMD4(scene.depth, scene.roughness, min(0.95, scene.deformation * curve.excursion), dynamics)
            secondary = SIMD4(scene.secondaryPalette, 0); accent = SIMD4(scene.accentPalette, 0)
            style = SIMD4(curve.evolution, curve.parallax, curve.complexity, curve.excursion)
        }
    }
    private struct Uniforms {
        var resolutionTime: SIMD4<Float>
        var weights: SIMD4<Float>
        var phases: SIMD4<Float>
        var neutral: SIMD4<Float>
        var home: SceneUniforms
        var radio: SceneUniforms
        var club: SceneUniforms
        var festival: SceneUniforms
        var touch0 = SIMD4<Float>.zero
        var touch1 = SIMD4<Float>.zero
        var touch2 = SIMD4<Float>.zero
        var touch3 = SIMD4<Float>.zero
    }
    init(device: MTLDevice, library: MTLLibrary) throws {
        guard let queue = device.makeCommandQueue() else { throw Failure.unavailable }
        self.queue = queue
        let solid = MTLRenderPipelineDescriptor()
        solid.vertexFunction = library.makeFunction(name: "vibeScapeVertex")
        solid.fragmentFunction = library.makeFunction(name: "vibeScapeFragment")
        solid.colorAttachments[0].pixelFormat = .bgra8Unorm
        solidPipeline = try device.makeRenderPipelineState(descriptor: solid)
        let bloom = MTLRenderPipelineDescriptor()
        bloom.vertexFunction = library.makeFunction(name: "vibeScapeBloomVertex")
        bloom.fragmentFunction = library.makeFunction(name: "vibeScapeBloomFragment")
        let attachment = bloom.colorAttachments[0]!
        attachment.pixelFormat = .bgra8Unorm; attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one; attachment.destinationRGBBlendFactor = .one
        attachment.sourceAlphaBlendFactor = .zero; attachment.destinationAlphaBlendFactor = .one
        bloomPipeline = try device.makeRenderPipelineState(descriptor: bloom)
    }
    enum Failure: Error { case unavailable }
    func encode(texture: MTLTexture, scene: VibeScapeScene, clock: Float,
                dynamics: Float, reducedQuality: Bool, touches: [VibeScapeTouch] = [],
                interactionUptime: TimeInterval = 0, reduceMotion: Bool = false) -> MTLCommandBuffer? {
        encode(texture: texture, frame: .single(scene, clock: clock, dynamics: dynamics), reducedQuality: reducedQuality,
            touches: touches, interactionUptime: interactionUptime, reduceMotion: reduceMotion)
    }
    func encode(texture: MTLTexture, frame: VibeScapeFrame, reducedQuality: Bool,
                touches: [VibeScapeTouch] = [], interactionUptime: TimeInterval = 0,
                reduceMotion: Bool = false) -> MTLCommandBuffer? {
        guard frame.dynamics.isFinite, (0...1).contains(frame.dynamics),
              frame.home.isValid, frame.radio.isValid, frame.club.isValid, frame.festival.isValid,
              simd_reduce_add(frame.weights) <= 1.001,
              (0..<3).allSatisfy({ frame.neutralPalette[$0].isFinite && (0...1).contains(frame.neutralPalette[$0]) }),
              (0..<4).allSatisfy({ frame.phases[$0].isFinite && frame.weights[$0].isFinite && (0...1).contains(frame.weights[$0]) }),
              permits.wait(timeout: .now()) == .success else { return nil }
        guard let command = queue.makeCommandBuffer() else { permits.signal(); return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { permits.signal(); return nil }
        // Rapid world changes can retain all four weights. Bound transition
        // sampling immediately, before an EMA could react to the extra passes.
        let activeWorlds = (0..<4).reduce(0) { $0 + (frame.weights[$1] > 0.0005 ? 1 : 0) }
        let reducedSampling = reducedQuality || activeWorlds > 1
        var uniforms = Uniforms(resolutionTime: SIMD4(Float(texture.width), Float(texture.height), 0, reducedSampling ? 0 : 1),
            weights: frame.weights, phases: frame.phases, neutral: SIMD4(frame.neutralPalette, 0),
            home: .init(frame.home, dynamics: frame.dynamics, family: .home),
            radio: .init(frame.radio, dynamics: frame.dynamics, family: .radio),
            club: .init(frame.club, dynamics: frame.dynamics, family: .club),
            festival: .init(frame.festival, dynamics: frame.dynamics, family: .festival))
        for (index, touch) in touches.suffix(4).enumerated() {
            let elapsed = interactionUptime - touch.startedAt
            guard elapsed.isFinite, elapsed >= 0, elapsed < 2.6,
                  touch.position.x.isFinite, touch.position.y.isFinite,
                  touch.strength.isFinite, (0.5...2.5).contains(touch.strength) else { continue }
            let value = SIMD4(touch.position.x, touch.position.y, reduceMotion ? 0.14 : Float(elapsed), touch.strength)
            switch index {
            case 0: uniforms.touch0 = value
            case 1: uniforms.touch1 = value
            case 2: uniforms.touch2 = value
            default: uniforms.touch3 = value
            }
        }
        encoder.setRenderPipelineState(solidPipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        if frame.weights.w > 0.0005 {
            encoder.setRenderPipelineState(bloomPipeline)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            // Quality changes sampling only. Dynamics modulates the same bounded
            // sculpture continuously; it never grows an unbounded particle list.
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: reducedSampling ? 7680 : 12288)
        }
        encoder.endEncoding()
        command.addCompletedHandler { [permits] _ in permits.signal() }
        return command
    }
}
