# Agent Guide

This repo is small. Keep the top level navigational and put implementation detail in `docs/`.

## Start Here

- [README](README.md) — product shape, build, install, CLI usage
- [Architecture](docs/ARCHITECTURE.md) — control model, catalog, install paths, WebKit bridge
- [Distribution](docs/DISTRIBUTION.md) — CI, release, Homebrew, GitHub policy
- [Contributing](CONTRIBUTING.md) — local validation and PR expectations
- [Security](SECURITY.md) — reporting and privacy expectations

## Hard rules

- Stay a menu bar WebKit player plus CLI; do not expand into a full desktop clone.
- Do not add Accessibility, global input monitoring, or system-wide event posting without an explicit design decision and user approval.
- Keep the player on `WKWebsiteDataStore.default()` so website login/session data persists across app restarts.
- Keep generated build outputs out of git (`bin/`, `build/`, generated app resources).
- Keep substantial page JavaScript in [EndelitoBridge.js](app/Resources/EndelitoBridge.js), not Swift string literals.
- When changing commands, URL schemes, bundle IDs, state paths, or build targets, update README, Contributing, and Architecture in the same change.

## Verification

```sh
make verify
```

Use `make smoke-live` when a macOS GUI session is available and you need to prove the app launches and accepts CLI source/play/pause commands through the URL scheme.

Use `make doctor` for a quick local environment, build-artifact, process, and state-file snapshot before deeper debugging.
