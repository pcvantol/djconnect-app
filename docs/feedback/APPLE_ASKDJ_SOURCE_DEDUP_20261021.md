# Ask DJ source rows

The producer current-artist information route supplies its Spotify track citation in both links and sources. The Apple response projection concatenates these, and the bubble previously rendered both source-like links. Presentation now keeps the first source row per exact destination URL. Different track URLs remain separate even with identical provider/title. Stored response links and image data are unchanged, so existing duplicate-containing local messages also benefit.

One targeted regression PASS verifies duplicate destinations collapse while distinct tracks and original links remain intact. Shared macOS UI compilation and unsigned iOS/iPadOS UI compilation PASS; diff whitespace check PASS. Initial compile caught file-private link classification; it is now module-internal for reuse, with unchanged classification semantics. Earlier logs are preserved.

The inspected Core current-artist information route explicitly returns images: []. Apple already renders supplied response images, and this change invents no fallback from current playback or from track URLs. Core owner has registered qualified captured-track albumart as an open producer follow-up, retaining owner/context/track-change/proxy/deadline constraints. No new image producer or physical runtime acceptance is claimed.

Local only, no installation or publication. Adjacent JSON binds private test/build logs. No personal question was resent, no model call or playback command was performed.
