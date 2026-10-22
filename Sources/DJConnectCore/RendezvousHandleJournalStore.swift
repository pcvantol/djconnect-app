import Foundation

/// Source-preparation store only. There is intentionally no shared instance,
/// bootstrap/import allocator, slot-reuse, activation or product factory yet.
/// A missing/malformed root never creates an empty child or initial permission.
final class RendezvousHandleJournalStore: @unchecked Sendable {
    enum Failure: Error { case missingRoot, invalidRoot, closed, staleBinding, unownedWriter, readRequired, conflict, overflow, invalidPayload, uncertainWrite, rollback }
    enum Channel: String, CaseIterable, Codable, Sendable {
        case registration, recovery, repair, submission
        var maximumBytes: Int {
            switch self {
            case .registration: 98_304
            case .recovery: 24_576
            case .repair: 16_384
            case .submission: 65_536
            }
        }
    }
    struct Binding: Codable, Equatable, Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        let slot: Int
        let sequence: UInt64
        let generationID: UUID
        let keyIdentifier: String
        var description: String { "RendezvousChildBinding(redacted)" }
        var debugDescription: String { description }
    }
    enum Disposition: String, Codable, Sendable { case selected, candidate, retired }
    struct Payload: Codable, Sendable {
        var revision: UInt64
        var bytes: Data?
    }
    struct Slot: Codable, Sendable {
        let binding: Binding
        var disposition: Disposition
        var channels: [String: Payload]
    }
    /// Internal prototype schema for an already reconciled installation. No
    /// production caller can create/import one through this class's API.
    struct Record: Codable, Sendable {
        var schemaVersion: Int
        let context: Data
        let lockIdentity: RendezvousLocalStorageExclusion.Identity
        var lastSequence: UInt64
        var selectedSequence: UInt64?
        var closed: Bool
        var slots: [Slot]
    }
    private struct ReadVersion { let bytes: Data?; let revision: UInt64 }
    private struct VersionKey: Hashable { let binding: Binding; let channel: Channel }
    private let context: Data
    private let backing: any RendezvousRepairStorage
    private let exclusion: RendezvousLocalStorageExclusion
    // Accessed only under the physical exclusion; bounded to the current two slots.
    private var highestSequence: UInt64 = 0
    private var observedRevisions: [VersionKey: UInt64] = [:]
    private static let maximumBytes = 2 * Channel.allCases.reduce(0) { $0 + (($1.maximumBytes + 2) / 3) * 4 } + 16_384

    init(context: Data, backing: any RendezvousRepairStorage, exclusion: RendezvousLocalStorageExclusion) throws {
        guard context.count == 32 else { throw Failure.invalidRoot }
        self.context = context; self.backing = backing; self.exclusion = exclusion
    }

    /// A binding is only a storage fence. It supplies no lifecycle/SDK authority.
    func childStorage(binding: Binding, channel: Channel) throws -> any RendezvousRepairStorage {
        try exclusion.perform { _ = try checkedSlot(in: readRecord(), binding: binding) }
        return ChildStorage(store: self, binding: binding, channel: channel)
    }
    func bindings() throws -> [Binding] {
        try exclusion.perform { try readRecord().slots.map(\.binding) }
    }
    private func read(binding: Binding, channel: Channel) throws -> ReadVersion {
        try exclusion.perform {
            let slot = try checkedSlot(in: readRecord(), binding: binding)
            let payload = slot.channels[channel.rawValue]!
            return .init(bytes: payload.bytes, revision: payload.revision)
        }
    }
    private func write(_ bytes: Data, binding: Binding, channel: Channel, expectedRevision: UInt64) throws -> UInt64 {
        try exclusion.perform {
            var root = try readRecord()
            _ = try checkedSlot(in: root, binding: binding)
            let index = root.slots.firstIndex { $0.binding == binding }!
            let current = root.slots[index].channels[channel.rawValue]!
            guard current.revision == expectedRevision else { throw Failure.conflict }
            let (next, overflow) = current.revision.addingReportingOverflow(1)
            guard !overflow else { throw Failure.overflow }
            try validatePayload(bytes, binding: binding, channel: channel)
            root.slots[index].channels[channel.rawValue] = .init(revision: next, bytes: bytes)
            try validate(root)
            let encoded = try JSONEncoder().encode(root)
            guard encoded.count <= Self.maximumBytes else { throw Failure.invalidRoot }
            try backing.write(encoded)
            // A silent/uncertain persistence result cannot release a reservation
            // or advance the caller's expected revision as if it were committed.
            guard try backing.read() == encoded else { throw Failure.uncertainWrite }
            observedRevisions[.init(binding: binding, channel: channel)] = next
            return next
        }
    }
    private func checkedSlot(in root: Record, binding: Binding) throws -> Slot {
        guard !root.closed else { throw Failure.closed }
        guard let slot = root.slots.first(where: { $0.binding == binding }), slot.disposition != .retired else { throw Failure.staleBinding }
        return slot
    }
    private func readRecord() throws -> Record {
        guard let data = try backing.read() else { throw Failure.missingRoot }
        guard !data.isEmpty, data.count <= Self.maximumBytes else { throw Failure.invalidRoot }
        let root: Record
        do { root = try JSONDecoder().decode(Record.self, from: data) }
        catch { throw Failure.invalidRoot }
        try validate(root)
        guard root.lastSequence >= highestSequence else { throw Failure.rollback }
        var seen: [VersionKey: UInt64] = [:]
        for slot in root.slots {
            for channel in Channel.allCases {
                let key = VersionKey(binding: slot.binding, channel: channel)
                let revision = slot.channels[channel.rawValue]!.revision
                guard revision >= (observedRevisions[key] ?? 0) else { throw Failure.rollback }
                seen[key] = revision
            }
        }
        highestSequence = root.lastSequence; observedRevisions = seen
        return root
    }
    private func validate(_ root: Record) throws {
        guard root.schemaVersion == 1, root.context == context, root.lockIdentity == exclusion.identity, root.lastSequence > 0,
              !root.slots.isEmpty, root.slots.count <= 2,
              Set(root.slots.map { $0.binding.slot }).count == root.slots.count,
              Set(root.slots.map { $0.binding.sequence }).count == root.slots.count,
              Set(root.slots.map { $0.binding.generationID }).count == root.slots.count,
              Set(root.slots.map { $0.binding.keyIdentifier }).count == root.slots.count else { throw Failure.invalidRoot }
        let selected = root.slots.filter { $0.disposition == .selected }
        guard selected.count <= 1, root.slots.filter({ $0.disposition == .candidate }).count <= 1,
              selected.first?.binding.sequence == root.selectedSequence else { throw Failure.invalidRoot }
        for slot in root.slots {
            guard (0...1).contains(slot.binding.slot), slot.binding.sequence > 0,
                  slot.binding.sequence <= root.lastSequence,
                  DJConnectRendezvousSubmitChallenge.canonicalKeyID(slot.binding.keyIdentifier),
                  Set(slot.channels.keys) == Set(Channel.allCases.map(\.rawValue)) else { throw Failure.invalidRoot }
            for channel in Channel.allCases {
                let payload = slot.channels[channel.rawValue]!
                if let bytes = payload.bytes {
                    guard payload.revision > 0, slot.disposition != .retired else { throw Failure.invalidRoot }
                    try validatePayload(bytes, binding: slot.binding, channel: channel)
                } else if slot.disposition != .retired, payload.revision != 0 { throw Failure.invalidRoot }
            }
        }
    }
    private func validatePayload(_ bytes: Data, binding: Binding, channel: Channel) throws {
        guard !bytes.isEmpty, bytes.count <= channel.maximumBytes,
              let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              object[channel == .repair ? "keyIdentifier" : "key"] as? String == binding.keyIdentifier else { throw Failure.invalidPayload }
        if channel == .submission {
            guard let raw = object["context"] as? String, Data(base64Encoded: raw) == context else { throw Failure.invalidPayload }
        }
        // Existing owning journals still validate their complete schemas, clock,
        // original requests and retry transitions. This store adds no such grant.
    }

    private final class ChildStorage: RendezvousRepairStorage, @unchecked Sendable {
        private let store: RendezvousHandleJournalStore
        private let binding: Binding
        private let channel: Channel
        private let lock = NSLock()
        private var observedRevision: UInt64?
        private var journalOwner: UUID?
        init(store: RendezvousHandleJournalStore, binding: Binding, channel: Channel) {
            self.store = store; self.binding = binding; self.channel = channel
        }
        func read() throws -> Data? { throw Failure.unownedWriter }
        func write(_ data: Data) throws { throw Failure.unownedWriter }
        func claimingJournalOwner(_ identity: UUID) -> any RendezvousRepairStorage {
            lock.withLock {
                if journalOwner == nil { journalOwner = identity }
                guard journalOwner == identity else { return DeniedStorage() }
                return WriterStorage(child: self, identity: identity)
            }
        }
        private func read(owner: UUID) throws -> Data? {
            try lock.withLock {
                guard journalOwner == owner else { throw Failure.unownedWriter }
                let value = try store.read(binding: binding, channel: channel)
                if let previous = observedRevision, value.revision < previous { throw Failure.rollback }
                observedRevision = value.revision
                return value.bytes
            }
        }
        private func write(_ data: Data, owner: UUID) throws {
            try lock.withLock {
                guard journalOwner == owner else { throw Failure.unownedWriter }
                guard let expected = observedRevision else { throw Failure.readRequired }
                let next = try store.write(data, binding: binding, channel: channel, expectedRevision: expected)
                observedRevision = next
            }
        }
        private final class WriterStorage: RendezvousRepairStorage, Sendable {
            let child: ChildStorage
            let identity: UUID
            init(child: ChildStorage, identity: UUID) { self.child = child; self.identity = identity }
            func read() throws -> Data? { try child.read(owner: identity) }
            func write(_ data: Data) throws { try child.write(data, owner: identity) }
            func claimingJournalOwner(_ identity: UUID) -> any RendezvousRepairStorage { child.claimingJournalOwner(identity) }
        }
        private struct DeniedStorage: RendezvousRepairStorage {
            func read() throws -> Data? { throw Failure.unownedWriter }
            func write(_ data: Data) throws { throw Failure.unownedWriter }
        }
    }
}
