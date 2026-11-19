import Foundation
import AVFoundation

extension DJConnectSpeechTransport {
    /// Private bounded Layer III only. Parse every frame; an ID3/Xing duration alone
    /// cannot admit a long or truncated stream. Return frames without opaque metadata
    /// so later playback never parses ID3 content. No play, prepareToPlay or disk cache.
    @discardableResult
    static func validateMP3(_ data: Data) throws -> Data {
        guard data.count >= 4, data.count <= 2 * 1024 * 1024 else { throw DJConnectError.invalidResponse }
        var cursor = 0, end = data.count
        if data.prefix(3) == Data("ID3".utf8) {
            guard data.count >= 10, (2...4).contains(data[3]), data[4] == 0,
                  data[6..<10].allSatisfy({ $0 < 128 }) else { throw DJConnectError.invalidResponse }
            let version = data[3], flags = data[5]
            let reserved: UInt8 = version == 2 ? 0x3f : version == 3 ? 0x1f : 0x0f
            guard flags & reserved == 0 else { throw DJConnectError.invalidResponse }
            let tagSize = data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            guard tagSize <= 64 * 1024, tagSize <= data.count - 10 else { throw DJConnectError.invalidResponse }
            cursor = 10 + tagSize
            if version == 4 && flags & 0x10 != 0 {
                guard data.count - cursor >= 10,
                      data[cursor..<cursor + 3] == Data("3DI".utf8),
                      data[cursor + 3..<cursor + 10] == data[3..<10] else { throw DJConnectError.invalidResponse }
                cursor += 10
            }
        }
        if end >= 128, data[end - 128..<end - 125] == Data("TAG".utf8) { end -= 128 }
        let audioStart = cursor
        var frames = 0, duration = 0.0, streamRate: Int?, streamChannels: Int?, streamVersion: Int?
        while cursor < end {
            try Task.checkCancellation()
            guard end - cursor >= 4 else { throw DJConnectError.invalidResponse }
            let a = data[cursor], b = data[cursor + 1], c = data[cursor + 2], d = data[cursor + 3]
            let version = Int((b >> 3) & 3), layer = (b >> 1) & 3
            let rateIndex = Int((c >> 2) & 3), bitrateIndex = Int(c >> 4)
            guard a == 0xff, b & 0xe0 == 0xe0, version != 1, layer == 1,
                  rateIndex < 3, (1...14).contains(bitrateIndex), d & 3 != 2 else { throw DJConnectError.invalidResponse }
            let divisor = version == 3 ? 1 : version == 2 ? 2 : 4
            let rate = [44100, 48000, 32000][rateIndex] / divisor
            let rates = version == 3 ? [32,40,48,56,64,80,96,112,128,160,192,224,256,320] : [8,16,24,32,40,48,56,64,80,96,112,128,144,160]
            let channels = d >> 6 == 3 ? 1 : 2
            let samples = version == 3 ? 1152 : 576
            let size = (version == 3 ? 144000 : 72000) * rates[bitrateIndex - 1] / rate + Int((c >> 1) & 1)
            let sideInformation = version == 3 ? (channels == 1 ? 17 : 32) : (channels == 1 ? 9 : 17)
            let crc = b & 1 == 0 ? 2 : 0
            guard size >= 4 + crc + sideInformation, size <= end - cursor,
                  streamRate == nil || streamRate == rate,
                  streamChannels == nil || streamChannels == channels,
                  streamVersion == nil || streamVersion == version else { throw DJConnectError.invalidResponse }
            streamRate = rate; streamChannels = channels; streamVersion = version
            frames += 1; duration += Double(samples) / Double(rate)
            guard duration <= 20 else { throw DJConnectError.invalidResponse }
            cursor += size
        }
        guard frames > 0, cursor == end, let streamRate, let streamChannels else { throw DJConnectError.invalidResponse }
        // Independent native parser, initialized only from these bounded RAM bytes.
        // A type hint is not admission: structural checks above are mandatory first.
        let framesOnly = Data(data[audioStart..<end])
        do {
            let player = try AVAudioPlayer(data: framesOnly, fileTypeHint: AVFileType.mp3.rawValue)
            guard player.duration.isFinite, player.duration > 0, player.duration <= 20,
                  player.format.sampleRate == Double(streamRate), player.numberOfChannels == streamChannels else {
                throw DJConnectError.invalidResponse
            }
        } catch { throw DJConnectError.invalidResponse }
        try Task.checkCancellation()
        return framesOnly
    }
}
