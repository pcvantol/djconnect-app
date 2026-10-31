import Foundation
import Testing
@testable import DJConnectCore

private func speechCases(_ corrected: Bool = false) throws -> [String: Any] {
    let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(corrected ? "Fixtures/session-speech-processor-core-323a3db4.json" : "Fixtures/session-speech-core-6b26158a.json")
    return try #require((JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])?["cases"] as? [String: Any])
}
private func speechDecode<T: Decodable>(_ value: Any, as: T.Type) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
}
private func speechDescriptor(_ name: String = "accepted_reply", corrected: Bool = false) throws -> [String: Any] {
    try #require((speechCases(corrected)[name] as? [String: Any])?["session_speech"] as? [String: Any])
}
private func freshSpeech(_ name: String, corrected: Bool = false) throws -> DJConnectSessionSpeech {
    var value = try speechDescriptor(name, corrected: corrected)
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
private func speechMP3(_ version: String = "mpeg1") throws -> Data {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try Data(contentsOf: root.appendingPathComponent("Fixtures/speech-silence-" + version + ".mp3"))
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
                bytes = try JSONSerialization.data(withJSONObject: try #require(speechCases(true)["provider_voice_options"]))
            } else if path == "prepare" {
                let name = body["processor"] as? String == "ha_configured" ? "ha_configured_audio" : "manual_after_never"
                var descriptor = try speechDescriptor(name, corrected: true)
                descriptor["expires_at"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(20))
                if request.url!.host!.hasPrefix("wrongtext") {
                    descriptor["segments"] = [["ordinal":1,"speaker_role":"dj","text":"A different answer"]]
                }
                bytes = try JSONSerialization.data(withJSONObject:["success":true,"session_speech":descriptor])
            } else {
                mime = "audio/wav"; bytes = speechWAV()
                if request.url!.host!.hasPrefix("badwav") { bytes = Data(bytes.prefix(20)) }
                if request.url!.host!.hasPrefix("mp3") { mime = "audio/mpeg"; bytes = try speechMP3() }
                if request.url!.host!.hasPrefix("mp3wav") { bytes = speechWAV() }
                if request.url!.host!.hasPrefix("wavmp3") { bytes = try speechMP3() }
            }
            let response = HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:"HTTP/1.1",headerFields:["Content-Type":mime,"Cache-Control":"no-store"])!
            client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:bytes); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:error) }
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct SessionSpeechContractTests {
    @Test(.isolatedClientResources) func speechContractPinnedDescriptorsRetainExactTextAndIdentity() throws {
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

    @Test(.isolatedClientResources) func speechContractMixedReferencesAndOversizedTextAreRejected() throws {
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

    @Test(.isolatedClientResources) func speechContractServerDefaultDoesNotInventGenderSupport() throws {
        let envelope = try #require(speechCases()["provider_voice_options"] as? [String: Any])
        let options = try speechDecode(try #require(envelope["speech_voice_options"]), as: DJConnectSpeechVoiceOptions.self)
        #expect(options.isValid && options.supports(.default))
        #expect(options.selectableGenders.isEmpty && !options.supports(.male) && !options.supports(.female))
    }

    @Test(.isolatedClientResources) func speechContractExpiredAndByteDifferentTextNeverAdmit() throws {
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

    @Test(.isolatedClientResources) func speechContractMinimalUnavailableStateRemainsNonExecutable() throws {
        let unavailable = try speechDecode(["schema_version":1,"reference":["turn_id":"turn-1"],"state":"unavailable",
            "reason":"voice_gender_unavailable","manual_allowed":false,"autoplay_eligible":false,
            "segments":[],"processors":[],"cache_policy":"private,no-store"] as [String:Any], as: DJConnectSessionSpeech.self)
        #expect(unavailable.reason == "voice_gender_unavailable")
        #expect(!unavailable.admits(reference: .turn("turn-1"), text: ""))
    }
    @Test(.isolatedClientResources) func speechContractPairedPrepareAndBytesUseExactPrivatePOST() async throws {
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
        let original = try freshSpeech("accepted_reply", corrected: true)
        let text = original.segments.map(\.text).joined()
        let options = try await client().speechVoiceOptions()
        #expect(!options.supports(.female))
        let local = try await client().prepareSpeech(original,acceptedText:text,processor:.localOnDevice)
        #expect(local.audioState == "renderer_pending" && local.effectiveVoice == nil && local.audioReference == nil)
        let haOriginal = original
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

    @Test(.isolatedClientResources) func speechContractWAVStructureRejectsTruncationAndFalseLength() throws {
        let valid = speechWAV()
        try DJConnectSpeechTransport.validateWAV(valid)
        for count in [0,12,20,43,valid.count-1] {
            #expect(throws:DJConnectError.invalidResponse) { try DJConnectSpeechTransport.validateWAV(Data(valid.prefix(count))) }
        }
        var bad = valid; bad[4] = 255
        #expect(throws:DJConnectError.invalidResponse) { try DJConnectSpeechTransport.validateWAV(bad) }
    }

    @Test(.isolatedClientResources) func speechContractCorrectedAdvertisementPermitsAttemptWithoutGrantingAudio() async throws {
        let old = try freshSpeech("accepted_reply")
        let corrected = try freshSpeech("accepted_reply", corrected: true)
        #expect(!old.advertisesPreparationAttempt(.haConfigured))
        #expect(corrected.processorQualificationRequired == true)
        #expect(corrected.advertisesPreparationAttempt(.haConfigured) && corrected.advertisesPreparationAttempt(.localOnDevice))
        #expect(corrected.audioState == nil && corrected.effectiveVoice == nil && corrected.audioReference == nil)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SpeechContractURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = DJConnectClient(baseURL: URL(string:"https://200.speech.invalid")!,
            identity:.init(deviceID:"djconnect-ios-speech-fixture",deviceName:"Fixture",clientType:.ios,firmware:"4.0.0",platform:.ios),
            tokenStore:DJConnectInMemoryTokenStore(token:"synthetic-speech-token"),session:session)
        let text = corrected.segments.map(\.text).joined()
        await #expect(throws:DJConnectError.invalidResponse) { try await client.speechAudio(corrected,acceptedText:text) }
        await #expect(throws:DJConnectError.invalidResponse) {
            try await client.prepareSpeech(old,acceptedText:text,processor:.haConfigured)
        }
        let cases = try speechCases(true)
        let deniedEnvelope = try #require(cases["ha_gender_unavailable"] as? [String:Any])
        let denied = try speechDecode(try #require(deniedEnvelope["session_speech"]),as:DJConnectSessionSpeech.self)
        #expect(denied.state == "unavailable" && denied.processors.isEmpty && denied.segments.isEmpty)
        #expect(!denied.advertisesPreparationAttempt(.haConfigured))
    }

    @Test(.isolatedClientResources, arguments: ["mpeg1", "mpeg2", "mpeg25"])
    func speechMP3IndependentNativeDecoderFixtures(_ version: String) throws {
        let bytes = try speechMP3(version)
        #expect(try DJConnectSpeechTransport.validateMP3(bytes) == bytes)
    }

    @Test(.isolatedClientResources) func speechMP3StripsBoundedID3WithoutTreatingTagAsAudio() throws {
        let frames = try speechMP3()
        // Synthetic ID3v2.3 TIT2 frame containing only "x"; no actual metadata.
        let tag = Data([0x49,0x44,0x33,3,0,0,0,0,0,13, 0x54,0x49,0x54,0x32,0,0,0,3,0,0,0,0x78,0])
        #expect(try DJConnectSpeechTransport.validateMP3(tag + frames) == frames)
        #expect(throws: DJConnectError.invalidResponse) { try DJConnectSpeechTransport.validateMP3(tag) }
        let v1 = Data("TAG".utf8) + Data(repeating: 0, count: 125)
        #expect(try DJConnectSpeechTransport.validateMP3(frames + v1) == frames)
        var footerTag = tag; footerTag[3] = 4; footerTag[5] = 0x10
        let footer = Data("3DI".utf8) + footerTag[3..<10]
        #expect(try DJConnectSpeechTransport.validateMP3(footerTag + footer + frames) == frames)
    }

    @Test(.isolatedClientResources) func speechMP3RejectsMalformedFramesAndUndeclaredTrailingBytes() throws {
        let bytes = try speechMP3()
        var faults = [Data(), Data(bytes.prefix(3)), Data(bytes.dropLast()), bytes + Data([0]), speechWAV()]
        var bad = bytes; bad[1] = 0xef; faults.append(bad) // Reserved MPEG version.
        bad = bytes; bad[2] = 0; faults.append(bad) // Unsupported free bitrate.
        bad = bytes; bad[419] = 0x94; faults.append(bad) // Midstream rate change.
        faults.append(Data([0x49,0x44,0x33,4,0,0,0xff,0,0,0]) + bytes)
        for fault in faults {
            #expect(throws: DJConnectError.invalidResponse) { try DJConnectSpeechTransport.validateMP3(fault) }
        }
    }

    @Test(.isolatedClientResources) func speechDurationIsBoundedIndependentlyOfByteLimit() throws {
        let mp3 = try speechMP3()
        var longMP3 = Data(); for _ in 0..<100 { longMP3.append(mp3) }
        #expect(longMP3.count < 2 * 1024 * 1024)
        #expect(throws: DJConnectError.invalidResponse) { try DJConnectSpeechTransport.validateMP3(longMP3) }
        func wav(seconds: Int) -> Data {
            var data = Data(speechWAV().prefix(44))
            data.append(Data(repeating: 0, count: seconds * 32000))
            for (offset, value) in [(4, data.count - 8), (40, seconds * 32000)] {
                for byte in 0..<4 { data[offset + byte] = UInt8((value >> (byte * 8)) & 255) }
            }
            return data
        }
        try DJConnectSpeechTransport.validateWAV(wav(seconds: 20))
        #expect(wav(seconds: 21).count < 2 * 1024 * 1024)
        #expect(throws: DJConnectError.invalidResponse) { try DJConnectSpeechTransport.validateWAV(wav(seconds: 21)) }
    }

    @Test(.isolatedClientResources) func speechPrivatePOSTAcceptsMP3AndRejectsMIMESpoofing() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SpeechContractURLProtocol.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        func client(_ host: String) -> DJConnectClient {
            DJConnectClient(baseURL: URL(string: "https://" + host + ".speech.invalid")!,
                identity: .init(deviceID: "djconnect-ios-speech-fixture", deviceName: "Fixture", clientType: .ios, firmware: "4.0.0", platform: .ios),
                tokenStore: DJConnectInMemoryTokenStore(token: "synthetic-speech-token"), session: session)
        }
        let prepared = try freshSpeech("ha_configured_audio", corrected: true), text = prepared.segments.map(\.text).joined()
        #expect(try await client("mp3").speechAudio(prepared, acceptedText: text) == speechMP3())
        for host in ["mp3wav", "wavmp3"] {
            await #expect(throws: DJConnectError.invalidResponse) { try await client(host).speechAudio(prepared, acceptedText: text) }
        }
    }

    @Test(.isolatedClientResources) func speechOptionalOwnerProjectionsDecodeWithoutPersistingGrants() throws {
        let cases = try speechCases()
        let reply = try #require(cases["accepted_reply"] as? [String: Any])
        let expected = try speechDecode(try #require(reply["session_speech"]), as: DJConnectSessionSpeech.self)
        let common = try speechDecode(reply, as: DJConnectAskDJMessageResponse.self)
        let legacy = try speechDecode(reply, as: DJConnectAskDJResponse.self)
        let scoped = try speechDecode(reply, as: DJConnectSessionConversationResponse.self)
        #expect(common.sessionSpeech == expected && legacy.sessionSpeech == expected)
        #expect(scoped.base.sessionSpeech == expected && scoped.ownerScope == reply["owner_profile_id"] as? String)
        #expect(expected.reference == .turn(scoped.conversation.turnID))
        let moments = try #require(cases["published_and_retained_moment_speech"] as? [String: Any])
        let retained = try #require(moments["retained_entry"] as? [String: Any])
        let entry = try speechDecode(retained, as: DJConnectHistoryEntry.self)
        let descriptor = try #require(entry.sessionSpeech)
        #expect(descriptor.reference == .entry(sessionID: entry.sessionID, entryID: entry.entryID))
        let admittedAt = try #require(descriptor.expiresAt.flatMap(DJConnectHistoryEntry.date)).addingTimeInterval(-0.01)
        #expect(descriptor.admits(reference: descriptor.reference, text: try #require(entry.text), at: admittedAt))
        // An ordinary Codable cache/export round trip retains content but cannot
        // persist provider metadata, asset IDs, or a grant that might be revived.
        func assertAbsent<T: Encodable>(_ value: T) throws {
            let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
            #expect(object["session_speech"] == nil)
        }
        try assertAbsent(common); try assertAbsent(legacy); try assertAbsent(entry)
        let restored = try JSONDecoder().decode(DJConnectHistoryEntry.self, from: JSONEncoder().encode(entry))
        #expect(restored.sessionSpeech == nil && restored.text == entry.text && restored.reference == entry.reference)
        let restoredReply = try JSONDecoder().decode(DJConnectAskDJMessageResponse.self, from: JSONEncoder().encode(common))
        #expect(restoredReply.sessionSpeech == nil && restoredReply.text == common.text)
    }

    @Test(.isolatedClientResources) func speechOptionalUnknownOrMalformedProjectionKeepsAnswerAndHistoryUsable() throws {
        let cases = try speechCases()
        let original = try #require(cases["accepted_reply"] as? [String: Any])
        let moments = try #require(cases["published_and_retained_moment_speech"] as? [String: Any])
        let retained = try #require(moments["retained_entry"] as? [String: Any])
        var future = try speechDescriptor(); future["schema_version"] = 2
        var publicCache = try speechDescriptor(); publicCache["cache_policy"] = "public"
        var mixed = try speechDescriptor(); mixed["reference"] = ["turn_id": "a", "entry_id": "b"]
        for optional: Any in [NSNull(), "bad", [:], future, publicCache, mixed] {
            var reply = original; reply["session_speech"] = optional
            let decoded = try speechDecode(reply, as: DJConnectAskDJMessageResponse.self)
            let legacy = try speechDecode(reply, as: DJConnectAskDJResponse.self)
            let scoped = try speechDecode(reply, as: DJConnectSessionConversationResponse.self)
            #expect(decoded.sessionSpeech == nil && decoded.text == original["text"] as? String)
            #expect(legacy.sessionSpeech == nil && legacy.text == original["text"] as? String)
            #expect(scoped.base.sessionSpeech == nil && scoped.conversation.turnID.isEmpty == false)
            var row = retained; row["session_speech"] = optional
            let entry = try speechDecode(row, as: DJConnectHistoryEntry.self)
            #expect(entry.sessionSpeech == nil && entry.text == retained["text"] as? String)
        }
        // Existing history message codecs also discard any optional private grant
        // on export. This modeled parent tests the privacy boundary, not a new
        // producer advertisement on the message route.
        let message: [String: Any] = ["id": "synthetic-message", "role": "assistant", "text": original["text"]!, "session_speech": original["session_speech"]!]
        let decoded = try speechDecode(message, as: DJConnectAskDJHistoryMessage.self)
        #expect(decoded.sessionSpeech != nil)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
        #expect(encoded["session_speech"] == nil)
    }

}

@Test(.isolatedClientResources) func liveBroadcastPayloadRetainsPrivateSpeechAndDoesNotExportIt() throws {
    let descriptor = try speechDescriptor()
    let payload = try speechDecode(["session_speech": ["schema_version": 1, "moments": [descriptor]]], as: DJConnectSessionBroadcastEvent.Payload.self)
    #expect(payload.sessionSpeech.count == 1)
    #expect(payload.sessionSpeech.first?.reference == .turn((descriptor["reference"] as? [String: String])?["turn_id"] ?? ""))
    let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
    #expect(encoded["session_speech"] == nil)
}
