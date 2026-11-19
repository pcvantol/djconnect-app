import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers
import simd

/// Synthetic inputs rendered by the shipping Metal pipelines on the current Mac.
/// No app installation, profile, network, microphone or fabricated music facts.
@main struct FamilyMetalProbe {
    static func main() throws {
        guard CommandLine.arguments.count == 3, let device = MTLCreateSystemDefaultDevice() else { fatalError("Missing Metal/paths") }
        let library = try device.makeLibrary(URL: URL(fileURLWithPath: CommandLine.arguments[1]))
        let engine = try VibeScapeMetalEngine(device: device, library: library)
        let output = URL(fileURLWithPath: CommandLine.arguments[2]); try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let width = 960, height = 640
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { fatalError("Texture unavailable") }
        var records: [[String: Any]] = []
        var fieldChecks: [[String: Any]] = []
        var touchChecks: [[String: Any]] = []
        func pixels() -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            texture.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return bytes
        }
        func render(_ frame: VibeScapeFrame, reduced: Bool = false,
                    touches: [VibeScapeTouch] = [], age: Double = 0) throws -> Double {
            guard let command = engine.encode(texture: texture, frame: frame, reducedQuality: reduced,
                touches: touches, interactionUptime: age) else { throw VibeScapeMetalEngine.Failure.unavailable }
            command.commit(); command.waitUntilCompleted()
            guard command.status == .completed else { throw command.error ?? VibeScapeMetalEngine.Failure.unavailable }
            return (command.gpuEndTime - command.gpuStartTime) * 1000
        }
        func image() -> CGImage {
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            texture.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        }
        func save(_ name: String) {
            let dest = CGImageDestinationCreateWithURL(output.appendingPathComponent(name).appendingPathExtension("png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, image(), nil); precondition(CGImageDestinationFinalize(dest))
        }
        let worlds: [VibeScapeFamily] = [.home, .radio, .club, .festival]
        for family in worlds {
            for mood in ["chill", "groove", "energy", "party"] {
                for dynamics: Float in [0, 0.5, 1] {
                    let scene = VibeScapeScene.autonomous(mood: mood, salt: 504, family: family)
                    var state = VibeScapeAnimationState(), times: [Double] = []
                    let name = "\(family)-\(mood)-\(Int(dynamics * 100))"
                    let gif = mood == "groove" ? CGImageDestinationCreateWithURL(output.appendingPathComponent(name).appendingPathExtension("gif") as CFURL, UTType.gif.identifier as CFString, 60, nil) : nil
                    if let gif { CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary) }
                    for tick in 0..<120 {
                        let frame = state.update(target: scene, dynamics: dynamics, at: Double(tick) / 15, reduceMotion: false)
                        times.append(try render(frame))
                        if tick % 2 == 0, let gif { CGImageDestinationAddImage(gif, image(), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 2.0 / 15]] as CFDictionary) }
                    }
                    if let gif { precondition(CGImageDestinationFinalize(gif)) }
                    save(name)
                    let sorted = times.sorted()
                    records.append(["scenario": name, "frames": times.count, "gpu_ms_median": sorted[60], "gpu_ms_p95": sorted[114]])
                    print(name, sorted[60], sorted[114])
                }
            }
            // A shared grey palette verifies topology rather than recolouring.
            var mono = VibeScapeScene.autonomous(mood: "groove", salt: 504, family: family)
            mono.palette = .init(repeating: 0.65); mono.secondaryPalette = .init(repeating: 0.5); mono.accentPalette = .init(repeating: 0.8)
            _ = try render(.single(mono, clock: 2, dynamics: 0.5)); save("\(family)-monochrome")
            // A GPU acknowledgement is meaningful only when accepted visual
            // fields actually affect this family's renderer. No fixture textures.
            for field in ["palette", "depth", "roughness", "deformation"] {
                var low = VibeScapeScene.autonomous(mood: "groove", salt: 504, family: family)
                var high = low
                switch field {
                case "palette":
                    low.palette = .init(0.8, 0.1, 0.15); high.palette = .init(0.1, 0.15, 0.8)
                case "depth": low.depth = 0; high.depth = 1
                case "roughness": low.roughness = 0; high.roughness = 1
                default: low.deformation = 0; high.deformation = 1
                }
                _ = try render(.single(low, clock: 2, dynamics: 0.5)); let first = pixels()
                _ = try render(.single(high, clock: 2, dynamics: 0.5)); let second = pixels()
                var difference = 0.0
                for index in stride(from: 0, to: first.count, by: 4) {
                    difference += abs(Double(first[index]) - Double(second[index]))
                    difference += abs(Double(first[index + 1]) - Double(second[index + 1]))
                    difference += abs(Double(first[index + 2]) - Double(second[index + 2]))
                }
                difference /= Double(width * height * 3)
                precondition(difference > 0.002, "Accepted \(family) \(field) did not affect GPU pixels")
                fieldChecks.append(["family": "\(family)", "field": field, "mean_rgb_byte_delta": difference])
            }
            let touchFrame = VibeScapeFrame.single(.autonomous(mood: "groove", salt: 504, family: family), clock: 2, dynamics: 0.5)
            _ = try render(touchFrame); let untouched = pixels()
            let tap = VibeScapeTouch(position: .init(-0.15, 0.4), startedAt: 0, strength: 2.4)
            let swipe = VibeScapeTouch(position: tap.position, startedAt: 0, strength: 0.8)
            _ = try render(touchFrame, touches: [tap], age: 0.14); let tapped = pixels(); save("\(family)-touch-tap")
            _ = try render(touchFrame, touches: [swipe], age: 0.14); let swiped = pixels()
            _ = try render(touchFrame, touches: [tap], age: 3); let expired = pixels()
            func difference(_ first: [UInt8], _ second: [UInt8]) -> Double {
                zip(first, second).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(first.count)
            }
            let tapDelta = difference(untouched, tapped), swipeDelta = difference(untouched, swiped)
            precondition(tapDelta > swipeDelta && swipeDelta > 0.002 && expired == untouched,
                "\(family) contact must be visible, stronger for tap, and restore exactly at expiry: \(tapDelta), \(swipeDelta)")
            touchChecks.append(["family": "\(family)", "tap_mean_byte_delta": tapDelta,
                "swipe_mean_byte_delta": swipeDelta, "expiry_restores_pixels": expired == untouched])
            for occurrence in 0..<20 {
                let scene = VibeScapeScene.autonomous(mood: "groove", salt: UInt64(500 + occurrence), family: family)
                _ = try render(.single(scene, clock: 2, dynamics: 0.5)); save("\(family)-synthetic-occurrence-\(occurrence)")
            }
        }
        var state = VibeScapeAnimationState(), transitionTimes: [Double] = []
        for tick in 0..<240 {
            let family = worlds[(tick / 10) % 4]
            let scene = VibeScapeScene.autonomous(mood: "groove", salt: 504, family: family)
            let frame = state.update(target: scene, dynamics: Float(tick % 60) / 59, at: Double(tick) / 60, reduceMotion: false)
            transitionTimes.append(try render(frame))
        }
        transitionTimes.sort()
        let report: [String: Any] = ["device": device.name, "resolution": [width, height], "scenarios": records,
            "visual_field_gpu_checks": fieldChecks, "touch_gpu_checks": touchChecks, "transition_frames": 240, "transition_gpu_ms_median": transitionTimes[120], "transition_gpu_ms_p95": transitionTimes[228],
            "occurrences": "20 explicit synthetic occurrence/seed inputs per family, not real provider playback",
            "evidence": "native macOS offscreen Metal; production pipeline and presentation integrator; no whole-app FPS claim",
            "physical_iphone_ipad": "NOT_RUN", "native_voice": "NOT_RUN", "user_acceptance": "PENDING"]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("gpu-report.json"))
    }
}
