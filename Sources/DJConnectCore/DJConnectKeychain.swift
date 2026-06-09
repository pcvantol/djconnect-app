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

    public init(service: String, account: String = "device_token") {
        self.service = service
        self.account = account
    }

    public func loadToken() throws -> String? {
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
        return String(data: data, encoding: .utf8)
    }

    public func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery()
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw DJConnectKeychainError.unhandledStatus(addStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw DJConnectKeychainError.unhandledStatus(status)
        }
    }

    public func clearToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DJConnectKeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public enum DJConnectKeychainError: Error, Equatable, Sendable {
    case unhandledStatus(OSStatus)
}
