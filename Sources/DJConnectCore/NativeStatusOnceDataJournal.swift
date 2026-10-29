#if os(iOS) || os(macOS)
import Foundation
import Darwin
import SQLite3

/// Internal transaction DATA preparation for the canonical native lifecycle design.
/// No production caller, bootstrap/repair, native capability, SDK or network port.
/// A committed row/ACK is NOT an original process-bound permission to invoke SDK.
actor NativeStatusOnceDataJournal {
    struct Request: Equatable, Sendable {
        let operation: UUID
        let decision: UUID
        let presentation: UUID
        let presentationGeneration: UUID
        let binding: Data
        let terminalOperation: UUID
        var valid: Bool {
            binding.count == 32 && operation != terminalOperation
        }
    }
    struct Snapshot: Equatable, Sendable {
        let request: Request
        let dispatchConsumed: Bool
        let terminalConsumed: Bool
    }
    enum Denial: Equatable, Sendable {
        case invalid, unavailable, capacity, conflict, originalProcessReservationMissing
        case transaction(Int32)
    }
    enum Result: Equatable, Sendable {
        /// Metadata ACK only. Never a usable native dispatch capability.
        case committed(Snapshot)
        case alreadyRecorded(Snapshot)
        case denied(Denial)
        case unknown(UUID, storageFailure: Int32? = nil)
    }
    /// Explicit metadata fault seam, internal and unused by any production caller.
    /// Drops a reply AFTER the real SQLite COMMIT; it never simulates commit itself.
    enum ReplyLoss: Sendable { case none, reserve, dispatch, terminal }

    private let connection: Connection
    private let replyLoss: ReplyLoss
    private var reservations: [UUID: Request] = [:]
    private var terminals: [UUID: Request] = [:]
    private var dispatchAttempts = Set<UUID>()
    private var terminalAttempts = Set<UUID>()
    private var withdrawn = false

    /// Opens only a pre-existing initialized database. There is deliberately no
    /// CREATE, migration, replacement or reconstruction of process reservations.
    /// Path/inode checks below are metadata hardening, NOT qualified VFS/restore
    /// provenance. Such provenance remains required before a production provider.
    init(existingDatabase: URL, storeID: UUID, capacity: Int, replyLoss: ReplyLoss = .none) throws {
        connection = try Connection(url: existingDatabase, storeID: storeID, capacity: capacity)
        self.replyLoss = replyLoss
    }

    /// Retires this whole storage-process custody, NOT positive display/source
    /// permission. A future positive owner must not use this to discard its
    /// separately admitted terminal authority or the persisted terminal slot.
    func closeProcessCustody() { withdrawn = true; reservations.removeAll(); terminals.removeAll() }

    func status(_ operation: UUID) throws -> Snapshot? {
        try connection.validate()
        return try connection.snapshot(operation)
    }

    func reserve(_ request: Request) -> Result {
        guard !withdrawn else { return .denied(.unavailable) }
        guard request.valid else { return .denied(.invalid) }
        do {
            try connection.validate()
            if let old = try connection.snapshot(request.operation) {
                return old.request == request ? .alreadyRecorded(old) : .denied(.conflict)
            }
            try connection.begin()
            // Serialize capacity and uniqueness checks with the actual insert.
            if let old = try connection.snapshot(request.operation) {
                try connection.rollback()
                return old.request == request ? .alreadyRecorded(old) : .denied(.conflict)
            }
            guard try connection.count() < connection.capacity else {
                try connection.rollback(); return .denied(.capacity)
            }
            do { try connection.insert(request) }
            catch Connection.Failure.conflict { try? connection.rollback(); return .denied(.conflict) }
            do { try connection.commit() }
            catch { return .unknown(request.operation, storageFailure: Self.storageCode(error)) }
            guard replyLoss != .reserve else { return .unknown(request.operation) }
            do {
                try connection.validate()
                let expected = Snapshot(request: request, dispatchConsumed: false, terminalConsumed: false)
                guard try connection.snapshot(request.operation) == expected else { return .unknown(request.operation) }
                reservations[request.operation] = request
                terminals[request.operation] = request
                return .committed(expected)
            } catch { return .unknown(request.operation, storageFailure: Self.storageCode(error)) }
        } catch Connection.Failure.sql(let code) {
            try? connection.rollback()
            return .denied(.transaction(code))
        } catch {
            try? connection.rollback()
            return .denied(.unavailable)
        }
    }

    func consumeDispatch(_ operation: UUID) -> Result {
        consume(operation, terminal: false)
    }

    /// The separately reserved terminal slot does not require a live positive
    /// admission. This consumes only SQL accounting, never a native end right.
    func consumeTerminal(_ operation: UUID) -> Result {
        consume(operation, terminal: true)
    }

    private func consume(_ operation: UUID, terminal: Bool) -> Result {
        guard !withdrawn else { return .denied(.unavailable) }
        do {
            try connection.validate()
            guard let old = try connection.snapshot(operation) else { return .denied(.invalid) }
            if terminal ? old.terminalConsumed : old.dispatchConsumed { return .alreadyRecorded(old) }
            let original = terminal ? terminals[operation] : reservations[operation]
            let attempted = terminal ? terminalAttempts.contains(operation) : dispatchAttempts.contains(operation)
            guard let original, !attempted else { return .denied(.originalProcessReservationMissing) }
            // Latch before beginning the transaction. Even a definitive denial
            // cannot free prior P1 capacity or make a new same-process attempt.
            if terminal { terminalAttempts.insert(operation) } else { dispatchAttempts.insert(operation) }
            // Retain the complete original binding. Observing a different valid
            // row spends this attempt too; restoring old SQL cannot revive it.
            guard old.request == original else { return .denied(.conflict) }
            try connection.begin()
            // Another connection could change metadata before BEGIN IMMEDIATE.
            // Compare again while the write transaction holds serialization.
            guard let locked = try connection.snapshot(operation), locked.request == original else {
                try connection.rollback(); return .denied(.conflict)
            }
            try connection.markConsumed(operation, terminal: terminal)
            do { try connection.commit() }
            catch { return .unknown(operation, storageFailure: Self.storageCode(error)) }
            guard replyLoss != (terminal ? .terminal : .dispatch) else { return .unknown(operation) }
            do {
                try connection.validate()
                guard let current = try connection.snapshot(operation), current.request == original else { return .unknown(operation) }
                return .committed(current)
            } catch { return .unknown(operation, storageFailure: Self.storageCode(error)) }
        } catch Connection.Failure.sql(let code) {
            try? connection.rollback()
            return .denied(.transaction(code))
        } catch Connection.Failure.conflict {
            try? connection.rollback()
            return .denied(.conflict)
        } catch {
            try? connection.rollback()
            return .denied(.unavailable)
        }
    }

    private static func storageCode(_ error: any Error) -> Int32? {
        if case Connection.Failure.sql(let code) = error { return code }
        return nil
    }

    /// FULLMUTEX connection remains behind one actor. This wrapper also makes
    /// deterministic close safe when the actor is destroyed; no external users.
    private final class Connection: @unchecked Sendable {
        let capacity: Int
        private let url: URL
        private let storeID: UUID
        private let device: Int64
        private let inode: UInt64
        private let parentDevice: Int64
        private let parentInode: UInt64
        private let db: OpaquePointer
        private var poisoned = false
        private var closed = false
        enum Failure: Error { case unavailable, sql(Int32), conflict }

        init(url: URL, storeID: UUID, capacity: Int) throws {
            guard url.isFileURL, capacity > 0 else { throw Failure.unavailable }
            let file = try Self.file(url)
            let parent = try Self.directory(url.deletingLastPathComponent())
            self.url = url; self.storeID = storeID; self.capacity = capacity
            device = Int64(file.st_dev); inode = UInt64(file.st_ino)
            parentDevice = Int64(parent.st_dev); parentInode = UInt64(parent.st_ino)
            var handle: OpaquePointer?
            let result = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_NOFOLLOW, nil)
            guard result == SQLITE_OK, let handle else {
                if let handle { sqlite3_close(handle) }; throw Failure.unavailable
            }
            db = handle
            do {
                try execute("PRAGMA trusted_schema=OFF; PRAGMA foreign_keys=ON; PRAGMA synchronous=FULL; PRAGMA fullfsync=ON;")
                guard try string("PRAGMA journal_mode") == "wal", try integer("PRAGMA synchronous") == 2,
                      try integer("PRAGMA fullfsync") == 1 else { throw Failure.unavailable }
                try validate()
            } catch { sqlite3_close(handle); closed = true; throw error }
        }
        deinit { if !closed { sqlite3_close(db) } }

        private static func file(_ url: URL) throws -> stat {
            var value = stat()
            guard lstat(url.path, &value) == 0, value.st_mode & S_IFMT == S_IFREG,
                  value.st_uid == geteuid(), value.st_mode & 0o077 == 0, value.st_nlink == 1,
                  value.st_size >= 100 else { throw Failure.unavailable }
            return value
        }
        private static func directory(_ url: URL) throws -> stat {
            var value = stat()
            guard lstat(url.path, &value) == 0, value.st_mode & S_IFMT == S_IFDIR,
                  value.st_uid == geteuid(), value.st_mode & 0o077 == 0 else { throw Failure.unavailable }
            return value
        }
        func validate() throws {
            guard !poisoned else { throw Failure.unavailable }
            do { try validateCurrentMetadata() }
            catch { poisoned = true; throw error }
        }
        private func validateCurrentMetadata() throws {
            let file = try Self.file(url), parent = try Self.directory(url.deletingLastPathComponent())
            guard Int64(file.st_dev) == device, UInt64(file.st_ino) == inode,
                  Int64(parent.st_dev) == parentDevice, UInt64(parent.st_ino) == parentInode else { throw Failure.unavailable }
            let statement = try prepare("SELECT schema_version, store_id, capacity FROM native_status_root WHERE singleton=1")
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW, sqlite3_column_type(statement, 0) == SQLITE_INTEGER,
                  sqlite3_column_type(statement, 2) == SQLITE_INTEGER, sqlite3_column_int64(statement, 0) == 1,
                  text(statement, 1) == storeID.uuidString.lowercased(), sqlite3_column_int64(statement, 2) == Int64(capacity),
                  sqlite3_step(statement) == SQLITE_DONE else { throw Failure.unavailable }
            let roles = try prepare("SELECT id,kind,reservation_operation_id FROM native_status_operation_ids LIMIT 0")
            sqlite3_finalize(roles)
        }
        func begin() throws { try validate(); try execute("BEGIN IMMEDIATE") }
        func rollback() throws {
            if sqlite3_get_autocommit(db) == 0 { try execute("ROLLBACK") }
        }
        func commit() throws {
            do { try validate(); try execute("COMMIT") }
            catch { poisoned = true; try? rollback(); throw error }
        }
        func count() throws -> Int {
            let value = try integer("SELECT COUNT(*) FROM native_status_operations")
            guard value >= 0, let count = Int(exactly: value) else { throw Failure.unavailable }
            return count
        }
        func execute(_ sql: String) throws {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw Failure.sql(sqlite3_extended_errcode(db)) }
        }
        private func prepare(_ sql: String) throws -> OpaquePointer {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw Failure.sql(sqlite3_extended_errcode(db)) }
            return statement
        }
        private func string(_ sql: String) throws -> String {
            let statement = try prepare(sql); defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW, let value = text(statement, 0) else { throw Failure.sql(sqlite3_extended_errcode(db)) }
            return value
        }
        private func integer(_ sql: String) throws -> Int64 {
            let statement = try prepare(sql); defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else { throw Failure.sql(sqlite3_extended_errcode(db)) }
            guard sqlite3_column_type(statement, 0) == SQLITE_INTEGER else { throw Failure.unavailable }
            return sqlite3_column_int64(statement, 0)
        }
        private func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
            // Only closed UUID/literal cells use this helper. Never coerce BLOB
            // or numeric cells to text, truncate at NUL or decode invalid UTF8.
            guard sqlite3_column_type(statement, column) == SQLITE_TEXT else { return nil }
            let count = Int(sqlite3_column_bytes(statement, column))
            guard (1...36).contains(count), let bytes = sqlite3_column_text(statement, column) else { return nil }
            let data = Data(bytes: bytes, count: count)
            guard !data.contains(0) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        private func uuid(_ statement: OpaquePointer, _ column: Int32) -> UUID? {
            guard let raw = text(statement, column), let value = UUID(uuidString: raw),
                  raw == value.uuidString.lowercased() else { return nil }
            return value
        }
        private func inserted(_ statement: OpaquePointer) throws {
            guard sqlite3_step(statement) == SQLITE_DONE else {
                if sqlite3_extended_errcode(db) & 0xff == SQLITE_CONSTRAINT { throw Failure.conflict }
                throw Failure.sql(sqlite3_extended_errcode(db))
            }
        }
        private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        private func bind(_ value: UUID, to statement: OpaquePointer, at index: Int32) throws {
            let code = sqlite3_bind_text(statement, index, value.uuidString.lowercased(), -1, transient)
            guard code == SQLITE_OK else { throw Failure.sql(code) }
        }
        func insert(_ request: Request) throws {
            let statement = try prepare("INSERT INTO native_status_operations(operation_id,decision_id,presentation_id,presentation_generation,binding,terminal_operation_id,dispatch_consumed,terminal_consumed) VALUES(?,?,?,?,?,?,0,0)")
            defer { sqlite3_finalize(statement) }
            try bind(request.operation, to: statement, at: 1); try bind(request.decision, to: statement, at: 2)
            try bind(request.presentation, to: statement, at: 3); try bind(request.presentationGeneration, to: statement, at: 4)
            let result = request.binding.withUnsafeBytes { sqlite3_bind_blob(statement, 5, $0.baseAddress, Int32($0.count), transient) }
            guard result == SQLITE_OK else { throw Failure.sql(result) }
            try bind(request.terminalOperation, to: statement, at: 6)
            try inserted(statement)
            // ONE shared namespace: kind is checked metadata, not a uniqueness
            // partition that could spend the same UUID under a different role.
            for (id, kind) in [(request.operation, "dispatch"), (request.terminalOperation, "terminal")] {
                let role = try prepare("INSERT INTO native_status_operation_ids(id,kind,reservation_operation_id) VALUES(?,'\(kind)',?)")
                defer { sqlite3_finalize(role) }
                try bind(id, to: role, at: 1); try bind(request.operation, to: role, at: 2)
                try inserted(role)
            }
        }
        func snapshot(_ operation: UUID) throws -> Snapshot? {
            let statement = try prepare("SELECT decision_id,presentation_id,presentation_generation,binding,terminal_operation_id,dispatch_consumed,terminal_consumed FROM native_status_operations WHERE operation_id=?")
            defer { sqlite3_finalize(statement) }; try bind(operation, to: statement, at: 1)
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return nil }
            guard result == SQLITE_ROW else { throw Failure.sql(sqlite3_extended_errcode(db)) }
            guard result == SQLITE_ROW,
                  let decision = uuid(statement, 0), let presentation = uuid(statement, 1),
                  let generation = uuid(statement, 2), sqlite3_column_type(statement, 3) == SQLITE_BLOB,
                  sqlite3_column_bytes(statement, 3) == 32, let bytes = sqlite3_column_blob(statement, 3),
                  let terminal = uuid(statement, 4), sqlite3_column_type(statement, 5) == SQLITE_INTEGER,
                  sqlite3_column_type(statement, 6) == SQLITE_INTEGER else { throw Failure.unavailable }
            let request = Request(operation: operation, decision: decision, presentation: presentation,
                                  presentationGeneration: generation, binding: Data(bytes: bytes, count: 32), terminalOperation: terminal)
            let dispatch = sqlite3_column_int64(statement, 5), negative = sqlite3_column_int64(statement, 6)
            guard request.valid, [0,1].contains(dispatch), [0,1].contains(negative) else { throw Failure.unavailable }
            let roles = try prepare("SELECT id,kind FROM native_status_operation_ids WHERE reservation_operation_id=?")
            defer { sqlite3_finalize(roles) }; try bind(operation, to: roles, at: 1)
            var actual: [String: UUID] = [:]
            while true {
                let step = sqlite3_step(roles)
                if step == SQLITE_DONE { break }
                guard step == SQLITE_ROW else { throw Failure.sql(sqlite3_extended_errcode(db)) }
                guard let id = uuid(roles, 0), let kind = text(roles, 1), actual[kind] == nil else { throw Failure.unavailable }
                actual[kind] = id
            }
            guard actual == ["dispatch": operation, "terminal": terminal] else { throw Failure.unavailable }
            return .init(request: request, dispatchConsumed: dispatch == 1, terminalConsumed: negative == 1)
        }
        func markConsumed(_ operation: UUID, terminal: Bool) throws {
            let column = terminal ? "terminal_consumed" : "dispatch_consumed"
            let statement = try prepare("UPDATE native_status_operations SET \(column)=1 WHERE operation_id=? AND \(column)=0")
            defer { sqlite3_finalize(statement) }; try bind(operation, to: statement, at: 1)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw Failure.sql(sqlite3_extended_errcode(db)) }
            guard sqlite3_changes(db) == 1 else { throw Failure.conflict }
        }
    }
}
#endif
