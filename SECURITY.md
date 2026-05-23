# Security

## Reporting

Please report security issues privately to [altay@hey.com](mailto:altay@hey.com) instead of opening a public issue.

## Scope

Endelito is a local macOS helper. The main sensitive surfaces are:

- Website session data stored by WebKit.
- Local state under `~/Library/Application Support/Endelito/`.
- The `endelito://` URL scheme used for local CLI commands.

## Supported Versions

Security fixes target the latest GitHub Release and current `main`.

## Expectations

- Do not log tokens, cookies, account details, or full page dumps that include private user content.
- Keep generated debug output local and out of git.
- Do not add Accessibility, global input monitoring, screen recording, key logging, or system-wide event posting without explicit approval.
- Do not introduce network services or remote control endpoints unless they are reviewed as a new security surface.
