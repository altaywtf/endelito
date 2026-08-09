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
3. `semantic-release` signs/notarizes, commits `VERSION` through GitHub's signed
   App commit API, then creates the version tag and a mutable draft GitHub
   Release containing the notarized zip
4. The workflow validates the draft asset manifest, publishes it once, and
   verifies GitHub's immutable-release attestation
5. The job remints a fresh App token, then Homebrew bumps
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

If notarization, upload, or publication fails after the tag exists, fix the
underlying failure and rerun the failed workflow. The workflow discovers the
single mutable draft on `main`, validates its asset manifest, and publishes it
without choosing a new version. If publication succeeded and only the Homebrew
update failed, the rerun skips release mutation and resumes at the tap update.

Never delete or move a published `v*` tag. Published releases and their assets
are immutable; only an unpublished draft may be repaired or deleted.
