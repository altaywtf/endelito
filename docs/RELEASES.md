# Releases

Pushes to `main` release automatically. Include `[skip ci]` in a commit
message to skip the `verify` and `release` jobs for that push (the push
itself still lands).

## Versioning

Conventional Commits drive the bump:

| Commit type | Release |
|---|---|
| `feat:` | minor |
| `fix:` / `perf:` / `refactor:` | patch |
| `feat!:` / breaking change | major |
| `docs:` / `test:` / `chore:` / `build:` / `ci:` | none |

## Pipeline

1. `verify` runs with read-only credentials
2. Protected `release` Environment imports Apple signing assets, then mints a
   short-lived `uinaf-releaser` installation token scoped to `endelito` +
   `homebrew-tap`
3. `semantic-release` signs/notarizes, commits `VERSION`, and creates the
   GitHub Release
4. The job remints a fresh App token, then Homebrew bumps
   `Casks/endelito.rb` on `uinaf/homebrew-tap`

Sources of truth: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml), [Distribution](DISTRIBUTION.md).

## Credentials

`release` Environment:

| Name | Kind |
|---|---|
| `UINAF_RELEASE_APP_CLIENT_ID` | variable |
| `UINAF_RELEASE_APP_PRIVATE_KEY` | secret |
| `APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64` | secret |
| `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD` | secret |
| `APPLE_NOTARY_API_KEY_P8` | secret |
| `APPLE_NOTARY_API_KEY_ID` | variable |
| `APPLE_NOTARY_API_ISSUER_ID` | variable |

## Checklist

Pre-merge (release Environment):

- [ ] `UINAF_RELEASE_APP_CLIENT_ID` is set
- [ ] `UINAF_RELEASE_APP_PRIVATE_KEY` is set

Post-merge (first real release after credential or workflow changes):

- [ ] Release commit / GitHub Release is attributed to `uinaf-releaser[bot]`
- [ ] `uinaf/homebrew-tap` `Casks/endelito.rb` bumps for the new version

## Recover a stuck publish

If notarization or signing succeeded but GitHub publish left a draft release or a
`v*` tag without assets:

1. Delete the draft GitHub Release if present.
2. Delete the orphan `v*` tag. `protect-release-tags` blocks normal deletes;
   `uinaf-releaser` can bypass, or a maintainer can briefly disable that ruleset.
3. Fix the failure (for asset upload on Node 24, keep
   `@semantic-release/github` at `12.0.9` or newer).
4. Push a releasable Conventional Commit to `main` so the pipeline republishes.
