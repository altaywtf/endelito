# Agent Guide

This repo is small. Keep the top level navigational and put implementation detail in `docs/`.

## Start Here

- [README](README.md) explains the user-facing shape and fastest build path.
- [Architecture](docs/ARCHITECTURE.md) explains the CLI, menu bar app, URL scheme, state file, and WebKit control model.
- [Distribution](docs/DISTRIBUTION.md) explains CI, release, and GitHub policy.
- [Contributing](CONTRIBUTING.md) lists local validation and PR expectations.
- [Security](SECURITY.md) covers reporting and privacy expectations.

## Repo Rules

- Keep Endelito focused on a menu bar WebKit player plus CLI control.
- Do not add Accessibility, global input monitoring, or system-wide event posting without an explicit design decision and user approval.
- Keep the player on `WKWebsiteDataStore.default()` so website login/session data persists across app restarts.
- Generated build outputs stay out of git: `bin/`, `build/`, and generated app resources.
- The WebKit compatibility bridge lives in [EndelitoBridge.js](app/Resources/EndelitoBridge.js); keep substantial page JavaScript out of Swift string literals.
- Known soundscapes live in [sources.json](internal/sources/sources.json); update that catalog instead of duplicating lists in Go or Swift.
- App icons are generated from [GenerateAssets.swift](tools/GenerateAssets.swift); update the generator rather than editing generated PNG or ICNS files.
- When changing commands, URL schemes, bundle IDs, state paths, or build targets, update README, Contributing, and Architecture in the same change.
- Local installs use `make install` (`/Applications/Endelito.app` + `$(PREFIX)/bin/endelito`); keep CLI app discovery in sync when install paths change.
- This is a release repo, not a deploy repo; keep GitHub policy details in [Distribution](docs/DISTRIBUTION.md), not repeated across docs.
- Dependabot tracks GitHub Actions updates through `.github/dependabot.yml`; keep action refs SHA-pinned with same-line version comments so update PRs can refresh them safely. Go has no third-party modules, so Dependabot does not watch `gomod`.
- Keep GitHub collaboration files boring: PRs use the repo template, security reports stay private through `SECURITY.md`, and issue templates should not duplicate policy docs.

## Verification

Use the repo guardrails before committing:

```sh
make verify
```

Use `make smoke-live` when a macOS GUI session is available and you need to prove the app launches and accepts CLI source/play/pause commands through the URL scheme.

Use `make doctor` for a quick local environment, build-artifact, process, and state-file snapshot before deeper debugging.
