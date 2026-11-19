import Testing
@testable import DJConnectCore

/// One runtime per test case, including parameterized cases. Child tasks inherit
/// the same pools; parallel tests cannot exhaust one another's process fixture.
private actor ClientFixtureParallelism {
    static let shared = ClientFixtureParallelism(limit: 8)
    static let appKitFocus = ClientFixtureParallelism(limit: 1)
    private let limit: Int
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    init(limit: Int) { self.limit = limit }
    private func acquire() async {
        if active < limit { active += 1; return }
        await withCheckedContinuation { waiting.append($0) }
    }
    private func release() {
        if waiting.isEmpty { active -= 1 } else { waiting.removeFirst().resume() }
    }
    func run(_ operation: @Sendable () async throws -> Void) async throws {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        try await operation()
    }
}
struct IsolatedClientResources: TestTrait, TestScoping {
    var appKitFocus = false
    func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        // A parameterized function also has an outer scope. Taking a permit
        // there would retain it while its cases wait for the same pool.
        testCase == nil ? nil : self
    }
    func provideScope(for test: Test, testCase: Test.Case?,
                      performing function: @Sendable () async throws -> Void) async throws {
        // Bound independent fixture load, not the concurrent operations under
        // test. The app's original deadlines and all assertions remain intact.
        try await ClientFixtureParallelism.shared.run {
            try await DJConnectTransportResources.$current.withValue(DJConnectTransportResources()) {
                if appKitFocus {
                    try await ClientFixtureParallelism.appKitFocus.run(function)
                } else { try await function() }
            }
        }
    }
}
extension Trait where Self == IsolatedClientResources {
    static var isolatedClientResources: Self { Self() }
    static var isolatedAppKitResources: Self { Self(appKitFocus: true) }
}
