# Endelito

A macOS menu bar player for [Endel](https://play.endel.io/en), built with Swift
and WebKit. Choose a soundscape, play or pause, and open the player to sign in.
The website session persists across app restarts.

## Install

Download the signed, notarized app from
[GitHub Releases](https://github.com/altaywtf/endelito/releases/latest), unzip it,
and move `Endelito.app` to Applications. Requires macOS 13 or later.

Open Endelito, then choose **Show Player** from its menu bar item to sign in.
The **Source** submenu selects a soundscape and preserves playback state.
If playback fails, show the player, resolve any website prompt, and retry.

To build and install locally:

```sh
make install
```

This builds `build/Endelito.app` and copies it to `/Applications`. Set
`APPLICATIONS_DIR=` to choose another destination. Local builds are ad-hoc
signed; release builds use Developer ID signing and Apple notarization.

## Development

Requires Node.js and Xcode command line tools. Mise is optional.

```sh
make build
make verify
make doctor
```

`mise run verify` skips unchanged sources. Menu interactions and audible
playback need a GUI session; see [Contributing](CONTRIBUTING.md#validate).

## Architecture

Endelito is a native Swift accessory app (`LSUIElement`, no Dock icon) in
[app/Sources/Endelito](app/Sources/Endelito). Its bundle identifier stays
`local.endelito` so existing website sessions keep working.

### Player and controls

The menu owns source selection, playback, reload, and the player window.
Sources load `https://play.endel.io/en/soundscape/<id>`; Focus is the initial
source. Switching sources preserves playback state.

The player uses `WKWebView` with `WKWebsiteDataStore.default()`; that session
persistence is part of the app contract. The bridge accepts messages from
`endel.io` hosts.

[EndelitoBridge.js](app/Resources/EndelitoBridge.js) supplies website APIs the
desktop wrapper expects. It observes media and WebAudio state so the menu
follows page and system playback changes, and ignores decorative muted videos.
Playback clicks happen inside the WebView, so the app needs no Accessibility or
system-wide input access.

[PlaybackIntent.swift](app/Sources/Endelito/PlaybackIntent.swift) assigns
intent tokens to playback and source changes. Pause and unrelated navigation
invalidate pending work. Missing controls get two delayed retries; exhaustion
clears optimistic state and writes an error to `debug.json`. To recover, open
the player, resolve its page state, and retry.

### Resources and diagnostics

- [sources.json](app/Resources/sources.json) owns known source IDs and aliases;
  the build copies it into the bundle. New or renamed soundscapes need a
  catalog update.
- `state.json` and `debug.json` under
  `~/Library/Application Support/Endelito/` hold state and playback
  diagnostics. They can include website URLs; sanitize them before sharing.
- The [Makefile](Makefile) owns bundle assembly, installation, and signing. It
  stamps the app and bridge from `VERSION` and generates icons with
  [GenerateAssets.swift](tools/GenerateAssets.swift). Generated resources stay
  in `build/`, outside git.
- [Verification](CONTRIBUTING.md#validate) covers deterministic playback and
  bundle integrity. Website login, subscription prompts, and audible playback
  need real-use checks. Updates come from GitHub Releases.

## Documentation

- [Contributing](CONTRIBUTING.md)
- [Security](https://github.com/altaywtf/.github/blob/main/SECURITY.md)

[MIT License](LICENSE).
