# Endelito

`endelito` is a small Go CLI plus a native Swift menu bar app for playing Endel from the website without the Electron desktop wrapper.

The shape is intentionally boring: one WebKit session, one menu bar app, one CLI.

- The Swift app is a menu bar-only `WKWebView` wrapper for `https://play.endel.io/en`.
- WebKit uses the default website data store, so the site session persists on this Mac.
- The Go CLI launches the app, sends `endelito://` commands, and reads a tiny local state file.
- There are no charts, dashboards, visualizations, or background provider scans.
- The prototype opens the Focus soundscape by default; broader soundscape selection is future work.

## Build

```sh
make build-cli build-app
```

Outputs:

- `bin/endelito`
- `build/Endelito.app`

The app bundle includes generated icons:

- `AppIcon.icns` for Finder/app identity
- `MenuBarIconTemplate.png` for the macOS menu bar

## Docs

- [Contributing](CONTRIBUTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Security](SECURITY.md)
- [Agent guide](AGENTS.md)

## Use

```sh
bin/endelito launch
bin/endelito status
bin/endelito show
bin/endelito hide
bin/endelito play
bin/endelito pause
bin/endelito toggle
bin/endelito mute
bin/endelito unmute
bin/endelito reload
bin/endelito debug
bin/endelito quit
```

Open the player once with `bin/endelito show` to sign in or pick content. After that, the app can stay in the menu bar and the CLI can control playback.

## How It Works

The app registers the `endelito://` URL scheme. Commands like `bin/endelito play` send `endelito://play`; the Swift app receives the URL and forwards the action into the WebView.

See [Architecture](docs/ARCHITECTURE.md) for the current control model and limitations.
