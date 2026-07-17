# DJConnect App Management Summary

Status: iPad internal deployment consumer increment reviewable

## Decision

Complete the missing deployment and smoke consumer for the approved Platform
Release 3.3 iPad artifact binding, without changing release authorization or
product behavior.

## Scope and Outcome

The iPad consumer validates the exact central manifest binding and checksum,
requires one configured physical iPad and the local Apple Development signing
identity, strips the unsupported Watch companion before iPad signing, installs
only the iPad app, and verifies the exact installed application version after
deployment. All evidence is redacted. No workflow can dispatch without its
separate operational approval.

## Known Limitation

The iPad UDID is not configured yet as the protected
`DJCONNECT_APPLE_IPAD_UDID` environment secret. The iPad must be present with
Developer Mode enabled when a separately authorized dispatch occurs.

## Recommended Next Prompt

Review and merge PR #37. After it is merged and the environment is
configured, request an exact iPad deployment authorization; do not dispatch
until that authorization is supplied.
