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

Commits on `main` use Conventional Commits. The CI workflow runs `make verify` for normal pushes and pull requests, then semantic-release creates GitHub Releases when commit history warrants a version. Release-only Node tooling is pinned in the workflow instead of committed as repo dependencies.

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
- Allow only GitHub-owned actions, verified actions, and the pinned `cycjimmy/semantic-release-action` workflow action.
- Semantic-release updates `VERSION` through `scripts/write-version.sh` and pushes `chore(release): <version> [skip ci]` to `main`; do not add required status checks, pull-request reviews, or push restrictions unless that bump path is redesigned first.
- Do not add deploy environments or deploy workflows for the app release path.
- Keep pull requests on the repo template and report vulnerabilities through `SECURITY.md` rather than public issues.

## Development Notes

- `ENDELITO_APP=/path/to/Endelito.app bin/endelito launch` overrides the app path the CLI opens.
- The app stores CLI-readable state at `~/Library/Application Support/Endelito/state.json`.
- `bin/endelito debug` writes page inspection data next to the state file.
- Build artifacts are ignored by git.
