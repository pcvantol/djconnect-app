import Foundation
import Darwin

/// Installation continuity and once accounting only. No enrollment/SDK grant.
/// A cold reader never acquires the original process reservation. There is no
/// repair, delete, reset, migration or adoption of Rendezvous/HA identifiers.
final class HostWakeFirstKeyJournal: @unchecked Sendable {
    private static let directoryName = "DJConnectHostWakeFirstKey-v1"
    enum Failure: Error { case closed, occupied, invalid, io }
    struct Identity: Codable, Equatable, Sendable {
        let installation: UUID
        let generation: UUID
        let operation: UUID
        let artifact: String
    }
    private let parent: Int32
    private let directory: Int32
    private let name: String
    private let support: URL
    private let identityBytes: Data
    let installationIdentifier: String
    private var identityFile: OwnedFile?
    private var claimFile: OwnedFile?
    private var referenceFile: OwnedFile?
    private var referenceBytes: Data?
    private var proofRecords: [String: (OwnedFile, Data)] = [:]
    private var proofAttempts: Set<String> = []
    private var attestationClaimed = false
    private let lock = NSLock()
    private var claimAttempted = false
    private var claimed = false
    private var resultAttempted = false
    private var closed = false

    /// Negative metadata check only. Absence does NOT authorize initialization,
    /// establish a fresh physical installation, or supply an operator grant.
    static func namespaceIsAbsent(inExistingSupport support: URL) -> Bool {
        guard support.isFileURL else { return false }
        let parent = open(support.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard parent >= 0 else { return false }; defer { Darwin.close(parent) }
        var info = stat()
        guard fstatat(parent, directoryName, &info, AT_SYMLINK_NOFOLLOW) != 0 else { return false }
        return errno == ENOENT
    }

    /// Called only inside the actual operator's separately reviewed fresh-install
    /// effect. An absent directory at app start is CLOSED, never automatic genesis.
    /// The exclusively created directory is itself a permanent occupied marker:
    /// partial initialization cannot be mistaken for an unused installation.
    init(freshInExistingSupport support: URL, artifact: String) throws {
        guard support.isFileURL, artifact.utf8.count == 64,
              artifact.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw Failure.invalid }
        name = Self.directoryName
        self.support = support
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let installation = UUID()
        installationIdentifier = installation.uuidString.lowercased()
        identityBytes = try encoder.encode(Identity(installation: installation, generation: UUID(), operation: UUID(), artifact: artifact))
        let parent = open(support.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard parent >= 0 else { throw Failure.io }
        self.parent = parent
        guard mkdirat(parent, name, 0o700) == 0 else {
            Darwin.close(parent); throw errno == EEXIST ? Failure.occupied : Failure.io
        }
        let directory = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard directory >= 0 else { Darwin.close(parent); throw Failure.io }
        self.directory = directory
        // All stored properties are initialized: a thrown error now runs deinit.
        // Persist directory creation in its parent before any SDK claim.
        guard fsync(parent) == 0 else { throw Failure.io }
        identityFile = try Self.create("identity.json", data: identityBytes, in: directory)
        try validateIdentity()
    }
    deinit { Darwin.close(directory); Darwin.close(parent) }
    func close() { lock.withLock { closed = true } }
    func validateOriginal() throws {
        try lock.withLock { guard !closed else { throw Failure.closed }; try validateIdentity() }
    }
    func claimBeforeSDK() throws {
        try lock.withLock {
            guard !closed, !claimAttempted else { throw Failure.closed }
            claimAttempted = true // Never refunded, including commit-then-error.
            try validateIdentity()
            claimFile = try Self.create("sdk-start.json", data: identityBytes, in: directory)
            claimed = true
        }
    }
    func recordOriginalCallback(_ key: String) throws {
        try lock.withLock {
            guard !closed, claimed, !resultAttempted else { throw Failure.closed }
            resultAttempted = true
            try validateIdentity()
            guard let bytes = Data(base64Encoded: key), bytes.count == 32,
                  bytes.base64EncodedString() == key else { throw Failure.invalid }
            // This is only the OS SDK key reference, never a private key or proof.
            let encodedReference = Data(key.utf8)
            referenceFile = try Self.create("key-reference", data: encodedReference, in: directory)
            referenceBytes = encodedReference
        }
    }
    /// One native proof per exact original child (at most the two surfaces),
    /// with one attestation for the first key and server-selected assertions.
    /// This is once accounting, never server enrollment/kind authority. Persist
    /// before entering the SDK; failure/unknown never refunds the reservation.
    /// The record contains binding DATA only, never opaque proof/private bytes.
    func claimNativeProofBeforeSDK(_ input: HostWakeNativeProofInputData) throws {
        try lock.withLock {
            guard !closed, proofAttempts.count < 2, !proofAttempts.contains(input.operationID),
                  input.kind != .attestation || !attestationClaimed else { throw Failure.closed }
            proofAttempts.insert(input.operationID)
            if input.kind == .attestation { attestationClaimed = true }
            try validateIdentity()
            guard referenceBytes == Data(input.keyIdentifier.utf8) else { throw Failure.closed }
            let record = NativeProofClaim(kind: input.kind.rawValue,
                clientDataSHA256: input.clientDataHash.map { String(format: "%02x", $0) }.joined(),
                keyIdentifier: input.keyIdentifier)
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            let bytes = try encoder.encode(record)
            let file = try Self.create("native-proof-" + input.operationID + ".json", data: bytes, in: directory)
            proofRecords[input.operationID] = (file, bytes)
        }
    }
    private struct NativeProofClaim: Codable {
        let kind: String
        let clientDataSHA256: String
        let keyIdentifier: String
    }
    private func validateIdentity() throws {
        var held = stat(), named = stat(), heldParent = stat(), namedParent = stat()
        guard fstat(parent, &heldParent) == 0, lstat(support.path, &namedParent) == 0,
              heldParent.st_dev == namedParent.st_dev, heldParent.st_ino == namedParent.st_ino,
              (namedParent.st_mode & S_IFMT) == S_IFDIR else { throw Failure.closed }
        guard fstat(directory, &held) == 0,
              fstatat(parent, name, &named, AT_SYMLINK_NOFOLLOW) == 0,
              held.st_dev == named.st_dev, held.st_ino == named.st_ino,
              (named.st_mode & S_IFMT) == S_IFDIR else { throw Failure.closed }
        guard let identityFile else { throw Failure.closed }
        let bytes = try Self.read("identity.json", original: identityFile, in: directory)
        guard bytes == identityBytes else { throw Failure.closed }
        if claimed {
            guard let claimFile,
                  try Self.read("sdk-start.json", original: claimFile, in: directory) == identityBytes else { throw Failure.closed }
        }
        if let referenceBytes {
            guard let referenceFile,
                  try Self.read("key-reference", original: referenceFile, in: directory) == referenceBytes else { throw Failure.closed }
        }
        for (operation, (file, bytes)) in proofRecords {
            guard try Self.read("native-proof-" + operation + ".json", original: file, in: directory) == bytes else { throw Failure.closed }
        }
    }
    private static func read(_ name: String, original: OwnedFile, in directory: Int32) throws -> Data {
        // Type validation follows open: NONBLOCK is required so replacing a
        // record with a FIFO cannot block this actor before fstat rejects it.
        let fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.io }; defer { Darwin.close(fd) }
        var info = stat(), held = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              fstat(original.fd, &held) == 0, held.st_dev == info.st_dev, held.st_ino == info.st_ino,
              held.st_nlink == 1,
              info.st_nlink == 1, info.st_size > 0, info.st_size <= 4096 else { throw Failure.invalid }
        var bytes = [UInt8](repeating: 0, count: Int(info.st_size))
        let count = bytes.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
        guard count == bytes.count else { throw Failure.io }
        return Data(bytes)
    }
    private static func create(_ name: String, data: Data, in directory: Int32) throws -> OwnedFile {
        guard !data.isEmpty, data.count <= 4096 else { throw Failure.invalid }
        let fd = openat(directory, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw Failure.io }
        let file = OwnedFile(fd)
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw Failure.io }; offset += count
            }
        }
        guard fsync(fd) == 0, fsync(directory) == 0 else { throw Failure.io }
        return file
    }
    private final class OwnedFile {
        let fd: Int32
        init(_ fd: Int32) { self.fd = fd }
        deinit { Darwin.close(fd) }
    }
}
