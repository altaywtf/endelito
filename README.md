# Endelito

`endelito` is a small Go CLI plus a native Swift menu bar app for playing Endel from the website without the Electron desktop wrapper.

The shape is intentionally boring:

- The Swift app is a menu bar-only `WKWebView` wrapper for `https://play.endel.io/en`.
- WebKit uses the default website data store, so the site session persists on this Mac.
- The Go CLI launches the app, sends `endelito://` commands, and reads a tiny local state file.
- There are no charts, dashboards, visualizations, or background provider scans.

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

The app registers the `endelito://` URL scheme. Commands like `bin/endelito play` send `endelito://play`; the Swift app receives that URL and forwards the action into the web page through a small `window.electron` compatibility shim.

For playback, the app targets Endel's own player button inside the WebView. It intentionally avoids Accessibility permissions and system-wide input events.

The shim exists because the official Endel Electron app injects `window.electron.playback.onCommand`, `window.electron.playback.updateState`, and related callbacks into the website.

## Limits

This is a proof of concept for playback. Login, purchase, notifications, and OAuth/deep-link auth flows still need real use before treating it as a daily-driver replacement.
