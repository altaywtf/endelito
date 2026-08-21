# Contributing

## Requirements

- macOS
- Mise
- Go 1.26 or newer
- Node.js for bridge syntax and contract checks
- Xcode command line tools with `swift`, `xcrun`, `iconutil`, and `codesign`

## Build

```sh
make build
```

Install into Applications and PATH:

```sh
make install
```

See [README](README.md) for user-facing CLI commands and [Architecture](docs/ARCHITECTURE.md) for the app, state file, URL scheme, and WebKit session model.

## Validate

Run these before pushing:

```sh
mise run verify
mise run --force verify # explicitly run the exhaustive gate
```

For UI changes, also launch the app and check the real state path:

```sh
make smoke-live
```

The live target runs the exhaustive gate first and reuses its app and CLI
artifacts for the launch proof.

For environment and runtime diagnostics:

```sh
make doctor
```

## Releases

Use Conventional Commits (`feat:`, `fix:`, `docs:`, …); they drive versions.

Successful pushes to `main` evaluate commits after `verify` passes. The release
job mints a short-lived `uinaf-releaser` token inside the `release` Environment,
signs/notarizes, creates the GitHub Release, and updates the Homebrew cask. See
[Releases](docs/RELEASES.md) and [Distribution](docs/DISTRIBUTION.md).

## Pull Requests

- Create a focused branch from current `main` and open a pull request against `main`.
- Use the repo pull request template.
- Include meaningful verification in the PR description.
- Include the review aid that best explains a non-trivial change: a focused diagram, labeled screenshot, or sanitized input/output example.
- Keep vulnerability reports out of public issues; use [Security](SECURITY.md).

## Development Notes

- `ENDELITO_APP=/path/to/Endelito.app endelito launch` overrides the app path the CLI opens.
- The app stores CLI-readable state at `~/Library/Application Support/Endelito/state.json`.
- `bin/endelito debug` writes page inspection data next to the state file.
- Soundscape IDs and aliases live in `internal/sources/sources.json`; update that catalog instead of duplicating lists in Go or Swift.
- Build artifacts are ignored by git.
