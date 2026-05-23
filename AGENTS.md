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
- This is a release repo, not a deploy repo: GitHub Actions verifies every push/PR and semantic-release publishes GitHub Releases from Conventional Commits on `main`.
- Dependabot tracks GitHub Actions and Go module updates through `.github/dependabot.yml`; keep action refs SHA-pinned with same-line version comments so update PRs can refresh them safely.

## Verification

Use the repo guardrails before committing:

```sh
make verify
```

Use `make smoke-live` when a macOS GUI session is available and you need to prove the app launches and writes state.
