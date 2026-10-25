# Contributing

Requires macOS 13 or later, Xcode command line tools, and Node.js. Mise is
optional.

## Build

```sh
make build     # build/Endelito.app, ad-hoc signed
make install   # copies it to /Applications; set APPLICATIONS_DIR to change
```

## Validate

```sh
make verify               # the gate
mise run verify           # the gate, skipped when sources are unchanged
mise run --force verify   # the gate, never skipped
```

For UI changes, open `build/Endelito.app` and check its menu bar item:

1. Choose **Show Player** and sign in if needed.
2. Select a different Source while paused; it should remain paused.
3. Play, then select another source; playback should resume after loading.
4. Pause while a source loads; it should stay paused when loading finishes.
5. Reload, close and reopen the player, then quit from the menu.

Run one copy at a time: builds share the `local.endelito` bundle identifier,
WebKit storage, and diagnostics. Audible playback and website login are only
proven by hand.

## Invariants

- Endelito is a menu bar WebKit player, not a full desktop client.
- Keep the bundle identifier `local.endelito`; existing website sessions
  depend on it.
- Keep the player on `WKWebsiteDataStore.default()` so website sessions
  persist across restarts.
- Keep page JavaScript in
  [EndelitoBridge.js](app/Resources/EndelitoBridge.js), not Swift string
  literals.
- New or renamed soundscapes need an entry in
  [sources.json](app/Resources/sources.json).
- Accessibility, global input monitoring, screen recording, key logging,
  system-wide event posting, network services, and remote control endpoints
  need an explicit security review and approval.

## Issues and pull requests

Bug reports include macOS version, Mac architecture, install method, app
version, and `make doctor` output, sanitized as in
[Privacy](README.md#privacy).

Use Conventional Commits and keep each pull request to one change. Report
vulnerabilities through
[Security](https://github.com/altaywtf/.github/blob/main/SECURITY.md).
