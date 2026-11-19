# Archived Session deletion request repair — 22 October 2026

User report: whole archived Session deletion fails on Mac with the generic
connection/retry message. Existing Apple writer, same draft PR179; no build,
installation or deletion of user data.

## Proven source mismatch

`deleteSavedSession` and `deleteAllSavedSessions` used `jsonRequest`, which encodes
`DJConnectIdentifiedRequestPayload`. That helper adds identity, client_id,
device_name, device_token and a nested payload copy. Core main
`83744790decc6ef8940795dc2c9c0e3fb058173b`,
`custom_components/djconnect/history_deletion_api.py`, rejects extra keys before
any deletion effect. The extra envelope therefore yields HTTP400 /
`invalid_history_delete_request`. Earlier mocks allowed extra fields, concealing
the producer/consumer mismatch; they did not prove real endpoint compatibility.

## Repair

Both archive mutation routes now use a dedicated authenticated request builder
and encode only their existing closed payload. Single deletion sends device_id,
client_type, session_id, expected_revision, operation_id and confirmed. Bulk
sends device_id, client_type, snapshot_id, operation_id and confirmed. Pairing
credentials remain in the authorization header. Existing owner/revision/snapshot,
explicit confirmation, journal, no replay, no-store and exact receipt checks are
preserved. This does not end or delete an active Session.

The existing single/bulk regression source now asserts exact key equality.
The old bulk subset assertion explicitly accepted the incompatible envelope;
that assertion and its misleading comment are replaced.

## Verification

Executed only the original Core shape-validation statements extracted through
Python AST, with in-memory synthetic single/bulk payloads. Old envelope shape
returned HTTP400; corrected exact shape passed both validators. No Core imports,
HA connection, database access or mutation ran. git diff --check and Apple work
register validation passed. Swift tests are updated but have NOT been compiled
or run; no native confirmation/real deletion acceptance or installed repair is
claimed. Those checks await the user's explicit build instruction.
