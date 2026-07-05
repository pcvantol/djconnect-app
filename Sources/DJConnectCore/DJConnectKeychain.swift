import Foundation

public protocol DJConnectTokenStore: Sendable {
    func loadToken() throws -> String?
    func saveToken(_ token: String) throws
    func clearToken() throws
}

public final class DJConnectInMemoryTokenStore: DJConnectTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    public init(token: String? = nil) {
        self.token = token
    }

    public func loadToken() throws -> String? {
        lock.withLock { token }
    }

    public func saveToken(_ token: String) throws {
        lock.withLock {
            self.token = token
        }
    }

    public func clearToken() throws {
        lock.withLock {
            token = nil
        }
    }
}

public final class DJConnectUserDefaultsTokenStore: DJConnectTokenStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "DJConnectDeviceToken") {
        self.defaults = defaults
        self.key = key
    }

    public func loadToken() throws -> String? {
        defaults.string(forKey: key)
    }

    public func saveToken(_ token: String) throws {
        defaults.set(token, forKey: key)
    }

    public func clearToken() throws {
        defaults.removeObject(forKey: key)
    }
}
