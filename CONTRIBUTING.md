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

Outputs:

- `bin/endelito`
- `build/Endelito.app`

## Run

```sh
bin/endelito launch
bin/endelito show
bin/endelito status
bin/endelito sources
bin/endelito source focus
```

Use `show` to open the WebView for sign-in or manual player selection. Use `sources` to list known source IDs, then use `source <id-or-name>` or `play <id-or-name>` to target one of Endel's source icons. The app persists website session data through WebKit's default data store.

Do not replace the player data store with `.nonPersistent()` or a per-launch custom store. Login persistence is expected behavior.

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

Use Conventional Commits. Pushes to `main` publish through semantic-release when commit history warrants a version.

The Homebrew formula lives in `altaywtf/homebrew-tap` and is bumped after GitHub Release publishing. See [Distribution](docs/DISTRIBUTION.md) for the release workflow, GitHub settings, and branch-policy expectations.

## Pull Requests

- Use the repo pull request template.
- Include meaningful verification in the PR description.
- Keep vulnerability reports out of public issues; use [Security](SECURITY.md).

## Development Notes

- `ENDELITO_APP=/path/to/Endelito.app bin/endelito launch` overrides the app path the CLI opens.
- The app stores CLI-readable state at `~/Library/Application Support/Endelito/state.json`.
- `bin/endelito debug` writes page inspection data next to the state file.
- Build artifacts are ignored by git.
