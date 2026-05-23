# Architecture

Endelito has two pieces:

- A Go CLI at `cmd/endelito`.
- A native Swift menu bar app at `app/Sources/Endelito`.

The CLI is intentionally thin. It launches the app, sends `endelito://` commands through Launch Services, and reads local state.

The Swift app owns the WebKit session and player window. It is an accessory app (`LSUIElement`) with no Dock icon.

## Control Flow

1. The user runs `bin/endelito play`.
2. The CLI opens `endelito://play`.
3. The app receives the URL through `NSAppleEventManager`.
4. The app updates local playback state and sends the command into the WebView.
5. `bin/endelito status` reads `~/Library/Application Support/Endelito/state.json`.

## Readiness

- Boot: `make run` builds the CLI and app, then launches the menu bar app.
- Smoke: `make smoke` checks the built CLI, app bundle, URL scheme, menu-bar flag, and generated icons.
- Live smoke: `make smoke-live` launches the app, waits for the state file, reads status, and quits the app.
- CI: `.github/workflows/ci.yml` runs `make verify` on `macos-latest`.
- Release: pushes to `main` run semantic-release and attach the packaged macOS app plus CLI zip to GitHub Releases.

## WebView

The player uses `WKWebView` with `WKWebsiteDataStore.default()`. That keeps login/session state in WebKit-managed storage for this app, keyed by the app identity. Rebuilding `Endelito.app` with the same bundle identifier keeps using the same WebKit session store.

Do not switch to `.nonPersistent()` or a custom throwaway data store for the player. Session persistence is part of the app contract.

The current default page is the Focus soundscape. Endel has more soundscapes and product features than the prototype exposes.

The app injects a small compatibility shim for the website APIs used by the desktop wrapper, including playback state, menu commands, and deeplink callbacks.

Playback targets the player button inside the WebView. The app intentionally avoids Accessibility permissions and system-wide input events.

## Local Files

- State: `~/Library/Application Support/Endelito/state.json`
- Debug page dump: `~/Library/Application Support/Endelito/debug.json`
- App bundle: `build/Endelito.app`
- CLI binary: `bin/endelito`

## Icons

Icons are generated during `make build-app` by [GenerateAssets.swift](../tools/GenerateAssets.swift).

Generated outputs include:

- `AppIcon.icns`
- `MenuBarIconTemplate.png`
- Intermediate `AppIcon.iconset`

Generated assets are build outputs and are not committed.

## Current Limits

- Soundscape/channel selection is not modeled yet. The app opens Focus by default, and future work should expose available soundscapes through CLI commands and menu items instead of hardcoding a single page.
- Playback from CLI depends on WebKit accepting the in-app control path. Manual WebView clicks are the baseline fallback.
- Login, purchase, notifications, and OAuth/deep-link auth flows need real-use validation before treating the app as a daily-driver replacement.
- The app has no release packaging or update flow yet.

## Future Work

- Add `list-soundscapes` and `play <soundscape>` commands once the stable website routes or in-page menu model are mapped.
- Reflect the current soundscape in `status`.
- Keep advanced Endel features opt-in rather than expanding the menu bar app into a full desktop clone.
