# Contributing

## Requirements

- macOS
- Go 1.26 or newer
- Node.js for bridge syntax checks
- Xcode command line tools with `swift`, `xcrun`, `iconutil`, and `codesign`

## Build

```sh
make build
```

See [README](README.md) for user-facing CLI commands and [Architecture](docs/ARCHITECTURE.md) for the app, state file, URL scheme, and WebKit session model.

## Validate

Run these before pushing:

```sh
make verify
```

For UI changes, also launch the app and check the real state path:

```sh
make smoke-live
```

For environment and runtime diagnostics:

```sh
make doctor
```

## Release

Use Conventional Commits. See [Distribution](docs/DISTRIBUTION.md) for release workflow, Homebrew cask, GitHub settings, and branch-policy expectations.

## Pull Requests

- Use the repo pull request template.
- Include meaningful verification in the PR description.
- Keep vulnerability reports out of public issues; use [Security](SECURITY.md).

## Development Notes

- `ENDELITO_APP=/path/to/Endelito.app bin/endelito launch` overrides the app path the CLI opens.
- The app stores CLI-readable state at `~/Library/Application Support/Endelito/state.json`.
- `bin/endelito debug` writes page inspection data next to the state file.
- Build artifacts are ignored by git.
