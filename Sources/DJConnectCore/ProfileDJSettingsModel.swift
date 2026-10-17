import Combine
import Foundation

/// A RAM-only projection of one paired owner's settings. No UserDefaults truth.
@MainActor
public final class ProfileDJSettingsModel: ObservableObject {
    public enum Phase: String, Sendable { case idle, loading, ready, saving, saved, conflict, unavailable, uncertain }
    public struct Services {
        var read: () async throws -> DJConnectProfileDJSettingsResponse
        var update: (DJConnectProfileDJSettingsResponse, DJConnectProfileDJSettings.Patch, String) async throws -> DJConnectProfileDJSettingsResponse
        var receipt: (String, String) async throws -> DJConnectProfileDJSettingsOperation
        public init(read: @escaping () async throws -> DJConnectProfileDJSettingsResponse,
                    update: @escaping (DJConnectProfileDJSettingsResponse, DJConnectProfileDJSettings.Patch, String) async throws -> DJConnectProfileDJSettingsResponse,
                    receipt: @escaping (String, String) async throws -> DJConnectProfileDJSettingsOperation) {
            self.read = read; self.update = update; self.receipt = receipt
        }
    }
    private struct Pending { let id: String; let binding: String }
    @Published public private(set) var response: DJConnectProfileDJSettingsResponse?
    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var active = false
    @Published public private(set) var errorCode: String?
    private var owner: String?
    private var generation = UUID()
    private var pending: Pending?
    private var readID: UUID?
    private var needsMutationReadback = false
    private var reconciling = false
    public init() {}
    public var negotiated: Bool { response?.isValid == true }
    // An ordinary freshness read must not disable an open native menu. A write
    // still requires its own current readback before another edit is admitted.
    public var canEdit: Bool { active && negotiated && !needsMutationReadback && pending == nil && ![.loading, .saving, .unavailable].contains(phase) }
    public var effective: DJConnectProfileDJSettings? { response?.snapshot.effective }
    public var hasUncertainOperation: Bool { pending != nil && phase == .uncertain }

    public func bind(owner value: String?, active enabled: Bool) {
        guard owner != value || active != enabled else { return }
        generation = UUID(); readID = nil; reconciling = false
        if owner != value {
            response = nil; pending = nil; needsMutationReadback = false; errorCode = nil; phase = .idle
        } else if pending != nil {
            // Suspension invalidates this task's completion, not the server write.
            // Resume through the original receipt; never leave an orphaned saving state.
            phase = .uncertain; errorCode = "settings_outcome_unknown"
        } else if phase == .loading {
            phase = response == nil ? .idle : .ready
        }
        owner = value; active = enabled && value != nil
    }

    private func withdrawIfNeeded(_ error: Error) -> Bool {
        guard (error as? DJConnectError)?.invalidatesSessionAuthority == true else { return false }
        withdrawAuthority()
        return true
    }

    public func withdrawAuthority() {
        generation = UUID(); readID = nil; reconciling = false; needsMutationReadback = false
        response = nil; active = false; phase = .unavailable
        errorCode = "settings_authority_unavailable"
        // Preserve an uncertain operation until the same binding is revalidated.
    }

    public func refresh(_ services: Services) async {
        guard active, readID == nil, phase != .saving else { return }
        let epoch = generation
        let request = UUID(); readID = request
        if response == nil { phase = .loading }
        defer { if readID == request { readID = nil } }
        do {
            let incoming = try await services.read()
            guard epoch == generation, readID == request, active else { return }
            guard incoming.isValid else { throw DJConnectError.invalidResponse }
            // Binding equality is scoped to this owner generation; a changed
            // binding invalidates any old operation, even when Profile returns ABA.
            if response.map({ $0.binding != incoming.binding }) == true || pending.map({ $0.binding != incoming.binding }) == true {
                pending = nil; errorCode = "settings_binding_changed"
            }
            response = incoming
            needsMutationReadback = false
            if pending != nil { phase = .uncertain }
            else if phase == .conflict {
                // A successful authoritative read resolves the stale view, not
                // the rejected write. The caller receives that rejection once.
                phase = .ready; errorCode = nil
            } else if phase != .saved { phase = .ready }
        } catch {
            guard epoch == generation, readID == request, active else { return }
            if withdrawIfNeeded(error) { return }
            phase = pending == nil ? .unavailable : .uncertain
            errorCode = (error as? DJConnectProfileDJSettingsFailure)?.error ?? "settings_unavailable"
        }
    }

