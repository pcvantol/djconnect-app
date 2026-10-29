#if os(iOS) || os(macOS)
import Foundation
import Testing
import SQLite3
import Darwin
@testable import DJConnectCore

private final class NativeOnceDatabase {
    let folder: URL
    let path: URL
    let storeID = UUID()
    let capacity: Int
    init(capacity: Int = 2) throws {
        self.capacity = capacity
        let root = ProcessInfo.processInfo.environment["DJCONNECT_NATIVE_SQLITE_TEST_ROOT"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory
        // SQLite NOFOLLOW also rejects symlinked parent components. Darwin's
        // default /var temporary URL can survive Foundation URL normalization;
        // resolve the existing test root through the filesystem itself.
        let resolved = try #require(realpath(root.path, nil))
        defer { free(resolved) }
        folder = URL(fileURLWithPath: String(cString: resolved)).appendingPathComponent("native-status-data-tests-" + UUID().uuidString)
        path = folder.appendingPathComponent("existing.sqlite3")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        // Explicit fresh disposable TEST bootstrap only; product source has none.
        let fd = open(path.path, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o600))
        try #require(fd >= 0); close(fd)
        let schema = try #require(Bundle.module.url(forResource: "native-status-once-data-test-schema-v1", withExtension: "sql", subdirectory: "Fixtures"))
        try sql(String(contentsOf: schema, encoding: .utf8))
        try sql("INSERT INTO native_status_root VALUES(1,1,'\(storeID.uuidString.lowercased())',\(capacity))")
    }
    deinit { try? FileManager.default.removeItem(at: folder) }
    func sql(_ sql: String) throws {
        var db: OpaquePointer?
        let result = sqlite3_open_v2(path.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOFOLLOW, nil)
        defer { sqlite3_close(db) }
        try #require(result == SQLITE_OK, "SQLite bootstrap: \(sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown") at \(path.path)")
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }
    func journal(_ loss: NativeStatusOnceDataJournal.ReplyLoss = .none) throws -> NativeStatusOnceDataJournal {
        try .init(existingDatabase: path, storeID: storeID, capacity: capacity, replyLoss: loss)
    }
    static func request() -> NativeStatusOnceDataJournal.Request {
        .init(operation: UUID(), decision: UUID(), presentation: UUID(), presentationGeneration: UUID(),
              binding: Data(repeating: 7, count: 32), terminalOperation: UUID())
    }
}

