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

`mise run verify` skips unchanged sources after a successful check.
`make verify` always runs bridge, playback-intent, catalog, and app-bundle checks.
Menu interactions and audible playback need a GUI session; see
[Contributing](CONTRIBUTING.md#validate).

## Documentation

- [Contributing](CONTRIBUTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Releases](docs/RELEASES.md)
- [Distribution and signing](docs/DISTRIBUTION.md)
- [Security](SECURITY.md)

[MIT License](LICENSE).
