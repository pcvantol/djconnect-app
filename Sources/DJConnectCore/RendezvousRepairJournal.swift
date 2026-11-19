import Foundation
import LocalAuthentication
import Security

// Internal seam for deterministic storage-failure qualification. Production has
// one journal, one fixed Keychain address and no public reset/delete operation.
protocol RendezvousRepairStorage: Sendable {
    func read() throws -> Data?
    func write(_ data: Data) throws
    func claimingJournalOwner(_ identity: UUID) -> any RendezvousRepairStorage
}

extension RendezvousRepairStorage {
    /// Legacy stores retain their existing actor ownership. A composed child
    /// overrides this to prevent two journal actors sharing one mutable CAS view.
    func claimingJournalOwner(_ identity: UUID) -> any RendezvousRepairStorage { self }
}

final class RendezvousRepairKeychainStorage: RendezvousRepairStorage {
    enum Failure: Error { case status(OSStatus), invalidItem }
    private let service: String
    private let account: String

    init(service: String = RendezvousBuildProfile.storageNamespace + ".repair", account: String = "paused-recovery-v1") {
        self.service = service
        self.account = account
    }

    private var query: [String: Any] {
        let authentication = LAContext()
        authentication.interactionNotAllowed = true
        var value: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecUseAuthenticationContext as String: authentication
        ]
        #if os(macOS)
        value[kSecUseDataProtectionKeychain as String] = true
        #endif
        return value
    }

    func read() throws -> Data? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecReturnAttributes as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure.status(status) }
        guard let attributes = result as? [String: Any],
              let data = attributes[kSecValueData as String] as? Data,
              let accessible = attributes[kSecAttrAccessible as String] as? String,
              accessible == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
              (attributes[kSecAttrSynchronizable as String] as? Bool) != true else {
            throw Failure.invalidItem
        }
        return data
    }

    func write(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure.status(added) }
        } else if status != errSecSuccess {
            throw Failure.status(status)
        }
    }
}

/// Protected persistence for paused same-key recovery accounting only.
/// The returned reservation authorizes accounting, not an SDK/API action. Use
/// the complete per-key queue and revalidate action/context/deadlines separately.
public actor RendezvousRepairJournal {
    public static let shared = RendezvousRepairJournal(storage: RendezvousRepairKeychainStorage())
    public enum Failure: Error, Sendable { case missingState, wrongKey, invalidData }
    private let storage: any RendezvousRepairStorage
    private static let maximumBytes = 16_384

    init(storage: any RendezvousRepairStorage) { self.storage = storage.claimingJournalOwner(UUID()) }

    /// Repeated pause entry preserves all counters, including after completion.
    /// Another key cannot replace this unresolved ledger through this API.
    public func beginPause(keyIdentifier: String, at nowMS: Int64) async throws -> RendezvousRepairWindow {
        guard RendezvousAppKeyOperations.initialEnrollmentLease == nil else { throw Failure.invalidData }
        return try await RendezvousAppKeyOperations.shared.perform(keyIdentifier:RendezvousAppKeyOperations.installationAdmissionSlot) {
            try await self.beginPauseLocked(keyIdentifier:keyIdentifier,at:nowMS)
        }
    }
    private func beginPauseLocked(keyIdentifier:String,at nowMS:Int64) throws -> RendezvousRepairWindow {
        if let current = try snapshot() {
            guard current.keyIdentifier == keyIdentifier else { throw Failure.wrongKey }
            return current
        }
        let state = try RendezvousRepairWindow(keyIdentifier: keyIdentifier, pausedAtMS: nowMS)
        try persist(state)
        return state
    }

    public func snapshot() throws -> RendezvousRepairWindow? {
        guard let bytes = try storage.read() else { return nil }
        guard !bytes.isEmpty, bytes.count <= Self.maximumBytes else { throw Failure.invalidData }
        do { return try JSONDecoder().decode(RendezvousRepairWindow.self, from: bytes) }
        catch { throw Failure.invalidData }
    }

    /// No reservation escapes this method unless its storage write succeeds.
    /// A write whose result is uncertain must be resolved by reading the journal;
    /// it cannot be treated as permission to start external work.
    public func reserveExplicitRecovery(keyIdentifier: String, at nowMS: Int64) throws -> UUID {
        var state = try requiredState(keyIdentifier)
        let id = try state.reserveExplicitRecovery(at: nowMS)
        try persist(state)
        return id
    }

    public func complete(keyIdentifier: String, reservation: UUID,
                         outcome: RendezvousRepairWindow.Outcome, notBeforeMS: Int64? = nil,
                         at nowMS: Int64) throws {
        var state = try requiredState(keyIdentifier)
        // Pacing and completion are one durable write. If persistence fails,
        // the old in-flight reservation remains occupied (or both changes are
        // committed); completion can never escape without its server delay.
        if let notBeforeMS { try state.delayRecovery(until: notBeforeMS, at: nowMS) }
        try state.complete(reservation, outcome: outcome, at: nowMS)
        try persist(state)
    }

    public func delayRecovery(keyIdentifier: String, until notBeforeMS: Int64, at nowMS: Int64) throws {
        var state = try requiredState(keyIdentifier)
        try state.delayRecovery(until: notBeforeMS, at: nowMS)
        try persist(state)
    }

    private func requiredState(_ key: String) throws -> RendezvousRepairWindow {
        guard let state = try snapshot() else { throw Failure.missingState }
        guard state.keyIdentifier == key else { throw Failure.wrongKey }
        return state
    }

    private func persist(_ state: RendezvousRepairWindow) throws {
        let bytes = try JSONEncoder().encode(state)
        guard bytes.count <= Self.maximumBytes else { throw Failure.invalidData }
        // Synchronous storage inside the actor: no actor reentrancy between the
        // read/mutation/write. This is not a cross-process compare-and-swap lock.
        try storage.write(bytes)
    }
}
