# Distribution

Endelito publishes its macOS app through
[GitHub Releases](https://github.com/altaywtf/endelito/releases).
GitHub ownership is independent of the Apple Developer team: releases retain
Developer ID signing and notarization by undefined is not a function LLC.

The `uinaf-ci` GitHub App must be installed for `altaywtf/endelito`.
The workflow scopes its installation token to the repository owner and this
repository only. The Apple certificate, notarization key, and Developer team
remain unchanged by the GitHub transfer.

## Signed package

```sh
CODESIGN_IDENTITY='Developer ID Application: …' make package-release
```

[Makefile](../Makefile) builds and signs the app with hardened runtime and a
secure timestamp, verifies its signature, then packages the app, version,
README, and license in a versioned zip. `make notarize-release` submits the
archive to Apple, staples and validates the ticket, and rebuilds the zip.

## Continuous release

[ci.yml](../.github/workflows/ci.yml) runs `make verify` on macOS, then evaluates
Conventional Commits on pushes to `main`. Semantic-release writes `VERSION`
through a signed App commit, builds and notarizes the app, and uploads a draft
release. The workflow validates the asset manifest before publishing and
verifying the immutable-release attestation.

The `[skip ci]` version commit prevents recursive releases. Notarization can
wait up to 90 minutes; timeout is not an Apple rejection. See
[Releases](RELEASES.md) for recovery.

## GitHub Policy

Keep GitHub configured for direct maintainer pushes plus automated release
writeback:

- Default branch: `main`.
- Merge policy: squash merge only; delete branches after merge.
- Ruleset `default-branch-baseline` on the default branch: block deletion and
  non-fast-forward updates; require signed commits without a release App bypass.
- Ruleset `protect-release-tags` on `refs/tags/v*`: block tag deletion and
  updates; require signed tags. `uinaf-ci` may bypass.
- The required `verify` check, which ends with the push-time scan, uses a
  separate non-strict ruleset.
  Admins and `uinaf-ci` bypass only this check rule, preserving signed
  release-version writeback. Renovate has no bypass.
- Actions policy: all actions are allowed; full commit SHA pins are enforced.
- Environment: the release job uses the approval-free `release` environment,
  restricted to workflow runs from `main`.
- GitHub writes: short-lived `uinaf-ci` installation token
  (`UINAF_CI_APP_CLIENT_ID` + `UINAF_CI_APP_PRIVATE_KEY`) scoped to
  `endelito`.
- Signing secrets: `APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64`,
  `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`, and `APPLE_NOTARY_API_KEY_P8`.
- Notarization variables: `APPLE_NOTARY_API_KEY_ID` and
  `APPLE_NOTARY_API_ISSUER_ID`.

See [Releases](RELEASES.md) for the publish contract. Keep its signed writeback
path working when changing repository rules.

## Workflow Maintenance

- Keep workflow actions and the shared scan action pinned to full commit SHAs
  with same-line version comments. The [personal Renovate preset](https://github.com/altaywtf/.github/blob/main/renovate-config.json)
  updates `uinaf/.github` pins along with other Actions dependencies.
- Keep semantic-release and plugins pinned in the workflow `extra_plugins`
  block rather than adding release-only Node dependencies to the repo.
- Keep `@semantic-release/github` at `12.0.9` or newer so Node 24 runners can
  upload release assets.
- Keep the release job non-cancellable so a tag/release publish is not
  interrupted midway.
- Keep immutable releases enabled. Upload and validation must finish against a
  mutable draft before publication.
- Renovate updates GitHub Actions and mise tools through `renovate.json`,
  which extends the shared `altaywtf/.github:renovate-config` preset.