    @discardableResult
    public func change(_ patch: DJConnectProfileDJSettings.Patch, using services: Services) async -> DJConnectProfileDJSettingsFailure? {
        guard canEdit, let current = response, patch.isValid,
              !current.requiresSelection || patch.isComplete else { return nil }
        // A concurrent freshness GET may predate this edit. Fence its completion
        // without cancelling/replaying either HTTP operation.
        readID = nil
        let epoch = generation
        // Use the producer's qualified clock; wall-clock drift must not mint an
        // invalid operation or extend its lifetime. Core rejects stale clocks.
        guard let serverDate = DJConnectHistoryEntry.date(current.as_of) else { return nil }
        let id = DJConnectOperationIdentity.uuidV7(milliseconds: Int(serverDate.timeIntervalSince1970 * 1000))
        pending = Pending(id: id, binding: current.binding); phase = .saving; errorCode = nil
        do {
            let accepted = try await services.update(current, patch, id)
            guard epoch == generation, active else { return nil }
            guard accepted.accepted == true, accepted.operation_id == id,
                  accepted.binding == current.binding, accepted.isValid else {
                phase = .uncertain; return await reconcile(services)
            }
            // Receipt snapshots are historical. Always read current authority;
            // replayed acceptance must not roll back another device's later edit.
            pending = nil; needsMutationReadback = true; phase = .saved
            await refresh(services)
        } catch let rejection as DJConnectProfileDJSettingsFailure {
            guard epoch == generation, active else { return nil }
            pending = nil; needsMutationReadback = true; phase = .conflict; errorCode = rejection.error
            await refresh(services)
            guard epoch == generation, active else { return nil }
            return rejection
        } catch {
            guard epoch == generation, active else { return nil }
            if withdrawIfNeeded(error) { return nil }
            phase = .uncertain; errorCode = "settings_outcome_unknown"
            return await reconcile(services)
        }
        return nil
    }

    @discardableResult
    public func reconcile(_ services: Services) async -> DJConnectProfileDJSettingsFailure? {
        guard active, let operation = pending, !reconciling else { return nil }
        let epoch = generation; reconciling = true
        defer { if epoch == generation { reconciling = false } }
        do {
            let result = try await services.receipt(operation.binding, operation.id)
            guard epoch == generation, active, result.validates(operationID: operation.id) else { return nil }
            switch result.phase {
            case "accepted": pending = nil; needsMutationReadback = true; phase = .saved; errorCode = nil
            case "not_accepted": pending = nil; needsMutationReadback = true; phase = .conflict; errorCode = "settings_not_accepted"
            default: phase = .uncertain; errorCode = "settings_outcome_unknown"
            }
            await refresh(services)
            guard epoch == generation, active else { return nil }
            if result.phase == "not_accepted" { return .init(error: "settings_not_accepted") }
        } catch {
            guard epoch == generation, active else { return nil }
            if withdrawIfNeeded(error) { return nil }
            phase = .uncertain; errorCode = "settings_outcome_unknown"
        }
        return nil
    }

    /// Explicitly leave an unknown old attempt behind after an authoritative read.
    /// This never resends its patch or interprets current values as its receipt.
    public func useCurrentSettings(_ services: Services) async {
        guard active, hasUncertainOperation else { return }
        let epoch = generation
        do {
            let current = try await services.read()
            guard epoch == generation, active, current.isValid else { return }
            response = current; pending = nil; needsMutationReadback = false; phase = .ready; errorCode = nil
        } catch { }
    }
}

/// A local task fence, never Profile authority. The authenticated settings3
/// response supplies that authority itself. History loading/suspension must not
/// block settings or erase an unresolved settings operation.
public struct DJConnectProfileSettingsOwnerFence {
    private var pairedContext: String?
    private var confirmedProfile: String?
    private var generation = UUID()
    public init() {}
    public mutating func owner(context: String?, confirmedProfile value: String?) -> String? {
        if context != pairedContext {
            generation = UUID(); confirmedProfile = nil; pairedContext = context
        }
        guard let context else { confirmedProfile = nil; return nil }
        if let value {
            if let previous = confirmedProfile, previous != value { generation = UUID() }
            confirmedProfile = value
        }
        return context + "|" + generation.uuidString
    }
}
