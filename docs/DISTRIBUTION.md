# Distribution

Endelito publishes versioned macOS app and CLI assets through
[GitHub Releases](https://github.com/uinaf/endelito/releases) and the
[uinaf Homebrew tap](https://github.com/uinaf/homebrew-tap). It does not deploy
a running service.

Channel: Developer ID–signed, Apple-notarized zip. Do not add Mac App Store
packaging without an explicit product decision.

## Signed Package

Release assets are built by:

```sh
CODESIGN_IDENTITY='Developer ID Application: …' make package-release
```

The target runs `make build`, signs the app and CLI with hardened runtime and a
secure timestamp, verifies both signatures, copies `build/Endelito.app`,
`bin/endelito`, `VERSION`, and README/license material into `dist/Endelito/`,
then creates `dist/endelito-<version>-macos-<arch>.zip`. Release publishing uses
`make notarize-release`, which submits that archive to Apple's notary service,
staples and validates the app ticket, and rebuilds the final archive.

The CLI binary embeds the release version from `VERSION`, so
`bin/endelito --version` matches the semantic-release version when the archive
is prepared. `make build-app` also stamps `CFBundleShortVersionString` /
`CFBundleVersion` in `Info.plist` and replaces `__ENDELITO_VERSION__` in the
bundled WebKit bridge.

## Homebrew Cask

Released versions are installable through the tap; see
[README](../README.md#install) for the user-facing command.

The cask lives at `Casks/endelito.rb` in
[uinaf/homebrew-tap](https://github.com/uinaf/homebrew-tap) and points at the
GitHub Release zip through a `#{version}` URL template. It installs both
`Endelito.app` and the `endelito` CLI. The release workflow bumps that cask
only after GitHub verifies the published immutable release.

## Continuous Release

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) contains both jobs:

- `verify` runs `make verify` on pushes and pull requests, except
  `[skip ci]` release commits, then runs `make smoke-live` to exercise
  CLI → URL scheme → app state on the macOS runner.
- `release` runs after `verify` on normal pushes to `main`.

Both jobs run on GitHub's `macos-latest` runner.

Semantic-release reads Conventional Commits on `main`. When a release is
warranted, it:

1. Computes the next version using the `conventionalcommits` preset.
2. Writes the version to `VERSION`, imports the uinaf Developer ID identity into
   an ephemeral runner keychain, signs the app and CLI, notarizes the archive,
   staples the app ticket, and builds the final `dist/*.zip`.
3. Commits `VERSION` back to `main` with `chore(release): <version> [skip ci]`.
4. Creates a draft GitHub Release and uploads the zip asset from `dist/`.
5. Validates the draft manifest, publishes the release once, and verifies its
   immutable-release attestation.
6. Bumps the cask version and checksum in `uinaf/homebrew-tap` through
   Homebrew's `brew bump-cask-pr`, including Homebrew's cask audit and style
   checks before pushing the tap commit.

The `[skip ci]` release commit is intentional: both CI jobs skip it so
publishing does not recursively trigger another verify and release run.

The release job allows up to 90 minutes for Apple's notarization queue before
failing. Signing completes before submission; a notarization timeout is not an
Apple rejection and remains visible in App Store Connect submission history.

## GitHub Policy

Keep GitHub configured for direct maintainer pushes plus automated release
writeback:

- Default branch: `main`.
- Merge policy: squash merge only; delete branches after merge.
- Ruleset `protect-main` on the default branch: block deletion and
  non-fast-forward updates; require signed commits. `uinaf-releaser` may bypass.
- Ruleset `protect-release-tags` on `refs/tags/v*`: block tag deletion and
  updates; require signed tags. `uinaf-releaser` may bypass.
- No required status checks, pull-request reviews, or push restrictions that
  would block semantic-release writeback to `main`.
- Actions policy: selected actions only; allow GitHub-owned actions, verified
  actions, `actions/create-github-app-token@*`,
  `cycjimmy/semantic-release-action@*`, and
  `Homebrew/actions/setup-homebrew@*`.
- Environment: the release job uses the approval-free `release` environment,
  restricted to workflow runs from `main`.
- GitHub writes: short-lived `uinaf-releaser` installation token
  (`UINAF_RELEASE_APP_CLIENT_ID` + `UINAF_RELEASE_APP_PRIVATE_KEY`) scoped to
  `endelito` + `homebrew-tap`.
- Signing secrets: `APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64`,
  `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`, and `APPLE_NOTARY_API_KEY_P8`.
- Notarization variables: `APPLE_NOTARY_API_KEY_ID` and
  `APPLE_NOTARY_API_ISSUER_ID`.

See [Releases](RELEASES.md) for the publish contract. Do not add required status
checks, pull-request reviews, push restrictions, or a PR-required ruleset unless
the semantic-release writeback path is redesigned first.

## Workflow Maintenance

- Keep workflow actions pinned to full commit SHAs with same-line version
  comments.
- Keep semantic-release and plugins pinned in the workflow `extra_plugins`
  block rather than adding release-only Node dependencies to the repo.
- Keep `@semantic-release/github` at `12.0.9` or newer so Node 24 runners can
  upload release assets.
- Keep the release job non-cancellable so a tag/release publish is not
  interrupted midway.
- Keep immutable releases enabled. Upload and validation must finish against a
  mutable draft; the Homebrew update starts only after publication succeeds.
- Dependabot updates GitHub Actions through `.github/dependabot.yml`. Go has no
  third-party modules, so there is no `gomod` Dependabot ecosystem entry.
