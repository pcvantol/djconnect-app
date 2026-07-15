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

Generation 2 Product Development: restore Apple release-version integrity.

This phase corrects Apple client version-source separation only. It does not
change protocol compatibility, deployment, release workflows or Home Assistant.

## Status

Reviewable; pending merge.

## Blocking Dependencies

- None identified before implementation reality verification.

## Current Prompt

Product Development: Restore Apple release-version integrity

## Completion Report

Repository-local implementation branch, commit, pull request and immutable
Prompt History record.

Review branch: `codex/restore-apple-release-version-integrity`.

Pull request: [#24](https://github.com/pcvantol/djconnect-app/pull/24).

## Last Qualification

Source and contract integrity tests passed. Unsigned macOS and watchOS builds
passed. The iOS scheme build is blocked by an existing duplicate-output project
configuration, recorded as deferred work rather than changed in this increment.

## Validated Base SHA

`adf60b14dab8b0a1bed8f74fa1d0fe394f281b62`

This value records the repository SHA inspected at the start of the
repository-local bootstrap alignment pass.

## Repository-Local Next Action

Review and merge this Apple release-version integrity pull request, then stop.

## Notes

Apple verification phases are governed by pcvantol/djconnect/PROMPT_INDEX.md; this repository prompt index must stay repository-local.
