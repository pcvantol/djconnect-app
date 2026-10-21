# Fixed VibeCast QA build

This generates a separate **unsigned** iOS/iPadOS app project and macOS contract
test target. It does not change the shipping project's environment or signing.
The build has one immutable tuple:

| Component | Fixed value |
| --- | --- |
| Compilation condition | `DJCONNECT_VIBECAST_FIXED_QA` |
| API origin | `https://api-vibecast-qa.djconnect.dev` |
| Browser origin | `https://qa.vibecast.tv` |
| Application identifier | `dev.djconnect.ios.vibecastqa` |
| Keychain service prefix | `dev.djconnect.rendezvous.fixedqa` |
| URL scheme | `djconnect-vibecast-qa` |

There is no runtime host or environment selector. Production keeps its existing
origins and storage service names, and rejects QA QR payloads. QA rejects
production payloads. Exact matching also rejects trailing slashes, URL userinfo,
queries, fragments, explicit ports and lookalike hosts.

## Generate and verify

Use an existing clean JOSESwift checkout at the shipping pin
`c2664a902e75c0426a1d43132bd4babc6fd173d3`. Choose a new output directory outside
the source tree. For example:

```sh
python3 Tools/qualification/vibecast-fixed-qa/prepare_fixed_qa.py \
  /tmp/djc-fixed-qa-project --jose-checkout /path/to/JOSESwift
xcodebuild test -project /tmp/djc-fixed-qa-project/VibeCastFixedQA.xcodeproj \
  -scheme FixedQAContractTests -destination platform=macOS \
  -derivedDataPath /tmp/djc-fixed-qa-tests -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build -project /tmp/djc-fixed-qa-project/VibeCastFixedQA.xcodeproj \
  -scheme VibeCastFixedQAIOS -destination generic/platform=iOS \
  -derivedDataPath /tmp/djc-fixed-qa-ios CODE_SIGNING_ALLOWED=NO
```

The generated project references working-tree source files. `source-inputs.json`
records their hashes; verify they are unchanged after building. Dirty input is
explicitly recorded with `source_sha: null` and a separate base SHA, rather than
being represented as a qualified commit. Generation refuses to overwrite an
existing output directory.

The checked-in fixtures are exact bytes from API source
`3b43332bb28ed4aea228938f2d3a61796c8c3f33`, published artifact
`fixed-rendezvous-qa-3b43332bb28ed4aea228938f2d3a61796c8c3f33` (run
`39615718356`, artifact `12352870721`). Origin fixture SHA-256:
`3d99505e746237f111866a611cf3ced950ee07668fdb81040bc7745f663b7085`.
Wire schema SHA-256:
`24ab72719195f7971e070e56c52ceea7e67e02ee1bd7c6946eca99883194505f`.
Tests bind parser, request URL, decrypted destination and recovery bytes to the
selected build profile. Test transport and journal storage are in-memory.

## Scope

This is source/build preparation. The generated app has no production signing
profile, entitlements or shared container. It does not establish a current
signed Apple profile or operational admission. It does not execute SDK key
generation, enrollment, repair, device installation or service activation.
The existing destination preparation's `notReady` boundary remains intact;
native SDK orchestration and physical device acceptance remain separate work.

## One finite signed native test

`prepare_native_test_run.py` extends the unsigned generator with a separately
reviewed, compile-time selected native run policy. Shipping and ordinary fixed-QA
builds still have no selected policy. This is not a runtime preference or host
selector. The selector source is generated only into the private qualification
project, for FixedQACoreIOS; the policy and generated source hashes are recorded.

The manifest uses schema `djc-apple-native-test-run/1`, exact `source_sha` and a
`policy` matching `RendezvousNativeRunPolicy`: canonical run UUID, QA bundle/build,
Team/AppID/development realm, actual embedded provisioning profile SHA256, fixed
QA service/browser tuple and an absolute selection window of at most two hours.
The actual run starts at its first protected SDK reservation and lasts at most
600 seconds on both original wall and monotonic clocks. Exactly one generate,
one attest and one assertion may start, in order. Failed SDK callbacks and
uncertain writes never refund a reservation. No automatic retries are admitted.

Unsigned selection compilation is allowed for source review; it cannot install
on an iOS device. With `--signing-inputs`, the tool additionally requires exact
clean source already present in local `origin/main`, an existing matching signed
profile/certificate and ordinary Xcode automatic selection without provisioning
updates. It makes a signed proposal, not API activation or an SDK run. Strict
signature/entitlements/profile/artifact readback and API owner's final external
admission manifest are required before an actual test installation/interaction.
The final artifact hash is external; a binary cannot contain its own final hash.

The app checks its actual physical iOS foreground state, Bundle identity/build,
compiled fixed origins and embedded profile digest, with protected device-local
persist-before-effect accounting. The OS-installed code signature and the
external verified installer/profile bind Team/AppID/environment. A real App
Attest result still requires API's genuine verifier; a profile hash is not an
attestation or proof of the returned AAGUID.
