#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Endelito.app"
CLI="$ROOT/bin/endelito"
STATE="$HOME/Library/Application Support/Endelito/state.json"
missing=0

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'doctor: command %-8s ok (%s)\n' "$1" "$(command -v "$1")"
  else
    printf 'doctor: command %-8s missing\n' "$1" >&2
    missing=1
  fi
}

printf 'doctor: repo %s\n' "$ROOT"

for command in go swift xcrun iconutil codesign plutil node; do
  check_command "$command"
done

if [[ -x "$CLI" ]]; then
  printf 'doctor: cli ok (%s)\n' "$CLI"
else
  printf 'doctor: cli missing; run make build\n'
fi

if [[ -x "$APP/Contents/MacOS/Endelito" ]]; then
  printf 'doctor: app ok (%s)\n' "$APP"
else
  printf 'doctor: app missing; run make build\n'
fi

if pgrep -x Endelito >/dev/null; then
  printf 'doctor: process running\n'
else
  printf 'doctor: process stopped\n'
fi

if [[ -f "$STATE" && -x "$(command -v node 2>/dev/null)" ]]; then
  node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$STATE"
  printf 'doctor: state ok (%s)\n' "$STATE"
elif [[ -f "$STATE" ]]; then
  printf 'doctor: state present but not parsed; node is missing (%s)\n' "$STATE"
else
  printf 'doctor: state missing; run bin/endelito launch\n'
fi

if [[ "$missing" != "0" ]]; then
  printf 'doctor: missing required commands\n' >&2
  exit 1
fi

printf 'doctor: ok\n'
