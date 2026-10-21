import Foundation

/// No signed Apple profile or finite native-effect admission has been selected
/// for this source. Bundle ID, device support, owner context and a server guard
/// are not substitutes. Deliberately no environment/defaults/QR override.
public enum RendezvousNativeAdmission {
    public enum Failure: Error, Sendable { case notAdmitted }
    public static let isAdmitted = false

    static func require() throws {
        guard isAdmitted else { throw Failure.notAdmitted }
    }

    /// Final common boundary immediately before an actual DeviceCheck call.
    /// A future admission must bind the reviewed signed profile and finite run;
    /// changing a build flag or passing an owner predicate cannot grant it.
    @MainActor static func perform(_ effect: () throws -> Void) throws {
        try require()
        try effect()
    }
}
