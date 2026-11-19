# Current Session history refresh repaired on Mac mini

The ordinary Mac mini app40403 reproduced the reported failure: `session-timeline-error` and **Bijwerken mislukt** after its timeline retry. Ask DJ could still answer independently. Read-only requests using the existing Mac installation and its already configured HTTPS HA all returned200: capabilities, active Session, Profile conversation history and active timeline.

The timeline contained12 entries, including a settings-feedback user/assistant pair with `input_type: setting_feedback`. The Apple history reader only accepted `text`/`voice`, so it rejected the entire otherwise coherent200page. The Core owner confirmed this existing producer behavior in protected58561f97 / Finalb4bf4701 (same232productbytes under newer pins): the server removes the inbound internal marker and emits the type only for qualified settings feedback.

Source `5ea65c6a422c8a9255e5aaa2f632828f51238d6d` adds only this recognized read type. Owner, Session, role, context and retention validation remain intact. No outbound setting-feedback request or backend patch was added.

The negative regression produced exactly one expected issue among six input-type cases, on setting_feedback. After correction, four focused functions /12cases PASS,0failures/skips, including decoding the private captured runtime page and existing answer-context/error checks. Unknown, empty and case-variant types remain rejected. The initial test-edit command was blocked before execution because it would have truncated the test file; a narrow insertion patch preserved all existing tests.

A separately built ordinary signed Mac application4.0.0(40404) was installed on **Mac mini only**. Strict signature validation, executable hash and complete installed bundle bytes/modes/symlinks match the built artifact. The actual running application was read back via native accessibility: the history error disappeared, rows loaded, and the same refresh action displayed **Bijgewerkt**. This is actual ordinary-app runtime evidence, beyond the fixture tests.

No personal question was resent or deleted and no diagnostic playback command was issued. App data, pairing and backend Session remain preserved. The new transient40403recovery application was removed after proving it duplicates the retained original40403product. Other devices remain40403. No source publication, PR or release was performed.

Raw real responses remain private under the access-limited evidence directory, not in repository fixtures. The adjacent JSON binds the source, private read/test/build/install receipts and runtime observation. The original screenshot's earlier context-changed question was not reproduced or resent; the user's subsequent clarification and Mac mini request identified the separate history-read failure fixed here.
