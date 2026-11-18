import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Actual process-local samples, captured before scheduling/awaiting a read.
/// Not Codable, not a source permission, and not a qualified rate/restore map.
public struct DJConnectNativeSurfaceClockCapture: Sendable {
    public static let localProfileID = "darwin-mach-continuous-warm-v1"
    public let continuous: ContinuousClock.Instant
    public let wall: Date
    public let uptime: TimeInterval
    public let process: UUID
    public let processID: Int32
    public let bootSession: UUID?
    public let continuousTicksBefore: UInt64?
    public let continuousTicks: UInt64?
    public let timebaseNumerator: UInt32?
    public let timebaseDenominator: UInt32?
    private static let processIdentity = UUID()

    public enum MissingQualification: Sendable { case originalPermission, crossDomainRate, restartRestoration }
    public var missingQualifications: [MissingQualification] { [.originalPermission, .crossDomainRate, .restartRestoration] }

    private init() {
        // Bracket the Swift instant in the actual continuous counter domain.
        // This whole capture precedes task scheduling and network IO.
        #if canImport(Darwin)
        continuousTicksBefore = mach_continuous_time()
        #else
        continuousTicksBefore = nil
        #endif
        continuous = ContinuousClock.now
        #if canImport(Darwin)
        continuousTicks = mach_continuous_time()
        var timebase = mach_timebase_info_data_t()
        if mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.numer > 0, timebase.denom > 0 {
            timebaseNumerator = timebase.numer; timebaseDenominator = timebase.denom
        } else { timebaseNumerator = nil; timebaseDenominator = nil }
        bootSession = Self.readBootSession()
        #else
        continuousTicks = nil; timebaseNumerator = nil; timebaseDenominator = nil; bootSession = nil
        #endif
        uptime = ProcessInfo.processInfo.systemUptime
        wall = Date()
        process = Self.processIdentity
        processID = ProcessInfo.processInfo.processIdentifier
    }
    public static func capture() -> Self { Self() }

    public enum Elapsed: Equatable, Sendable {
        case measuredNanoseconds(UInt64)
        case unavailable(Reason)
        public enum Reason: Equatable, Sendable { case processChanged, bootIdentityUnavailable, bootChanged, counterUnavailable, counterRollback, conversionOverflow }
    }
    /// Local warm-domain measurement only. This does not compare server time
    /// or supply rho_min. Cold restore and missing boot evidence stay closed.
    public func localCounterElapsedFloor(to later: Self) -> Elapsed {
        guard process == Self.processIdentity, later.process == process,
              processID == ProcessInfo.processInfo.processIdentifier, later.processID == processID else { return .unavailable(.processChanged) }
        guard let bootSession, let nextBoot = later.bootSession else { return .unavailable(.bootIdentityUnavailable) }
        guard bootSession == nextBoot else { return .unavailable(.bootChanged) }
        guard let start = continuousTicks, let end = later.continuousTicksBefore,
              let numerator = timebaseNumerator, let denominator = timebaseDenominator,
              numerator == later.timebaseNumerator, denominator == later.timebaseDenominator else { return .unavailable(.counterUnavailable) }
        guard continuous <= later.continuous, start <= end else { return .unavailable(.counterRollback) }
        guard let ns = Self.nanosecondsFloor(ticks: end - start, numerator: numerator, denominator: denominator) else { return .unavailable(.conversionOverflow) }
        // end-before minus start-after measures an interior counter interval.
        // Its units are this Mach domain only, not a server or Swift-clock rate
        // assertion. Flooring never enlarges the exact rational counter value.
        return .measuredNanoseconds(ns)
    }
    static func nanosecondsFloor(ticks: UInt64, numerator: UInt32, denominator: UInt32) -> UInt64? {
        guard numerator > 0, denominator > 0 else { return nil }
        let product = ticks.multipliedFullWidth(by: UInt64(numerator))
        let divisor = UInt64(denominator)
        guard product.high < divisor else { return nil }
        return divisor.dividingFullWidth(product).quotient
    }

    #if canImport(Darwin)
    private static func readBootSession() -> UUID? {
        var count = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &count, nil, 0) == 0, (2...128).contains(count) else { return nil }
        var bytes = [UInt8](repeating: 0, count: count)
        let result = bytes.withUnsafeMutableBytes { buffer in
            sysctlbyname("kern.bootsessionuuid", buffer.baseAddress, &count, nil, 0)
        }
        guard result == 0, count > 1, count <= bytes.count, bytes[count - 1] == 0,
              let text = String(bytes: bytes.prefix(count - 1), encoding: .utf8) else { return nil }
        return UUID(uuidString: text)
    }
    #endif
}
