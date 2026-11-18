import Foundation
import CryptoKit
import Dispatch
import Testing
@testable import DJConnectCore

private typealias PendingStore = RendezvousPendingMetadataStoreV1
private final class PendingMemory: RendezvousRepairStorage, @unchecked Sendable {
    enum Fault: String, CaseIterable, Sendable { case normal, beforeWrite, afterWrite, drop, missingRead, wrongRead, failedRead, cancelAfterWrite }
    enum Injected: Error { case unavailable }
    private let lock = NSLock()
    private var bytes: Data?
    private var fault: Fault = .normal
    private var readFault: Fault = .normal
    private var count = 0
    init(_ bytes: Data? = nil) { self.bytes = bytes }
    var writes: Int { lock.withLock { count } }
    func configure(_ fault: Fault) { lock.withLock { self.fault = fault } }
    func replace(_ data: Data?) { lock.withLock { bytes = data } }
    func read() throws -> Data? {
        try lock.withLock {
            let f = readFault; readFault = .normal
            if f == .failedRead { throw Injected.unavailable }
            if f == .missingRead { return nil }
            if f == .wrongRead { return Data("wrong".utf8) }
            return bytes
        }
    }
    func write(_ data: Data) throws {
        let selected = try lock.withLock {
            count += 1; let f = fault; fault = .normal
            if f == .beforeWrite { throw Injected.unavailable }
            if f != .drop { bytes = data }
            if f == .afterWrite { throw Injected.unavailable }
            if [.missingRead, .wrongRead, .failedRead].contains(f) { readFault = f }
            return f
        }
        if selected == .cancelAfterWrite { withUnsafeCurrentTask { $0?.cancel() } }
    }
}
private enum PendingBusyEvent: Equatable, Sendable { case entered, finished, failed }
private actor PendingGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async { if opened { return }; await withCheckedContinuation { waiters.append($0) } }
    func open() { opened = true; let current = waiters; waiters = []; current.forEach { $0.resume() } }
}
private struct PendingFixture: Sendable {
    let directory: URL
    let exclusion: RendezvousLocalStorageExclusion
    let context: Data
    let original: Data
    let backing: PendingMemory
    let store: PendingStore
    let revision: UInt64
    let highWater: UInt64
    let boundRow: String?
    func another(bytes: Data? = nil, revision: UInt64? = nil, sequence: UInt64? = nil) throws -> PendingStore {
        try PendingStore(context: context, backing: backing,
            exclusion: RendezvousLocalStorageExclusion(directory: directory, identity: exclusion.identity),
            comparison: .init(originalRootBytes: bytes ?? original,
                minimumRevision: revision ?? self.revision, minimumSequence: sequence ?? highWater))
    }
}
// Independently spelled canonical fixture, not the production encoder.
private func pendingFixture(bound: String? = nil, revision: UInt64 = 1, highWater: UInt64 = 0) throws -> PendingFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pending-cas-fixture-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory)
    let exclusion = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    let context = Data(repeating: 9, count: 32)
    let lock = "{\"directory_device\":\(identity.directoryDevice),\"directory_inode\":\(identity.directoryInode),\"file_device\":\(identity.fileDevice),\"file_inode\":\(identity.fileInode),\"file_birth_seconds\":\(identity.fileBirthSeconds),\"file_birth_nanoseconds\":\(identity.fileBirthNanoseconds)}"
    let key = Data(repeating: 255, count: 32).base64EncodedString()
    let row = bound.map { "{\"kind\":\"bound\",\"slot\":0,\"sequence\":1,\"generation_id\":\"00000000-0000-4000-8000-000000000001\",\"purpose\":\"initial\",\"key_identifier\":\"\(key)\",\"disposition\":\"\($0)\"}" }
    let slots = row.map { "\"0\":\($0)" } ?? ""
    let selection = bound == "selected" ? ",\"selected_sequence\":1" : ""
    let sequence = bound == nil ? highWater : max(1, highWater)
    let metadata = "{\"schema_version\":2,\"context_sha256\":\"\(String(repeating: "09", count: 32))\",\"lock_identity\":\(lock),\"last_sequence\":\(sequence),\"slots\":{\(slots)}\(selection)}"
    let bytes = Data("{\"pending_store_schema\":1,\"revision\":\(revision),\"metadata\":\(metadata),\"consumed_associations\":{}}".utf8)
    let backing = PendingMemory(bytes)
    let store = try PendingStore(context: context, backing: backing, exclusion: exclusion,
        comparison: .init(originalRootBytes: bytes, minimumRevision: revision, minimumSequence: sequence))
    return .init(directory: directory, exclusion: exclusion, context: context, original: bytes,
                 backing: backing, store: store, revision: revision, highWater: sequence, boundRow: row)
}
private func consumed(_ purpose: RendezvousKeyLifecycleJournal.Purpose = .initial,
                      id: UUID = UUID()) -> PendingStore.ConsumedAssociation {
    .init(generationID: id, purpose: purpose, lifecycleDigest: Data(repeating: 6, count: 32))
}
private func closes(_ store: PendingStore, snapshot: PendingStore.Snapshot,
                    association: PendingStore.ConsumedAssociation) async {
    await #expect(throws: PendingStore.Failure.self) { try await store.capture() }
    await #expect(throws: PendingStore.Failure.self) { try await store.append(expected: snapshot, consumed: association) }
    #expect(await store.state == .closed)
}

