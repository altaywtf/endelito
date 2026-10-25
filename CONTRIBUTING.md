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
See [Architecture](README.md#architecture) for playback and WebKit session behavior.

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
WebKit storage, and diagnostics. Audible playback and website login are only
proven by hand.

## Issues and product boundaries

Feature requests stay within the menu bar WebKit player. Bug reports include
macOS version, Mac architecture, install method, app version, and `make doctor`
output.

WebKit session data and diagnostics under
`~/Library/Application Support/Endelito/` can hold credentials, cookies,
account details, and page URLs; sanitize them before sharing. Adding Accessibility,
global input monitoring, screen recording, key logging, system-wide event
posting, network services, or remote control endpoints requires an explicit
security review and approval.

## Development notes

- [sources.json](app/Resources/sources.json) owns soundscape IDs and aliases.
- `make test-playback` runs the production playback intent and callback code
  against deterministic fixtures: cancellation, stale callbacks, duplicate
  attempts, and retry limits.

## Pull requests and releases

Use Conventional Commits and keep each pull request to one change. Report
vulnerabilities through
[Security](https://github.com/altaywtf/.github/blob/main/SECURITY.md).

Pushes to `main` evaluate a signed, notarized release after verification passes.

`make install` and `make uninstall` also remove the legacy CLI from `PREFIX/bin`
(the Homebrew prefix by default). Set `PREFIX` if the old CLI was installed elsewhere.
