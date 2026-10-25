# Endelito

A macOS menu bar player for [Endel](https://play.endel.io/en), built with Swift
and WebKit. Choose a soundscape, play or pause, and open the player to sign in.
The website session persists across app restarts.

## Install

Download the signed, notarized app from
[GitHub Releases](https://github.com/altaywtf/endelito/releases/latest), unzip it,
and move `Endelito.app` to Applications. Requires macOS 13 or later.

Open Endelito, then choose **Show Player** from its menu bar item to sign in.
The **Source** submenu selects a soundscape. If playback fails, show the
player, resolve any website prompt, and retry.

To build from source, see [Contributing](CONTRIBUTING.md).

## Privacy

WebKit session data, `state.json` and `debug.json` under
`~/Library/Application Support/Endelito/` can hold cookies, account details,
and page URLs. Sanitize them before sharing.

## Documentation

- [Contributing](CONTRIBUTING.md)
- [Security](https://github.com/altaywtf/.github/blob/main/SECURITY.md)

[MIT License](LICENSE).