@Suite(.serialized) struct NativeStatusOnceDataJournalTests {
    @Test func exactReserveConsumeAndIndependentTerminalMetadata() async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        let initial = NativeStatusOnceDataJournal.Snapshot(request: request, dispatchConsumed: false, terminalConsumed: false)
        #expect(await journal.reserve(request) == .committed(initial))
        #expect(await journal.reserve(request) == .alreadyRecorded(initial))
        let consumed = NativeStatusOnceDataJournal.Snapshot(request: request, dispatchConsumed: true, terminalConsumed: false)
        #expect(await journal.consumeDispatch(request.operation) == .committed(consumed))
        #expect(await journal.consumeDispatch(request.operation) == .alreadyRecorded(consumed))
        let terminal = NativeStatusOnceDataJournal.Snapshot(request: request, dispatchConsumed: true, terminalConsumed: true)
        #expect(await journal.consumeTerminal(request.operation) == .committed(terminal))
        #expect(await journal.consumeTerminal(request.operation) == .alreadyRecorded(terminal))
        #expect(try await journal.status(request.operation) == terminal)
    }

    @Test func finiteCapacityKeepsTerminalReservationAfterPositiveConsumption() async throws {
        let database = try NativeOnceDatabase(capacity: 1), journal = try database.journal()
        let first = NativeOnceDatabase.request(), other = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(first) else { Issue.record("reserve failed"); return }
        #expect(await journal.reserve(other) == .denied(.capacity))
        guard case .committed = await journal.consumeDispatch(first.operation) else { Issue.record("consume failed"); return }
        #expect(await journal.reserve(other) == .denied(.capacity))
        guard case .committed = await journal.consumeTerminal(first.operation) else { Issue.record("terminal failed"); return }
        #expect(await journal.reserve(other) == .denied(.capacity))
    }

    @Test(arguments: [NativeStatusOnceDataJournal.ReplyLoss.reserve, .dispatch, .terminal])
    func lostReplyFollowsActualCommitAndNeverRecreatesProcessReservation(_ loss: NativeStatusOnceDataJournal.ReplyLoss) async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal(loss)
        let request = NativeOnceDatabase.request()
        let reserve = await journal.reserve(request)
        if loss == .reserve {
            #expect(reserve == .unknown(request.operation))
            #expect(await journal.consumeDispatch(request.operation) == .denied(.originalProcessReservationMissing))
        } else {
            guard case .committed = reserve else { Issue.record("reserve failed"); return }
            if loss == .dispatch { #expect(await journal.consumeDispatch(request.operation) == .unknown(request.operation)) }
            else { #expect(await journal.consumeTerminal(request.operation) == .unknown(request.operation)) }
        }
        let reopened = try database.journal()
        let status = try #require(await reopened.status(request.operation))
        #expect(status.dispatchConsumed == (loss == .dispatch))
        #expect(status.terminalConsumed == (loss == .terminal))
        if loss != .dispatch { #expect(await reopened.consumeDispatch(request.operation) == .denied(.originalProcessReservationMissing)) }
    }

    @Test func reopenStatusCannotGrantAnUnconsumedOriginalProcessReservation() async throws {
        let database = try NativeOnceDatabase(), original = try database.journal()
        let request = NativeOnceDatabase.request()
        guard case .committed = await original.reserve(request) else { Issue.record("reserve failed"); return }
        let reopened = try database.journal()
        let prior = try #require(await reopened.status(request.operation))
        #expect(await reopened.reserve(request) == .alreadyRecorded(prior))
        #expect(await reopened.consumeDispatch(request.operation) == .denied(.originalProcessReservationMissing))
        #expect(await reopened.consumeTerminal(request.operation) == .denied(.originalProcessReservationMissing))
        guard case .committed = await original.consumeDispatch(request.operation) else { Issue.record("original lost custody"); return }
    }

    @Test func duplicateDecisionOrPresentationCannotOccupyAnotherReservation() async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let original = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(original) else { Issue.record("reserve failed"); return }
        let other = NativeStatusOnceDataJournal.Request(operation: UUID(), decision: original.decision,
            presentation: UUID(), presentationGeneration: UUID(), binding: original.binding, terminalOperation: UUID())
        #expect(await journal.reserve(other) == .denied(.conflict))
        #expect(try await journal.status(other.operation) == nil)
        let mismatched = NativeStatusOnceDataJournal.Request(operation: original.operation, decision: UUID(),
            presentation: original.presentation, presentationGeneration: UUID(), binding: original.binding, terminalOperation: UUID())
        #expect(await journal.reserve(mismatched) == .denied(.conflict))
    }

    @Test(arguments: [false, true])
    func operationIDsCannotBeReusedAcrossPositiveAndTerminalRoles(_ aliasPositive: Bool) async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let first = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(first) else { Issue.record("reserve failed"); return }
        let request = NativeStatusOnceDataJournal.Request(operation: aliasPositive ? first.terminalOperation : UUID(),
            decision: UUID(), presentation: UUID(), presentationGeneration: UUID(), binding: first.binding,
            terminalOperation: aliasPositive ? UUID() : first.operation)
        #expect(await journal.reserve(request) == .denied(.conflict))
        #expect(try await journal.status(request.operation) == nil)
    }

    @Test func definitivePrecommitDenialDoesNotResetP1OrItsLocalAttempt() async throws {
        let database = try NativeOnceDatabase(capacity: 1), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(request) else { Issue.record("reserve failed"); return }
        try database.sql("CREATE TRIGGER deny_dispatch BEFORE UPDATE OF dispatch_consumed ON native_status_operations BEGIN SELECT RAISE(ABORT,'synthetic-denial'); END;")
        // The SDK's composite SQLITE_CONSTRAINT_TRIGGER macro is not imported
        // into Swift: sqlite3.h defines it as SQLITE_CONSTRAINT | (7 << 8).
        #expect(await journal.consumeDispatch(request.operation) == .denied(.transaction(SQLITE_CONSTRAINT | (7 << 8))))
        try database.sql("DROP TRIGGER deny_dispatch")
        #expect(await journal.consumeDispatch(request.operation) == .denied(.originalProcessReservationMissing))
        #expect(await journal.reserve(NativeOnceDatabase.request()) == .denied(.capacity))
        let original = try #require(await journal.status(request.operation))
        #expect(!original.dispatchConsumed)
        guard case .committed = await journal.consumeTerminal(request.operation) else { Issue.record("negative slot lost"); return }
    }

    @Test func withdrawalAndChangedStoreIdentityCannotContinue() async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(request) else { Issue.record("reserve failed"); return }
        await journal.closeProcessCustody()
        #expect(await journal.consumeDispatch(request.operation) == .denied(.unavailable))
        #expect(await journal.reserve(NativeOnceDatabase.request()) == .denied(.unavailable))
        let reopened = try database.journal()
        try database.sql("UPDATE native_status_root SET store_id='\(UUID().uuidString.lowercased())'")
        #expect(await reopened.consumeDispatch(request.operation) == .denied(.unavailable))
    }

    @Test func missingEmptyAndSymlinkDatabaseNeverBootstrapOrRepair() throws {
        let database = try NativeOnceDatabase()
        let missing = database.folder.appendingPathComponent("missing.sqlite3")
        #expect(throws: (any Error).self) { try NativeStatusOnceDataJournal(existingDatabase: missing, storeID: database.storeID, capacity: 2) }
        #expect(!FileManager.default.fileExists(atPath: missing.path))
        let link = database.folder.appendingPathComponent("link.sqlite3")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: database.path)
        #expect(throws: (any Error).self) { try NativeStatusOnceDataJournal(existingDatabase: link, storeID: database.storeID, capacity: 2) }
        let empty = database.folder.appendingPathComponent("empty.sqlite3")
        #expect(FileManager.default.createFile(atPath: empty.path, contents: Data(), attributes: [.posixPermissions: 0o600]))
        #expect(throws: (any Error).self) { try NativeStatusOnceDataJournal(existingDatabase: empty, storeID: database.storeID, capacity: 2) }
        #expect(try Data(contentsOf: empty).isEmpty)
    }

    @Test func observingReplacedFileCannotReviveAfterRestoringTheOldPath() async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(request) else { Issue.record("reserve failed"); return }
        let retained = database.folder.appendingPathComponent("retained-original.sqlite3")
        try FileManager.default.moveItem(at: database.path, to: retained)
        #expect(await journal.consumeDispatch(request.operation) == .denied(.unavailable))
        try FileManager.default.moveItem(at: retained, to: database.path)
        #expect(await journal.consumeDispatch(request.operation) == .denied(.unavailable))
        let reopened = try database.journal()
        let original = try #require(await reopened.status(request.operation))
        #expect(!original.dispatchConsumed)
        #expect(await reopened.consumeDispatch(request.operation) == .denied(.originalProcessReservationMissing))
    }

    @Test func coincidentTypedIdentityValuesDoNotCreateSharedOperationCredit() async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let id = UUID()
        let request = NativeStatusOnceDataJournal.Request(operation: id, decision: id, presentation: id,
            presentationGeneration: UUID(), binding: Data(repeating: 9, count: 32), terminalOperation: UUID())
        guard case .committed = await journal.reserve(request) else { Issue.record("typed metadata rejected"); return }
        guard case .committed = await journal.consumeDispatch(id) else { Issue.record("consume failed"); return }
        guard case .alreadyRecorded = await journal.consumeDispatch(id) else { Issue.record("duplicate was not retained"); return }
    }

    @Test(arguments: ["schema_version", "dispatch_consumed", "terminal_consumed"])
    func fullWidthSQLiteIntegersCannotAliasAcceptedVersionOrFlags(_ column: String) async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(request) else { Issue.record("reserve failed"); return }
        if column == "schema_version" {
            try database.sql("PRAGMA ignore_check_constraints=ON; UPDATE native_status_root SET schema_version=4294967297")
            #expect(throws: (any Error).self) { try database.journal() }
        } else {
            try database.sql("PRAGMA ignore_check_constraints=ON; UPDATE native_status_operations SET \(column)=4294967296")
            var rejected = false
            do { _ = try await journal.status(request.operation) } catch { rejected = true }
            #expect(rejected)
        }
    }

    @Test(arguments: ["store_nul", "decision_nul", "role_nul", "kind_nul", "kind_invalid_utf8", "store_blob"])
    func identityTextRejectsEmbeddedNULAndNonTextCells(_ mutation: String) async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(request) else { Issue.record("reserve failed"); return }
        switch mutation {
        case "store_nul": try database.sql("UPDATE native_status_root SET store_id=store_id||char(0)||'suffix'")
        case "decision_nul": try database.sql("UPDATE native_status_operations SET decision_id=decision_id||char(0)||'suffix'")
        case "role_nul": try database.sql("UPDATE native_status_operation_ids SET id=id||char(0)||'suffix'")
        case "kind_nul": try database.sql("PRAGMA ignore_check_constraints=ON; UPDATE native_status_operation_ids SET kind=kind||char(0)||'suffix'")
        case "kind_invalid_utf8": try database.sql("PRAGMA ignore_check_constraints=ON; UPDATE native_status_operation_ids SET kind=CAST(x'80' AS TEXT) WHERE kind='dispatch'")
        default: try database.sql("UPDATE native_status_root SET store_id=CAST(store_id AS BLOB)")
        }
        var rejected = false
        do { _ = try await journal.status(request.operation) } catch { rejected = true }
        #expect(rejected)
    }

    @Test(arguments: ["binding", "decision_id", "presentation_id", "presentation_generation", "terminal_operation_id"], [false, true])
    func processReservationRetainsItsOriginalImmutableRequest(_ column: String, _ terminal: Bool) async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(request) else { Issue.record("reserve failed"); return }
        let changed = column == "binding" ? "zeroblob(32)" : "'\(UUID().uuidString.lowercased())'"
        try database.sql("UPDATE native_status_operations SET \(column)=\(changed)")
        if column == "terminal_operation_id" {
            try database.sql("UPDATE native_status_operation_ids SET id=\(changed) WHERE kind='terminal'")
        }
        let rejected = terminal ? await journal.consumeTerminal(request.operation) : await journal.consumeDispatch(request.operation)
        #expect(rejected == .denied(.conflict))
        let original: String
        switch column {
        case "binding": original = "x'" + request.binding.map { String(format: "%02x", $0) }.joined() + "'"
        case "decision_id": original = "'\(request.decision.uuidString.lowercased())'"
        case "presentation_id": original = "'\(request.presentation.uuidString.lowercased())'"
        case "presentation_generation": original = "'\(request.presentationGeneration.uuidString.lowercased())'"
        default: original = "'\(request.terminalOperation.uuidString.lowercased())'"
        }
        try database.sql("UPDATE native_status_operations SET \(column)=\(original)")
        if column == "terminal_operation_id" {
            try database.sql("UPDATE native_status_operation_ids SET id=\(original) WHERE kind='terminal'")
        }
        let retry = terminal ? await journal.consumeTerminal(request.operation) : await journal.consumeDispatch(request.operation)
        #expect(retry == .denied(.originalProcessReservationMissing))
        let snapshot = try #require(await journal.status(request.operation))
        #expect(!snapshot.dispatchConsumed && !snapshot.terminalConsumed)
    }

    @Test(arguments: [false, true])
    func changedCommittedBindingCannotReturnPositiveAcknowledgement(_ terminal: Bool) async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        guard case .committed = await journal.reserve(request) else { Issue.record("reserve failed"); return }
        let column = terminal ? "terminal_consumed" : "dispatch_consumed"
        try database.sql("CREATE TRIGGER change_binding AFTER UPDATE OF \(column) ON native_status_operations BEGIN UPDATE native_status_operations SET binding=zeroblob(32) WHERE operation_id=NEW.operation_id; END;")
        let result = terminal ? await journal.consumeTerminal(request.operation) : await journal.consumeDispatch(request.operation)
        #expect(result == .unknown(request.operation))
        try database.sql("DROP TRIGGER change_binding")
        let original = request.binding.map { String(format: "%02x", $0) }.joined()
        try database.sql("UPDATE native_status_operations SET binding=x'\(original)'")
        let snapshot = try #require(await journal.status(request.operation))
        #expect(snapshot.dispatchConsumed == !terminal && snapshot.terminalConsumed == terminal)
        let retry = terminal ? await journal.consumeTerminal(request.operation) : await journal.consumeDispatch(request.operation)
        #expect(retry == .alreadyRecorded(snapshot))
    }

    @Test func changedReserveReadbackCannotMintOriginalProcessReservation() async throws {
        let database = try NativeOnceDatabase(), journal = try database.journal()
        let request = NativeOnceDatabase.request()
        try database.sql("CREATE TRIGGER change_reserve AFTER INSERT ON native_status_operations BEGIN UPDATE native_status_operations SET binding=zeroblob(32) WHERE operation_id=NEW.operation_id; END;")
        #expect(await journal.reserve(request) == .unknown(request.operation))
        try database.sql("DROP TRIGGER change_reserve")
        let original = request.binding.map { String(format: "%02x", $0) }.joined()
        try database.sql("UPDATE native_status_operations SET binding=x'\(original)'")
        #expect(await journal.consumeDispatch(request.operation) == .denied(.originalProcessReservationMissing))
        #expect(await journal.consumeTerminal(request.operation) == .denied(.originalProcessReservationMissing))
        let snapshot = try #require(await journal.status(request.operation))
        #expect(!snapshot.dispatchConsumed && !snapshot.terminalConsumed)
    }
}
#endif
