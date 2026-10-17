# Physical App Attest qualification (hosted diagnostic only)

This XCTest bundle runs inside the actual signed `dev.djconnect.ios` app. It is
not a scanner, enrollment endpoint client, or production verifier. The host must
be the existing app target with the existing Team/App ID, not a standalone runner.
Use an isolated native build stage; never add this test bundle to a release.

The executed XcodeGen overlay for2026-10-17 is retained under
`/private/tmp/djc-settings3-native-source/appattest-qualification.yml` and the
private input/evidence root is `/private/tmp/djc-appattest40227-private`.
The overlay adds an iOS `bundle.unit-test` target, dependency `DJConnectIOS` and
DeviceCheck.framework, `TEST_HOST=$(BUILT_PRODUCTS_DIR)/DJConnect.app/DJConnect`,
`BUNDLE_LOADER=$(TEST_HOST)`, generated Info.plist, existing development Team,
and the diagnostic Swift source plus `challenges.json` as a test-only resource.

Generate cryptographically random, action-separated synthetic challenge input on
the controlling host. This is controlled diagnostic input, not API challenge or
server authority. Preserve these exact bytes and bound them to each captured
proof. Challenge keys: active/replacement × attest/assert-1/assert-2/assert-3/
assert-4, and invalid-key. Values are UTF-8 strings, hashed once by the device.

1. Build-for-testing and inspect the actual signed app/provision identity before
   running. Missing explicit App Attest environment alone is not a development
   failure. Do not alter accounts/provisioning to guess an environment.
2. Test-without-building on the real iPhone. The first run creates at most two
   handles, captures each attestation and two assertions. Errors stop; uncertain
   attestation does not regenerate/re-attest automatically. Raw evidence stays in
   the app's complete-file-protection diagnostic directory, outside ordinary logs.
3. Copy only `Library/Application Support/DJConnect/AppAttestQualification` to a
   mode0700 private host directory. Do not copy preferences/tokens or publish raw
   proofs, key handles, receipts, or challenge-bound diagnostic archives.
4. A second app-build/process run reuses those exact handles and captures two more
   assertions. Further runs stop at the bound. Corrupt state throws, never resets.
   This demonstrates handle survival across an update, not server enrollment
   recovery, revocation, reinstall, restore, hardware erasure, or monthly rotation.
5. `inspect_capture.py <private-evidence-dir>` uses cbor2==5.6.5 plus cryptography.
   It checks bounded genuine-fixture structure, expected App-ID hash, leaf/key-ID
   binding, actual assertion signatures, changed-clientData rejection and monotonic
   observed counters. It is deliberately not a trust-chain/receipt/parser security
   verifier. API owns full root/path/nonce/receipt, strict parser and runtime gates.
6. Regenerate the ordinary project from its canonical project.yml, rebuild the
   app without the test overlay, ensure no qualification bundle is embedded,
   install and read back the ordinary app. Preserve normal HA pairing/profile.

Never infer contractfreeze or scanner runtime admission from these diagnostics.
