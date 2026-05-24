# Endelito

`endelito` is a small Go CLI plus a native Swift menu bar app for playing Endel from the website without the Electron desktop wrapper.

The shape is intentionally boring: one WebKit session, one menu bar app, one CLI.

- The Swift app is a menu bar-only `WKWebView` wrapper for `https://play.endel.io/en`.
- WebKit uses the default website data store, so the site session persists on this Mac.
- The Go CLI launches the app, sends `endelito://` commands, and reads a tiny local state file.
- There are no charts, dashboards, visualizations, or background provider scans.
- The app opens the Focus soundscape by default and can switch between Endel's source icons.

## Build

```sh
make build
```

Outputs:

- `bin/endelito`
- `build/Endelito.app`

The app bundle includes generated icons:

- `AppIcon.icns` for Finder/app identity
- `MenuBarIconTemplate.png` for the macOS menu bar

## Use

```sh
bin/endelito launch
bin/endelito status
bin/endelito show
bin/endelito hide
bin/endelito sources
bin/endelito source focus
bin/endelito source "nature elements"
bin/endelito play dynamic-focus
bin/endelito play
bin/endelito pause
bin/endelito toggle
bin/endelito reload
bin/endelito debug
bin/endelito quit
```

Open the player once with `bin/endelito show` to sign in or pick content. After that, the app can stay in the menu bar and the CLI can control playback. The menu bar item includes a Source submenu with the known Focus, Relax, and Sleep sources. Use `bin/endelito sources` to list known source IDs. Use `bin/endelito source <id-or-name>` to load a source without starting playback, or `bin/endelito play <id-or-name>` to load and start it.

Sign-in persists across app restarts through WebKit's default website data store for `Endelito.app`. Rebuilding the app with the same bundle identifier keeps using the same WebKit session storage.

## Install

Released versions are available from the Homebrew tap:

```sh
brew tap altaywtf/tap
brew install --cask endelito
```

The cask installs both `Endelito.app` and the `endelito` CLI from the GitHub Release archive.

## How It Works

The app registers the `endelito://` URL scheme. Commands like `bin/endelito play` send `endelito://play`; the Swift app receives the URL and forwards the action into the WebView.

See [Architecture](docs/ARCHITECTURE.md) for the current control model and limitations.

## Verify

```sh
make verify
```

`make verify` syntax-checks the WebKit bridge, runs Go tests, builds the CLI and app, and checks the app bundle, URL scheme, icons, and CLI help. On a local macOS GUI session, `make smoke-live` also launches the app, drives CLI source/play/pause commands through the URL scheme, checks state updates, and quits the app.

For a quick machine-readable environment and runtime snapshot:

```sh
make doctor
```

GitHub Actions runs the same verify gate on `macos-latest`. Pushes to `main` then run semantic-release and publish a GitHub Release when Conventional Commits produce a new version.

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Distribution](docs/DISTRIBUTION.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)
- [Agent guide](AGENTS.md)
