import Foundation
import CryptoKit

/// One explicit, foreground Core B approval intent. Independent of App Attest/A.
/// No display bearer, auto-start, automatic replay, persistence or key operation.
@MainActor public final class DJConnectDisplayConsentSession {
    public enum State: Equatable, Sendable { case idle, resolving, ready, approving, approved, revoking, revoked, revokeUncertain, unavailable, uncertain }
    public struct ExistingShare: Sendable {
        public let identifier: String
        public let generation: Int
        public let expiresAt: Date
        fileprivate let deadline: TimeInterval
    }
    public struct Receipt: Sendable {
        public let displayID: String
        public let shareID: String
        public let shareGeneration: Int
        public let sessionID: String
        public let expiresAt: Date
        fileprivate let admittedAt: Date
        fileprivate let requestedUptime: TimeInterval
        fileprivate let deadline: TimeInterval
        fileprivate let authorityIsCurrent: @MainActor @Sendable () -> Bool
        @MainActor public func isCurrent() -> Bool {
            isCurrent(now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
        }
        // Internal clock injection supports boundary tests; public consumers
        // cannot replace the clocks used for displayed authority.
        @MainActor func isCurrent(now: Date, uptime: TimeInterval) -> Bool {
            authorityIsCurrent() && now.timeIntervalSince1970.isFinite && now >= admittedAt && now < expiresAt &&
            uptime.isFinite && uptime >= requestedUptime && uptime < deadline
        }
    }
    public private(set) var state: State = .idle
    public private(set) var resolvedClaim: DJConnectDisplayClaim?
    public private(set) var existingShare: ExistingShare?
    private var storedReceipt: Receipt?
    public var receipt: Receipt? {
        guard state == .approved else { return nil }
        guard current(), let value = storedReceipt, value.isCurrent() else {
            // Once displayed authority expires or is observed withdrawn, a
            // clock/token/owner round trip cannot revive the old UI receipt.
            storedReceipt = nil; state = .unavailable; return nil
        }
        return value
    }
    private let client: DJConnectClient
    private let installationID: String
    private let sessionID: String
    private let pairedLocalOrigin: URL?
    private let tokenDigest: Data
    private let isOwnerCurrent: @MainActor @Sendable () -> Bool
    private var route: String?

    public init(client: DJConnectClient, installationID: String, sessionID: String, pairedLocalOrigin: URL?,
                isCurrent: @escaping @MainActor @Sendable () -> Bool) throws {
        guard [.ios, .macos].contains(client.identity.clientType), !installationID.isEmpty,
              !sessionID.isEmpty, sessionID.utf8.count <= 128,
              sessionID == sessionID.trimmingCharacters(in: .whitespacesAndNewlines),
              sessionID.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              let token = try client.tokenStore.loadToken(), !token.isEmpty else { throw DJConnectError.invalidResponse }
        self.client = client; self.installationID = installationID; self.sessionID = sessionID
        self.pairedLocalOrigin = pairedLocalOrigin; self.isOwnerCurrent = isCurrent
        tokenDigest = Data(SHA256.hash(data: Data(token.utf8)))
    }
    private func receiptAuthorityIsCurrent() -> Bool {
        guard state == .approved else { return false }
        guard current() else {
            storedReceipt = nil; state = .unavailable; return false
        }
        return true
    }
    private func current() -> Bool {
        guard !Task.isCancelled, isOwnerCurrent(), let token = try? client.tokenStore.loadToken() else { return false }
        return Data(SHA256.hash(data: Data(token.utf8))) == tokenDigest
    }
    public func withdraw() {
        state = state == .revoking || state == .revokeUncertain ? .revokeUncertain : state == .approving ? .uncertain : .unavailable
        resolvedClaim = nil; existingShare = nil; storedReceipt = nil
    }
    private func ownerContext() async throws -> DJConnectDisplayOwnerContext {
        let context = try await client.displayOwnerContext(expectedInstallationID: installationID,
            pairedLocalOrigin: pairedLocalOrigin, isCurrent: { self.current() && (self.state == .resolving || self.state == .approving || self.state == .revoking) })
        guard current(), context.sessionID == sessionID else { throw DJConnectError.invalidResponse }
        return context
    }
    private func share(_ context: DJConnectDisplayOwnerContext, requestedAt: Date, uptime: TimeInterval) throws -> ExistingShare? {
        if context.shareID == nil && context.shareGeneration == nil && context.expiresAt == nil && context.expiresIn == nil { return nil }
        guard let id = context.shareID, DJConnectRendezvousQR.canonicalToken(id),
              let generation = context.shareGeneration, generation > 0,
              let text = context.expiresAt, let expiry = displayWireDate(text), expiry > Date(),
              let remaining = context.expiresIn, remaining.isFinite, remaining > 0, remaining <= 28800,
              expiry.timeIntervalSince(requestedAt) <= 28800 else { throw DJConnectError.invalidResponse }
        let deadline = uptime + min(remaining, expiry.timeIntervalSince(requestedAt))
        guard deadline.isFinite, ProcessInfo.processInfo.systemUptime < deadline else { throw DJConnectError.invalidResponse }
        return ExistingShare(identifier: id, generation: generation, expiresAt: expiry, deadline: deadline)
    }

