# Receiver a713ab2 — scoped Apple source compatibility review

Decision: **SOURCE_COMPATIBLE_NO_BLOCKING_FINDING** for receiver commit
`a713ab246465843447966ddfd08e53800e8502ff`, tree
`5e00324b7430aa622f27a15d0ff91d8b61c93afa`.

The existing receiver writer requested this bounded read-only review within the
owner's previously authorized cross-lane VibeCast review. Apple inspected exact
Git objects; no receiver files, builds/tests, publication, provider state,
App Attest effects or installed applications were changed by this review.

## Reviewed Apple compatibility

- The static QA graph has the exact separate browser/service tuple used by the
  compiled fixed-QA Apple profile. Shipping bootstrap continues to select the
  unavailable adapter. No runtime origin/URL configuration is introduced.
- The build applies hash-bound single-occurrence transforms to wire origins,
  schema and entry/CSP. The QA artifact remains marked source-review only with
  no selected admission or activation artifact. This is not deployment review.
- Receiver QR generation and Apple's bounded parser agree on the closed eight
  fields, wire version, UUID-v4 transaction, canonical 32-byte token encodings,
  numeric generation, 1,024-byte cap and original 120-second deadline.
- Native encryption and receiver verification agree on RSA2048/OAEP-SHA256,
  A256GCM, exact typ/kid headers and the eight destination plaintext fields.
  Receiver verification binds transaction/generation/thumbprint/original expiry,
  browser origin and issuer epoch before allowing HTTPS navigation.
- Browser navigation remains destination preparation. It does not start a DJ
  Session or grant Core B display approval; the native six-digit confirmation
  remains independent.

The receiver QA wire fixture is byte-equal to Apple's protected fixture:
SHA256 `24ab72719195f7971e070e56c52ceea7e67e02ee1bd7c6946eca99883194505f`.

The origin-fixture JSON differs in **two historical provenance fields only**:
receiver source `9a87fb2f3cc821c0a2482e8fa6b88c2340179e78` and worker hash
`ed335d516613e40cddd84067742b4efa24dee1559c77144eef79e06b45138a90`,
versus Apple's protected source `3b43332bb28ed4aea228938f2d3a61796c8c3f33`
and worker hash `2a9eab83813c283aea5010da452fd52645187bbf3d18780183d8b442293b4e09`.
All remaining fixture JSON fields match, including the fixed origins, wire hash,
activation false and null Apple profile/admission. This does not block the
bounded source-compatibility review; it cannot establish equality or admission
of actual worker artifacts. Neither fixture was rewritten or relabeled.

## Limits

The API writer independently reconfirmed current protected API main
`9ab24315a10b569b84e738d09bf32df6da12e38b`: historical native 40408 selection
expired, current Apple profile/admission null, activation false and all 22
full-service gates open. This source ACK grants no public/QA service activation,
new native run, device installation, Pages delivery or full iPhone/HA/receiver/TV
acceptance. Those need their own current exact evidence and authorization.

Private evidence with reviewed-file hashes and fixture comparison:
`/Volumes/Shared Data/tmp/pcvantol/djc-vibecast-completion-20261022/receiver-source-review.json`.
The exact scoped ACK was delivered to the existing receiver writer.
