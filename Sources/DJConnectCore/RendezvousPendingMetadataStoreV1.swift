import Foundation

/// Comparison-only pending metadata prototype. No root creation, real shared
/// storage, lifecycle mutation, native admission, SDK or product factory.
/// Original reservation/floor provenance belongs to a later authenticated join.
actor RendezvousPendingMetadataStoreV1 {
    enum Failure: Error { case unavailable }
    enum State: Equatable, Sendable { case fresh, captured, attempted, closed }
    enum Outcome: Equatable, Sendable { case metadataRecorded }
    struct Comparison: Sendable {
        let originalRootBytes: Data
        let minimumRevision: UInt64
        let minimumSequence: UInt64
    }
    struct ConsumedAssociation: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let generationID: UUID
        let purpose: RendezvousKeyLifecycleJournal.Purpose
        let lifecycleDigest: Data
        var description: String { "ConsumedAssociationComparison(redacted)" }
        var debugDescription: String { description }
    }
    struct Snapshot: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        fileprivate let storeID: UUID
        fileprivate let bytes: Data
        fileprivate let revision: UInt64
        fileprivate let highWater: UInt64
        var description: String { "PendingMetadataSnapshot(redacted)" }
        var debugDescription: String { description }
    }
    private(set) var state: State = .fresh
    private let storeID = UUID()
    private let context: Data
    private let backing: any RendezvousRepairStorage
    private let exclusion: RendezvousLocalStorageExclusion
    private let original: Comparison
    private var minimumRevision: UInt64
    private var minimumSequence: UInt64

    init(context: Data, backing: any RendezvousRepairStorage,
         exclusion: RendezvousLocalStorageExclusion, comparison: Comparison?) throws {
        guard context.count == 32, let comparison,
              !comparison.originalRootBytes.isEmpty,
              comparison.originalRootBytes.count <= PendingRootV1Codec.maximumBytes,
              (1...PendingRootV1Codec.maximumInteger).contains(comparison.minimumRevision),
              comparison.minimumSequence <= PendingRootV1Codec.maximumInteger else { throw Failure.unavailable }
        self.context = context; self.backing = backing; self.exclusion = exclusion
        original = comparison; minimumRevision = comparison.minimumRevision
        minimumSequence = comparison.minimumSequence
    }
    /// One original capture only. Missing/invalid/busy state is terminal.
    func capture() throws -> Snapshot {
        guard state == .fresh else { state = .closed; throw Failure.unavailable }
        do {
            try Task.checkCancellation()
            let snapshot = try exclusion.perform {
                let (root, bytes) = try readOriginal()
                try Task.checkCancellation()
                return Snapshot(storeID: storeID, bytes: bytes, revision: root.revision,
                                highWater: root.metadata.lastSequence)
            }
            try Task.checkCancellation()
            state = .captured
            return snapshot
        } catch { state = .closed; throw Failure.unavailable }
    }
    /// Every invocation consumes at entry, including busy, stale and cancelled.
    /// Success reports metadata only and never an authentic reservation/key grant.
    func append(expected: Snapshot, consumed: ConsumedAssociation) throws -> Outcome {
        let priorState = state
        state = .attempted
        defer { state = .closed }
        do {
            guard priorState == .captured, expected.storeID == storeID,
                  consumed.lifecycleDigest.count == 32 else { throw Failure.unavailable }
            try Task.checkCancellation()
            let result = try exclusion.perform {
                let (root, bytes) = try readOriginal()
                guard bytes == expected.bytes, root.revision == expected.revision,
                      root.metadata.lastSequence == expected.highWater,
                      root.metadata.slots.count < 2,
                      !root.metadata.slots.contains(where: { $0.coordinates.generationID == consumed.generationID }),
                      root.revision < PendingRootV1Codec.maximumInteger,
                      root.metadata.lastSequence < PendingRootV1Codec.maximumInteger,
                      let slot = [0, 1].first(where: { index in !root.metadata.slots.contains(where: { $0.coordinates.slot == index }) })
                else { throw Failure.unavailable }
                let nextRevision = root.revision + 1
                let nextSequence = root.metadata.lastSequence + 1
                let row = RendezvousHandleCompositionEnvelopeV2.Slot.pending(.init(
                    slot: slot, sequence: nextSequence, generationID: consumed.generationID, purpose: consumed.purpose))
                let metadataBytes = try PendingRootV1Codec.metadataBytes(context: context,
                    identity: exclusion.identity, highWater: nextSequence,
                    slots: root.metadata.slots + [row], selected: root.metadata.selectedSequence)
                let metadata = try RendezvousHandleCompositionEnvelopeV2.decode(metadataBytes,
                    expectedContext: context, expectedLockIdentity: exclusion.identity, minimumSequence: nextSequence)
                var associations = root.associations; associations[slot] = consumed
                let encoded = try PendingRootV1Codec.encode(.init(revision: nextRevision,
                    metadata: metadata, associations: associations))
                _ = try PendingRootV1Codec.decode(encoded, context: context, identity: exclusion.identity,
                    minimumRevision: nextRevision, minimumSequence: nextSequence)
                try Task.checkCancellation()
                // Floors advance before the one write and never refund on failure.
                minimumRevision = nextRevision; minimumSequence = nextSequence
                try backing.write(encoded)
                guard try backing.read() == encoded else { throw Failure.unavailable }
                try Task.checkCancellation()
                return Outcome.metadataRecorded
            }
            try Task.checkCancellation()
            return result
        } catch { throw Failure.unavailable }
    }
    private func readOriginal() throws -> (PendingRootV1Codec.Root, Data) {
        guard let bytes = try backing.read(), bytes == original.originalRootBytes else { throw Failure.unavailable }
        return (try PendingRootV1Codec.decode(bytes, context: context, identity: exclusion.identity,
            minimumRevision: minimumRevision, minimumSequence: minimumSequence), bytes)
    }
}

