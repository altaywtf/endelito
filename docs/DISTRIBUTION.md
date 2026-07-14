# Distribution

Endelito is a versioned artifact repo. It publishes macOS app and CLI release assets through GitHub Releases; it does not deploy a running service.

## Local Package

Release assets are built by:

```sh
make package-release
```

The target runs `make build`, copies `build/Endelito.app`, `bin/endelito`, `VERSION`, and README/license material into `dist/Endelito/`, then creates `dist/endelito-<version>-macos-<arch>.zip`.

The CLI binary embeds the release version from `VERSION`, so `bin/endelito --version` matches the semantic-release version when the archive is prepared. `make build-app` also stamps `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist` and replaces `__ENDELITO_VERSION__` in the bundled WebKit bridge.

## Homebrew Cask

Released versions are installable through the tap; see [README](../README.md#install) for the user-facing command.

The cask lives at `Casks/endelito.rb` in `altaywtf/homebrew-tap` and points at the GitHub Release zip through a `#{version}` URL template. It installs both `Endelito.app` and the `endelito` CLI. The release workflow bumps that cask after semantic-release publishes a new version.

## Continuous Release

`.github/workflows/ci.yml` contains both jobs:

- `verify` runs `make verify` on pushes and pull requests, except `[skip ci]` release commits, then runs `make smoke-live` to exercise CLI → URL scheme → app state on the macOS runner.
- `release` runs after `verify` on normal pushes to `main`.

Both jobs run on GitHub's `macos-latest` runner.

Semantic-release reads Conventional Commits on `main`. When a release is warranted, it:

1. Computes the next version using the `conventionalcommits` preset.
2. Writes the version to `VERSION` and builds `dist/*.zip`.
3. Commits `VERSION` back to `main` with `chore(release): <version> [skip ci]`.
4. Creates a GitHub Release and uploads the zip asset from `dist/`.
5. Bumps the cask version and checksum in `altaywtf/homebrew-tap` through Homebrew's `brew bump-cask-pr`, including Homebrew's cask audit and style checks before pushing the tap commit.

The `[skip ci]` release commit is intentional: both CI jobs skip it so publishing does not recursively trigger another verify and release run.

## GitHub Policy

Keep GitHub configured for direct maintainer pushes plus automated release writeback:

- Default branch: `main`.
- Merge policy: squash merge only; delete branches after merge.
- Branch protection: required conversation resolution, no required status checks, no required pull request reviews, no push restrictions.
- Actions policy: selected actions only; allow GitHub-owned actions, verified actions, `cycjimmy/semantic-release-action@*`, and `Homebrew/actions/setup-homebrew@*`.
- Secrets: `TAP_GITHUB_TOKEN` is a tap-scoped fine-grained token with `contents: write` on `altaywtf/homebrew-tap`.

Do not add required status checks, pull-request reviews, push restrictions, or a PR-required ruleset unless the semantic-release writeback path is redesigned first.

## Workflow Maintenance

- Keep workflow actions pinned to full commit SHAs with same-line version comments.
- Keep semantic-release and plugins pinned in the workflow `extra_plugins` block rather than adding release-only Node dependencies to the repo.
- Keep the release job non-cancellable so a tag/release publish is not interrupted midway.
- Dependabot updates GitHub Actions and Go modules through `.github/dependabot.yml`.
