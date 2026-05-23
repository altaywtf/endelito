# Agent Guide

This repo is small. Keep the top level navigational and put implementation detail in `docs/`.

## Start Here

- [README](README.md) explains the user-facing shape and fastest build path.
- [Architecture](docs/ARCHITECTURE.md) explains the CLI, menu bar app, URL scheme, state file, and WebKit control model.
- [Contributing](CONTRIBUTING.md) lists local validation, release, and branch-policy expectations.
- [Security](SECURITY.md) covers reporting and privacy expectations.

## Repo Rules

- Keep Endelito focused on a menu bar WebKit player plus CLI control.
- Do not add Accessibility, global input monitoring, or system-wide event posting without an explicit design decision and user approval.
- Keep the player on `WKWebsiteDataStore.default()` so website login/session data persists across app restarts.
- Generated build outputs stay out of git: `bin/`, `build/`, and generated app resources.
- The WebKit compatibility bridge lives in [EndelitoBridge.js](app/Resources/EndelitoBridge.js); keep substantial page JavaScript out of Swift string literals.
- App icons are generated from [GenerateAssets.swift](tools/GenerateAssets.swift); update the generator rather than editing generated PNG or ICNS files.
- When changing commands, URL schemes, bundle IDs, state paths, or build targets, update README, Contributing, and Architecture in the same change.
- This is a release repo, not a deploy repo: GitHub Actions verifies normal pushes/PRs, and semantic-release publishes GitHub Releases from Conventional Commits on `main`.
- Keep `main` protected with required conversation resolution; do not add deploy environments for this release-only path.
- Semantic-release writes `VERSION` back to `main` with a `chore(release): ... [skip ci]` commit; do not add required status checks, pull-request reviews, or push restrictions unless that bump path is redesigned first.
- Dependabot tracks GitHub Actions and Go module updates through `.github/dependabot.yml`; keep action refs SHA-pinned with same-line version comments so update PRs can refresh them safely.
- Keep GitHub collaboration files boring: PRs use the repo template, security reports stay private through `SECURITY.md`, and issue templates should not duplicate policy docs.

## Verification

Use the repo guardrails before committing:

```sh
make verify
```

Use `make smoke-live` when a macOS GUI session is available and you need to prove the app launches and accepts CLI source/play/pause commands through the URL scheme.

Use `make doctor` for a quick local environment, build-artifact, process, and state-file snapshot before deeper debugging.
