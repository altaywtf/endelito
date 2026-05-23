# Distribution

Endelito is a versioned artifact repo. It publishes macOS app and CLI release assets through GitHub Releases; it does not deploy a running service.

## Local Package

Release assets are built by:

```sh
scripts/package-release.sh
```

The script runs `make build`, copies `build/Endelito.app`, `bin/endelito`, and README/license material into `dist/Endelito/`, then creates `dist/endelito-macos-<arch>.zip`.

## Continuous Release

`.github/workflows/ci.yml` contains both jobs:

- `verify` runs `make verify` on pushes and pull requests, except `[skip ci]` release commits.
- `release` runs after `verify` on normal pushes to `main`.

Semantic-release reads Conventional Commits on `main`. When a release is warranted, it:

1. Computes the next version using the `conventionalcommits` preset.
2. Writes the version to `VERSION` through `scripts/write-version.sh`.
3. Commits `VERSION` back to `main` with `chore(release): <version> [skip ci]`.
4. Creates a GitHub Release and uploads `dist/*.zip`.

The `[skip ci]` release commit is intentional: both CI jobs skip it so publishing does not recursively trigger another verify and release run.

## GitHub Policy

Keep GitHub configured for direct maintainer pushes plus automated release writeback:

- Default branch: `main`.
- Merge policy: squash merge only; delete branches after merge.
- Branch protection: required conversation resolution, no required status checks, no required pull request reviews, no push restrictions.
- Actions policy: selected actions only; allow GitHub-owned actions, verified actions, and `cycjimmy/semantic-release-action@*`.
- Environments: none for the current release path.

Do not add required status checks, pull-request reviews, push restrictions, or a PR-required ruleset unless the semantic-release writeback path is redesigned first.

## Workflow Maintenance

- Keep workflow actions pinned to full commit SHAs with same-line version comments.
- Keep semantic-release and plugins pinned in the workflow `extra_plugins` block rather than adding release-only Node dependencies to the repo.
- Keep the release job non-cancellable so a tag/release publish is not interrupted midway.
- Dependabot updates GitHub Actions and Go modules through `.github/dependabot.yml`.
