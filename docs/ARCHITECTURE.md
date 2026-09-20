# Architecture

Endelito is a native Swift menu bar app in
[app/Sources/Endelito](../app/Sources/Endelito). It is an accessory app
(`LSUIElement`) with no Dock icon. Its bundle identifier remains `local.endelito`
so existing website sessions continue to work.

## Player and controls

The menu owns source selection, playback, reload, and the player window.
Sources load `https://play.endel.io/en/soundscape/<id>`. Switching sources
preserves playback state. Focus is the initial source.

The player uses `WKWebView` with `WKWebsiteDataStore.default()`. Do not replace
it with a nonpersistent store: login/session persistence is part of the app
contract. Bridge messages are accepted only from trusted Endel origins.

[EndelitoBridge.js](../app/Resources/EndelitoBridge.js) supplies website APIs
expected by the desktop wrapper. It observes media and WebAudio state so the
menu follows page and system playback changes. Decorative muted videos are
ignored. Playback clicks stay inside the WebView; the app does not require
Accessibility or system-wide input access.

[PlaybackIntent.swift](../app/Sources/Endelito/PlaybackIntent.swift) assigns
intent tokens to playback and source changes. Pause and unrelated navigation
invalidate pending work. Missing controls get two delayed retries; exhaustion
clears optimistic state and writes an error to `debug.json`. Open the player,
resolve its page state, and retry.

## Resources and diagnostics

[app/Resources/sources.json](../app/Resources/sources.json) owns known source IDs
and aliases. The build copies it into the app bundle. New or renamed soundscapes
need a catalog update.

State and playback diagnostics are written to `state.json` and `debug.json`
under `~/Library/Application Support/Endelito/`. These files can include website
URLs; sanitize them before sharing.

[Makefile](../Makefile) owns bundle assembly, installation, and signing targets.
It stamps the app and bridge from `VERSION` and generates icons with
[GenerateAssets.swift](../tools/GenerateAssets.swift). Generated resources stay
in `build/`, outside git.

[Verification](../CONTRIBUTING.md#validate) covers deterministic playback and
bundle integrity. Website login, subscription prompts, and audible playback
require real-use checks. Updates are downloaded from GitHub Releases.