@Suite("Pending metadata CAS only", .serialized)
struct RendezvousPendingMetadataStoreTests {
    @Test(arguments: ["selected", "candidate", "retired"])
    func existingBoundRowsAndSelectionRemainUnchanged(_ disposition: String) async throws {
        let f = try pendingFixture(bound: disposition, revision: 9)
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let snapshot = try await f.store.capture(), a = consumed(.replacement)
        #expect(try await f.store.append(expected: snapshot, consumed: a) == .metadataRecorded)
        let bytes = try #require(try f.backing.read()), text = try #require(String(data: bytes, encoding: .utf8))
        #expect(text.contains(try #require(f.boundRow)))
        #expect(text.contains("\"revision\":10") && text.contains("\"last_sequence\":2"))
        #expect(text.contains("\"selected_sequence\":1") == (disposition == "selected"))
        let restored = try f.another(bytes: bytes, revision: 10, sequence: 2)
        _ = try await restored.capture() // Valid occupied nested wrapper, depth3 overall.
        await #expect(throws: PendingStore.Failure.self) { try await restored.append(expected: snapshot, consumed: consumed(.rollover)) }
        #expect(f.backing.writes == 1)
        await closes(f.store, snapshot: snapshot, association: a)
        #expect(f.backing.writes == 1)
    }
    @Test func twoPendingRowsCountTowardCapacityWithoutKeysOrSelection() async throws {
        let f = try pendingFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
        let first = try await f.store.capture()
        _ = try await f.store.append(expected: first, consumed: consumed())
        let afterFirst = try #require(try f.backing.read()), second = try f.another(bytes: afterFirst, revision: 2, sequence: 1)
        let snapshot = try await second.capture()
        _ = try await second.append(expected: snapshot, consumed: consumed(.rollover))
        let bytes = try #require(try f.backing.read()), text = String(decoding: bytes, as: UTF8.self)
        #expect(!text.contains("key_identifier") && !text.contains("selected_sequence") && !text.contains("disposition"))
        let third = try f.another(bytes: bytes, revision: 3, sequence: 2), expected = try await third.capture()
        await #expect(throws: PendingStore.Failure.self) { try await third.append(expected: expected, consumed: consumed(.replacement)) }
        #expect(f.backing.writes == 2)
    }
    @Test(arguments: PendingMemory.Fault.allCases.filter { $0 != .normal })
    fileprivate func everyPersistenceFailureLeavesActualOriginalLifecycleSpent(_ fault: PendingMemory.Fault) async throws {
        let f = try pendingFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
        let lifeMemory = PendingMemory(), lifecycle = RendezvousKeyLifecycleJournal(storage: lifeMemory)
        let original = try await lifecycle.reserveGeneration(purpose: .initial, appContext: f.context, foreground: true, at: 1000)
        let association = PendingStore.ConsumedAssociation(generationID: original.identifier, purpose: original.purpose,
            lifecycleDigest: Data(SHA256.hash(data: try #require(try lifeMemory.read()))))
        let snapshot = try await f.store.capture(); f.backing.configure(fault)
        let operation = Task { try await f.store.append(expected: snapshot, consumed: association) }
        switch await operation.result { case .success: Issue.record("Uncertain write cannot succeed"); case .failure: break }
        #expect(!Task.isCancelled && f.backing.writes == 1)
        await closes(f.store, snapshot: snapshot, association: association)
        #expect(f.backing.writes == 1)
        let restarted = RendezvousKeyLifecycleJournal(storage: lifeMemory)
        await #expect(throws: (any Error).self) {
            try await restarted.reserveGeneration(purpose: .initial, appContext: f.context, foreground: true, at: 1001)
        }
        let handles = try await restarted.snapshot(appContext: f.context, at: 1002)
        #expect(handles.count == 1 && handles[0].identifier == original.identifier)
        #expect(throws: PendingStore.Failure.self) {
            try PendingStore(context: f.context, backing: f.backing, exclusion: f.exclusion, comparison: nil)
        } // Lost original history is not reconstructed from surviving bytes or zero.
    }
    @Test func cancellationBeforeEntryAndRecaptureAreTerminal() async throws {
        let f = try pendingFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
        let snapshot = try await f.store.capture(), a = consumed(), gate = PendingGate()
        let operation = Task { await gate.wait(); return try await f.store.append(expected: snapshot, consumed: a) }
        operation.cancel(); await gate.open()
        switch await operation.result { case .success: Issue.record("Cancelled append cannot succeed"); case .failure: break }
        await closes(f.store, snapshot: snapshot, association: a)
        #expect(f.backing.writes == 0)
        let other = try f.another(), second = try await other.capture()
        await #expect(throws: PendingStore.Failure.self) { try await other.capture() }
        await closes(other, snapshot: second, association: a)
        #expect(f.backing.writes == 0)
    }
    @Test(arguments: [false, true])
    func independentInstancesPermitAtMostOneOriginalCAS(_ sameGeneration: Bool) async throws {
        let f = try pendingFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
        let other = try f.another(), left = try await f.store.capture(), right = try await other.capture()
        let a = consumed(), b = sameGeneration ? a : consumed()
        let wins = await withTaskGroup(of: Bool.self) { group in
            group.addTask { (try? await f.store.append(expected: left, consumed: a)) != nil }
            group.addTask { (try? await other.append(expected: right, consumed: b)) != nil }
            var wins = 0; for await value in group { if value { wins += 1 } }; return wins
        }
        #expect(wins == 1 && f.backing.writes == 1)
        await closes(f.store, snapshot: left, association: a); await closes(other, snapshot: right, association: b)
        #expect(f.backing.writes == 1)
    }
    @Test(arguments: ["space", "order", "escaped-field", "duplicate-root", "duplicate-metadata", "schema", "outer-schema", "bool", "fraction", "number-string", "overflow", "array", "deep", "unknown"])
    func malformedOrNoncanonicalRootsAreNeverRewritten(_ mutation: String) async throws {
        let f = try pendingFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
        var text = String(decoding: f.original, as: UTF8.self)
        switch mutation {
        case "space": text = " " + text
        case "order": text = text.replacingOccurrences(of: "\"pending_store_schema\":1,\"revision\":1", with: "\"revision\":1,\"pending_store_schema\":1")
        case "outer-schema": text = text.replacingOccurrences(of: "\"pending_store_schema\":1", with: "\"pending_store_schema\":2")
        case "fraction": text = text.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":1.0")
        case "number-string": text = text.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":\"1\"")
        case "escaped-field": text = text.replacingOccurrences(of: "pending_store_schema", with: "pending\\u005fstore_schema")
        case "duplicate-root": text = text.replacingOccurrences(of: "\"pending_store_schema\":1,", with: "\"pending_store_schema\":1,\"pending\\u005fstore_schema\":1,")
        case "duplicate-metadata": text = text.replacingOccurrences(of: "\"schema_version\":2,", with: "\"schema_version\":2,\"schema\\u005fversion\":2,")
        case "schema": text = text.replacingOccurrences(of: "\"schema_version\":2", with: "\"schema_version\":1")
        case "bool": text = text.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":true")
        case "overflow": text = text.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":9007199254740992")
        case "array": text = text.replacingOccurrences(of: "\"consumed_associations\":{}", with: "\"consumed_associations\":[]")
        case "deep": text = text.replacingOccurrences(of: "\"slots\":{}", with: "\"slots\":{\"0\":{\"kind\":{\"nested\":{}}}}")
        default: text = text.replacingOccurrences(of: "\"revision\":1,", with: "\"revision\":1,\"unknown\":0,")
        }
        let bad = Data(text.utf8); f.backing.replace(bad)
        let store = try f.another(bytes: bad)
        await #expect(throws: PendingStore.Failure.self) { try await store.capture() }
        #expect(await store.state == .closed)
        #expect(try f.backing.read() == bad && f.backing.writes == 0)
    }
    @Test func absentChangedRootRequiredFloorsAndForeignSnapshotsDeny() async throws {
        let f = try pendingFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
        let snapshot = try await f.store.capture(), foreign = try f.another(), own = try await foreign.capture()
        await #expect(throws: PendingStore.Failure.self) { try await foreign.append(expected: snapshot, consumed: consumed()) }
        await closes(foreign, snapshot: own, association: consumed())
        f.backing.replace(nil)
        await #expect(throws: PendingStore.Failure.self) { try await f.store.append(expected: snapshot, consumed: consumed()) }
        #expect(f.backing.writes == 0)
        f.backing.replace(f.original)
        let staleRevision = try f.another(revision: 2), staleSequence = try f.another(sequence: 1)
        await #expect(throws: PendingStore.Failure.self) { try await staleRevision.capture() }
        await #expect(throws: PendingStore.Failure.self) { try await staleSequence.capture() }
        let fresh = try f.another()
        await #expect(throws: PendingStore.Failure.self) { try await fresh.append(expected: snapshot, consumed: consumed()) }
        #expect(await fresh.state == .closed && f.backing.writes == 0)
    }
    @Test(arguments: [false, true])
    func safeIntegerCounterExhaustionNeverWraps(_ sequence: Bool) async throws {
        let maximum: UInt64 = 9_007_199_254_740_991
        let f = try pendingFixture(revision: sequence ? 1 : maximum, highWater: sequence ? maximum : 0)
        defer { try? FileManager.default.removeItem(at: f.directory) }
        let snapshot = try await f.store.capture()
        await #expect(throws: PendingStore.Failure.self) { try await f.store.append(expected: snapshot, consumed: consumed()) }
        #expect(f.backing.writes == 0); #expect(try f.backing.read() == f.original)
    }
    @Test func busyRefusalIsTerminalAfterPhysicalLockIsReleased() async throws {
        let f = try pendingFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
        let snapshot = try await f.store.capture()
        let blocker = try RendezvousLocalStorageExclusion(directory: f.directory, identity: f.exclusion.identity)
        let events = AsyncStream<PendingBusyEvent>.makeStream()
        let release = DispatchSemaphore(value: 0)
        Thread {
            do {
                try blocker.perform {
                    events.continuation.yield(.entered)
                    _ = release.wait(timeout: .now() + 5) // Test-only OS thread, no Swift task or await under lock.
                }
                events.continuation.yield(.finished)
            } catch { events.continuation.yield(.failed) }
            events.continuation.finish()
        }.start()
        do {
            var iterator = events.stream.makeAsyncIterator()
            let first = await iterator.next(); try #require(first == .entered)
            await #expect(throws: PendingStore.Failure.self) { try await f.store.append(expected: snapshot, consumed: consumed()) }
            release.signal()
            let last = await iterator.next(); try #require(last == .finished)
            await closes(f.store, snapshot: snapshot, association: consumed())
            #expect(f.backing.writes == 0)
        } catch {
            release.signal()
            for await _ in events.stream {} // Cooperatively await the bounded OS-thread cleanup.
            throw error
        }
    }
    @Test(arguments: ["escaped-slash", "escaped-field", "duplicate-association", "wrong-association", "deeper-association"])
    func occupiedCanonicalFormatAndAssociationJoinsRemainStrict(_ mutation: String) async throws {
        let f = try pendingFixture(bound: "selected"); defer { try? FileManager.default.removeItem(at: f.directory) }
        let snapshot = try await f.store.capture()
        _ = try await f.store.append(expected: snapshot, consumed: consumed(.replacement))
        let bytes = try #require(try f.backing.read()); var text = String(decoding: bytes, as: UTF8.self)
        let marker = "\"consumed_associations\":{"
        let range = try #require(text.range(of: marker)), prefix = String(text[..<range.upperBound])
        let row = String(text[range.upperBound...].dropLast(2))
        switch mutation {
        case "escaped-slash": text = text.replacingOccurrences(of: "/", with: "\\/")
        case "escaped-field": text = text.replacingOccurrences(of: "generation_id", with: "generation\\u005fid")
        case "duplicate-association": text = prefix + row + "," + row.replacingOccurrences(of: "\"1\":", with: "\"\\u0031\":") + "}}"
        case "wrong-association": text = prefix + row.replacingOccurrences(of: "\"purpose\":\"replacement\"", with: "\"purpose\":\"rollover\"") + "}}"
        default:
            let object = try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            let associations = try #require(object["consumed_associations"] as? [String: Any])
            let originalRow = try #require(associations["1"] as? [String: Any])
            let id = try #require(originalRow["generation_id"] as? String)
            text = prefix + row.replacingOccurrences(of: "\"generation_id\":\"\(id)\"", with: "\"generation_id\":{\"unexpected\":{}}") + "}}"
        }
        let bad = Data(text.utf8); try #require(bad != bytes); f.backing.replace(bad)
        let other = try f.another(bytes: bad, revision: 2, sequence: 2)
        await #expect(throws: PendingStore.Failure.self) { try await other.capture() }
        #expect(try f.backing.read() == bad && f.backing.writes == 1)
    }
    @Test func staleCASAndDuplicateGenerationDoNotRewriteForeignRoot() async throws {
        let f = try pendingFixture(bound: "selected"); defer { try? FileManager.default.removeItem(at: f.directory) }
        let snapshot = try await f.store.capture()
        let changed = Data(String(decoding: f.original, as: UTF8.self).replacingOccurrences(of: "\"revision\":1", with: "\"revision\":2").utf8)
        f.backing.replace(changed)
        await #expect(throws: PendingStore.Failure.self) { try await f.store.append(expected: snapshot, consumed: consumed(.replacement)) }
        #expect(try f.backing.read() == changed && f.backing.writes == 0)
        f.backing.replace(f.original)
        let other = try f.another(), expected = try await other.capture()
        let duplicate = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))
        await #expect(throws: PendingStore.Failure.self) { try await other.append(expected: expected, consumed: consumed(.replacement, id: duplicate)) }
        #expect(f.backing.writes == 0)
    }

}
