import Foundation

/// Pure metadata decoder only. No persistence, bootstrap, migration, selection operation,
/// native effect, admission seal or initial-eligibility calculation. This is not
/// the persisted child-store schema1 or a complete future composition format.
struct RendezvousHandleCompositionEnvelopeV2: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "RendezvousCompositionMetadata(redacted)" }
    var debugDescription: String { description }
    enum Failure: Error { case invalidEnvelope }
    enum Disposition: String, Equatable, Sendable { case selected, candidate, retired }
    struct Coordinates: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        var description: String { "RendezvousCompositionCoordinates(redacted)" }
        var debugDescription: String { description }
        let slot: Int
        let sequence: UInt64
        let generationID: UUID
        let purpose: RendezvousKeyLifecycleJournal.Purpose
    }
    struct Bound: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        var description: String { "RendezvousCompositionBound(redacted)" }
        var debugDescription: String { description }
        let coordinates: Coordinates
        let keyIdentifier: String
        let disposition: Disposition
    }
    enum Slot: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        var description: String { "RendezvousCompositionSlot(redacted)" }
        var debugDescription: String { description }
        case pending(Coordinates), bound(Bound)
        var coordinates: Coordinates {
            switch self { case .pending(let c): c; case .bound(let b): b.coordinates }
        }
    }
    let context: Data
    let lockIdentity: RendezvousLocalStorageExclusion.Identity
    let lastSequence: UInt64
    let slots: [Slot]
    let selectedSequence: UInt64?
    private init(context: Data, lockIdentity: RendezvousLocalStorageExclusion.Identity,
                 lastSequence: UInt64, slots: [Slot], selectedSequence: UInt64?) {
        self.context = context; self.lockIdentity = lockIdentity
        self.lastSequence = lastSequence; self.slots = slots; self.selectedSequence = selectedSequence
    }

    /// Expected coordinates are comparison inputs, not authentic lifecycle or
    /// lock provenance. The required floor is only a comparison input; decoding
    /// neither establishes its authenticity nor retains history or validates an OS anchor.
    static func decode(_ data: Data, expectedContext: Data,
                       expectedLockIdentity: RendezvousLocalStorageExclusion.Identity,
                       minimumSequence: UInt64) throws -> Self {
        do { return try parse(data, context: expectedContext, lock: expectedLockIdentity, minimumSequence: minimumSequence) }
        catch { throw Failure.invalidEnvelope } // Never expose stored input in errors.
    }
    private static func parse(_ data: Data, context: Data,
                              lock: RendezvousLocalStorageExclusion.Identity, minimumSequence: UInt64) throws -> Self {
        guard context.count == 32 else { throw Failure.invalidEnvelope }
        let root = try RendezvousFlatJSON.parse(data, maximumBytes: 4096)
        let required: Set<String> = ["schema_version", "context_sha256", "lock_identity", "last_sequence", "slots"]
        guard Set(root.keys) == required || Set(root.keys) == required.union(["selected_sequence"]),
              root["schema_version"] == .integer(2),
              root["context_sha256"] == .string(context.map { String(format: "%02x", $0) }.joined()),
              case .object(let identity)? = root["lock_identity"],
              case .object(let rawSlots)? = root["slots"],
              Set(rawSlots.keys).isSubset(of: ["0", "1"]) else { throw Failure.invalidEnvelope }
        try validate(identity, against: lock)
        let highWater = try integer(root["last_sequence"])
        guard highWater >= minimumSequence else { throw Failure.invalidEnvelope }
        var slots: [Slot] = []
        for name in ["0", "1"] {
            guard let raw = rawSlots[name] else { continue }
            guard case .object(let fields) = raw else { throw Failure.invalidEnvelope }
            let common: Set<String> = ["kind", "slot", "sequence", "generation_id", "purpose"]
            guard let index = Int(name), try integer(fields["slot"]) == UInt64(index),
                  let idText = string(fields["generation_id"]), let id = UUID(uuidString: idText),
                  id.uuidString.lowercased() == idText,
                  let purposeText = string(fields["purpose"]),
                  let purpose = RendezvousKeyLifecycleJournal.Purpose(rawValue: purposeText) else { throw Failure.invalidEnvelope }
            let sequence = try integer(fields["sequence"])
            guard sequence > 0, sequence <= highWater else { throw Failure.invalidEnvelope }
            let coordinates = Coordinates(slot: index, sequence: sequence, generationID: id, purpose: purpose)
            switch fields["kind"] {
            case .some(.string("pending")):
                guard Set(fields.keys) == common else { throw Failure.invalidEnvelope }
                slots.append(.pending(coordinates))
            case .some(.string("bound")):
                guard Set(fields.keys) == common.union(["key_identifier", "disposition"]),
                      let key = string(fields["key_identifier"]),
                      DJConnectRendezvousSubmitChallenge.canonicalKeyID(key),
                      let rawDisposition = string(fields["disposition"]),
                      let disposition = Disposition(rawValue: rawDisposition) else { throw Failure.invalidEnvelope }
                slots.append(.bound(.init(coordinates: coordinates, keyIdentifier: key, disposition: disposition)))
            default: throw Failure.invalidEnvelope
            }
        }
        guard slots.count <= 2,
              slots.filter({ $0.coordinates.purpose == .initial }).count <= 1,
              Set(slots.map { $0.coordinates.sequence }).count == slots.count,
              Set(slots.map { $0.coordinates.generationID }).count == slots.count else { throw Failure.invalidEnvelope }
        let bound = slots.compactMap { slot -> Bound? in if case .bound(let b) = slot { b } else { nil } }
        guard Set(bound.map(\.keyIdentifier)).count == bound.count,
              bound.filter({ $0.disposition == .candidate }).count <= 1 else { throw Failure.invalidEnvelope }
        let selected = bound.filter { $0.disposition == .selected }
        let selectedSequence = try root["selected_sequence"].map { try integer($0) }
        guard selected.count <= 1, selected.first?.coordinates.sequence == selectedSequence else { throw Failure.invalidEnvelope }
        return Self(context: context, lockIdentity: lock, lastSequence: highWater,
                    slots: slots, selectedSequence: selectedSequence)
    }
    private static func integer(_ value: RendezvousFlatJSON.Value?) throws -> UInt64 {
        guard case .integer(let n)? = value, n >= 0 else { throw Failure.invalidEnvelope }
        return UInt64(n) // The existing closed reader also rejects unsafe/overflowing JSON integers.
    }
    private static func string(_ value: RendezvousFlatJSON.Value?) -> String? {
        if case .string(let s)? = value { s } else { nil }
    }
    private static func validate(_ value: [String: RendezvousFlatJSON.Value],
                                 against expected: RendezvousLocalStorageExclusion.Identity) throws {
        let fields: Set<String> = ["directory_device", "directory_inode", "file_device", "file_inode", "file_birth_seconds", "file_birth_nanoseconds"]
        guard Set(value.keys) == fields, expected.directoryDevice >= 0, expected.fileDevice >= 0,
              expected.directoryInode > 0, expected.fileInode > 0, expected.fileBirthSeconds >= 0,
              (0..<1_000_000_000).contains(expected.fileBirthNanoseconds),
              try integer(value["directory_device"]) == UInt64(expected.directoryDevice),
              try integer(value["directory_inode"]) == expected.directoryInode,
              try integer(value["file_device"]) == UInt64(expected.fileDevice),
              try integer(value["file_inode"]) == expected.fileInode,
              try integer(value["file_birth_seconds"]) == UInt64(expected.fileBirthSeconds),
              try integer(value["file_birth_nanoseconds"]) == UInt64(expected.fileBirthNanoseconds) else { throw Failure.invalidEnvelope }
    }
}
