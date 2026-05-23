# Agent Guide

This repo is small. Keep the top level navigational and put implementation detail in `docs/`.

## Start Here

- [README](README.md) explains the user-facing shape and fastest build path.
- [Architecture](docs/ARCHITECTURE.md) explains the CLI, menu bar app, URL scheme, state file, and WebKit control model.
- [Contributing](CONTRIBUTING.md) lists local validation commands.
- [Security](SECURITY.md) covers reporting and privacy expectations.

## Repo Rules

- Keep Endelito focused on a menu bar WebKit player plus CLI control.
- Do not add Accessibility, global input monitoring, or system-wide event posting without an explicit design decision and user approval.
- Keep the player on `WKWebsiteDataStore.default()` so website login/session data persists across app restarts.
- Generated build outputs stay out of git: `bin/`, `build/`, and generated app resources.
- App icons are generated from [GenerateAssets.swift](tools/GenerateAssets.swift); update the generator rather than editing generated PNG or ICNS files.
- When changing commands, URL schemes, bundle IDs, state paths, or build targets, update README, Contributing, and Architecture in the same change.

## Verification

Use the repo guardrails before committing:

```sh
go test ./...
make build-cli
make build-app
```
