# DJConnect App Engineering Status

Status: iPad internal deployment consumer increment reviewable

Repository: `pcvantol/djconnect-app`

## Current Engineering State

The macOS runner CI-tooling maintenance increments are merged into `main`
(most recently PR #36). The active bounded increment adds the missing
manifest-bound iPad internal deployment consumer and its post-deployment smoke
consumer for Platform Release 3.3. It does not dispatch a deployment, modify a
release manifest, publish an artifact, or change Apple product behavior.

## Qualification Context

- The Apple Release Version Integrity and Build Engineering qualifications are
  merged.
- The iPhone + paired Watch consumer is qualified; the iPad artifact binding
  exists in the approved central manifest, but no iPad consumer previously
  existed.
- The active work validates the iPad physical-device scope, manifest binding,
  checksum, local Apple Development signing, installed version, and redacted
  deployment/smoke evidence.

## Current Decision

The iPad is a standalone Apple target. Its consumer must not inherit paired
Watch validation or signing. It removes the embedded Watch companion before
local iPad-profile signing, validates the installed iPad application version,
and fails closed if the central binding changes to require Watch validation.

Decision: `IPAD_INTERNAL_DEPLOYMENT_CONSUMER_REVIEWABLE`.
Stop after the reviewable pull request; do not begin a deployment or a
subsequent increment automatically.

## Planning Entry Point

Read `ROADMAP_INDEX.md`, then `PROMPT_INDEX.md`.
