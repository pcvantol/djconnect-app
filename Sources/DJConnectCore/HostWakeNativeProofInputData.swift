import Foundation

/// Native SDK input/output DATA only. This is deliberately not an invocation
/// permit, a genuine enrolled-key reference, a clock or an owner factory.
/// The native adapter still needs its actual signed/enrollment/clock custody.
struct HostWakeNativeProofInputData: Sendable {
    enum Kind: String, Sendable {
        case attestation = "app_attest_attestation"
        case assertion = "app_attest_assertion"
        enum SDKOperation: Sendable { case attestKey, generateAssertion }
        var sdkOperation: SDKOperation { self == .attestation ? .attestKey : .generateAssertion }
    }
    let kind: Kind
    let keyIdentifier: String
    let clientData: Data
    let clientDataHash: Data

    init(preparedOriginal: Data, preparedKind: String, challengeTranscript: Data,
         challengeKind: String, advertisedHash: String,
         suppliedSDKKeyIdentifier: String, originalToken: Data) throws {
        guard let kind = Kind(rawValue: preparedKind), challengeKind == kind.rawValue,
              suppliedSDKKeyIdentifier.utf8.count == 44,
              let key = Data(base64Encoded: suppliedSDKKeyIdentifier), key.count == 32,
              key.base64EncodedString() == suppliedSDKKeyIdentifier else { throw DJConnectError.invalidResponse }
        let transcript = try HostWakeNativeTranscriptData(canonicalTranscript: challengeTranscript)
        try transcript.compareData(originalCanonicalBytes: preparedOriginal, nativeToken: originalToken,
            advertisedHash: advertisedHash)
        guard transcript.original.object?["native_key_id_b64"]?.string == suppliedSDKKeyIdentifier else { throw DJConnectError.invalidResponse }
        self.kind = kind; keyIdentifier = suppliedSDKKeyIdentifier
        clientData = transcript.clientData; clientDataHash = transcript.clientDataHash
    }

    func proofData(_ opaqueSDKBytes: Data) throws -> DirectRichWireJSON {
        try Self.proofData(kind: kind.rawValue, opaqueSDKBytes: opaqueSDKBytes)
    }
    /// Preserve opaque SDK bytes exactly. No CBOR/properties/certificate/key
    /// reconstruction or API-private custodian reference is accepted here.
    static func proofData(kind: String, opaqueSDKBytes: Data) throws -> DirectRichWireJSON {
        guard let kind = Kind(rawValue: kind), (1...9216).contains(opaqueSDKBytes.count) else { throw DJConnectError.invalidResponse }
        return .object(["kind": .string(kind.rawValue), "bytes_b64": .string(opaqueSDKBytes.base64EncodedString())])
    }
}
