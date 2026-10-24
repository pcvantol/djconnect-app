import Foundation
import Testing
@testable import DJConnectCore

private final class HandleRootMemory: RendezvousRepairStorage, @unchecked Sendable {
    enum Failure: Error { case beforeCommit, afterCommit }
    enum Mode { case normal, failBefore, failAfter, silentlyDrop }
    private let lock = NSLock()
    private var data: Data?
    private var mode: Mode = .normal
    private var count = 0
    init(_ data: Data?) { self.data = data }
    var writes: Int { lock.withLock { count } }
    func configure(_ mode: Mode) { lock.withLock { self.mode = mode } }
    func replaceForTest(_ data: Data?) { lock.withLock { self.data = data } }
    func read() throws -> Data? { lock.withLock { data } }
    func write(_ data: Data) throws {
        try lock.withLock {
            count += 1; let selected = mode; mode = .normal
            if selected == .failBefore { throw Failure.beforeCommit }
            if selected != .silentlyDrop { self.data = data }
            if selected == .failAfter { throw Failure.afterCommit }
        }
    }
}
private struct HandleStoreFixture {
    let directory: URL
    let exclusion: RendezvousLocalStorageExclusion
    let backing: HandleRootMemory
    let store: RendezvousHandleJournalStore
    let context: Data
    let binding: RendezvousHandleJournalStore.Binding
    let record: RendezvousHandleJournalStore.Record
}
private func handleStoreFixture() throws -> HandleStoreFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rendezvous-child-store-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory)
    let exclusion = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    let context = Data(repeating: 4, count: 32)
    let binding = RendezvousHandleJournalStore.Binding(slot: 0, sequence: 1, generationID: UUID(), keyIdentifier: Data(repeating: 1, count: 32).base64EncodedString())
    let channels = Dictionary(uniqueKeysWithValues: RendezvousHandleJournalStore.Channel.allCases.map { ($0.rawValue, RendezvousHandleJournalStore.Payload(revision: 0, bytes: nil)) })
    let record = RendezvousHandleJournalStore.Record(schemaVersion: 1, context: context, lockIdentity: identity, lastSequence: 1,
        selectedSequence: 1, closed: false, slots: [.init(binding: binding, disposition: .selected, channels: channels)])
    // Test-only pre-seeded reconciled record. The production class has no bootstrap/import API.
    let backing = HandleRootMemory(try JSONEncoder().encode(record))
    let store = try RendezvousHandleJournalStore(context: context, backing: backing, exclusion: exclusion)
    return .init(directory: directory, exclusion: exclusion, backing: backing, store: store, context: context, binding: binding, record: record)
}

@Test func rendezvousChildStoreMissingMalformedClosedAndWrongContextNeverBootstrap() throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    for data in [Optional<Data>.none, Data(), Data("{}".utf8)] {
        f.backing.replaceForTest(data)
        #expect(throws: RendezvousHandleJournalStore.Failure.self) { try f.store.childStorage(binding: f.binding, channel: .repair) }
    }
    var closed = f.record; closed.closed = true; f.backing.replaceForTest(try JSONEncoder().encode(closed))
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try f.store.childStorage(binding: f.binding, channel: .repair) }
    f.backing.replaceForTest(try JSONEncoder().encode(f.record))
    let other = try RendezvousHandleJournalStore(context: Data(repeating: 9, count: 32), backing: f.backing, exclusion: f.exclusion)
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try other.childStorage(binding: f.binding, channel: .repair) }
    #expect(f.backing.writes == 0)
}

@Test func rendezvousChildStoreUsesCASAcrossInstancesAndRefusesWrongKeyOrEmptyReset() throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    let otherExclusion = try RendezvousLocalStorageExclusion(directory: f.directory, identity: f.exclusion.identity)
    let otherStore = try RendezvousHandleJournalStore(context: f.context, backing: f.backing, exclusion: otherExclusion)
    let first = try f.store.childStorage(binding: f.binding, channel: .repair).claimingJournalOwner(UUID())
    let stale = try otherStore.childStorage(binding: f.binding, channel: .repair).claimingJournalOwner(UUID())
    let state = try RendezvousRepairWindow(keyIdentifier: f.binding.keyIdentifier, pausedAtMS: 100)
    let bytes = try JSONEncoder().encode(state)
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try first.write(bytes) }
    #expect(try first.read() == nil && stale.read() == nil)
    try first.write(bytes)
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try stale.write(bytes) }
    #expect(f.backing.writes == 1)
    #expect(try stale.read() == bytes)
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try stale.write(Data()) }
    let wrong = try JSONEncoder().encode(RendezvousRepairWindow(keyIdentifier: Data(repeating: 2, count: 32).base64EncodedString(), pausedAtMS: 100))
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try stale.write(wrong) }
    #expect(f.backing.writes == 1)
}

