import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers

/// Actual offscreen GPU qualification. Synthetic scene inputs grant no Profile
/// or playback authority. Does not launch/install the app or record a microphone.
@main struct MetalProbe {
    static func main() throws {
        guard [3,5].contains(CommandLine.arguments.count),
              let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal unavailable or missing paths") }
        let library = try device.makeLibrary(URL: URL(fileURLWithPath:CommandLine.arguments[1]))
        let engine = try VibeScapeMetalEngine(device:device,library:library)
        let output = URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let width = CommandLine.arguments.count == 5 ? Int(CommandLine.arguments[3]) ?? 0 : 960
        let height = CommandLine.arguments.count == 5 ? Int(CommandLine.arguments[4]) ?? 0 : 640
        guard (64...2048).contains(width), (64...2048).contains(height) else { fatalError("Invalid probe size") }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget,.shaderRead]
        guard let texture = device.makeTexture(descriptor:descriptor) else { fatalError("Texture unavailable") }
        var gpuMS: [Double] = []
        var scenes: [String] = []
        for index in 0..<20 {
            let mood = ["chill","chill","groove","groove","energy","party"][index % 6]
            let scene = VibeScapeScene.autonomous(mood:mood,salt:UInt64(index+500))
            for frame in 0..<12 {
                guard let command = engine.encode(texture:texture,scene:scene,clock:Float(frame)*0.13,dynamics:0.5,reducedQuality:false) else { fatalError("Encoding failed") }
                command.commit(); command.waitUntilCompleted()
                guard command.status == .completed else { throw command.error ?? VibeScapeMetalEngine.Failure.unavailable }
                gpuMS.append((command.gpuEndTime-command.gpuStartTime)*1000)
            }
            let imageName = String(format:"scene-%02d-%@.png",index,mood)
            try save(texture,to:output.appendingPathComponent(imageName))
            scenes.append(imageName)
        }
        // Hold composition, mood and initial clock fixed. Verify that moving
        // the slider changes actual GPU pixels, including a static frame, and
        // that its temporal effect is larger at the intense end.
        let subject = VibeScapeScene.autonomous(mood: "groove", salt: 504)
        var starts: [[UInt8]] = []
        var motionDelta: [Double] = []
        for dynamics: Float in [0, 1] {
            var frames: [[UInt8]] = []
            for seconds: Float in [0, 3] {
                let clock = 2 + seconds * subject.motion * VibeScapeDynamics.motionRate(dynamics)
                guard let command = engine.encode(texture: texture, scene: subject, clock: clock,
                                                  dynamics: dynamics, reducedQuality: false) else { fatalError("Encoding failed") }
                command.commit(); command.waitUntilCompleted()
                guard command.status == .completed else { throw command.error ?? VibeScapeMetalEngine.Failure.unavailable }
                frames.append(pixels(texture))
                try save(texture, to: output.appendingPathComponent("dynamics-\(Int(dynamics))-\(Int(seconds))s.png"))
            }
            starts.append(frames[0])
            motionDelta.append(pixelDelta(frames[0], frames[1]))
        }
        let staticDelta = pixelDelta(starts[0], starts[1])
        guard staticDelta > 0.5, motionDelta[1] > motionDelta[0] else {
            fatalError("Dynamics failed actual GPU pixel regression: \(staticDelta), \(motionDelta)")
        }
        func touchFrame(_ touches: [VibeScapeTouch], age: TimeInterval, name: String? = nil) throws -> [UInt8] {
            guard let command = engine.encode(texture: texture, scene: subject, clock: 2, dynamics: 0.5,
                                              reducedQuality: false, touches: touches, interactionUptime: age) else {
                throw VibeScapeMetalEngine.Failure.unavailable
            }
            command.commit(); command.waitUntilCompleted()
            guard command.status == .completed else { throw command.error ?? VibeScapeMetalEngine.Failure.unavailable }
            if let name { try save(texture, to: output.appendingPathComponent(name)) }
            return pixels(texture)
        }
        let touchA = VibeScapeTouch(position: SIMD2(-0.15, 0.4), startedAt: 0)
        let touchB = VibeScapeTouch(position: SIMD2(0.15, 0.65), startedAt: 0)
        let untouched = try touchFrame([], age: 0, name: "touch-baseline.png")
        let nudged = try touchFrame([touchA], age: 0.14, name: "touch-left.png")
        let otherPoint = try touchFrame([touchB], age: 0.14, name: "touch-right.png")
        let expired = try touchFrame([touchA], age: 3, name: "touch-expired.png")
        let near = regionDelta(untouched, nudged, width: width, height: height, point: touchA.position)
        let far = regionDelta(untouched, nudged, width: width, height: height, point: SIMD2(0.3, -0.8))
        guard near > far, pixelDelta(nudged, otherPoint) > 0.001, expired == untouched else {
            fatalError("Touch must deform locally at its own position and expire without persistent changes")
        }
        // Freeze the autonomous clock so successive-frame differences come
        // only from the touch response, not the underlying moving liquid.
        var prior = untouched
        var touchFrameDeltas: [Double] = []
        for frame in 0...78 {
            let next = try touchFrame([touchA], age: Double(frame)/30)
            touchFrameDeltas.append(pixelDelta(prior,next))
            prior = next
        }
        let sorted = gpuMS.sorted()
        let report: [String:Any] = ["device":device.name,"resolution":[width,height],"frames":gpuMS.count,
            "gpu_ms_median":sorted[sorted.count/2],"gpu_ms_p95":sorted[Int(Double(sorted.count)*0.95)],
            "scenes":scenes,"context":"20 synthetic renderer inputs, offscreen macOS GPU only",
            "dynamics_static_mean_pixel_delta": staticDelta,
            "dynamics_3s_mean_pixel_delta_calm_intense": motionDelta,
            "dynamics_gpu_regression": "PASS",
            "touch_gpu_regression": "PASS",
            "touch_mean_pixel_delta_near_far": [near,far],
            "touch_position_changes_output": pixelDelta(nudged, otherPoint),
            "touch_expiry_restores_original_pixels": expired == untouched,
            "touch_temporal_mean_frame_delta": touchFrameDeltas.reduce(0,+)/Double(touchFrameDeltas.count),
            "touch_temporal_max_frame_delta": touchFrameDeltas.max() ?? 0,
            "iphone_ipad_ui_thermal_battery_acceptance":"NOT_RUN","native_voice":"NOT_RUN"]
        let data = try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try data.write(to:output.appendingPathComponent("gpu-report.json"))
        print(String(decoding:data,as:UTF8.self))
    }
    static func pixelDelta(_ first: [UInt8], _ second: [UInt8]) -> Double {
        zip(first, second).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(first.count)
    }
    static func regionDelta(_ first: [UInt8], _ second: [UInt8], width: Int, height: Int, point: SIMD2<Float>) -> Double {
        let centerX = Int((Double(point.x)/Double(width)*Double(height)+1)*0.5*Double(width))
        let centerY = Int((1-Double(point.y))*0.5*Double(height))
        let radius = max(8,height/16)
        var total = 0.0; var count = 0
        for y in max(0,centerY-radius)..<min(height,centerY+radius) {
            for x in max(0,centerX-radius)..<min(width,centerX+radius) {
                for channel in 0..<3 {
                    let index = (y*width+x)*4+channel
                    total += abs(Double(first[index])-Double(second[index])); count += 1
                }
            }
        }
        return total/Double(max(1,count))
    }
    static func pixels(_ texture: MTLTexture) -> [UInt8] {
        let row = texture.width*4
        var bytes = [UInt8](repeating:0,count:row*texture.height)
        bytes.withUnsafeMutableBytes { storage in
            texture.getBytes(storage.baseAddress!,bytesPerRow:row,from:MTLRegionMake2D(0,0,texture.width,texture.height),mipmapLevel:0)
        }
        return bytes
    }
    static func save(_ texture:MTLTexture,to url:URL) throws {
        let row = texture.width*4
        let bytes = pixels(texture)
        guard let provider = CGDataProvider(data:Data(bytes) as CFData),
              let image = CGImage(width:texture.width,height:texture.height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:row,
                                  space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                                  provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent),
              let target = CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else { throw VibeScapeMetalEngine.Failure.unavailable }
        CGImageDestinationAddImage(target,image,nil)
        guard CGImageDestinationFinalize(target) else { throw VibeScapeMetalEngine.Failure.unavailable }
    }
}
