import Foundation
import Testing
@testable import DJConnectCore

private enum CompositionMetadataFixture {
    static let context = Data(repeating: 42, count: 32)
    static let identity = RendezvousLocalStorageExclusion.Identity(directoryDevice: 1, directoryInode: 2,
        fileDevice: 1, fileInode: 3, fileBirthSeconds: 4, fileBirthNanoseconds: 0)
    static let first = "00000000-0000-4000-8000-000000000001"
    static let second = "00000000-0000-4000-8000-000000000002"
    static let key = Data(repeating: 12, count: 32).base64EncodedString()
    static var lock: [String: Any] { ["directory_device":1,"directory_inode":2,"file_device":1,
        "file_inode":3,"file_birth_seconds":4,"file_birth_nanoseconds":0] }
    static var bound: [String: Any] { ["kind":"bound","slot":0,"sequence":1,"generation_id":first,
        "purpose":"initial","key_identifier":key,"disposition":"selected"] }
    static var pending: [String: Any] { ["kind":"pending","slot":1,"sequence":2,
        "generation_id":second,"purpose":"replacement"] }
    static var root: [String: Any] { ["schema_version":2,"context_sha256":String(repeating:"2a",count:32),
        "lock_identity":lock,"last_sequence":2,"slots":["0":bound,"1":pending],"selected_sequence":1] }
    static func bytes(_ value: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: .sortedKeys)
    }
    static func decode(_ data: Data) throws -> RendezvousHandleCompositionEnvelopeV2 {
        try .decode(data, expectedContext: context, expectedLockIdentity: identity, minimumSequence: 0)
    }
}

@Suite("Retained composition metadata only")
struct RendezvousCompositionEnvelopeTests {
    @Test func selectedBoundAndPendingGenerationAreDistinctMetadata() throws {
        let value = try CompositionMetadataFixture.decode(CompositionMetadataFixture.bytes(CompositionMetadataFixture.root))
        #expect(value.context == CompositionMetadataFixture.context)
        #expect(value.lockIdentity == CompositionMetadataFixture.identity)
        #expect(value.lastSequence == 2 && value.selectedSequence == 1 && value.slots.count == 2)
        guard case .bound(let bound) = value.slots[0], case .pending(let pending) = value.slots[1] else {
            Issue.record("Expected distinct bound and pending metadata tags"); return
        }
        #expect(bound.coordinates.slot == 0 && bound.coordinates.sequence == 1)
        #expect(bound.disposition == .selected && bound.keyIdentifier == CompositionMetadataFixture.key)
        #expect(pending.slot == 1 && pending.sequence == 2 && pending.purpose == .replacement)
        #expect(bound.coordinates.generationID != pending.generationID)
        // A parsed value carries no native admission, journal writer or selection operation.
    }

    @Test(arguments: [UInt64(0), UInt64(2)])
    func emptyMetadataRetainsHighWaterWithoutSelection(_ highWater: UInt64) throws {
        var raw = CompositionMetadataFixture.root
        raw["slots"] = [String: Any](); raw["last_sequence"] = highWater
        raw.removeValue(forKey: "selected_sequence")
        let value = try CompositionMetadataFixture.decode(CompositionMetadataFixture.bytes(raw))
        #expect(value.slots.isEmpty && value.selectedSequence == nil && value.lastSequence == highWater)
        // Zero slots are representable metadata, never proof of an unused installation.
    }

    @Test func bothPendingReservationsCountAgainstTheTwoSlots() throws {
        var first = CompositionMetadataFixture.pending
        first["slot"] = 0; first["sequence"] = 1; first["generation_id"] = CompositionMetadataFixture.first
        first["purpose"] = "initial"
        var raw = CompositionMetadataFixture.root
        raw["slots"] = ["0":first,"1":CompositionMetadataFixture.pending]
        raw.removeValue(forKey: "selected_sequence")
        let value = try CompositionMetadataFixture.decode(CompositionMetadataFixture.bytes(raw))
        #expect(value.slots.count == 2 && value.selectedSequence == nil)
        #expect(value.slots.allSatisfy { if case .pending = $0 { true } else { false } })
    }

