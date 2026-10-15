import Foundation
import Testing
@testable import DJConnectCore

private func speechCases() throws -> [String: Any] {
    let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/session-speech-core-6b26158a.json")
    return try #require((JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])?["cases"] as? [String: Any])
}
private func speechDecode<T: Decodable>(_ value: Any, as: T.Type) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
}
private func speechDescriptor(_ name: String = "accepted_reply") throws -> [String: Any] {
    try #require((speechCases()[name] as? [String: Any])?["session_speech"] as? [String: Any])
}
private func freshSpeech(_ name: String) throws -> DJConnectSessionSpeech {
    var value = try speechDescriptor(name)
    value["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30))
    return try speechDecode(value, as: DJConnectSessionSpeech.self)
}

private func speechWAV() -> Data {
    var data = Data("RIFF".utf8)
    func little(_ value: Int, bytes: Int) { for n in 0..<bytes { data.append(UInt8((value >> (8*n)) & 255)) } }
    little(68,bytes:4); data.append(Data("WAVEfmt ".utf8)); little(16,bytes:4)
    little(1,bytes:2); little(1,bytes:2); little(16000,bytes:4); little(32000,bytes:4)
    little(2,bytes:2); little(16,bytes:2); data.append(Data("data".utf8)); little(32,bytes:4)
    data.append(Data(repeating: 0,count:32)); return data
}
private final class SpeechContractURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-speech-token")
            #expect(request.value(forHTTPHeaderField: "X-DJConnect-Client-Type") == "ios")
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating:0,count:4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer,maxLength:buffer.count)
                    if count <= 0 { break }; data.append(contentsOf:buffer.prefix(count))
                }
            }
            let body = try #require(JSONSerialization.jsonObject(with: data) as? [String:Any])
            let path = request.url!.lastPathComponent
            let identity: Set<String> = ["client_type","device_id","contract_version"]
            let expected = path == "voice-options" ? identity : identity.union(path == "audio" ? ["asset_id"] : ["reference","processor","voice_preference"])
            #expect(Set(body.keys) == expected)
            #expect(body["contract_version"] as? Int == 1)
            var mime = "application/json", bytes = Data()
            let status = Int(request.url!.host!.split(separator:".")[0]) ?? 200
            if path == "voice-options" {
                bytes = try JSONSerialization.data(withJSONObject: try #require(speechCases()["provider_voice_options"]))
            } else if path == "prepare" {
                let name = body["processor"] as? String == "ha_configured" ? "ha_configured_audio" : "manual_after_never"
                var descriptor = try speechDescriptor(name)
                descriptor["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(20))
                if request.url!.host!.hasPrefix("wrongtext") {
                    descriptor["segments"] = [["ordinal":1,"speaker_role":"dj","text":"A different answer"]]
                }
                bytes = try JSONSerialization.data(withJSONObject:["success":true,"session_speech":descriptor])
            } else {
                mime = "audio/wav"; bytes = speechWAV()
                if request.url!.host!.hasPrefix("badwav") { bytes = Data(bytes.prefix(20)) }
            }
            let response = HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:"HTTP/1.1",headerFields:["Content-Type":mime,"Cache-Control":"no-store"])!
            client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:bytes); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:error) }
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct SessionSpeechContractTests {
    @Test func speechContractPinnedDescriptorsRetainExactTextAndIdentity() throws {
        let cases = try speechCases()
        var count = 0
        func visit(_ value: Any) throws {
            if let object = value as? [String: Any] {
                if object["schema_version"] != nil, object["reference"] != nil, object["segments"] != nil {
                    let descriptor = try speechDecode(object, as: DJConnectSessionSpeech.self)
                    if descriptor.state == "available" {
                        let date = try #require(descriptor.expiresAt.flatMap(DJConnectHistoryEntry.date)).addingTimeInterval(-0.01)
                        #expect(descriptor.admits(reference: descriptor.reference, text: descriptor.segments.map(\.text).joined(), at: date))
                        count += 1
                    }
                }
                for child in object.values { try visit(child) }
            } else if let items = value as? [Any] { for child in items { try visit(child) } }
        }
        try visit(cases)
        #expect(count >= 10)
        let accepted = try freshSpeech("accepted_reply")
        let reply = try #require(cases["accepted_reply"] as? [String: Any])
        #expect(accepted.admits(reference: accepted.reference, text: try #require(reply["text"] as? String)))
        #expect(!accepted.autoplayEligible && accepted.manualAllowed)
        #expect(!accepted.admits(reference: .turn("another-turn"), text: accepted.segments.map(\.text).joined()))
        #expect(!accepted.admits(reference: accepted.reference, text: "Replacement local story"))
    }

    @Test func speechContractMixedReferencesAndOversizedTextAreRejected() throws {
        for value: [String: String] in [["turn_id":"a","moment_id":"b"], ["session_id":"a"], ["turn_id":""], ["turn_id":" padded "], ["turn_id":String(repeating:"x",count:129)]] {
            #expect(throws: (any Error).self) { try speechDecode(value, as: DJConnectSpeechReference.self) }
        }
        var value = try speechDescriptor()
        value["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30))
        value["segments"] = [["ordinal":1,"speaker_role":"dj","text":String(repeating:"x",count:1201)]]
        let descriptor = try speechDecode(value, as: DJConnectSessionSpeech.self)
        #expect(!descriptor.admits(reference: descriptor.reference, text: String(repeating:"x",count:1201)))
        value["state"] = "withdrawn"
        let withdrawn = try speechDecode(value, as: DJConnectSessionSpeech.self)
        #expect(!withdrawn.admits(reference: withdrawn.reference, text: "anything"))
    }

    @Test func speechContractServerDefaultDoesNotInventGenderSupport() throws {
        let envelope = try #require(speechCases()["provider_voice_options"] as? [String: Any])
        let options = try speechDecode(try #require(envelope["speech_voice_options"]), as: DJConnectSpeechVoiceOptions.self)
        #expect(options.isValid && options.supports(.default))
        #expect(options.selectableGenders.isEmpty && !options.supports(.male) && !options.supports(.female))
    }

    @Test func speechContractExpiredAndByteDifferentTextNeverAdmit() throws {
        let descriptor = try freshSpeech("accepted_reply")
        let text = descriptor.segments.map(\.text).joined()
        let deadline = try #require(descriptor.expiresAt.flatMap(DJConnectHistoryEntry.date))
        #expect(!descriptor.admits(reference: descriptor.reference, text: text, at: deadline))
        #expect(!descriptor.admits(reference: descriptor.reference, text: text + " "))
        var value = try speechDescriptor()
        value["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30))
        value["segments"] = [["ordinal":1,"speaker_role":"dj","text":"é"]]
        let unicode = try speechDecode(value, as: DJConnectSessionSpeech.self)
        #expect(!unicode.admits(reference: unicode.reference, text: "e\u{301}"))
    }

    @Test func speechContractMinimalUnavailableStateRemainsNonExecutable() throws {
        let unavailable = try speechDecode(["schema_version":1,"reference":["turn_id":"turn-1"],"state":"unavailable",
            "reason":"voice_gender_unavailable","manual_allowed":false,"autoplay_eligible":false,
            "segments":[],"processors":[],"cache_policy":"private,no-store"] as [String:Any], as: DJConnectSessionSpeech.self)
        #expect(unavailable.reason == "voice_gender_unavailable")
        #expect(!unavailable.admits(reference: .turn("turn-1"), text: ""))
    }
    @Test func speechContractPairedPrepareAndBytesUseExactPrivatePOST() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SpeechContractURLProtocol.self]
        let session = URLSession(configuration:configuration)
        defer { session.invalidateAndCancel() }
        let token = DJConnectInMemoryTokenStore(token:"synthetic-speech-token")
        func client(_ host: String = "200.speech.invalid") -> DJConnectClient {
            DJConnectClient(baseURL:URL(string:"https://"+host)!,
                identity:.init(deviceID:"djconnect-ios-speech-fixture",deviceName:"Fixture",clientType:.ios,firmware:"4.0.0",platform:.ios),
                tokenStore:token,session:session)
        }
        let original = try freshSpeech("accepted_reply")
        let text = original.segments.map(\.text).joined()
        let options = try await client().speechVoiceOptions()
        #expect(!options.supports(.female))
        let local = try await client().prepareSpeech(original,acceptedText:text,processor:.localOnDevice)
        #expect(local.audioState == "renderer_pending" && local.effectiveVoice == nil && local.audioReference == nil)
        let haOriginal = try freshSpeech("ha_configured_audio")
        let ha = try await client().prepareSpeech(haOriginal,acceptedText:text,processor:.haConfigured)
        let audio = try await client().speechAudio(ha,acceptedText:text)
        #expect(audio == speechWAV())
        await #expect(throws:DJConnectError.invalidResponse) {
            try await client().prepareSpeech(original,acceptedText:text,processor:.localOnDevice,preference:.female,voiceOptions:options)
        }
        await #expect(throws:DJConnectError.invalidResponse) {
            try await client("wrongtext.speech.invalid").prepareSpeech(original,acceptedText:text,processor:.localOnDevice)
        }
        for (status, expected) in [(401,DJConnectError.authStale(statusCode:401,message:nil)),
                                    (403,.profile(code:.profileAccessDenied,statusCode:403,message:nil)),
                                    (404,.routeMissing(message:nil)),(410,.routeMissing(message:nil))] {
            await #expect(throws:expected) { try await client("\(status).speech.invalid").speechAudio(ha,acceptedText:text) }
            #expect(try token.loadToken() == "synthetic-speech-token")
        }
        await #expect(throws:DJConnectError.invalidResponse) { try await client("badwav.speech.invalid").speechAudio(ha,acceptedText:text) }
    }

    @Test func speechContractWAVStructureRejectsTruncationAndFalseLength() throws {
        let valid = speechWAV()
        try DJConnectSpeechTransport.validateWAV(valid)
        for count in [0,12,20,43,valid.count-1] {
            #expect(throws:DJConnectError.invalidResponse) { try DJConnectSpeechTransport.validateWAV(Data(valid.prefix(count))) }
        }
        var bad = valid; bad[4] = 255
        #expect(throws:DJConnectError.invalidResponse) { try DJConnectSpeechTransport.validateWAV(bad) }
    }

}
