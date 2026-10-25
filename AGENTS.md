# Agent Guide

- [Contributing](CONTRIBUTING.md): build, verify, UI checks, and invariants.
  The security-review invariant needs user approval.
- [Release runbook](https://app.notion.com/p/3e5e75710b5281999cc8c6a31e5a9e5c) (Notion, Endelito releases): publish path,
  recovery, signing, and GitHub policy.
- [Security](https://github.com/altaywtf/.github/blob/main/SECURITY.md): private vulnerability reporting.

## Rules

- When changing menu controls, bundle IDs, state paths, or build targets,
  update README and Contributing in the same change.
- When changing signing, notarization, release credentials, workflow pins, or
  GitHub release policy, update the release runbook in the same change.

## Verification

`mise run verify`; `mise run --force verify` never skips. Docs-only changes
need no build or UI check. UI changes need
[the menu checks](CONTRIBUTING.md#validate). `make doctor` snapshots the
environment, build, processes, and state files for debugging.

## Delivery

Push to `main` or squash-merge a PR. On `main`, `feat`, `fix`, `perf`,
`revert` and breaking commits publish a signed, notarized GitHub Release;
`[skip ci]` skips CI. `v*` tags and releases are immutable: to recover a failed
publish, fix the cause and rerun the failed workflow.

Release workflow invariants:

- Pin actions and the shared scan action to full commit SHAs with same-line
  version comments.
- Pin semantic-release and its plugins in the workflow's `extra_plugins`
  block; keep `@semantic-release/github` at `12.0.9` or newer so Node 24
  runners can upload assets.
- Keep the release job non-cancellable and on the run's own commit.
- Upload and validate against a mutable draft before publishing.

## Repository skills

- Use [Swift concurrency](.agents/skills/swift-concurrency/SKILL.md) for tasks, actor isolation, Sendable, and callback-to-async changes.