/// Independently bounded outer storage codec. This never raises FlatJSON's
/// standalone metadata depth2 limit or accepts schema1 as a new root.
private enum PendingRootV1Codec {
    typealias Metadata = RendezvousHandleCompositionEnvelopeV2
    typealias Association = RendezvousPendingMetadataStoreV1.ConsumedAssociation
    static let maximumBytes = 16_384
    static let maximumInteger: UInt64 = 9_007_199_254_740_991
    struct Root {
        let revision: UInt64
        let metadata: Metadata
        let associations: [Int: Association]
    }
    private struct Header: Decodable { let pending_store_schema: Int; let revision: UInt64 }
    private struct AssociationRow: Decodable {
        let generation_id: UUID
        let purpose: RendezvousKeyLifecycleJournal.Purpose
        let lifecycle_digest: String
    }
    static func decode(_ bytes: Data, context: Data, identity: RendezvousLocalStorageExclusion.Identity,
                       minimumRevision: UInt64, minimumSequence: UInt64) throws -> Root {
        guard !bytes.isEmpty, bytes.count <= maximumBytes else { throw unavailable() }
        try DJConnectSurfacePushJSON.validate(bytes) // Unchanged duplicate-safe lexical reader.
        guard let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(object.keys) == ["pending_store_schema", "revision", "metadata", "consumed_associations"],
              let rawMetadata = object["metadata"] as? [String: Any],
              let rawAssociations = object["consumed_associations"] as? [String: Any],
              Set(rawAssociations.keys).isSubset(of: ["0", "1"]) else { throw unavailable() }
        let header = try JSONDecoder().decode(Header.self, from: bytes)
        guard header.pending_store_schema == 1, header.revision > 0,
              header.revision >= minimumRevision, header.revision <= maximumInteger else { throw unavailable() }
        // Decode the subobject alone: occupied metadata is depth3 in the wrapper.
        let metadataBytes = try JSONSerialization.data(withJSONObject: rawMetadata, options: [.sortedKeys])
        let metadata = try Metadata.decode(metadataBytes, expectedContext: context,
            expectedLockIdentity: identity, minimumSequence: minimumSequence)
        var associations: [Int: Association] = [:]
        for name in ["0", "1"] {
            guard let value = rawAssociations[name] else { continue }
            guard let object = value as? [String: Any],
                  Set(object.keys) == ["generation_id", "purpose", "lifecycle_digest"], let slot = Int(name) else { throw unavailable() }
            let row = try JSONDecoder().decode(AssociationRow.self,
                from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
            let hex = Array(row.lifecycle_digest.utf8)
            guard hex.count == 64, hex.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw unavailable() }
            var digest = Data()
            for index in stride(from: 0, to: hex.count, by: 2) {
                guard let byte = UInt8(String(decoding: hex[index..<index + 2], as: UTF8.self), radix: 16) else { throw unavailable() }
                digest.append(byte)
            }
            associations[slot] = .init(generationID: row.generation_id, purpose: row.purpose, lifecycleDigest: digest)
        }
        let pending = metadata.slots.compactMap { value -> Metadata.Coordinates? in
            if case .pending(let row) = value { return row }; return nil
        }
        guard Set(associations.keys) == Set(pending.map(\.slot)), pending.allSatisfy({ row in
            associations[row.slot]?.generationID == row.generationID && associations[row.slot]?.purpose == row.purpose
        }) else { throw unavailable() }
        let root = Root(revision: header.revision, metadata: metadata, associations: associations)
        guard try encode(root) == bytes else { throw unavailable() } // Reject, never normalize, predecessors.
        return root
    }
    static func encode(_ root: Root) throws -> Data {
        let metadata = try metadataBytes(context: root.metadata.context, identity: root.metadata.lockIdentity,
            highWater: root.metadata.lastSequence, slots: root.metadata.slots, selected: root.metadata.selectedSequence)
        let rows = try [0, 1].compactMap { slot -> String? in
            guard let value = root.associations[slot] else { return nil }
            guard value.lifecycleDigest.count == 32 else { throw unavailable() }
            return "\"\(slot)\":{\"generation_id\":\(try quote(value.generationID.uuidString.lowercased())),\"purpose\":\(try quote(purpose(value.purpose))),\"lifecycle_digest\":\(try quote(hex(value.lifecycleDigest)))}"
        }.joined(separator: ",")
        let bytes = Data("{\"pending_store_schema\":1,\"revision\":\(root.revision),\"metadata\":\(String(decoding: metadata, as: UTF8.self)),\"consumed_associations\":{\(rows)}}".utf8)
        guard root.revision > 0, root.revision <= maximumInteger, bytes.count <= maximumBytes else { throw unavailable() }
        return bytes
    }
    static func metadataBytes(context: Data, identity: RendezvousLocalStorageExclusion.Identity,
                              highWater: UInt64, slots: [Metadata.Slot], selected: UInt64?) throws -> Data {
        let lock = "{\"directory_device\":\(identity.directoryDevice),\"directory_inode\":\(identity.directoryInode),\"file_device\":\(identity.fileDevice),\"file_inode\":\(identity.fileInode),\"file_birth_seconds\":\(identity.fileBirthSeconds),\"file_birth_nanoseconds\":\(identity.fileBirthNanoseconds)}"
        let rows = try slots.sorted(by: { $0.coordinates.slot < $1.coordinates.slot }).map { value -> String in
            let c = value.coordinates
            let kind: String
            switch value { case .pending: kind = "pending"; case .bound: kind = "bound" }
            var fields = "\"kind\":\(try quote(kind)),\"slot\":\(c.slot),\"sequence\":\(c.sequence),\"generation_id\":\(try quote(c.generationID.uuidString.lowercased())),\"purpose\":\(try quote(purpose(c.purpose)))"
            if case .bound(let bound) = value {
                fields += ",\"key_identifier\":\(try quote(bound.keyIdentifier)),\"disposition\":\(try quote(disposition(bound.disposition)))"
            }
            return "\"\(c.slot)\":{\(fields)}"
        }.joined(separator: ",")
        let selection = selected.map { ",\"selected_sequence\":\($0)" } ?? ""
        let bytes = Data("{\"schema_version\":2,\"context_sha256\":\(try quote(hex(context))),\"lock_identity\":\(lock),\"last_sequence\":\(highWater),\"slots\":{\(rows)}\(selection)}".utf8)
        guard context.count == 32, highWater <= maximumInteger, bytes.count <= 4096 else { throw unavailable() }
        return bytes
    }
    private static func quote(_ value: String) throws -> String {
        guard value.utf8.allSatisfy({ (32...126).contains($0) && $0 != 34 && $0 != 92 }) else { throw unavailable() }
        return "\"" + value + "\"" // Exact ASCII, no escapes; literal base64 slash.
    }
    private static func purpose(_ value: RendezvousKeyLifecycleJournal.Purpose) -> String {
        switch value { case .initial: "initial"; case .replacement: "replacement"; case .rollover: "rollover" }
    }
    private static func disposition(_ value: Metadata.Disposition) -> String {
        switch value { case .selected: "selected"; case .candidate: "candidate"; case .retired: "retired" }
    }
    private static func hex(_ bytes: Data) -> String { bytes.map { String(format: "%02x", $0) }.joined() }
    private static func unavailable() -> RendezvousPendingMetadataStoreV1.Failure { .unavailable }
}
