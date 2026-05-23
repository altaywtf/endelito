#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Endelito.app"
CLI="$ROOT/bin/endelito"
PLIST="$APP/Contents/Info.plist"
RESOURCES="$APP/Contents/Resources"
STATE="$HOME/Library/Application Support/Endelito/state.json"

fail() {
  printf 'smoke: %s\n' "$*" >&2
  exit 1
}

test -x "$CLI" || fail "missing CLI at $CLI"
test -x "$APP/Contents/MacOS/Endelito" || fail "missing app executable"
test -f "$RESOURCES/AppIcon.icns" || fail "missing app icon"
test -f "$RESOURCES/MenuBarIconTemplate.png" || fail "missing menu bar icon"

"$CLI" --help | grep -q 'Usage: endelito <command>' || fail "CLI help did not render"

test "$(plutil -extract CFBundleIdentifier raw -o - "$PLIST")" = "local.endelito" || fail "unexpected bundle id"
test "$(plutil -extract CFBundleName raw -o - "$PLIST")" = "Endelito" || fail "unexpected bundle name"
test "$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw -o - "$PLIST")" = "endelito" || fail "missing endelito URL scheme"
test "$(plutil -extract LSUIElement raw -o - "$PLIST")" = "true" || fail "app is not menu-bar-only"

if [[ "${ENDELITO_SMOKE_LAUNCH:-0}" == "1" ]]; then
  rm -f "$STATE"
  pkill -x Endelito >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    if ! pgrep -x Endelito >/dev/null; then
      break
    fi
    sleep 0.1
  done
  ENDELITO_APP="$APP" "$CLI" launch

  for _ in $(seq 1 20); do
    if [[ -f "$STATE" ]]; then
      break
    fi
    sleep 0.25
  done

  test -f "$STATE" || fail "app did not write state file"
  "$CLI" status | grep -q '^Endelito:' || fail "status did not read app state"
  "$CLI" quit || true
  pkill -x Endelito >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    if ! pgrep -x Endelito >/dev/null; then
      break
    fi
    sleep 0.1
  done
fi

printf 'smoke: ok\n'
