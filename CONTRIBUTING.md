# Contributing

## Requirements

- macOS
- Go 1.26 or newer
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
```

Use `show` to open the WebView for sign-in or manual player selection. The app persists website session data through WebKit's default data store.

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

## Release

Commits on `main` use Conventional Commits. The CI workflow runs `make verify` and then semantic-release creates GitHub Releases when commit history warrants a version. Release-only Node tooling is pinned in the workflow instead of committed as repo dependencies.

Dependabot checks GitHub Actions and Go modules weekly. Keep workflow actions pinned to full commit SHAs with same-line version comments.

Release assets are built by:

```sh
scripts/package-release.sh
```

## GitHub Settings

This repo is a release repo, not a deploy repo. Keep GitHub configured so the release workflow can publish from `main`:

- Allow squash merge only.
- Delete branches after merge.
- Protect `main` with required conversation resolution.
- Do not add required status checks, pull-request reviews, or push restrictions unless the semantic-release bump commit path is updated at the same time.
- Do not add deploy environments or deploy workflows for the app release path.

## Development Notes

- `ENDELITO_APP=/path/to/Endelito.app bin/endelito launch` overrides the app path the CLI opens.
- The app stores CLI-readable state at `~/Library/Application Support/Endelito/state.json`.
- `bin/endelito debug` writes page inspection data next to the state file.
- Build artifacts are ignored by git.
