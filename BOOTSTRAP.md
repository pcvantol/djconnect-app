# DJConnect App Repository Bootstrap

Status: canonical repository bootstrap

Repository: `pcvantol/djconnect-app`

## Purpose

This repository owns the Apple DJConnect client surfaces for iOS, iPadOS,
macOS and watchOS. It implements Apple presentation and runtime behaviour; it
does not redefine the DJConnect Platform Foundation.

## Required Synchronization

Before engineering work, synchronize the repository and verify that the
working tree is clean:

```sh
git switch main
git pull --ff-only
git status --short --branch
```

Confirm the checked-out branch, HEAD commit, upstream tracking branch,
fast-forward state and working-tree cleanliness. Stop and resolve repository
state if any of these checks fail.

## Canonical Reading Order

1. Read this document.
2. Read `AGENTS.md` for repository rules and ownership boundaries.
3. Read `CANONICAL_REFERENCES.md` for the platform, verification and Meta
   Engineering reference map.
4. Read `docs/governance/ADOPTION.md` for the local Version 2.2 adoption,
   lifecycle and hygiene contract.
5. Read `ENGINEERING_STATUS.md` for the current local engineering state.
5. Read `REPOSITORY_STATUS.md` for repository role, ownership and readiness.
6. Read `MANAGEMENT_SUMMARY.md` for the decision-level summary.
7. Read `ROADMAP_INDEX.md` for repository-local planning navigation.
8. Read `PROMPT_INDEX.md` for the active repository-local increment.
9. Read only the local implementation, test, build or release documentation
   relevant to the supplied prompt. Consult canonical platform documents only
   when the task requires them.

## Document Responsibilities

| Document | Responsibility |
| --- | --- |
| `ENGINEERING_STATUS.md` | Current engineering lifecycle state and qualification context. |
| `REPOSITORY_STATUS.md` | Repository purpose, ownership boundary and operational readiness. |
| `MANAGEMENT_SUMMARY.md` | Concise decision-level status for maintainers. |
| `ROADMAP_INDEX.md` | Repository-local planning entry point; it links to work without copying the platform roadmap. |
| `PROMPT_INDEX.md` | The single active repository-local prompt or its review/stop state. |
| `docs/governance/` | Apple Definition of Done plus native validation and release profile. |

## Planning and Verification Entry Points

Begin planning at `ROADMAP_INDEX.md`, then confirm the executable local
increment in `PROMPT_INDEX.md`. Before implementation, verify the documents in
the reading order above exist and describe a consistent repository state.

For engineering phases, follow the canonical completion protocol in
`pcvantol/djconnect/docs/meta/PHASE_COMPLETION_PROTOCOL.md`.

## Codex Compatibility Guidance

`BOOTSTRAP_CODEX_SESSION.md` is deprecated because it previously duplicated
this bootstrap. It remains only as a compatibility pointer for older Codex
instructions; it is not a second bootstrap entrypoint.

## Independence From Conversation History

All engineering prompts must be executable from repository documents and the
explicit prompt alone. Conversation history is never required.