@Test func rendezvousChildStoreKeepsUncertainCommittedRepairReservationAcrossRestart() async throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    let actor = RendezvousRepairJournal(storage: try f.store.childStorage(binding: f.binding, channel: .repair))
    _ = try await actor.beginPause(keyIdentifier: f.binding.keyIdentifier, at: 100)
    f.backing.configure(.failAfter)
    do { _ = try await actor.reserveExplicitRecovery(keyIdentifier: f.binding.keyIdentifier, at: 60_100); Issue.record("Uncertain reservation escaped") }
    catch HandleRootMemory.Failure.afterCommit {}
    let restarted = try RendezvousHandleJournalStore(context: f.context, backing: f.backing,
        exclusion: RendezvousLocalStorageExclusion(directory: f.directory, identity: f.exclusion.identity))
    let reader = RendezvousRepairJournal(storage: try restarted.childStorage(binding: f.binding, channel: .repair))
    let snapshot = try #require(try await reader.snapshot())
    #expect(snapshot.attemptsStarted == 1 && snapshot.reservation != nil)
    do { _ = try await reader.reserveExplicitRecovery(keyIdentifier: f.binding.keyIdentifier, at: 60_200); Issue.record("In-flight allowance was refunded") }
    catch RendezvousRepairWindow.Failure.inFlight {}
    #expect(try await reader.snapshot()?.attemptsStarted == 1)
}

@Test func rendezvousChildStoreBeforeCommitFailureDoesNotPretendAWriteWasCommitted() throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    let child = try f.store.childStorage(binding: f.binding, channel: .repair).claimingJournalOwner(UUID())
    #expect(try child.read() == nil)
    let bytes = try JSONEncoder().encode(RendezvousRepairWindow(keyIdentifier: f.binding.keyIdentifier, pausedAtMS: 100))
    f.backing.configure(.failBefore)
    #expect(throws: HandleRootMemory.Failure.self) { try child.write(bytes) }
    #expect(try child.read() == nil)
    f.backing.configure(.silentlyDrop)
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try child.write(bytes) }
    #expect(try child.read() == nil)
    try child.write(bytes)
    #expect(try child.read() == bytes)
}

@Test func rendezvousChildStoreOldCapabilityCannotReadOrWriteReusedSlotAndRollbackCloses() throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    let old = try f.store.childStorage(binding: f.binding, channel: .repair).claimingJournalOwner(UUID())
    #expect(try old.read() == nil)
    let next = RendezvousHandleJournalStore.Binding(slot: 0, sequence: 2, generationID: UUID(), keyIdentifier: Data(repeating: 2, count: 32).base64EncodedString())
    var reused = f.record; reused.lastSequence = 2; reused.selectedSequence = 2
    reused.slots = [.init(binding: next, disposition: .selected, channels: f.record.slots[0].channels)]
    // Test-only simulation of a future qualified terminal transition, not a production allocator.
    f.backing.replaceForTest(try JSONEncoder().encode(reused))
    let fresh = try f.store.childStorage(binding: next, channel: .repair).claimingJournalOwner(UUID())
    #expect(try fresh.read() == nil)
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try old.read() }
    let bytes = try JSONEncoder().encode(RendezvousRepairWindow(keyIdentifier: f.binding.keyIdentifier, pausedAtMS: 100))
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try old.write(bytes) }
    f.backing.replaceForTest(try JSONEncoder().encode(f.record))
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try old.read() }
    #expect(f.backing.writes == 0)
}

