# Original widget background first-read admission

This client-owned source increment implements the initial owner-bound pin
required after an admitted native widget registration. It follows protected
PR183 preparation and preserves the separate foreground v1 contract. It does
not enable the producer, enroll an operator, implement an HTTP transport,
persist a credential in an extension, or demonstrate APNs delivery.

## Exact producer evidence

The original HTTP fixture remains byte-identical to protected Core73637899's
`examples/client_contracts/surface_push_v1/actual-ha-wire.json`, SHA256
`ec2ff50371f725f3d320fcdc3c388809a256c4913c6380a39ff0fc11033c2317`.
The actual Core exporter constructs SurfaceGrant from purpose.capability_id,
paired authority.binding and purpose.delegation_id. The read response returns
its exact registration coordinate separately. These domains are not equated:
registration.generation is transport generation; projection.generation is
original purpose delegation. The foreground grant's generation is not reused.

## Client admission

- Bootstrap requires the original foreground continuation, original install /
  owner epoch / Session / purpose / target / token witness and winning scoped
  background credential from its confirmed registration response. A cached
  status receipt, ordinary bearer or background-only first read cannot seed IDs.
- Capture original registration coordinate, credential and both request clocks
  before awaiting the one read. Recheck original authority, foreground bootstrap
  permission, both absolute grant deadlines, cancellation and local epoch after
  the await and after all synchronous callbacks before adopting a frame.
- Match the complete original registration ID, transport generation, revision,
  state, expiry, platform, role and no-store policy. Pin original server binding,
  purpose generation, Session, semantic sequence and digest only after success.
- Later reads require that pin. Lower sequences, changed bindings/generations,
  altered same-sequence content or changed transport coordinates retire it.
  An as_of-only duplicate retains the original frame and deadlines.
- Wall and monotonic frame/content expiry are anchored to pre-await clocks,
  capped by the original registration grant. Per-field expiry cannot hide behind
  a longer outer frame. Even a higher sequence cannot reanchor the same original
  frame expiry after wall-clock rollback.
- Shape/rights and current display eligibility remain distinct. An expired or
  stale projection is not displayed, but does not destroy the original longer
  registration; a later strictly qualified fresh sequence can update it without
  re-registration. No renewal-on-read or background bootstrap is introduced.
- Explicit withdrawal scrubs local scoped credential and pin synchronously. No
  late read or callback can resurrect them. Known connection failures can retain
  only the unchanged original pin/deadlines; there is no automatic read retry.
  Denial, malformed response, failed initial read and lost owner retire the pin.

The admission object and snapshots are RAM-only, with no credential in a
snapshot. The final extension/keychain transport and actual owner lifecycle
wiring remain required before operational use. Callers must supply their genuine
original authority and original foreground continuation; injected booleans and
test fixtures are never enrollment or consent evidence.

## Validation

Eighteen targeted test functions pass against the unchanged original producer
fixture and explicit synthetic read/clock boundaries. They cover first-read
binding, original generation domains, no background bootstrap, receipt changes,
late owner/foreground/cancellation/withdrawal, strict wall/monotonic equality,
original individual content expiry with lagging wall clock, duplicate semantics,
rebinding, regression, clock rollback, stale-to-fresh update under the same grant,
reentrant authority callbacks, concurrent reads and connection loss versus denial.
Original target output: `/private/tmp/apple-widget-read-pin-clock-pair-green-20261023.log`.
No HTTP, APNs, new ordinary app build, installation or physical rendering occurs.
The first full frozen source9ec suite passed1,224 tests /24 suites130.245s,
plus86 XCTest tests with five existing skips and zero failures. A later causal
clock-pair regression then found that wall-first clock sampling could extend
remaining time after scheduling between the samples. That original source fails
the new test with two issues. Monotonic-first capture passes the same test;
source9ec is superseded and its review approval must not be transplanted.
The corrected frozen7cadeb suite passed1,225 tests /24 suites130.933s,
plus86 XCTest tests with five existing skips and zero failures. Its original log
is `/private/tmp/apple-widget-read-pin-full-v2-tests-20261023.log`.
Exact independent source review and protected CI/delivery remain subsequent gates.
