import Foundation

/// A short-lived browser capability, never a URL to open or owner authority.
/// Wire: protected API djc-rendezvous/1-implementation.1, QR maximum1024 UTF8 bytes.
public struct DJConnectRendezvousQR: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public static let serviceOrigin = "https://api.djconnect.dev"
    public let transactionID: String
    public let generation: Int64
    public let expiresAtMS: Int64
    public let browserKeyThumbprint: String
    public let capability: String
    private let admittedAtMS: Int64
    private let admittedUptime: TimeInterval
    private let monotonicDeadline: TimeInterval
    public var description: String { "DJConnectRendezvousQR(redacted)" }
    public var debugDescription: String { description }
    public enum Failure: Error, Equatable, Sendable { case invalid, expired }

    public static func parse(_ text: String, at nowMS: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                             uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws -> Self {
        let object = try RendezvousFlatJSON.parse(Data(text.utf8), maximumBytes: 1024)
        guard Set(object.keys) == ["type", "v", "service_origin", "transaction_id", "generation", "expires_at", "browser_key_thumbprint", "qr_capability"],
              object["type"] == .string("djc-rendezvous-qr"), object["v"] == .string("djc-rendezvous/1"),
              object["service_origin"] == .string(serviceOrigin),
              case let .string(transaction)? = object["transaction_id"],
              transaction.utf8.count == 36,
              transaction.range(of: #"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#, options: .regularExpression) != nil,
              case let .integer(generation)? = object["generation"], (1...2_147_483_647).contains(generation),
              case let .integer(expiry)? = object["expires_at"],
              case let .string(thumbprint)? = object["browser_key_thumbprint"], canonicalToken(thumbprint),
              case let .string(capability)? = object["qr_capability"], canonicalToken(capability),
              nowMS >= 0, uptime.isFinite, uptime >= 0 else { throw Failure.invalid }
        guard expiry > nowMS, expiry - nowMS <= 120_000 else { throw Failure.expired }
        return .init(transactionID: transaction, generation: generation, expiresAtMS: expiry,
                     browserKeyThumbprint: thumbprint, capability: capability, admittedAtMS: nowMS, admittedUptime: uptime,
                     monotonicDeadline: uptime + Double(expiry - nowMS) / 1000)
    }

    public func isCurrent(at nowMS: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                          uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        nowMS >= admittedAtMS && nowMS < expiresAtMS && uptime.isFinite && uptime >= admittedUptime && uptime < monotonicDeadline
    }
    static func canonicalToken(_ value: String) -> Bool {
        guard value.utf8.count == 43, value.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }),
              let data = Data(base64Encoded: value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "="), data.count == 32 else { return false }
        return data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") == value
    }
}

/// Limited to bounded string/integer/object wire schemas. Decode keys
/// before duplicate detection; Foundation validates each JSON string's escapes.
/// Arrays, fractional/negative/unsafe integers and duplicate aliases fail.
/// Schema callers compare booleans separately; booleans never become integers.
enum RendezvousFlatJSON {
    indirect enum Value: Equatable { case string(String), integer(Int64), bool(Bool), object([String: Value]) }
    static func parse(_ data: Data, maximumBytes: Int) throws -> [String: Value] {
        func reject() -> DJConnectRendezvousQR.Failure { .invalid }
        guard !data.isEmpty, data.count <= maximumBytes, String(data: data, encoding: .utf8) != nil else { throw reject() }
        let bytes = Array(data); var index = 0
        func whitespace() { while index < bytes.count && [9, 10, 13, 32].contains(bytes[index]) { index += 1 } }
        func take(_ byte: UInt8) throws {
            whitespace(); guard index < bytes.count, bytes[index] == byte else { throw reject() }; index += 1
        }
        func string() throws -> String {
            whitespace(); let start = index
            guard index < bytes.count, bytes[index] == 34 else { throw reject() }; index += 1
            while index < bytes.count {
                if bytes[index] == 92 { index += 2; continue }
                if bytes[index] == 34 {
                    index += 1
                    guard let result = try? JSONSerialization.jsonObject(with: Data(bytes[start..<index]), options: [.fragmentsAllowed]) as? String else { throw reject() }
                    return result
                }
                index += 1
            }
            throw reject()
        }
        func objectValue(depth: Int) throws -> [String: Value] {
        guard depth <= 2 else { throw reject() }
        try take(123); whitespace(); var object: [String: Value] = [:]
        if index < bytes.count, bytes[index] == 125 { index += 1 }
        else {
            while true {
                let key = try string()
                guard object[key] == nil, object.count < 16 else { throw reject() }
                try take(58); whitespace(); guard index < bytes.count else { throw reject() }
                let value: Value
                if bytes[index] == 34 { value = .string(try string()) }
                else if bytes[index] == 123 { value = .object(try objectValue(depth: depth + 1)) }
                else if bytes[index...].starts(with: Array("true".utf8)) { index += 4; value = .bool(true) }
                else if bytes[index...].starts(with: Array("false".utf8)) { index += 5; value = .bool(false) }
                else {
                    let start = index
                    while index < bytes.count, (48...57).contains(bytes[index]) { index += 1 }
                    let token = String(decoding: bytes[start..<index], as: UTF8.self)
                    guard !token.isEmpty, token == "0" || !token.hasPrefix("0"),
                          let integer = Int64(token), integer <= 9_007_199_254_740_991 else { throw reject() }
                    value = .integer(integer)
                }
                object[key] = value; whitespace(); guard index < bytes.count else { throw reject() }
                if bytes[index] == 125 { index += 1; break }
                try take(44)
            }
        }
        return object
        }
        let object = try objectValue(depth: 0)
        whitespace(); guard index == bytes.count else { throw reject() }
        return object
    }
}
