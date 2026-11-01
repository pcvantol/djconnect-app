import Foundation
import CryptoKit

/// The new direct wire's primitive domain. This is data, never a display permit.
/// Its canonical encoder preserves Unicode scalar sequences (including NFD)
/// and matches Core's ensure_ascii=false, sorted ASCII keys, compact JSON.
indirect enum DirectRichWireJSON: Equatable, Sendable, Decodable {
    case object([String: Self]), array([Self]), string(String), integer(Int64), bool(Bool), null

    private struct Key: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: any Decoder) throws {
        guard decoder.codingPath.count <= 8 else { throw DJConnectError.invalidResponse }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { self = .null }
        else if let value = try? single.decode(Bool.self) { self = .bool(value) }
        else if let value = try? single.decode(Int64.self) {
            guard (-9_007_199_254_740_991...9_007_199_254_740_991).contains(value) else { throw DJConnectError.invalidResponse }
            self = .integer(value)
        } else if let value = try? single.decode(String.self) { self = .string(value) }
        else if var items = try? decoder.unkeyedContainer() {
            var values = [Self]()
            while !items.isAtEnd { values.append(try items.decode(Self.self)) }
            self = .array(values)
        } else {
            let keyed = try decoder.container(keyedBy: Key.self)
            var values = [String: Self]()
            for key in keyed.allKeys {
                guard key.stringValue.unicodeScalars.allSatisfy({ $0.value < 128 }) else { throw DJConnectError.invalidResponse }
                values[key.stringValue] = try keyed.decode(Self.self, forKey: key)
            }
            self = .object(values)
        }
    }

    static func parse(_ bytes: Data, maximumBytes: Int) throws -> Self {
        guard !bytes.isEmpty, bytes.count <= maximumBytes else { throw DJConnectError.invalidResponse }
        // The frozen recognizer rejects duplicate *decoded* keys, unsafe ints,
        // floats, invalid UTF8/surrogates and trailing input before any decoding.
        try DJConnectSurfacePushJSON.validate(bytes)
        return try JSONDecoder().decode(Self.self, from: bytes)
    }

    func canonicalData() throws -> Data {
        var output = ""
        func quoted(_ value: String) -> String {
            var result = "\""
            for scalar in value.unicodeScalars {
                switch scalar.value {
                case 34: result += "\\\""
                case 92: result += "\\\\"
                case 8: result += "\\b"
                case 9: result += "\\t"
                case 10: result += "\\n"
                case 12: result += "\\f"
                case 13: result += "\\r"
                case 0...31: result += String(format: "\\u%04x", scalar.value)
                default: result.unicodeScalars.append(scalar)
                }
            }
            return result + "\""
        }
        func append(_ value: Self, depth: Int) throws {
            guard depth <= 8 else { throw DJConnectError.invalidResponse }
            switch value {
            case .null: output += "null"
            case .bool(let flag): output += flag ? "true" : "false"
            case .integer(let number):
                guard (-9_007_199_254_740_991...9_007_199_254_740_991).contains(number) else { throw DJConnectError.invalidResponse }
                output += String(number)
            case .string(let text): output += quoted(text)
            case .array(let values):
                output += "["
                for (index, child) in values.enumerated() {
                    if index > 0 { output += "," }; try append(child, depth: depth + 1)
                }
                output += "]"
            case .object(let values):
                guard values.keys.allSatisfy({ $0.unicodeScalars.allSatisfy({ $0.value < 128 }) }) else { throw DJConnectError.invalidResponse }
                output += "{"
                for (index, key) in values.keys.sorted().enumerated() {
                    if index > 0 { output += "," }
                    output += quoted(key) + ":"; try append(values[key]!, depth: depth + 1)
                }
                output += "}"
            }
        }
        try append(self, depth: 0)
        return Data(output.utf8)
    }

    func digest() throws -> String {
        SHA256.hash(data: try canonicalData()).map { String(format: "%02x", $0) }.joined()
    }

    var object: [String: Self]? { if case .object(let value) = self { value } else { nil } }
    var string: String? { if case .string(let value) = self { value } else { nil } }
    var integer: Int64? { if case .integer(let value) = self { value } else { nil } }
    var array: [Self]? { if case .array(let value) = self { value } else { nil } }
}
