# DJConnect Repository Status

Status: Active engineering repository

## Repository

`pcvantol/djconnect-app`

## Role

Apple Intelligence Client UX for iOS, iPadOS, macOS and watchOS.

## Ownership

Owns: Apple client implementation, Apple presentation/runtime behavior and localized rendering for Apple surfaces.

Does not own: backend intelligence, Music DNA storage, Spotify OAuth secrets, central relay logic, canonical Profile resolution or foundation docs.

## Current Phase

macOS runner CI-tooling maintenance automation.

This phase creates a user-level launchd task that updates installed Homebrew
CI tooling and records Apple toolchain versions. It does not change project
architecture, product behaviour, release, signing or protocol compatibility.

## Status

Reviewable.

## Blocking Dependencies

- The maintenance installer must run once as the logged-in Apple runner user.
- Xcode updates remain a separately qualified Apple toolchain operation.

## Current Prompt

macOS runner CI-tooling maintenance automation

## Completion Report

Repository-local implementation branch, commit, pull request and immutable
Prompt History record.

`docs/MACOS_RUNNER_CI_TOOLING_MAINTENANCE.md` and immutable Prompt History.

## Last Qualification

PR #27 is merged. The maintenance scripts pass shell syntax validation and
their launchd configuration is statically verified. Live runner maintenance is
pending the one-time user-level installation after merge.

## Validated Base SHA

`cd9fde94144fdf97f5e3a71a698b0a2fd0e3b010`

The completion record captures the exact implementation commit.

## Repository-Local Next Action

Review and merge the maintenance PR. Then install and verify the launchd task
as the Apple runner user; do not update Xcode unattended.

## Notes

Apple verification phases are governed by pcvantol/djconnect/PROMPT_INDEX.md; this repository prompt index must stay repository-local.
