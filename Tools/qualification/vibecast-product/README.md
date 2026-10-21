# Bounded native HTTP/software qualification

This opt-in runner consumes a clean, protected API checkout at
`828fbaf300ca369dcc753b676295e84094d5e8c6` and the API provenance-checked
JOSE 6.2.12 package. It never installs dependencies or modifies the API checkout.

Precompile the current native Swift test binary (do not reuse an older build):

```sh
swift test --scratch-path "$SWIFT_SCRATCH" --filter '[Rr]endezvous'
node Tools/qualification/vibecast-product/run_api_http.mjs \
  "$API_CHECKOUT" "$SWIFT_SCRATCH" "$PINNED_JOSE_PACKAGE"
```

The explicit run creates an ephemeral loopback root target, private 0700 plan
directory, software-only RSA browser recipient and one 120-second transaction.
The actual Mac Swift service inspects the original QR and shipping JOSESwift
encrypts a synthetic HA destination. Node's independently pinned JOSE decrypts
and verifies it, then cancels the transaction. Only create, inspect and cancel
are expected. Runtime and fixture HTTP server are closed in finally.

No attestation/key enrollment, assertion, submit, physical device, public service
or real HA/Profile operation is performed. The URLProtocol translates only the
canonical request locator/response URL metadata to the private loopback locator;
body/status/crypto are unchanged. This is not public TLS, browser UI, positive
iOS/genuine App Attest or end-to-end product acceptance. Ordinary CI skips the
opt-in test unless its private plan environment is explicitly supplied.

Plans, capabilities and raw receipts stay private. Publish only sanitized source
pins, hashes, route/status counts and explicit evidence limits.

## Actual iOS AppModel consent qualification

Generate a separate, unsigned iOS unit-test project using an existing clean
JOSESwift checkout at the shipping pin. Use a new output directory for each
project so earlier results remain available:

```sh
python3 Tools/qualification/vibecast-product/prepare_native_consent_tests.py \
  "$QUALIFICATION_DIRECTORY" --jose-checkout "$JOSE_CHECKOUT"
xcodebuild -project "$QUALIFICATION_DIRECTORY/NativeConsentQualification.xcodeproj" \
  -scheme NativeConsentTests -destination "platform=iOS Simulator,id=$OWN_SIMULATOR_ID" \
  -parallel-testing-enabled NO \
  -derivedDataPath "$QUALIFICATION_DERIVED_DATA" \
  -resultBundlePath "$QUALIFICATION_DIRECTORY/result.xcresult" \
  CODE_SIGNING_ALLOWED=NO test
```

The project references the current Core/UI sources and existing consent tests;
it does not edit shipping targets. The iOS-only tests initialize the real
`DJConnectAppModel`, decode Session and Profile responses through its ordinary
HTTP read paths, and invoke the same lookup/confirm/withdrawal methods as the
native form. The shared serialized suite avoids cross-test interference in the
URLProtocol fixture. Replacing source bytes requires a new build/result.

Responses use an isolated synthetic owner and loopback locator intercepted by
URLProtocol. The two checked-in historical producer fixtures remain unchanged;
the wire rebinds the synthetic Session identifier to the consent fixture. This
proves native iOS appmodel integration, including explicit single approval,
existing-share selection, uncertain-result no-replay, and authority withdrawal.
It does not prove native button taps, a live HA/Profile, receiver rendering,
App Attest, provider behavior or physical device acceptance.

For actual simulator taps on the production `VibeCastDisplayConsentForm`, add
`--with-ui` to project generation and select scheme `NativeConsentUI`. The
separate disposable app has its own bundle identifier, in-memory synthetic token
and isolated defaults. It uses the same test-wire implementation extracted into
the generated directory. Native tests enter the code, look it up, confirm once,
withdraw the synthetic Profile and exercise an uncertain result. Screenshot
attachments remain in the result bundle. This is form interaction over a
synthetic wire, separate from full-app navigation and installed HA/receiver
qualification. No ordinary app target or preference is modified.

The opt-in `actualIOSNativeConsentInflightLifecycle()` uses `DJCONNECT_CONSENT_INFLIGHT_DIR` and the test-only `delayed-approval` URLProtocol mode. It delays the existing synthetic approval response for two seconds, removes the actual form hierarchy while approving, remounts before the acknowledgement, and verifies that the late result cannot revive or replay the old operation. Approval is an explicit model method, not a native button tap. Select only this new function with its parentheses and retain a new log/result directory; existing ready-only lifecycle evidence remains separate.
