import Foundation

/// Installation-local companion correlation, never a backend owner or grant.
/// A reset rotates this intent even when the Watch device ID remains unchanged.
public struct DJConnectWatchPairingIntent: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let deviceID: String
    public let identifier: String
    public let pairCode: String
    public var description: String { "WatchPairingIntent(redacted)" }
    public var debugDescription: String { description }
    public init?(deviceID: String, identifier: String, pairCode: String) {
        guard deviceID.hasPrefix("djconnect-watchos-"), deviceID.utf8.count <= 256,
              UUID(uuidString: identifier)?.uuidString.lowercased() == identifier,
              pairCode.utf8.count == 6, pairCode.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        self.deviceID = deviceID; self.identifier = identifier; self.pairCode = pairCode
    }
    public static func load(defaults: UserDefaults, deviceID: String, pairCode: String,
                            reset: Bool = false) -> Self? {
        let key = "DJConnectWatchCompanionPairingIntent"
        let identifier: String
        if reset || defaults.object(forKey: key) == nil {
            identifier = UUID().uuidString.lowercased()
            defaults.set(identifier, forKey: key)
        } else { identifier = defaults.string(forKey: key) ?? "" }
        guard defaults.string(forKey: key) == identifier else { return nil }
        return Self(deviceID: deviceID, identifier: identifier, pairCode: pairCode)
    }
    /// Validate the exact receiver/intent before any credential-store write.
    /// Old companions without correlation cannot deliver a new credential.
    @discardableResult public func receive(deviceID: String?, identifier: String?, pairCode: String?,
                                            token: String?, existingToken: String? = nil,
                                            save: (String) throws -> Void) throws -> Bool {
        guard deviceID == self.deviceID, identifier == self.identifier, pairCode == self.pairCode,
              let token, !token.isEmpty, token.utf8.count <= 16_384,
              existingToken.map({ $0 == token }) ?? true else { return false }
        try save(token)
        return true
    }
}

/// The commit is synchronous on the same actor as the final owner check. A late
/// success/error after cancellation or context ABA cannot mutate UI or emit a token.
@MainActor public enum DJConnectWatchPairingReadback {
    @discardableResult public static func perform(isCurrent: () -> Bool,
        read: () async throws -> Void, commit: () -> Void) async throws -> Bool {
        guard !Task.isCancelled, isCurrent() else { return false }
        do { try await read() }
        catch {
            guard !Task.isCancelled, isCurrent() else { return false }
            throw error
        }
        guard !Task.isCancelled, isCurrent() else { return false }
        commit()
        return true
    }
}
