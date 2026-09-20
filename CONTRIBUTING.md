# Contributing

## Requirements

- macOS 13 or later
- Node.js for bridge and catalog checks
- Xcode command line tools (`swift`, `xcrun`, `iconutil`, `codesign`)
- Mise for cached verification (optional)

## Build

```sh
make build
make install
```

The app is built in `build/Endelito.app`; installation copies it to Applications.
See [Architecture](docs/ARCHITECTURE.md) for playback and WebKit session behavior.

## Validate

```sh
make verify
```

The gate checks JavaScript syntax, bridge contracts, deterministic Swift
playback intent, the source catalog, and the built app's resources, version,
menu-bar identity, and signature. `mise run verify` caches successful results;
`mise run --force verify` runs the full gate.

For UI changes, open `build/Endelito.app` and check its menu bar item:

1. Choose **Show Player** and sign in if needed.
2. Select a different Source while paused; it should remain paused.
3. Play, then select another source; playback should resume after loading.
4. Pause while a source loads; it should stay paused when loading finishes.
5. Reload, close and reopen the player, then quit from the menu.

Run one copy at a time: builds share the `local.endelito` bundle identifier,
WebKit storage, and diagnostics. Automated checks do not establish audible
playback or website authentication. Use `make doctor` for local diagnostics.

## Development notes

- [sources.json](app/Resources/sources.json) owns soundscape IDs and aliases.
- `make test-playback` compiles the production intent owner and extracted
  callback/navigation methods with deterministic fixtures. It covers
  cancellation, stale callbacks, duplicate attempts, and retry limits.
- Diagnostics are written under `~/Library/Application Support/Endelito/`.
  Remove private page/account details before sharing them.
- Build artifacts are ignored by git.

## Pull requests and releases

Use Conventional Commits. Focus pull requests on one change, include relevant
verification, and follow the repository template. Report vulnerabilities through
[Security](SECURITY.md).

Pushes to `main` evaluate a signed, notarized release after verification passes.
See [Releases](docs/RELEASES.md) for credentials and recovery.
