import Foundation
import Darwin

/// Synchronous exclusion only, not a root/journal/key or external-effect grant.
/// No product factory is wired. The eventual qualified factory must persist the
/// original Identity in the retained root and give that same identity to every
/// instance/process. Normal acquisition NEVER creates/adopts/replaces a lock.
final class RendezvousLocalStorageExclusion: @unchecked Sendable {
    enum Failure: Error { case invalidDirectory, unsafeFile, busy, system(Int32) }
    struct Identity: Codable, Equatable, Sendable {
        let directoryDevice: Int64
        let directoryInode: UInt64
        let fileDevice: Int64
        let fileInode: UInt64
        let fileBirthSeconds: Int64
        let fileBirthNanoseconds: Int64
    }
    static let filename = ".rendezvous-journal-exclusion-v1.lock"
    let identity: Identity
    private let directory: URL
    private let processLock = NSLock()
    init(directory: URL, identity: Identity) throws {
        guard directory.isFileURL, directory.path.hasPrefix("/"), !directory.path.utf8.contains(0),
              identity.directoryInode > 0, identity.fileInode > 0,
              (0..<1_000_000_000).contains(identity.fileBirthNanoseconds) else { throw Failure.invalidDirectory }
        self.directory = directory; self.identity = identity
    }

    /// Low-level one-time file creation ONLY for a separately qualified retained
    /// bootstrap/migration transaction. O_EXCL refuses every occupied path. This
    /// supplies no empty-root proof and must never be an acquire/error fallback.
    /// The product transaction/root commit/restart join remains unimplemented.
    static func prepareNewIdentity(directory: URL) throws -> Identity {
        guard directory.isFileURL else { throw Failure.invalidDirectory }
        let parent = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard parent >= 0 else { throw Failure.invalidDirectory }
        defer { Darwin.close(parent) }
        var parentState = stat()
        guard fstat(parent, &parentState) == 0, privateDirectory(parentState) else { throw Failure.invalidDirectory }
        try validateDirectory(directory, expected: parentState)
        let descriptor = openat(parent, filename, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw Failure.unsafeFile }
        defer { Darwin.close(descriptor) }
        var file = stat()
        guard fstat(descriptor, &file) == 0, privateFile(file) else { throw Failure.unsafeFile }
        try validateDirectory(directory, expected: parentState)
        // An uncertain creation is left occupied, never removed to retry.
        let identity = Identity(directoryDevice: Int64(parentState.st_dev), directoryInode: parentState.st_ino,
                                fileDevice: Int64(file.st_dev), fileInode: file.st_ino,
                                fileBirthSeconds: Int64(file.st_birthtimespec.tv_sec), fileBirthNanoseconds: Int64(file.st_birthtimespec.tv_nsec))
        let exclusion = try Self(directory: directory, identity: identity)
        try exclusion.validateFile(parent: parent, file: file)
        return identity
    }

    /// Never hold this physical lock over a Swift await, queued-key acquisition,
    /// provider call or SDK operation. The body must be bounded local storage.
    func perform<Value>(_ operation: () throws -> Value) throws -> Value {
        guard processLock.try() else { throw Failure.busy }
        defer { processLock.unlock() }
        let parent = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard parent >= 0 else { throw Failure.invalidDirectory }
        defer { Darwin.close(parent) }
        var parentState = stat()
        guard fstat(parent, &parentState) == 0, Self.privateDirectory(parentState),
              Int64(parentState.st_dev) == identity.directoryDevice, parentState.st_ino == identity.directoryInode else { throw Failure.invalidDirectory }
        try Self.validateDirectory(directory, expected: parentState)
        let descriptor = openat(parent, Self.filename, O_RDWR | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw Failure.unsafeFile }
        defer { Darwin.close(descriptor) }
        var file = stat()
        guard fstat(descriptor, &file) == 0 else { throw Failure.unsafeFile }
        try validateFile(parent: parent, file: file)
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            if code == EWOULDBLOCK || code == EAGAIN { throw Failure.busy }
            throw Failure.system(code)
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        try validateFile(parent: parent, file: file)
        try Self.validateDirectory(directory, expected: parentState)
        let result = Result(catching: operation)
        try validateFile(parent: parent, file: file)
        try Self.validateDirectory(directory, expected: parentState)
        return try result.get()
    }
    private static func validateDirectory(_ directory: URL, expected: stat) throws {
        var current = stat()
        guard lstat(directory.path, &current) == 0, privateDirectory(current),
              current.st_dev == expected.st_dev, current.st_ino == expected.st_ino else { throw Failure.invalidDirectory }
    }
    private func validateFile(parent: Int32, file: stat) throws {
        var current = stat()
        guard Self.privateFile(file), matchesIdentity(file),
              fstatat(parent, Self.filename, &current, AT_SYMLINK_NOFOLLOW) == 0,
              Self.privateFile(current), matchesIdentity(current) else { throw Failure.unsafeFile }
    }
    private func matchesIdentity(_ value: stat) -> Bool {
        Int64(value.st_dev) == identity.fileDevice && value.st_ino == identity.fileInode
            && Int64(value.st_birthtimespec.tv_sec) == identity.fileBirthSeconds
            && Int64(value.st_birthtimespec.tv_nsec) == identity.fileBirthNanoseconds
    }
    private static func privateDirectory(_ value: stat) -> Bool {
        value.st_mode & S_IFMT == S_IFDIR && value.st_uid == geteuid() && value.st_mode & 0o077 == 0
    }
    private static func privateFile(_ value: stat) -> Bool {
        value.st_mode & S_IFMT == S_IFREG && value.st_uid == geteuid() && value.st_nlink == 1 && value.st_mode & 0o777 == 0o600
    }
}
