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
