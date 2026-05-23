# Contributing

## Requirements

- macOS
- Go 1.26 or newer
- Xcode command line tools with `swift`, `xcrun`, `iconutil`, and `codesign`

## Build

```sh
make build-cli
make build-app
```

Outputs:

- `bin/endelito`
- `build/Endelito.app`

## Run

```sh
bin/endelito launch
bin/endelito show
bin/endelito status
```

Use `show` to open the WebView for sign-in or manual player selection. The app persists website session data through WebKit's default data store.

Do not replace the player data store with `.nonPersistent()` or a per-launch custom store. Login persistence is expected behavior.

## Validate

Run these before pushing:

```sh
go test ./...
make build-cli
make build-app
```

For UI changes, also launch the app and check the real state path:

```sh
bin/endelito launch
bin/endelito status
```

## Development Notes

- `ENDELITO_APP=/path/to/Endelito.app bin/endelito launch` overrides the app path the CLI opens.
- The app stores CLI-readable state at `~/Library/Application Support/Endelito/state.json`.
- `bin/endelito debug` writes page inspection data next to the state file.
- Build artifacts are ignored by git.