    @Test func retiredAndSelectedMetadataRemainDistinct() throws {
        var retired = CompositionMetadataFixture.bound; retired["disposition"] = "retired"
        var selected = CompositionMetadataFixture.bound
        selected["slot"] = 1; selected["sequence"] = 2; selected["generation_id"] = CompositionMetadataFixture.second
        selected["purpose"] = "rollover"; selected["key_identifier"] = Data(repeating: 13, count: 32).base64EncodedString()
        var raw = CompositionMetadataFixture.root; raw["slots"] = ["0":retired,"1":selected]; raw["selected_sequence"] = 2
        let value = try CompositionMetadataFixture.decode(CompositionMetadataFixture.bytes(raw))
        #expect(value.selectedSequence == 2 && value.slots.count == 2)
        guard case .bound(let old) = value.slots[0], case .bound(let current) = value.slots[1] else {
            Issue.record("Expected bound metadata only"); return
        }
        #expect(old.disposition == .retired && current.disposition == .selected)
    }

    @Test func supportedIntegerLimitAndRedactedDescriptionsRemainExplicit() throws {
        var raw = CompositionMetadataFixture.root; raw["last_sequence"] = UInt64(9_007_199_254_740_991)
        let value = try CompositionMetadataFixture.decode(CompositionMetadataFixture.bytes(raw))
        #expect(value.lastSequence == 9_007_199_254_740_991)
        #expect(String(describing: value) == "RendezvousCompositionMetadata(redacted)")
        #expect(String(reflecting: value) == "RendezvousCompositionMetadata(redacted)")
        for slot in value.slots {
            #expect(String(reflecting: slot) == "RendezvousCompositionSlot(redacted)")
            #expect(String(reflecting: slot.coordinates) == "RendezvousCompositionCoordinates(redacted)")
            if case .bound(let bound) = slot { #expect(String(reflecting: bound) == "RendezvousCompositionBound(redacted)") }
        }
    }

    @Test func retainedHighWaterComparisonRefusesOlderMetadata() throws {
        let data = try CompositionMetadataFixture.bytes(CompositionMetadataFixture.root)
        let original = try RendezvousHandleCompositionEnvelopeV2.decode(data,
            expectedContext: CompositionMetadataFixture.context, expectedLockIdentity: CompositionMetadataFixture.identity,
            minimumSequence: 2)
        #expect(original.lastSequence == 2)
        for floor in [UInt64(3), UInt64.max] {
            #expect(throws: RendezvousHandleCompositionEnvelopeV2.Failure.self) {
                try RendezvousHandleCompositionEnvelopeV2.decode(data,
                    expectedContext: CompositionMetadataFixture.context, expectedLockIdentity: CompositionMetadataFixture.identity,
                    minimumSequence: floor)
            }
        }
        // The comparison floor is supplied metadata, not an authenticated lifecycle/first-use witness.
    }

    private enum Invalid: String, CaseIterable, Sendable {
        case oldVersion, futureVersion, booleanVersion, nullVersion, stringVersion, missingVersion
        case wrongContext, uppercaseContext, shortContext, invalidExpectedContext, wrongExpectedLock
        case unknownRoot, missingHighWater, zeroHighWater, negativeHighWater, fractionalHighWater
        case booleanHighWater, nullHighWater, unsafeHighWater, uint64Overflow, exponent, integralFloat, leadingZero
        case pendingSelected, danglingSelected, zeroSelected, booleanSelected, nullSelected, missingSelected
        case slotsArray, thirdSlot, slotAlias, slotMismatch, sequenceZero, sequenceBeyondHighWater, duplicateSequence
        case duplicateGeneration, uppercaseGeneration, invalidGeneration, invalidPurpose, duplicateInitial, invalidKind
        case pendingKey, pendingDisposition, boundMissingKey, boundNoncanonicalKey, boundWrongTag
        case duplicateBoundKey, duplicateSelected, duplicateCandidates, selectRetired
        case wrongLock, lockExtra, lockMissing, lockZeroInode, lockInvalidNanoseconds, lockBoolean
        case escapedRootDuplicate, childDuplicate, escapedSlotDuplicate, excessiveDepth, trailingBytes, oversized, invalidUTF8, unknownAdmission
    }
    private enum FixtureFailure: Error { case missingReplacement }