@Test func rendezvousChildStoreRejectsRetiredBindingRevisionOverflowAndWrongRootLock() throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    var retired = f.record; retired.selectedSequence = nil; retired.slots[0].disposition = .retired
    f.backing.replaceForTest(try JSONEncoder().encode(retired))
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try f.store.childStorage(binding: f.binding, channel: .repair) }
    var maximum = f.record
    let bytes = try JSONEncoder().encode(RendezvousRepairWindow(keyIdentifier: f.binding.keyIdentifier, pausedAtMS: 100))
    maximum.slots[0].channels["repair"] = .init(revision: .max, bytes: bytes)
    f.backing.replaceForTest(try JSONEncoder().encode(maximum))
    let child = try f.store.childStorage(binding: f.binding, channel: .repair).claimingJournalOwner(UUID())
    #expect(try child.read() == bytes)
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try child.write(bytes) }
    let otherDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("rendezvous-other-anchor-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: otherDirectory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: otherDirectory) }
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: otherDirectory)
    let other = try RendezvousHandleJournalStore(context: f.context, backing: f.backing,
        exclusion: RendezvousLocalStorageExclusion(directory: otherDirectory, identity: identity))
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try other.childStorage(binding: f.binding, channel: .repair) }
    #expect(f.backing.writes == 0)
}

@Test func rendezvousChildStoreCannotAliasOneCASWriterAcrossJournalActors() async throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    let raw = try f.store.childStorage(binding: f.binding, channel: .repair)
    #expect(throws: RendezvousHandleJournalStore.Failure.self) { try raw.read() }
    let first = RendezvousRepairJournal(storage: raw), second = RendezvousRepairJournal(storage: raw)
    _ = try await first.beginPause(keyIdentifier: f.binding.keyIdentifier, at: 100)
    do { _ = try await second.snapshot(); Issue.record("A second actor shared the first actor's mutable CAS view") }
    catch RendezvousHandleJournalStore.Failure.unownedWriter {}
    _ = try await first.reserveExplicitRecovery(keyIdentifier: f.binding.keyIdentifier, at: 60_100)
    #expect(try await first.snapshot()?.attemptsStarted == 1)
    #expect(f.backing.writes == 2)
}

@Test func rendezvousChildStoreOriginalEnrollmentExpiryScrubsProofWithoutResettingAttempt() async throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    let registration = RendezvousRegistrationJournal(storage: try f.store.childStorage(binding: f.binding, channel: .registration))
    let challenge = Data(repeating: 3, count: 32).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    let attempt = try await registration.prepare(keyIdentifier: f.binding.keyIdentifier, challengeIdentifier: challenge,
        nonce: Data(repeating: 5, count: 32), attestation: Data([1, 2, 3]), admittedAtMS: 100, deadlineMS: 120_100)
    let before = try #require(try await registration.snapshot(at: 120_099))
    #expect(before.phase == .prepared && before.attemptIdentifier == attempt)
    let expired = try #require(try await registration.snapshot(at: 120_100))
    #expect(expired.phase == .registrationUncertain && expired.attemptIdentifier == attempt)
    let root = try JSONDecoder().decode(RendezvousHandleJournalStore.Record.self, from: #require(try f.backing.read()))
    let bytes = try #require(root.slots[0].channels["registration"]?.bytes)
    let body = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    for secret in ["nonce", "nonceHash", "request", "requestHash", "challenge"] { #expect(body[secret] == nil) }
    let restarted = RendezvousRegistrationJournal(storage: try f.store.childStorage(binding: f.binding, channel: .registration))
    do {
        _ = try await restarted.prepare(keyIdentifier: f.binding.keyIdentifier, challengeIdentifier: challenge,
            nonce: Data(repeating: 5, count: 32), attestation: Data([1, 2, 3]), admittedAtMS: 120_101, deadlineMS: 240_101)
        Issue.record("Expired original enrollment was replaced with a fresh attempt")
    } catch RendezvousRegistrationJournal.Failure.alreadyExists {}
}

@Test func rendezvousChildStoreObservedRevisionRollbackCannotReturnAnOlderBudget() async throws {
    let f = try handleStoreFixture(); defer { try? FileManager.default.removeItem(at: f.directory) }
    let repair = RendezvousRepairJournal(storage: try f.store.childStorage(binding: f.binding, channel: .repair))
    _ = try await repair.beginPause(keyIdentifier: f.binding.keyIdentifier, at: 100)
    let before = try f.backing.read()
    _ = try await repair.reserveExplicitRecovery(keyIdentifier: f.binding.keyIdentifier, at: 60_100)
    #expect(try await repair.snapshot()?.attemptsStarted == 1)
    // Test-only rollback of the backing bytes; this is not a production API.
    f.backing.replaceForTest(before)
    do { _ = try await repair.snapshot(); Issue.record("Observed channel revision rolled back") }
    catch RendezvousHandleJournalStore.Failure.rollback {}
}
