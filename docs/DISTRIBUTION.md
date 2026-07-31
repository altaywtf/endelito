# Distribution

Endelito is a versioned artifact repo. It publishes macOS app and CLI assets through [GitHub Releases](https://github.com/uinaf/endelito/releases); it does not deploy a running service.

## Signed Package

Release assets are built by:

```sh
CODESIGN_IDENTITY='Developer ID Application: …' make package-release
```

The target runs `make build`, signs the app and CLI with hardened runtime and a secure timestamp, verifies both signatures, copies `build/Endelito.app`, `bin/endelito`, `VERSION`, and README/license material into `dist/Endelito/`, then creates `dist/endelito-<version>-macos-<arch>.zip`. Release publishing uses `make notarize-release`, which submits that archive to Apple's notary service, staples and validates the app ticket, and rebuilds the final archive.

The CLI binary embeds the release version from `VERSION`, so `bin/endelito --version` matches the semantic-release version when the archive is prepared. `make build-app` also stamps `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist` and replaces `__ENDELITO_VERSION__` in the bundled WebKit bridge.

## Homebrew Cask

Released versions are installable through the tap; see [README](../README.md#install) for the user-facing command.

The cask lives at `Casks/endelito.rb` in [uinaf/homebrew-tap](https://github.com/uinaf/homebrew-tap) and points at the GitHub Release zip through a `#{version}` URL template. It installs both `Endelito.app` and the `endelito` CLI. The release workflow bumps that cask after semantic-release publishes a new version.

## Continuous Release

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) contains both jobs:

- `verify` runs `make verify` on pushes and pull requests, except `[skip ci]` release commits, then runs `make smoke-live` to exercise CLI → URL scheme → app state on the macOS runner.
- `release` runs after `verify` on normal pushes to `main`.

Both jobs run on GitHub's `macos-latest` runner.

Semantic-release reads Conventional Commits on `main`. When a release is warranted, it:

1. Computes the next version using the `conventionalcommits` preset.
2. Writes the version to `VERSION`, imports the uinaf Developer ID identity into an ephemeral runner keychain, signs the app and CLI, notarizes the archive, staples the app ticket, and builds the final `dist/*.zip`.
3. Commits `VERSION` back to `main` with `chore(release): <version> [skip ci]`.
4. Creates a GitHub Release and uploads the zip asset from `dist/`.
5. Bumps the cask version and checksum in `uinaf/homebrew-tap` through Homebrew's `brew bump-cask-pr`, including Homebrew's cask audit and style checks before pushing the tap commit.

The `[skip ci]` release commit is intentional: both CI jobs skip it so publishing does not recursively trigger another verify and release run.

The release job allows up to 90 minutes for Apple's notarization queue before failing. Signing completes before submission; a notarization timeout is not an Apple rejection and remains visible in App Store Connect submission history.

## GitHub Policy

Keep GitHub configured for direct maintainer pushes plus automated release writeback:

- Default branch: `main`.
- Merge policy: squash merge only; delete branches after merge.
- Branch protection: required conversation resolution, no required status checks, no required pull request reviews, no push restrictions.
- Actions policy: selected actions only; allow GitHub-owned actions, verified actions, `cycjimmy/semantic-release-action@*`, and `Homebrew/actions/setup-homebrew@*`.
- Environment: the release job uses the approval-free `release` environment, restricted to workflow runs from `main`.
- Signing secrets: `APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64`, `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`, and `APPLE_NOTARY_API_KEY_P8`.
- Notarization variables: `APPLE_NOTARY_API_KEY_ID` and `APPLE_NOTARY_API_ISSUER_ID`.
- Tap secret: `TAP_GITHUB_TOKEN` is a fine-grained token with `contents: write` on `uinaf/homebrew-tap` only.

Do not add required status checks, pull-request reviews, push restrictions, or a PR-required ruleset unless the semantic-release writeback path is redesigned first.

## Workflow Maintenance

- Keep workflow actions pinned to full commit SHAs with same-line version comments.
- Keep semantic-release and plugins pinned in the workflow `extra_plugins` block rather than adding release-only Node dependencies to the repo.
- Keep the release job non-cancellable so a tag/release publish is not interrupted midway.
- Dependabot updates GitHub Actions through `.github/dependabot.yml`. Go has no third-party modules, so there is no `gomod` Dependabot ecosystem entry.
