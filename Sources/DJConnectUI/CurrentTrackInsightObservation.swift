import Foundation
import DJConnectCore

/// Client observation epoch only. No durable intelligence or guessed recording identity.
struct CurrentTrackInsightObservation {
    private(set) var generation = UUID()
    private var previous: DJConnectPlayback?
    mutating func observe(_ playback: DJConnectPlayback?) -> Bool {
        let seekBack: Bool
        if let old = previous?.progressMS, let new = playback?.progressMS { seekBack = Double(old) - Double(new) > 5_000 }
        else { seekBack = false }
        let changed = previous?.uri != playback?.uri || previous?.isPlaying != playback?.isPlaying
            || previous?.hasPlayback != playback?.hasPlayback || previous?.device?.id != playback?.device?.id
            || previous?.device?.provider != playback?.device?.provider || previous?.device?.source != playback?.device?.source
            || (playback?.uri == nil && (previous?.trackName != playback?.trackName || previous?.artistName != playback?.artistName))
            || seekBack
        previous = playback
        if changed { generation = UUID() }
        return changed
    }
}

/// Accepted settings identity includes revisions, so A→B→A cannot revive a read.
struct CurrentInsightSessionStyle: Equatable {
    let sessionID: String
    let state: String
    let mood: String
    let moodRevision: Int?
    let persona: DJConnectSessionPersonaValue?
    let personaRevision: Int?
    let presence: DJConnectSessionPresenceValue?
    let presenceRevision: Int?
    init(_ session: DJConnectSessionRuntime) {
        sessionID = session.id; state = session.runtimeState
        mood = session.selectedMood; moodRevision = session.confirmedMoodRevision
        persona = session.confirmedPersona?.selectedPersona; personaRevision = session.personaRevisionFloor
        presence = session.confirmedPresence?.selectedPresence; presenceRevision = session.presenceRevisionFloor
    }
}

struct CurrentInsightProfileStyle: Equatable {
    let binding: String
    let snapshot: DJConnectProfileDJSettingsSnapshot
    let voiceRevision: String
    init(_ response: DJConnectProfileDJSettingsResponse) {
        binding = response.binding; snapshot = response.snapshot; voiceRevision = response.voice_revision
    }
}
