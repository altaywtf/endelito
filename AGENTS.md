# Agent Guide

[Contributing](CONTRIBUTING.md) covers build, verify, UI checks, and
invariants. The security-review invariant needs user approval.

## Rules

- When changing menu controls, bundle IDs, state paths, or build targets,
  update README and Contributing in the same change.

## Verification

`mise run verify`; `mise run --force verify` never skips. Docs-only changes
need no build or UI check. UI changes need
[the menu checks](CONTRIBUTING.md#validate). `make doctor` snapshots the
environment, build, processes, and state files for debugging.

## Delivery

Push to `main` or squash-merge a PR; [CI](.github/workflows/ci.yml) and
[.releaserc.json](.releaserc.json) decide what publishes. `v*` tags and
releases are immutable: to recover a failed publish, fix the cause and rerun
the failed workflow.

In the release job, keep `cancel-in-progress: false`, the draft-first upload,
and `@semantic-release/github` at `12.0.9` or newer: older versions fail asset
uploads on Node 24 runners.
