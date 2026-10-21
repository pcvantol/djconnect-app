# Session artwork requests speaker choices

In an active Session, album-art play/pause now sends the existing localized Ask DJ question for available speakers when no current output is known. The screen switches to Flow, clears its search filter and uses the existing submitted-question scroll target. An already known output follows the existing playback command path.

The request uses the existing Profile conversation owner/epoch and current Session context, excludes an unrelated selected history entry, preserves the unsent composer draft and rejects a repeated in-flight request. It does not select an output or send a play/pause command before the user chooses one. No queued automatic playback continuation was added. The existing Core speaker-list phrases are used in all five languages; no new producer contract or backend source was introduced.

Two functions / eight parameterized cases PASS: missing/known output, wrong Session, withdrawn owner, and existing Ask DJ 502/503/decode/409 error handling. The missing-output case verifies one conversation POST, output actions in the accepted response, preserved draft and no command POST. This is a model/transport fixture test, not a native artwork tap or physical speaker-selection test. DJConnectUIIOS unsigned compilation PASS; localization validation PASS for1389keys/five locales; diff whitespace check PASS.

Earlier fixture iterations are preserved in the private evidence directory. The first compile exposed a nested test macro; later fixtures corrected stale response revisions and the separate messages array. Delayed synthetic replies overlapped the independently started, incompletely modeled live Session transport and did not qualify completion. The final bounded immediate-response regression passes; no delayed/live-transport acceptance is inferred. Production context and authority guards were not weakened.

Local source only. No installation, publication, real speaker switch or playback command was performed. Raw logs and their hashes are recorded in the adjacent JSON.
