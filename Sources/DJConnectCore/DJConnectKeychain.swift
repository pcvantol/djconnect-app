import Foundation
import Security

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

public final class DJConnectKeychainTokenStore: DJConnectTokenStore, @unchecked Sendable {
    private let service: String
    private let account: String
    private let requiresUserPresence: Bool
    private let cacheLock = NSLock()
    private var cachedToken: String?

    public init(
        service: String,
        account: String = "device_token",
        requiresUserPresence: Bool = false
    ) {
        self.service = service
        self.account = account
        self.requiresUserPresence = requiresUserPresence
    }

    public func loadToken() throws -> String? {
        if let cachedToken = cacheLock.withLock({ cachedToken }) {
            return cachedToken
        }

        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw DJConnectKeychainError.unhandledStatus(status)
        }
        guard let data = item as? Data else {
            return nil
        }
        let token = String(data: data, encoding: .utf8)
        cacheLock.withLock {
            cachedToken = token
        }
        return token
    }

    public func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery()
        let attributes = tokenAttributes(data: data)
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            tokenAttributes(data: data).forEach { key, value in
                query[key] = value
            }
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw DJConnectKeychainError.unhandledStatus(addStatus)
            }
            cacheLock.withLock {
                cachedToken = token
            }
            return
        }

        if status == errSecParam, requiresUserPresence {
            let fallbackStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard fallbackStatus == errSecSuccess else {
                throw DJConnectKeychainError.unhandledStatus(fallbackStatus)
            }
            cacheLock.withLock {
                cachedToken = token
            }
            return
        }

        guard status == errSecSuccess else {
            throw DJConnectKeychainError.unhandledStatus(status)
        }
        cacheLock.withLock {
            cachedToken = token
        }
    }

    public func clearToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DJConnectKeychainError.unhandledStatus(status)
        }
        cacheLock.withLock {
            cachedToken = nil
        }
    }

    func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func tokenAttributes(data: Data) -> [String: Any] {
        var attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        if requiresUserPresence, let accessControl = Self.makeUserPresenceAccessControl() {
            attributes[kSecAttrAccessControl as String] = accessControl
        } else {
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        return attributes
    }

    private static func makeUserPresenceAccessControl() -> SecAccessControl? {
        SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            nil
        )
    }
}

public enum DJConnectKeychainError: Error, Equatable, Sendable {
    case unhandledStatus(OSStatus)

    public var requiresUserAction: Bool {
        switch self {
        case let .unhandledStatus(status):
            status == errSecUserCanceled || status == errSecAuthFailed || status == errSecInteractionNotAllowed
        }
    }
}
