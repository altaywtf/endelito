# Agent Guide

This repo is small. Keep the top level navigational and put implementation
detail in `docs/`.

## Start Here

- [README](README.md): product shape and installation
- [Contributing](CONTRIBUTING.md): setup, verify, pull requests
- [Architecture](docs/ARCHITECTURE.md): control model, catalog, WebKit bridge
- [Release runbook](https://app.notion.com/p/3e5e75710b5281999cc8c6a31e5a9e5c) (Notion, Endelito releases): publish path,
  recovery, signing, and GitHub policy
- [Security](https://github.com/altaywtf/.github/blob/main/SECURITY.md): private vulnerability reporting

## Hard rules

- Stay a menu bar WebKit player; do not expand into a full desktop
  clone.
- Do not add Accessibility, global input monitoring, or system-wide event
  posting without an explicit design decision and user approval.
- Keep the player on `WKWebsiteDataStore.default()` so website login/session
  data persists across app restarts.
- Keep generated build outputs out of git (`build/`, generated app
  resources).
- Keep substantial page JavaScript in
  [EndelitoBridge.js](app/Resources/EndelitoBridge.js), not Swift string
  literals.
- When changing menu controls, bundle IDs, state paths, or build
  targets, update README, Contributing, and Architecture in the same change.
- When changing signing, notarization, release credentials, workflow pins, or
  GitHub release policy, update the release runbook in the same change.

## Verification

```sh
mise run verify
```

This skips unchanged sources after a successful result. Use
`mise run --force verify` for an explicit full pass. `make verify` remains the
exhaustive underlying repository gate. Docs-only changes need no build or UI
check.

For UI changes, follow [the native menu checks](CONTRIBUTING.md#validate).
Run one app copy at a time; checkouts share its bundle ID and website storage.

Use `make doctor` for a quick local environment, build-artifact, process, and
state-file snapshot before deeper debugging.

## Delivery

Maintainers push to `main` directly or squash-merge a PR. Every push to `main`
runs `verify`, then the release job: `feat`, `fix`, `perf`, `revert` and
breaking commits publish a signed, notarized GitHub Release; other types
publish nothing. `[skip ci]` skips both jobs. Published `v*` tags and releases
are immutable; to recover a failed publish, fix the cause and rerun the failed
workflow.

Release workflow invariants:

- Pin actions and the shared scan action to full commit SHAs with same-line
  version comments.
- Pin semantic-release and its plugins in the workflow's `extra_plugins`
  block, not as repository Node dependencies; keep `@semantic-release/github`
  at `12.0.9` or newer so Node 24 runners can upload assets.
- Keep the release job non-cancellable and on the run's own commit, not
  `ref: main`.
- Upload and validate against a mutable draft before publishing.

## Repository skills

- Use [Swift concurrency](.agents/skills/swift-concurrency/SKILL.md) for tasks, actor isolation, Sendable, and callback-to-async changes.
