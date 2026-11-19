import Foundation

/// Exact original ISO8601 value arithmetic, not a wall-clock observation or a
/// server/native clock qualification. Fractional source digits are never
/// rounded through Double before conservative millisecond comparison.
struct DirectRichWireInstant: Sendable, Comparable {
    let seconds: Int64
    let fractionalDigits: String
    let floorMilliseconds: Int64
    let ceilMilliseconds: Int64

    init(_ original: String) throws {
        let pattern = "\\A([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\\.([0-9]+))?(Z|[+-][0-9]{2}:[0-9]{2})\\z"
        guard original.utf8.count <= 64, let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: original, range: NSRange(original.startIndex..., in: original)) else { throw DJConnectError.invalidResponse }
        func part(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: original) else { return "" }; return String(original[range])
        }
        let year = Int(part(1))!, month = Int(part(2))!, day = Int(part(3))!
        let hour = Int(part(4))!, minute = Int(part(5))!, second = Int(part(6))!
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else { throw DJConnectError.invalidResponse }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fields = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let whole = calendar.date(from: fields) else { throw DJConnectError.invalidResponse }
        let actual = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: whole)
        guard actual.year == year, actual.month == month, actual.day == day,
              actual.hour == hour, actual.minute == minute, actual.second == second else { throw DJConnectError.invalidResponse }
        let zone = part(8)
        var offset: Int64 = 0
        if zone != "Z" {
            let h = Int(zone.dropFirst().prefix(2))!, m = Int(zone.suffix(2))!
            guard h <= 23, m <= 59 else { throw DJConnectError.invalidResponse }
            offset = Int64(h * 3600 + m * 60) * (zone.first == "-" ? -1 : 1)
        }
        // Whole Gregorian seconds in this bounded year range are exact binary
        // integers. Only that integer passes through Foundation's Date.
        let epoch = whole.timeIntervalSince1970
        guard epoch.isFinite, epoch == epoch.rounded(), abs(epoch) < 300000000000 else { throw DJConnectError.invalidResponse }
        seconds = Int64(epoch) - offset
        fractionalDigits = part(7)
        let ms = Int64((fractionalDigits + "000").prefix(3))!
        floorMilliseconds = seconds * 1000 + ms
        ceilMilliseconds = floorMilliseconds + (fractionalDigits.dropFirst(3).contains(where: { $0 != "0" }) ? 1 : 0)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.seconds != rhs.seconds { return lhs.seconds < rhs.seconds }
        let count = max(lhs.fractionalDigits.count, rhs.fractionalDigits.count)
        return lhs.fractionalDigits.padding(toLength: count, withPad: "0", startingAt: 0) < rhs.fractionalDigits.padding(toLength: count, withPad: "0", startingAt: 0)
    }
    static func == (lhs: Self, rhs: Self) -> Bool { !(lhs < rhs) && !(rhs < lhs) }
    func intervalEndsWithin120Seconds(_ end: Self) -> Bool {
        guard self < end else { return false }
        let delta = end.seconds - seconds
        if delta < 120 { return true }
        if delta > 120 { return false }
        let count = max(fractionalDigits.count, end.fractionalDigits.count)
        return end.fractionalDigits.padding(toLength: count, withPad: "0", startingAt: 0) <= fractionalDigits.padding(toLength: count, withPad: "0", startingAt: 0)
    }
}
