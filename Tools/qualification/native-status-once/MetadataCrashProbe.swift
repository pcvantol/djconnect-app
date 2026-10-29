import Foundation
import Darwin

// Compiled alongside the exact internal journal source by the opt-in runner.
// These decoded values are synthetic SQL metadata, never native capabilities.
private struct ProbeInput: Decodable {
    let database: String
    let store: UUID
    let capacity: Int
    let operation: UUID
    let decision: UUID
    let presentation: UUID
    let generation: UUID
    let terminal: UUID
    let binding: Data
}
private enum ProbeFailure: Error { case arguments, reserve, consume, mode }

@main struct MetadataCrashProbe {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { throw ProbeFailure.arguments }
        let input = try JSONDecoder().decode(ProbeInput.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        let journal = try NativeStatusOnceDataJournal(existingDatabase: URL(fileURLWithPath: input.database), storeID: input.store, capacity: input.capacity)
        let request = NativeStatusOnceDataJournal.Request(operation: input.operation, decision: input.decision,
            presentation: input.presentation, presentationGeneration: input.generation, binding: input.binding, terminalOperation: input.terminal)
        let mode = CommandLine.arguments[1]
        if mode == "before-reserve" { _exit(71) }
        if mode == "reopen" {
            let status = try await journal.status(input.operation)
            func outcome(_ value: NativeStatusOnceDataJournal.Result) -> String {
                switch value {
                case .committed: "metadata-committed"
                case .alreadyRecorded: "already-recorded"
                case .denied(.originalProcessReservationMissing): "original-process-reservation-missing"
                case .denied(.invalid): "missing-record"
                case .denied: "other-denied"
                case .unknown: "unknown"
                }
            }
            let dispatch = await journal.consumeDispatch(input.operation)
            let terminal = await journal.consumeTerminal(input.operation)
            let report: [String: Any] = ["record_present": status != nil, "dispatch_consumed": status?.dispatchConsumed ?? false,
                "terminal_consumed": status?.terminalConsumed ?? false, "dispatch_result": outcome(dispatch),
                "terminal_result": outcome(terminal), "native_effects": false]
            print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
            return
        }
        guard case .committed = await journal.reserve(request) else { throw ProbeFailure.reserve }
        if mode == "after-reserve" { _exit(72) }
        if mode == "after-consume" {
            guard case .committed = await journal.consumeDispatch(input.operation) else { throw ProbeFailure.consume }
            _exit(73)
        }
        if mode == "after-terminal" {
            guard case .committed = await journal.consumeTerminal(input.operation) else { throw ProbeFailure.consume }
            _exit(74)
        }
        throw ProbeFailure.mode
    }
}
