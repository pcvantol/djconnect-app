import Foundation

/// Explicit LOCAL format for the existing Activity alias, separate from the
/// frozen rich-v1 DATA carrier. All results remain presentation DATA: no
/// permission, source/native clock mapping, restored owner or SDK handle.
enum DJConnectDirectLocalPresentationV2 {
    static let profileID = "djconnect-session-rich-direct-local-v2"
    struct Value {
        let attributes: Data; let contentState: Data; let snapshot: DJConnectSessionSurfaceSnapshot
        let contributionOmitted: Bool
    }
    private struct Attributes: Codable { let presentationID: String }
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }

    /// Only our complete encoder output is accepted. Re-encoding equality is a
    /// deliberately strict local-format rule: unknown/duplicate keys, omitted
    /// required data, optional nulls and lexical marker 2.0 cannot disappear
    /// through Codable. This is not a general remote JSON normalizer.
    static func preflight(attributes: Data, state: Data) throws -> Value {
        guard !attributes.isEmpty, !state.isEmpty, attributes.count + state.count <= 4096 else { throw invalid() }
        let attrs = try JSONDecoder().decode(Attributes.self, from: attributes)
        guard try encoder().encode(attrs) == attributes else { throw invalid() }
        let snapshot = try JSONDecoder().decode(DJConnectSessionSurfaceSnapshot.self, from: state)
        guard try encoder().encode(snapshot) == state else { throw invalid() }
        try validate(snapshot)
        return Value(attributes: attributes, contentState: state, snapshot: snapshot, contributionOmitted: false)
    }

    /// The whole original source graph remains in separate RAM custody. A
    /// local inability to display a story clears only that story; it never
    /// changes the original Core frame or extends any observation/deadline.
    static func prepare(attributes: Data, snapshot: DJConnectSessionSurfaceSnapshot) throws -> Value {
        guard let rich = snapshot.rich, rich.directLocalVersion == 2 else { throw invalid() }
        do { return try preflight(attributes: attributes, state: encoder().encode(snapshot)) }
        catch {
            guard rich.contribution != nil, rich.nowPlaying != nil else { throw invalid() }
            let downgraded = DJConnectPassiveActivityContent(directLocalBinding: rich.bindingID,
                generation: rich.generation, sequence: rich.sequence, receivedAt: rich.receivedAt,
                receivedUptime: rich.receivedUptime, expiresAt: rich.expiresAt, contribution: nil,
                nowPlaying: rich.nowPlaying, playbackState: rich.playbackState, researchAttribution: nil)
            let state = DJConnectSessionSurfaceSnapshot(preserving: snapshot, replacingRich: downgraded)
            let value = try preflight(attributes: attributes, state: encoder().encode(state))
            return Value(attributes: value.attributes, contentState: value.contentState, snapshot: value.snapshot, contributionOmitted: true)
        }
    }

    private static func validate(_ snapshot: DJConnectSessionSurfaceSnapshot) throws {
        guard snapshot.isCurrent(at: snapshot.observedAt), let rich = snapshot.rich, rich.directLocalVersion == 2,
              DJConnectPassiveSession.identifier(rich.bindingID), DJConnectPassiveSession.identifier(rich.generation), rich.sequence >= 0,
              rich.receivedUptime.isFinite, rich.receivedUptime >= 0, rich.receivedAt <= snapshot.observedAt,
              rich.expiresAt.timeIntervalSince(rich.receivedAt) <= 120,
              rich.isCurrent(at: snapshot.observedAt, uptime: rich.receivedUptime), snapshot.expiresAt <= rich.expiresAt,
              rich.contribution != nil || rich.nowPlaying != nil,
              try encoder().encode(rich).count <= 2800 else { throw invalid() }
        if let contribution = rich.contribution {
            guard DJConnectPassiveSession.identifier(contribution.moment_id),
                  contribution.text.unicodeScalars.count <= 640, contribution.text.utf8.count <= 2560,
                  ["home_dj", "radio_dj", "club_dj", "festival_dj"].contains(contribution.persona),
                  rich.currentContribution(at: snapshot.observedAt, uptime: rich.receivedUptime) != nil else { throw invalid() }
            if contribution.usage_basis == "public_artist_narration_v1" {
                guard rich.researchAttribution?.matches(contribution) == true,
                      Set(contribution.source_attribution.keys) == ["provider", "url", "license", "revision_url"] else { throw invalid() }
            } else {
                guard ["runtime_authored_direction", "cc0_facts_authored_expression"].contains(contribution.usage_basis),
                      rich.researchAttribution == nil else { throw invalid() }
                if contribution.usage_basis == "runtime_authored_direction" {
                    guard contribution.source_attribution.isEmpty else { throw invalid() }
                } else {
                    guard Set(contribution.source_attribution.keys) == ["provider", "url", "license"] else { throw invalid() }
                }
            }
            if contribution.usage_basis != "runtime_authored_direction" {
                let a = contribution.source_attribution
                guard a["provider"]!.utf8.count <= 512, a["license"]!.utf8.count <= 512,
                      validURL(a["url"]!), a["revision_url"] == nil || a["revision_url"] == "" || validURL(a["revision_url"]!) else { throw invalid() }
            }
        } else if rich.researchAttribution != nil { throw invalid() }
        if let music = rich.nowPlaying {
            guard DirectRichRequest.matches(music.item_id, "[a-f0-9]{24}"),
                  DirectRichRequest.matches(music.subject_uri, "spotify:track:[A-Za-z0-9]{22}"),
                  [music.track, music.artist, music.album].allSatisfy({ $0.utf8.count <= 512 }),
                  music.usage_basis == "spotify_temporary_passive_metadata",
                  Set(music.attribution.keys) == ["provider", "mark", "url"],
                  music.attribution["provider"] == "Spotify", music.attribution["mark"] == "spotify",
                  validURL(music.source_url), music.attribution["url"].map(validURL) == true,
                  rich.currentPlayback(at: snapshot.observedAt, uptime: rich.receivedUptime) != nil else { throw invalid() }
        }
        for end in [rich.contribution?.expires_at, rich.nowPlaying?.expires_at].compactMap({ $0 }) {
            guard let date = DJConnectHistoryEntry.date(end), rich.expiresAt <= date else { throw invalid() }
        }
        if let state = rich.playbackState {
            guard rich.nowPlaying != nil, ["stopped", "playing", "paused", "unknown"].contains(state) else { throw invalid() }
        }
    }
    private static func validURL(_ string: String) -> Bool {
        guard string.utf8.count <= 2048, let value = URLComponents(string: string) else { return false }
        return value.scheme == "https" && value.host?.isEmpty == false && value.user == nil && value.password == nil
    }
    private static func invalid() -> DJConnectError { .invalidResponse }
}
