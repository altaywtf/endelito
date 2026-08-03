# Releases

Pushes to `main` release automatically. Skip a push with `[skip ci]`.

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
2. Protected `release` Environment mints a short-lived `uinaf-releaser` installation token scoped to `endelito` + `homebrew-tap`
3. `semantic-release` signs/notarizes, commits `VERSION`, and creates the GitHub Release
4. Homebrew bumps `Casks/endelito.rb` on `uinaf/homebrew-tap`

Sources of truth: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml), [Distribution](DISTRIBUTION.md).

## Credentials

`release` Environment:

| Name | Kind |
|---|---|
| `UINAF_RELEASE_APP_ID` | variable |
| `UINAF_RELEASE_APP_PRIVATE_KEY` | secret |
| `APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64` | secret |
| `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD` | secret |
| `APPLE_NOTARY_API_KEY_P8` | secret |
| `APPLE_NOTARY_API_KEY_ID` | variable |
| `APPLE_NOTARY_API_ISSUER_ID` | variable |
