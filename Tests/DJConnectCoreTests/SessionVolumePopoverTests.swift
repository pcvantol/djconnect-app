import Foundation
import Testing
@testable import DJConnectCore
@testable import DJConnectUI

@Test(.isolatedClientResources) @MainActor
func sessionVolumePopoverRequiresSupportedActiveOutput() throws {
    let suite = "session-volume-capability-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
    #expect(!SessionPlaybackVolumeButton(model: model).canPresentVolume)
    model.startDemoMode()
    #expect(SessionPlaybackVolumeButton(model: model).canPresentVolume)
    model.availableOutputs[0].supportsVolume = false
    #expect(!SessionPlaybackVolumeButton(model: model).canPresentVolume)
    model.availableOutputs[0].supportsVolume = true
    var playback = try #require(model.playback)
    playback.device?.active = false
    model.apply(playback: playback)
    #expect(!SessionPlaybackVolumeButton(model: model).canPresentVolume)
}

@Test(.isolatedClientResources) @MainActor
func delayedVolumeCommitCannotFollowSpeakerSelection() async throws {
    let suite = "session-volume-output-fence-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
    model.startDemoMode()
    let next = try #require(model.availableOutputs.last)
    let originalVolume = next.volumePercent
    model.volume = 83
    model.commitVolumeChange()
    model.selectOutput(next)
    for _ in 0..<100 where model.availableOutputs.first(where: { $0.id == next.id })?.active != true {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.availableOutputs.first(where: { $0.id == next.id })?.active == true)
    // Cross the original 300ms debounce. The queued volume belonged to the old
    // output and must not be applied to the newly selected speaker.
    try await Task.sleep(for: .milliseconds(400))
    #expect(model.availableOutputs.first(where: { $0.id == next.id })?.volumePercent == originalVolume)
}

@Test(.isolatedClientResources) @MainActor
func volumePopoverKeepsReleasedValueThroughDebounceAndOldStatusReadback() throws {
    let suite = "session-volume-draft-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    let model = DJConnectAppModel(defaults: defaults, tokenStore: DJConnectInMemoryTokenStore(), startBackgroundTasks: false)
    defer { model.markInactiveSession(); defaults.removePersistentDomain(forName: suite) }
    model.startDemoMode()
    let old = try #require(model.playback)
    model.volume = 83; model.commitVolumeChange()
    #expect(model.currentPlaybackVolumePercent == 83)
    model.apply(playback: old) // A status sample from before finger-up.
    #expect(model.currentPlaybackVolumePercent == 83)
}
