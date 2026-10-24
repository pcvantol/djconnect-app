import Foundation
import Testing
@testable import DJConnectCore

private let watchPairIntentA = "11111111-1111-4111-8111-111111111111"
private let watchPairIntentB = "22222222-2222-4222-8222-222222222222"

@Test @MainActor func watchPairingReadbackRejectsLateSuccessBeforeAnyMutationOrTokenMessage() async throws {
    for change in ["clear", "device", "intent", "code", "token", "origin", "aba", "cancel", "background"] {
        let originalGeneration = UUID()
        var generation = originalGeneration
        let original = ["watch-a", watchPairIntentA, "123456", "synthetic-token-a", "https://ha-a.invalid"]
        var current: [String]? = original
        var foreground = true
        var continuation: CheckedContinuation<Void, Never>?
        var mutations = 0, messages = 0
        let task = Task { try await DJConnectWatchPairingReadback.perform(
            isCurrent: { foreground && generation == originalGeneration && current == original },
            read: { await withCheckedContinuation { continuation = $0 } },
            commit: { mutations += 1; messages += 1 }) }
        while continuation == nil { await Task.yield() }
        switch change {
        case "clear": current = nil; generation = UUID()
        case "device": current?[0] = "watch-b"
        case "intent": current?[1] = watchPairIntentB
        case "code": current?[2] = "654321"
        case "token": current?[3] = "synthetic-token-b"
        case "origin": current?[4] = "https://ha-b.invalid"
        case "aba": current = nil; generation = UUID(); current = original
        case "cancel": task.cancel()
        default: foreground = false
        }
        // Deliberately return success despite cancellation/context loss.
        continuation?.resume()
        #expect(try await task.value == false)
        #expect(mutations == 0 && messages == 0)
    }
}

@Test @MainActor func watchPairingReadbackSuppressesLateErrorAndCommitsCurrentSuccessOnce() async throws {
    var current = true
    var continuation: CheckedContinuation<Void, any Error>?
    var commits = 0
    let task = Task { try await DJConnectWatchPairingReadback.perform(isCurrent: { current },
        read: { try await withCheckedThrowingContinuation { continuation = $0 } },
        commit: { commits += 1 }) }
    while continuation == nil { await Task.yield() }
    current = false
    continuation?.resume(throwing: DJConnectError.missingToken)
    #expect(try await task.value == false && commits == 0)
    current = true
    #expect(try await DJConnectWatchPairingReadback.perform(isCurrent: { current }, read: {}, commit: { commits += 1 }))
    #expect(commits == 1)
}

@Test func watchPairingReceiverRejectsWrongResetMissingAndLegacyTargetsBeforeTokenStorage() throws {
    let device = "djconnect-watchos-synthetic-a"
    let original = try #require(DJConnectWatchPairingIntent(deviceID: device, identifier: watchPairIntentA, pairCode: "123456"))
    var writes = 0
    for fields: [String?] in [
        [nil, nil, nil], ["djconnect-watchos-synthetic-b", watchPairIntentA, "123456"],
        [device, watchPairIntentB, "123456"], [device, watchPairIntentA, "654321"]
    ] {
        #expect(try !original.receive(deviceID: fields[0], identifier: fields[1], pairCode: fields[2],
            token: "synthetic-token", save: { _ in writes += 1 }))
    }
    let reset = try #require(DJConnectWatchPairingIntent(deviceID: device, identifier: watchPairIntentB, pairCode: "123456"))
    #expect(try !reset.receive(deviceID: device, identifier: watchPairIntentA, pairCode: "123456", token: "synthetic-token", save: { _ in writes += 1 }))
    #expect(writes == 0)
    #expect(try original.receive(deviceID: device, identifier: watchPairIntentA, pairCode: "123456", token: "synthetic-token", save: { _ in writes += 1 }))
    #expect(writes == 1)
    #expect(try !original.receive(deviceID: device, identifier: watchPairIntentA, pairCode: "123456",
        token: "synthetic-old-token", existingToken: "synthetic-current-token", save: { _ in writes += 1 }))
    #expect(writes == 1)
    #expect(!String(describing: original).contains(device) && !String(reflecting: original).contains("123456"))
}

@Test func watchPairingIntentPersistsAcrossModelsAndRotatesBeforeResetRegistration() throws {
    let suite = "watch-pair-intent-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let device = "djconnect-watchos-synthetic"
    let a = try #require(DJConnectWatchPairingIntent.load(defaults: defaults, deviceID: device, pairCode: "123456"))
    #expect(DJConnectWatchPairingIntent.load(defaults: defaults, deviceID: device, pairCode: "123456") == a)
    let b = try #require(DJConnectWatchPairingIntent.load(defaults: defaults, deviceID: device, pairCode: "654321", reset: true))
    #expect(b.identifier != a.identifier)
    #expect(DJConnectWatchPairingIntent.load(defaults: defaults, deviceID: device, pairCode: "654321") == b)
    defaults.set("malformed", forKey: "DJConnectWatchCompanionPairingIntent")
    #expect(DJConnectWatchPairingIntent.load(defaults: defaults, deviceID: device, pairCode: "654321") == nil)
    #expect(defaults.string(forKey: "DJConnectWatchCompanionPairingIntent") == "malformed")
}