    /// Lookup is a pure read and cannot create a share. One lookup per intent.
    public func resolve(code: String) async throws {
        guard state == .idle, current(), code.utf8.count == 6,
              code.utf8.allSatisfy({ (48...57).contains($0) }) else { throw DJConnectError.invalidResponse }
        state = .resolving
        do {
            let started = Date(), tick = ProcessInfo.processInfo.systemUptime
            let context = try await ownerContext()
            let offered = try share(context, requestedAt: started, uptime: tick)
            let body = try JSONSerialization.data(withJSONObject: ["contract_version": 1, "code": code,
                "identity": ["device_id": client.identity.deviceID, "client_type": client.identity.clientType.rawValue]])
            let requested = Date(), requestedTick = ProcessInfo.processInfo.systemUptime
            let data = try await client.displayConsentExchange(path: "resolve", body: body, isCurrent: {
                self.current() && self.state == .resolving
            })
            let claim = try DJConnectDisplayClaim.parse(data, code: code, expectedIssuerEpoch: context.issuerEpoch,
                requestedAt: requested, requestedUptime: requestedTick, now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
            guard current(), state == .resolving else { throw DJConnectError.invalidResponse }
            route = context.displayEntryURL; existingShare = offered; resolvedClaim = claim; state = .ready
        } catch {
            withdraw(); throw error
        }
    }

    /// Call only from a distinct user confirmation for the current Session and
    /// displayed share choice. The original owner predicate must capture every
    /// UI/Profile/Session/route/background revision, including ABA withdrawals.
    public func approve(share choice: DJConnectDisplayClaim.Share) async throws -> Receipt {
        guard state == .ready else { throw DJConnectError.invalidResponse }
        guard current(), let claim = resolvedClaim, claim.isCurrent() else {
            withdraw(); throw DJConnectError.invalidResponse
        }
        state = .approving
        var possibleEffect = false
        do {
            let started = Date(), tick = ProcessInfo.processInfo.systemUptime
            let context = try await ownerContext()
            guard context.issuerEpoch == claim.issuerEpoch, context.displayEntryURL == route, claim.isCurrent() else { throw DJConnectError.invalidResponse }
            let freshShare = try share(context, requestedAt: started, uptime: tick)
            let maxExpiry: Date
            let maxDeadline: TimeInterval
            let expectedID: String?
            let expectedGeneration: Int
            switch choice {
            case .createTwoHours:
                guard existingShare == nil, freshShare == nil else { throw DJConnectError.invalidResponse }
                maxExpiry = Date().addingTimeInterval(7200); maxDeadline = ProcessInfo.processInfo.systemUptime + 7200; expectedID = nil; expectedGeneration = 1
            case let .existing(id, generation):
                guard let offered = existingShare, let fresh = freshShare,
                      id == offered.identifier, generation == offered.generation,
                      id == fresh.identifier, generation == fresh.generation,
                      Date() < offered.expiresAt, ProcessInfo.processInfo.systemUptime < offered.deadline else { throw DJConnectError.invalidResponse }
                maxExpiry = min(offered.expiresAt, fresh.expiresAt); maxDeadline = min(offered.deadline, fresh.deadline); expectedID = id; expectedGeneration = generation
            }
            let body = try claim.approvalBody(identity: client.identity, sessionID: sessionID,
                currentIssuerEpoch: context.issuerEpoch, share: choice, now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
            let requestedAt = Date(), requestedUptime = ProcessInfo.processInfo.systemUptime
            possibleEffect = true
            let data = try await client.displayConsentExchange(path: "approve", body: body, isCurrent: {
                self.current() && self.state == .approving && claim.isCurrent() &&
                (self.existingShare.map { Date() < $0.expiresAt && ProcessInfo.processInfo.systemUptime < $0.deadline } ?? true)
            })
            let value = try JSONDecoder().decode(ApprovalWire.self, from: data)
            guard current(), state == .approving, claim.isCurrent(), value.success, value.contract_version == 1,
                  value.state == "approved", value.session_id == sessionID,
                  DJConnectRendezvousQR.canonicalToken(value.display_id), DJConnectRendezvousQR.canonicalToken(value.share_id),
                  expectedID == nil || expectedID == value.share_id, value.share_generation == expectedGeneration,
                  value.share_expires_in.isFinite, value.share_expires_in > 0, value.share_expires_in <= (expectedID == nil ? 7200 : 28800),
                  let expiry = displayWireDate(value.share_expires_at), min(expiry, maxExpiry) > Date() else { throw DJConnectError.invalidResponse }
            // Relative server lifetime and all original offer/request clocks are
            // independent upper bounds, not replacements for one another.
            let now = Date(), uptime = ProcessInfo.processInfo.systemUptime
            let effectiveExpiry = min(min(expiry, maxExpiry), requestedAt.addingTimeInterval(value.share_expires_in))
            let deadline = min(maxDeadline, requestedUptime + min(value.share_expires_in, effectiveExpiry.timeIntervalSince(requestedAt)))
            guard now >= requestedAt, now < effectiveExpiry, deadline.isFinite,
                  uptime >= requestedUptime, uptime < deadline else { throw DJConnectError.invalidResponse }
            let result = Receipt(displayID: value.display_id, shareID: value.share_id, shareGeneration: value.share_generation,
                sessionID: sessionID, expiresAt: effectiveExpiry, admittedAt: now, requestedUptime: requestedUptime, deadline: deadline,
                authorityIsCurrent: { [weak self] in self?.receiptAuthorityIsCurrent() ?? false })
            storedReceipt = result; state = .approved; return result
        } catch {
            withdraw(); state = possibleEffect ? .uncertain : .unavailable; throw error
        }
    }
    /// Distinct user intent: revoke this display only, preserving other displays
    /// in the same share and the active owner Session. Never automatically replay.
    public func revokeDisplay() async throws {
        guard let approved = receipt, current() else { throw DJConnectError.invalidResponse }
        storedReceipt = nil; state = .revoking
        var possibleEffect = false
        do {
            let context = try await ownerContext()
            guard current(), state == .revoking, context.displayEntryURL == route,
                  context.issuerEpoch == resolvedClaim?.issuerEpoch,
                  Date() >= approved.admittedAt, Date() < approved.expiresAt,
                  ProcessInfo.processInfo.systemUptime >= approved.requestedUptime,
                  ProcessInfo.processInfo.systemUptime < approved.deadline else {
                throw DJConnectError.invalidResponse
            }
            let body = try JSONSerialization.data(withJSONObject: ["contract_version": 1,
                "identity": ["device_id": client.identity.deviceID, "client_type": client.identity.clientType.rawValue],
                "session_id": sessionID, "share_id": approved.shareID, "display_id": approved.displayID])
            possibleEffect = true
            let data = try await client.displayConsentExchange(path: "revoke", body: body, isCurrent: {
                self.current() && self.state == .revoking && Date() >= approved.admittedAt && Date() < approved.expiresAt &&
                    ProcessInfo.processInfo.systemUptime >= approved.requestedUptime && ProcessInfo.processInfo.systemUptime < approved.deadline
            })
            struct Reply: Decodable { let success: Bool; let contract_version: Int }
            let reply = try JSONDecoder().decode(Reply.self, from: data)
            guard current(), state == .revoking, reply.success, reply.contract_version == 1 else { throw DJConnectError.invalidResponse }
            resolvedClaim = nil; existingShare = nil; state = .revoked
        } catch {
            storedReceipt = nil; state = possibleEffect ? .revokeUncertain : .unavailable
            throw error
        }
    }

    private struct ApprovalWire: Decodable {
        let success: Bool
        let contract_version: Int
        let state: String
        let display_id: String
        let session_id: String
        let share_id: String
        let share_generation: Int
        let share_expires_in: Double
        let share_expires_at: String
    }
}
