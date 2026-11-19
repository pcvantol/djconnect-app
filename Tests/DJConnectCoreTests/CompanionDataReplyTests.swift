import Dispatch
import Foundation
import Testing
@testable import DJConnectCore

// A MainActor caller is deliberate: the 40475 regression crashed when a WC
// operation queue invoked a callback that had inherited that actor.
@MainActor @Test func companionReplyResumesMainActorAfterBackgroundSuccess() async throws {
    let expected = Data("demo-snapshot".utf8)
    let result: Data = try await withCheckedThrowingContinuation { continuation in
        let reply = DJConnectCompanionDataReply(continuation)
        DispatchQueue.global(qos: .utility).async { reply.success(expected) }
    }
    MainActor.assertIsolated()
    #expect(result == expected)
}

private enum CompanionTestFailure: Error { case unavailable }

@MainActor @Test func companionReplyResumesMainActorAfterBackgroundFailure() async {
    do {
        let _: Data = try await withCheckedThrowingContinuation { continuation in
            let reply = DJConnectCompanionDataReply(continuation)
            DispatchQueue.global(qos: .utility).async { reply.failure(CompanionTestFailure.unavailable) }
        }
        Issue.record("A failed companion callback must throw")
    } catch {
        MainActor.assertIsolated()
        #expect(error is CompanionTestFailure)
    }
}
