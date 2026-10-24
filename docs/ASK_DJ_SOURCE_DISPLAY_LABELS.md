# Human-readable playback source label

The Spotify source card exposed the internal source code spotify_playback_context as its subtitle. Map that exact code to a localized Current playback information label in the shared Ask DJ source-card renderer, including its title fallback. Dutch: Huidige afspeelinformatie. English, German, French and Spanish translations included. Preserve provider title Spotify and the original link/source payload for navigation/provenance. This is display-only and adds no playback/artwork inference or backend request.

Validation: source/diff inspection and localization-plist syntax checks only. No build, compiled tests, render or installation under explicit-build-only instruction. Last installed preview40447 is unchanged. Pending source is in PR179 without merge; physical label verification follows the next explicitly requested build.
