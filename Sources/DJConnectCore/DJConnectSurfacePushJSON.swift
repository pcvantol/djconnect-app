import Foundation

/// Bounded recognizer for this integer-only Core wire, before Codable decoding.
/// Rejects duplicate decoded keys, invalid Unicode and unsafe numeric tokens at
/// every depth. No normalized dictionary can erase conflicting authority fields.
enum DJConnectSurfacePushJSON {
    static func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count <= 65536, String(data:data,encoding:.utf8) != nil else { throw DJConnectError.invalidResponse }
        let b = Array(data); var i = 0
        func fail() -> DJConnectError { .invalidResponse }
        func space() { while i < b.count && [9,10,13,32].contains(b[i]) { i += 1 } }
        func take(_ c: UInt8) throws { space(); guard i < b.count && b[i] == c else { throw fail() }; i += 1 }
        func string() throws -> String {
            space(); let start = i; try take(34)
            while i < b.count {
                if b[i] == 92 { i += 2; continue }
                if b[i] == 34 {
                    i += 1
                    guard let s = try? JSONDecoder().decode(String.self,from:Data(b[start..<i])) else { throw fail() }
                    return s
                }
                i += 1
            }
            throw fail()
        }
        func value(_ depth: Int) throws {
            guard depth <= 16 else { throw fail() }; space(); guard i < b.count else { throw fail() }
            switch b[i] {
            case 123:
                i += 1; space(); var keys = Set<String>()
                if i < b.count && b[i] == 125 { i += 1; return }
                while true {
                    guard keys.insert(try string()).inserted else { throw fail() }
                    try take(58); try value(depth + 1); space()
                    if i < b.count && b[i] == 125 { i += 1; return }
                    try take(44)
                }
            case 91:
                i += 1; space(); if i < b.count && b[i] == 93 { i += 1; return }
                while true {
                    try value(depth + 1); space()
                    if i < b.count && b[i] == 93 { i += 1; return }
                    try take(44)
                }
            case 34: _ = try string()
            case 116,102,110:
                let literal = b[i] == 116 ? Array("true".utf8) : b[i] == 102 ? Array("false".utf8) : Array("null".utf8)
                guard i + literal.count <= b.count && Array(b[i..<i+literal.count]) == literal else { throw fail() }; i += literal.count
            default:
                let start = i
                if b[i] == 45 { i += 1 }
                let digits = i
                while i < b.count && (48...57).contains(b[i]) { i += 1 }
                guard i > digits, i - digits == 1 || b[digits] != 48,
                      let number = Int64(String(decoding:b[start..<i],as:UTF8.self)),
                      (-9_007_199_254_740_991...9_007_199_254_740_991).contains(number) else { throw fail() }
            }
        }
        space(); guard i < b.count && b[i] == 123 else { throw fail() }
        try value(0); space(); guard i == b.count else { throw fail() }
    }
}
