import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers

/// Actual offscreen GPU qualification. Synthetic scene inputs grant no Profile
/// or playback authority. Does not launch/install the app or record a microphone.
@main struct MetalProbe {
    static func main() throws {
        guard CommandLine.arguments.count == 3,
              let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal unavailable or missing paths") }
        let library = try device.makeLibrary(URL: URL(fileURLWithPath:CommandLine.arguments[1]))
        let engine = try VibeScapeMetalEngine(device:device,library:library)
        let output = URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:960,height:640,mipmapped:false)
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
        let sorted = gpuMS.sorted()
        let report: [String:Any] = ["device":device.name,"resolution":[960,640],"frames":gpuMS.count,
            "gpu_ms_median":sorted[sorted.count/2],"gpu_ms_p95":sorted[Int(Double(sorted.count)*0.95)],
            "scenes":scenes,"context":"20 synthetic renderer inputs, offscreen macOS GPU only",
            "iphone_ipad_ui_thermal_battery_acceptance":"NOT_RUN","native_voice":"NOT_RUN"]
        let data = try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try data.write(to:output.appendingPathComponent("gpu-report.json"))
        print(String(decoding:data,as:UTF8.self))
    }
    static func save(_ texture:MTLTexture,to url:URL) throws {
        let row = texture.width*4
        var bytes = [UInt8](repeating:0,count:row*texture.height)
        bytes.withUnsafeMutableBytes { storage in
            texture.getBytes(storage.baseAddress!,bytesPerRow:row,from:MTLRegionMake2D(0,0,texture.width,texture.height),mipmapLevel:0)
        }
        guard let provider = CGDataProvider(data:Data(bytes) as CFData),
              let image = CGImage(width:texture.width,height:texture.height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:row,
                                  space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                                  provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent),
              let target = CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else { throw VibeScapeMetalEngine.Failure.unavailable }
        CGImageDestinationAddImage(target,image,nil)
        guard CGImageDestinationFinalize(target) else { throw VibeScapeMetalEngine.Failure.unavailable }
    }
}
