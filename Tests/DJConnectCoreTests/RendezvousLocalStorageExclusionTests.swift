import Foundation
import Darwin
import Testing
@testable import DJConnectCore

private func exclusionDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("rendezvous-exclusion-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    return url
}

@Test func rendezvousPhysicalExclusionRejectsAnotherInstanceAndNestedEntryWithoutWaiting() throws {
    let directory = try exclusionDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory)
    let first = try RendezvousLocalStorageExclusion(directory: directory, identity: identity), other = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    var entered = 0
    try first.perform {
        entered += 1
        #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try other.perform { entered += 100 } }
        #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try first.perform { entered += 100 } }
    }
    try other.perform { entered += 1 }
    #expect(entered == 2)
}

@Test func rendezvousPhysicalExclusionReleasesAfterUncertainBodyFailureAndKeepsLockFile() throws {
    enum Expected: Error { case uncertain }
    let directory = try exclusionDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory)
    let exclusion = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    #expect(throws: Expected.self) { try exclusion.perform { throw Expected.uncertain } }
    let path = directory.appendingPathComponent(RendezvousLocalStorageExclusion.filename)
    #expect(FileManager.default.fileExists(atPath: path.path))
    let value = try exclusion.perform { 42 }; #expect(value == 42)
    #expect(try Data(contentsOf: path).isEmpty) // no root, proof or nonce is stored in the lock
}

@Test func rendezvousPhysicalExclusionRejectsUnsafeDirectoryFileAndHardlinkWithoutRepair() throws {
    let root = try exclusionDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let rootIdentity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: root)
    let unsafe = root.appendingPathComponent("unsafe")
    try FileManager.default.createDirectory(at: unsafe, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])
    let unsafeExclusion = try RendezvousLocalStorageExclusion(directory: unsafe, identity: rootIdentity)
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try unsafeExclusion.perform { Issue.record("Unsafe directory entered") } }
    let symlink = root.appendingPathComponent("linked")
    try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: unsafe)
    let linkedExclusion = try RendezvousLocalStorageExclusion(directory: symlink, identity: rootIdentity)
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try linkedExclusion.perform { Issue.record("Symlink directory entered") } }
    let privateDirectory = root.appendingPathComponent("private")
    try FileManager.default.createDirectory(at: privateDirectory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    let privateIdentity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: privateDirectory)
    let file = privateDirectory.appendingPathComponent(RendezvousLocalStorageExclusion.filename)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
    let privateExclusion = try RendezvousLocalStorageExclusion(directory: privateDirectory, identity: privateIdentity)
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try privateExclusion.perform { Issue.record("Public lock file entered") } }
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    let alias = root.appendingPathComponent("hardlink")
    try FileManager.default.linkItem(at: file, to: alias)
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try privateExclusion.perform { Issue.record("Hardlink lock file entered") } }
}

@Test func rendezvousPhysicalExclusionDetectsReplacedLockBeforeSuccessfulReturn() throws {
    let directory = try exclusionDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory)
    let exclusion = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    let file = directory.appendingPathComponent(RendezvousLocalStorageExclusion.filename)
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) {
        try exclusion.perform {
            try FileManager.default.removeItem(at: file)
            #expect(FileManager.default.createFile(atPath: file.path, contents: Data(), attributes: [.posixPermissions: 0o600]))
        }
    }
}

#if os(macOS)
@Test func rendezvousPhysicalExclusionActuallyExcludesAnotherProcess() throws {
    let directory = try exclusionDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory)
    let process = Process(), output = Pipe(), input = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-c", "import os,sys,fcntl\nf=os.open(sys.argv[1],os.O_RDWR)\nfcntl.flock(f,fcntl.LOCK_EX)\nprint('READY',flush=True)\nsys.stdin.readline()\nos.close(f)", directory.appendingPathComponent(RendezvousLocalStorageExclusion.filename).path]
    process.standardOutput = output; process.standardInput = input
    try process.run()
    defer { try? input.fileHandleForWriting.close(); if process.isRunning { process.terminate() }; process.waitUntilExit() }
    let ready = try #require(try output.fileHandleForReading.read(upToCount: 6))
    #expect(String(data: ready, encoding: .utf8) == "READY\n")
    let exclusion = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    var entered = false
    let start = ContinuousClock.now
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try exclusion.perform { entered = true } }
    #expect(!entered && start.duration(to: .now) < .seconds(2))
    try input.fileHandleForWriting.write(contentsOf: Data("release\n".utf8)); try input.fileHandleForWriting.close()
    process.waitUntilExit(); #expect(process.terminationStatus == 0)
    let value = try exclusion.perform { 7 }; #expect(value == 7)
}
#endif

@Test func rendezvousPhysicalExclusionRefusesReplacementBeforeSecondBodyWhileOldFDLives() throws {
    let directory = try exclusionDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory)
    let first = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    let second = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    let file = directory.appendingPathComponent(RendezvousLocalStorageExclusion.filename)
    var secondEntered = false
    var firstRejected = false
    do {
        try first.perform {
            try FileManager.default.removeItem(at: file)
            #expect(FileManager.default.createFile(atPath: file.path, contents: Data(), attributes: [.posixPermissions: 0o600]))
            #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try second.perform { secondEntered = true } }
            #expect(!secondEntered)
        }
    } catch is RendezvousLocalStorageExclusion.Failure { firstRejected = true }
    #expect(firstRejected && !secondEntered)
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try second.perform { secondEntered = true } }
    // Neither a scan nor an ordinary acquire can bootstrap/adopt the replacement.
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory) }
}

@Test func rendezvousPhysicalExclusionDoesNotRecreateMissingRetainedLock() throws {
    let directory = try exclusionDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    let identity = try RendezvousLocalStorageExclusion.prepareNewIdentity(directory: directory)
    let exclusion = try RendezvousLocalStorageExclusion(directory: directory, identity: identity)
    let file = directory.appendingPathComponent(RendezvousLocalStorageExclusion.filename)
    try FileManager.default.removeItem(at: file)
    #expect(throws: RendezvousLocalStorageExclusion.Failure.self) { try exclusion.perform { Issue.record("Missing lock granted body") } }
    #expect(!FileManager.default.fileExists(atPath: file.path))
}
