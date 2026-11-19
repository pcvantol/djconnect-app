import Testing
@testable import DJConnectCore

@Suite struct DirectRichWireInstantTests {
    @Test func exactSourceFractionsRoundOnlyInConservativeDirection() throws {
        let value = try DirectRichWireInstant("2026-10-31T10:00:00.000000001+00:00")
        #expect(value.floorMilliseconds == 1793440800000)
        #expect(value.ceilMilliseconds == 1793440800001)
        let original = try DirectRichWireInstant("2026-10-31T12:00:00.001000000+02:00")
        #expect(original.floorMilliseconds == value.ceilMilliseconds)
        #expect(original.ceilMilliseconds == original.floorMilliseconds)
        #expect(try DirectRichWireInstant("2026-10-31T10:00:00Z") == DirectRichWireInstant("2026-10-31T10:00:00.000000000+00:00"))
    }
    @Test func exact120SecondCapDoesNotGetFloatingPointTolerance() throws {
        let start = try DirectRichWireInstant("2026-10-31T10:00:00.123456+00:00")
        #expect(try start.intervalEndsWithin120Seconds(DirectRichWireInstant("2026-10-31T10:02:00.123456Z")))
        #expect(try !start.intervalEndsWithin120Seconds(DirectRichWireInstant("2026-10-31T10:02:00.123457Z")))
        #expect(!start.intervalEndsWithin120Seconds(start))
    }
    @Test(arguments: ["2026-02-30T10:00:00Z", "0000-01-01T00:00:00Z", "2026-10-31T24:00:00Z", "2026-10-31T10:00:60Z", "2026-10-31T10:00:00", "2026-10-31T10:00:00+24:00", "2026-10-31T10:00:00+00:60", "2026-10-31 10:00:00Z"])
    func invalidOriginalTimeCannotNormalizeIntoValidity(_ original: String) {
        #expect(throws: (any Error).self) { _ = try DirectRichWireInstant(original) }
    }
}
