![endelito — tiny macOS menu bar app and CLI for playing Endel without Electron.](https://uinaf.dev/og/banner/endelito.png)

# uinaf/endelito

`endelito` is a small Go CLI plus a native Swift menu bar app for playing Endel from the website without the Electron desktop wrapper.

The shape is intentionally boring: one WebKit session, one menu bar app, one CLI.

- The Swift app is a menu bar-only `WKWebView` wrapper for `https://play.endel.io/en`.
- WebKit uses the default website data store, so the site session persists on this Mac.
- The Go CLI launches the app, sends `endelito://` commands, and reads a tiny local state file.
- The app opens the Focus soundscape by default and can switch across 17 known Focus, Relax, and Sleep soundscapes.

## Install

Install the signed and notarized release from the uinaf Homebrew tap:

```sh
brew tap uinaf/tap
brew install --cask endelito
```

The cask installs both `Endelito.app` and the `endelito` CLI from the latest [GitHub Release](https://github.com/uinaf/endelito/releases/latest).

To build and install from source instead:

```sh
make build
make install
```

This copies `build/Endelito.app` to `/Applications/Endelito.app` and installs `bin/endelito` to `$(brew --prefix)/bin/endelito` when Homebrew is present (otherwise `/usr/local/bin`). Override with `PREFIX=` / `APPLICATIONS_DIR=`.

## Use

```sh
endelito launch
endelito status
endelito show
endelito hide
endelito sources
endelito source focus
endelito source "nature elements"
endelito play dynamic-focus
endelito play
endelito pause
endelito toggle
endelito reload
endelito debug
endelito deeplink "https://play.endel.io/en/soundscape/focus"
endelito quit
```

Open the player once with `endelito show` to sign in or pick content. After that, the app can stay in the menu bar and the CLI can control playback.

- The menu bar item includes a Source submenu with the known Focus, Relax, and Sleep soundscapes.
- `endelito sources` lists known source IDs.
- `endelito source <id-or-name>` loads a source and preserves playback state;
  the new source starts only if playback was already running.
- `endelito play <id-or-name>` loads a source and starts it. A later pause cancels
  queued playback. Missing player controls are retried twice, then reported in
  `debug.json`; show the player and retry after resolving the page state.
- `ENDELITO_APP=/path/to/Endelito.app endelito play` selects the app for command
  delivery, even when another copy is running. A missing override is an error.
- `endelito deeplink <url>` forwards a URL into the web player's deeplink handlers.

## How It Works

The app registers the `endelito://` URL scheme. Commands like `endelito play` send `endelito://play`; the Swift app receives the URL and forwards the action into the WebView.

See [Architecture](docs/ARCHITECTURE.md) for the current control model and limitations.

## Build and Verify

```sh
make build
```

Build outputs are written to `bin/endelito` and `build/Endelito.app`. The app bundle includes generated Finder and menu bar icons.

```sh
mise run verify
mise run --force verify # explicitly run the exhaustive gate
```

The incremental command skips unchanged sources after a successful result.
The underlying `make verify` gate syntax-checks the WebKit bridge, runs bridge
contract tests and deterministic Swift playback-intent tests, formats/vets Go,
runs Go tests, builds the CLI and app, and
checks the app bundle, URL scheme, icons, and CLI help. Mise is optional; run
`make verify` directly for an exhaustive pass without it.

For a quick machine-readable environment and runtime snapshot:

```sh
make doctor
```

See [Contributing](CONTRIBUTING.md) for local validation and [Distribution](docs/DISTRIBUTION.md) for CI and release details.

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Releases](docs/RELEASES.md)
- [Distribution](docs/DISTRIBUTION.md)
- [Security](SECURITY.md)

## Contributing

See [Contributing](CONTRIBUTING.md) for setup, validation, and pull request expectations. Agent-specific repository rules are in [the agent guide](AGENTS.md).

## License

Endelito is available under the [MIT License](LICENSE).