    @Test(arguments: Invalid.allCases)
    private func invalidMetadataNeverBecomesAParsedEnvelope(_ mutation: Invalid) throws {
        var root = CompositionMetadataFixture.root
        var pending = CompositionMetadataFixture.pending
        var bound = CompositionMetadataFixture.bound
        var lock = CompositionMetadataFixture.lock
        var expectedContext = CompositionMetadataFixture.context
        var expectedLock = CompositionMetadataFixture.identity
        var direct: Data?
        func replace(_ needle: String, with replacement: String) throws -> Data {
            let text = String(decoding: try CompositionMetadataFixture.bytes(CompositionMetadataFixture.root), as: UTF8.self)
            guard text.contains(needle) else { throw FixtureFailure.missingReplacement }
            return Data(text.replacingOccurrences(of: needle, with: replacement).utf8)
        }
        switch mutation {
        case .oldVersion: root["schema_version"] = 1
        case .futureVersion: root["schema_version"] = 3
        case .booleanVersion: root["schema_version"] = true
        case .nullVersion: root["schema_version"] = NSNull()
        case .stringVersion: root["schema_version"] = "2"
        case .missingVersion: root.removeValue(forKey: "schema_version")
        case .wrongContext: root["context_sha256"] = String(repeating: "ff", count: 32)
        case .uppercaseContext: root["context_sha256"] = String(repeating: "2A", count: 32)
        case .shortContext: root["context_sha256"] = String(repeating: "2a", count: 31)
        case .invalidExpectedContext: expectedContext = Data(repeating: 42, count: 31)
        case .wrongExpectedLock: expectedLock = .init(directoryDevice: 1, directoryInode: 2,
            fileDevice: 1, fileInode: 4, fileBirthSeconds: 4, fileBirthNanoseconds: 0)
        case .unknownRoot: root["unselected_policy"] = 1
        case .missingHighWater: root.removeValue(forKey: "last_sequence")
        case .zeroHighWater: root["last_sequence"] = 0
        case .negativeHighWater: root["last_sequence"] = -1
        case .fractionalHighWater: root["last_sequence"] = 1.5
        case .booleanHighWater: root["last_sequence"] = true
        case .nullHighWater: root["last_sequence"] = NSNull()
        case .unsafeHighWater: root["last_sequence"] = UInt64(9_007_199_254_740_992)
        case .uint64Overflow: direct = try replace("\"last_sequence\":2", with: "\"last_sequence\":18446744073709551616")
        case .exponent: direct = try replace("\"last_sequence\":2", with: "\"last_sequence\":2e0")
        case .integralFloat: direct = try replace("\"last_sequence\":2", with: "\"last_sequence\":2.0")
        case .leadingZero: direct = try replace("\"last_sequence\":2", with: "\"last_sequence\":02")
        case .pendingSelected: root["selected_sequence"] = 2
        case .danglingSelected: root["selected_sequence"] = 3
        case .zeroSelected: root["selected_sequence"] = 0
        case .booleanSelected: root["selected_sequence"] = true
        case .nullSelected: root["selected_sequence"] = NSNull()
        case .missingSelected: root.removeValue(forKey: "selected_sequence")
        case .slotsArray: root["slots"] = [bound, pending]
        case .thirdSlot: root["slots"] = ["0":bound,"1":pending,"2":pending]
        case .slotAlias: root["slots"] = ["0":bound,"01":pending]
        case .slotMismatch: pending["slot"] = 0
        case .sequenceZero: pending["sequence"] = 0
        case .sequenceBeyondHighWater: pending["sequence"] = 3
        case .duplicateSequence: pending["sequence"] = 1
        case .duplicateGeneration: pending["generation_id"] = CompositionMetadataFixture.first
        case .uppercaseGeneration: pending["generation_id"] = "ABCDEFAB-0000-4000-8000-000000000002"
        case .invalidGeneration: pending["generation_id"] = "not-a-generation"
        case .invalidPurpose: pending["purpose"] = "reset"
        case .duplicateInitial: pending["purpose"] = "initial"
        case .invalidKind: pending["kind"] = "active"
        case .pendingKey: pending["key_identifier"] = CompositionMetadataFixture.key
        case .pendingDisposition: pending["disposition"] = "candidate"
        case .boundMissingKey: bound.removeValue(forKey: "key_identifier")
        case .boundNoncanonicalKey: bound["key_identifier"] = "not-a-canonical-key"
        case .boundWrongTag: bound["disposition"] = "active"
        case .duplicateBoundKey, .duplicateSelected, .duplicateCandidates:
            var second = bound
            second["slot"] = 1; second["sequence"] = 2; second["generation_id"] = CompositionMetadataFixture.second
            second["purpose"] = "replacement"
            second["key_identifier"] = mutation == .duplicateBoundKey ? CompositionMetadataFixture.key : Data(repeating: 13, count: 32).base64EncodedString()
            second["disposition"] = mutation == .duplicateSelected ? "selected" : "candidate"
            if mutation == .duplicateCandidates { bound["disposition"] = "candidate"; root.removeValue(forKey: "selected_sequence") }
            root["slots"] = ["0":bound,"1":second]
        case .selectRetired: bound["disposition"] = "retired"
        case .wrongLock: lock["file_inode"] = 4
        case .lockExtra: lock["extra"] = 1
        case .lockMissing: lock.removeValue(forKey: "file_inode")
        case .lockZeroInode: lock["file_inode"] = 0
        case .lockInvalidNanoseconds: lock["file_birth_nanoseconds"] = 1_000_000_000
        case .lockBoolean: lock["file_birth_nanoseconds"] = false
        case .escapedRootDuplicate:
            direct = try replace("\"schema_version\":2", with: "\"schema_version\":2,\"schema_vers\\u0069on\":2")
        case .childDuplicate: direct = try replace("\"sequence\":2", with: "\"sequence\":2,\"sequence\":2")
        case .escapedSlotDuplicate: direct = try replace("\"slots\":{\"0\":", with: "\"slots\":{\"\\u0030\":{},\"0\":")
        case .excessiveDepth: pending["sequence"] = ["too_deep":["value":1]]
        case .trailingBytes: direct = try CompositionMetadataFixture.bytes(root) + Data("{}".utf8)
        case .oversized: direct = try CompositionMetadataFixture.bytes(root) + Data(repeating: 32, count: 4096)
        case .invalidUTF8: direct = Data([0xff])
        case .unknownAdmission: root["admitted"] = true
        }
        switch mutation {
        case .slotMismatch, .sequenceZero, .sequenceBeyondHighWater, .duplicateSequence,
             .duplicateGeneration, .uppercaseGeneration, .invalidGeneration, .invalidPurpose,
             .duplicateInitial, .invalidKind, .pendingKey, .pendingDisposition, .boundMissingKey,
             .boundNoncanonicalKey, .boundWrongTag, .selectRetired, .excessiveDepth:
            root["slots"] = ["0":bound,"1":pending]
        default: break
        }
        root["lock_identity"] = lock
        let data = try direct ?? CompositionMetadataFixture.bytes(root)
        #expect(throws: RendezvousHandleCompositionEnvelopeV2.Failure.self) {
            try RendezvousHandleCompositionEnvelopeV2.decode(data, expectedContext: expectedContext,
                                                             expectedLockIdentity: expectedLock, minimumSequence: 0)
        }
    }
}
