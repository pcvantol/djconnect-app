import Foundation
import Testing
@testable import DJConnectCore

/// These are resource/stage MODEL controls. They cannot construct the real
/// custody, whose private source-parent factory still needs genuine HTTPS.
@Suite struct CoreHostWakeProxyCustodyTests {
    private func prefix(_ book: inout CoreHostWakeProxyStageBook, until operation: CoreHostWakeProxyRequest.Operation) throws {
        if operation == .prepare { return }
        try book.accept(book.begin(.prepare), state: "prepared")
        if operation == .nativeChallenge { return }
        try book.accept(book.begin(.nativeChallenge), state: "pending")
        if operation == .nativeComplete { return }
        try book.accept(book.begin(.nativeComplete), state: "native_verified")
    }
    @Test func acknowledgedPendingAdvancesOnlyItsRetainedJobAndNeverAliasesRegistration() throws {
        var book = CoreHostWakeProxyStageBook()
        try prefix(&book, until: .nativeComplete)
        try book.accept(book.begin(.nativeComplete), state: "pending")
        #expect(book.phase == .verifying)
        #expect(throws: (any Error).self) { _ = try book.begin(.register) }
        try book.accept(book.begin(.nativeStatus), state: "native_verified")
        #expect(book.phase == .verifying) // Read alone is not continuation permission.
        book.resolveKnownPending(.status, state: "registered")
        #expect(book.phase == .verifying)
        book.resolveKnownPending(.nativeStatus, state: "native_verified") // MODEL only; actual owner must check its private parent.
        #expect(book.phase == .nativeVerified)
        try book.accept(book.begin(.register), state: "pending")
        #expect(book.phase == .registerPending)
        try book.accept(book.begin(.status), state: "registered")
        #expect(book.phase == .registerPending)
        book.resolveKnownPending(.status, state: "registered")
        #expect(book.phase == .registered)
        #expect(throws: (any Error).self) { _ = try book.begin(.register) }
    }
    @Test(arguments: [CoreHostWakeProxyRequest.Operation.prepare, .nativeChallenge, .nativeComplete, .register])
    func lostMutationCannotBeReplayedOrRestoredByHistory(_ operation: CoreHostWakeProxyRequest.Operation) throws {
        var book = CoreHostWakeProxyStageBook(); try prefix(&book, until: operation)
        let original = try book.begin(operation)
        #expect(throws: (any Error).self) { _ = try book.begin(operation) }
        book.fail(original)
        #expect(book.phase == .uncertain)
        try book.accept(book.begin(.nativeStatus), state: "native_verified")
        book.resolveKnownPending(.nativeStatus, state: "native_verified")
        try book.accept(book.begin(.status), state: "registered")
        book.resolveKnownPending(.status, state: "registered")
        #expect(book.phase == .uncertain)
        for mutation in [CoreHostWakeProxyRequest.Operation.prepare, .nativeChallenge, .nativeComplete, .register] {
            #expect(throws: (any Error).self) { _ = try book.begin(mutation) }
        }
        #expect(throws: (any Error).self) { try book.accept(original, state: "prepared") }
    }
    @Test func retirementFencesLateMutationButPreservesNegativeBookkeeping() throws {
        var book = CoreHostWakeProxyStageBook()
        let pending = try book.begin(.prepare); book.retire()
        #expect(throws: (any Error).self) { try book.accept(pending, state: "prepared") }
        let status = try book.begin(.status); book.retire()
        try book.accept(status, state: "registered")
        book.resolveKnownPending(.status, state: "registered")
        #expect(book.phase == .withdrawn)
        let lateRead = try book.begin(.status); book.withdraw()
        let withdrawal = try book.begin(.withdraw)
        #expect(throws: (any Error).self) { try book.accept(lateRead, state: "registered") }
        try book.accept(withdrawal, state: "pending")
        #expect(book.phase == .withdrawn)
        try book.accept(book.begin(.status), state: "unknown")
        #expect(book.phase == .withdrawn)
    }
    @Test func coldOrIdleStatusDoesNotCreatePreparedOrVerifiedState() throws {
        var book = CoreHostWakeProxyStageBook()
        try book.accept(book.begin(.nativeStatus), state: "native_verified")
        book.resolveKnownPending(.nativeStatus, state: "native_verified")
        try book.accept(book.begin(.status), state: "registered")
        book.resolveKnownPending(.status, state: "registered")
        #expect(book.phase == .idle)
        #expect(throws: (any Error).self) { _ = try book.begin(.register) }
        // Pure idle DATA bookkeeping still cannot create a source-parent port.
    }
    @Test func parentCancellationStopsPositiveWorkAndAllowsOnlyNegativeCleanup() throws {
        let control = CoreHostWakeProxyCancellation(), positive = UUID(), negative = UUID()
        let recorder = CancellationRecorder()
        try control.install(positive, positive: true, cancel: { recorder.record("positive") })
        #expect(control.isCurrent(positive))
        control.cancelPositive()
        #expect(!control.isCurrent(positive) && control.positivesClosed && recorder.values == ["positive"])
        #expect(throws: (any Error).self) { try control.install(UUID(), positive: true, cancel: {}) }
        try control.install(negative, positive: false, cancel: { recorder.record("negative") })
        control.cancelPositive()
        #expect(control.isCurrent(negative) && recorder.values == ["positive"])
        control.finish(positive) // An old completion cannot remove new negative work.
        #expect(control.isCurrent(negative))
        control.cancelAll()
        #expect(!control.isCurrent(negative) && recorder.values == ["positive", "negative"])
        #expect(throws: (any Error).self) { try control.install(UUID(), positive: false, cancel: {}) }
    }
    @Test func explicitWithdrawalCancelsReadWithoutCreatingNewPositiveAuthority() throws {
        let control = CoreHostWakeProxyCancellation(), first = UUID(), withdrawal = UUID(), recorder = CancellationRecorder()
        try control.install(first, positive: false, cancel: { recorder.record("read") })
        control.cancelPositive(); control.cancelCurrent()
        try control.install(withdrawal, positive: false, cancel: { recorder.record("withdraw") })
        control.finish(first)
        #expect(!control.isCurrent(first) && control.isCurrent(withdrawal) && control.positivesClosed)
        #expect(recorder.values == ["read"])
        control.finish(withdrawal)
        #expect(!control.isCurrent(withdrawal))
    }
    @Test @MainActor func nativeIntentBoundsAreDataChecksNotEnrollmentOrEnvironmentProof() throws {
        func intent(tokenCount: Int = 32, key: String = Data(repeating: 0xfb, count: 32).base64EncodedString(), platform: String = "ipados", environment: String = "sandbox") -> CoreHostWakeProxyCustody.NativeIntentData {
            .init(token: Data(repeating: 0, count: tokenCount), hostBundleID: "example.fixture.host", installationID: "fixture-installation",
                platform: platform, environment: environment, nativeKeyID: key)
        }
        #expect(try intent().tokenSnapshot().count == 32)
        #expect(try intent(tokenCount: 2048).tokenSnapshot().count == 2048)
        for invalid in [intent(tokenCount: 15), intent(tokenCount: 2049), intent(key: ""), intent(key: String(repeating: "A", count: 4096)),
                        intent(key: Data(repeating: 0, count: 31).base64EncodedString()), intent(platform: "macos"), intent(environment: "development")] {
            #expect(throws: (any Error).self) { _ = try invalid.tokenSnapshot() }
        }
        // Even synthetically well-shaped DATA never constructs a source parent,
        // an actual proxy custody, a key, a signed environment or SDK permission.
    }
    @Test(arguments: ["cancel", "entry-failure"]) @MainActor
    func cancellationBeforeAsyncEntryFinalizesClaimAndOriginalToken(_ failure: String) async throws {
        let model = SubmissionModel(), request = try model.request()
        let pending = Task { @MainActor in
            let ticket = try model.book.begin(.prepare)
            let claim = CoreHostWakeProxySubmission(request: request, ticket: ticket, positive: true, prepared: nil, tokenOwner: ticket.id)
            try model.cancel.reserve(ticket.id, positive: true)
            model.token.retain(Data(repeating: 7, count: 32), owner: ticket.id)
            defer { claim.finish(book: &model.book, token: &model.token, cancellation: model.cancel) }
            #expect(model.book.phase == .preparing && model.cancel.isCurrent(ticket.id) && model.token.value != nil)
            if failure == "cancel" { withUnsafeCurrentTask { $0?.cancel() } }
            do { try await model.asyncEntry(fail: failure == "entry-failure"); return false }
            catch is CancellationError { return failure == "cancel" }
            catch SubmissionModel.Failure.rejected { return failure == "entry-failure" }
        }
        #expect(try await pending.value)
        #expect(!model.entered && model.book.phase == .uncertain && model.token.value == nil && model.token.owner == nil)
        #expect(throws: (any Error).self) { _ = try model.book.begin(.prepare) }
        // Actual shared finalizer/model only, not a genuine-parent runtime repro.
    }
    @Test @MainActor func oldSubmissionCannotClearLaterWorkOrDifferentlyOwnedToken() throws {
        let model = SubmissionModel(), request = try model.request()
        let first = try model.book.begin(.prepare)
        let old = CoreHostWakeProxySubmission(request: request, ticket: first, positive: true, prepared: nil, tokenOwner: first.id)
        try model.cancel.reserve(first.id, positive: true)
        model.token.retain(Data(repeating: 1, count: 32), owner: first.id)
        model.book.withdraw(); model.cancel.cancelCurrent()
        let newer = try model.book.begin(.status)
        try model.cancel.reserve(newer.id, positive: false)
        model.token.retain(Data(repeating: 2, count: 32), owner: newer.id) // Resource ownership counterexample, no parent/key factory.
        old.finish(book: &model.book, token: &model.token, cancellation: model.cancel)
        #expect(model.book.isCurrent(newer) && model.cancel.isCurrent(newer.id))
        #expect(model.token.owner == newer.id && model.token.value == Data(repeating: 2, count: 32))
    }
    @Test @MainActor func successfulSubmissionFinalizerRetainsOriginalTokenForSameJob() throws {
        let model = SubmissionModel(), request = try model.request(), ticket = try model.book.begin(.prepare)
        let claim = CoreHostWakeProxySubmission(request: request, ticket: ticket, positive: true, prepared: nil, tokenOwner: ticket.id)
        try model.cancel.reserve(ticket.id, positive: true)
        model.token.retain(Data(repeating: 3, count: 32), owner: ticket.id)
        try model.book.accept(ticket, state: "prepared"); claim.completed = true
        claim.finish(book: &model.book, token: &model.token, cancellation: model.cancel)
        #expect(model.book.phase == .prepared && model.token.owner == ticket.id && !model.cancel.isCurrent(ticket.id))
    }
    @Test func reservedWorkRetiredBeforeWorkerAttachmentCancelsLateWorker() throws {
        let signal = CoreHostWakeProxyCancellation(), id = UUID(), recorder = CancellationRecorder()
        try signal.reserve(id, positive: true)
        signal.cancelPositive()
        #expect(throws: (any Error).self) { try signal.attach(id, cancel: { recorder.record("late-worker") }) }
        #expect(!signal.isCurrent(id) && recorder.values == ["late-worker"])
    }
}
@MainActor private final class SubmissionModel {
    enum Failure: Error { case rejected }
    var book = CoreHostWakeProxyStageBook()
    var token = CoreHostWakeProxyTokenSlot()
    let cancel = CoreHostWakeProxyCancellation()
    var entered = false
    func asyncEntry(fail: Bool) async throws {
        try Task.checkCancellation()
        if fail { throw Failure.rejected }
        entered = true
    }
    func request() throws -> CoreHostWakeProxyRequest {
        // Request DATA only: deliberately no genuine source parent or SDK proof.
        try .init(operation: .prepare, originalBody: DirectRichWireJSON.object([
            "contract_version": .integer(1), "device_id": .string("djconnect-ios-ABCDEF123456"), "client_type": .string("ios"),
            "session_id": .string("model-session"), "surface": .string("widget"),
            "purpose_id": .string("11111111-1111-4111-8111-111111111111"), "operation_id": .string("22222222-2222-4222-8222-222222222222"),
            "target": .object(["host_bundle_id": .string("example.fixture.host"), "installation_id": .string("model-install")]),
            "platform": .string("ios"), "apns_environment": .string("sandbox"),
            "native_key_id_b64": .string(Data(repeating: 0, count: 32).base64EncodedString()), "native_token_sha256": .string(String(repeating: "0", count: 64))
        ]).canonicalData())
    }
}
private final class CancellationRecorder: @unchecked Sendable {
    private let lock = NSLock(); private var data: [String] = []
    var values: [String] { lock.withLock { data } }
    func record(_ value: String) { lock.withLock { data.append(value) } }
}
