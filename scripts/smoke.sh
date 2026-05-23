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

wait_for_process_exit() {
  for _ in $(seq 1 20); do
    if ! pgrep -x Endelito >/dev/null; then
      return
    fi
    sleep 0.1
  done

  fail "app did not quit"
}

wait_for_state() {
  local description="$1"
  local expected_source="$2"
  local expected_playing="$3"

  for _ in $(seq 1 40); do
    if [[ -f "$STATE" ]] && node - "$STATE" "$expected_source" "$expected_playing" <<'NODE'
const fs = require("fs");
const [statePath, expectedSource, expectedPlaying] = process.argv.slice(2);
const state = JSON.parse(fs.readFileSync(statePath, "utf8"));
if (expectedSource !== "*" && state.source !== expectedSource) process.exit(1);
if (expectedPlaying !== "*" && String(state.isPlaying) !== expectedPlaying) process.exit(1);
NODE
    then
      return
    fi
    sleep 0.25
  done

  fail "state did not reach: $description"
}

test -x "$CLI" || fail "missing CLI at $CLI"
test -x "$APP/Contents/MacOS/Endelito" || fail "missing app executable"
test -f "$RESOURCES/EndelitoBridge.js" || fail "missing WebKit bridge script"
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
  wait_for_process_exit
  ENDELITO_APP="$APP" "$CLI" launch

  wait_for_state "initial launch state" "focus" "false"
  "$CLI" status | grep -q '^Endelito:' || fail "status did not read app state"

  ENDELITO_APP="$APP" "$CLI" source relax
  wait_for_state "source command selects Relax while paused" "relax" "false"

  ENDELITO_APP="$APP" "$CLI" play focus
  wait_for_state "play command selects Focus" "focus" "*"

  ENDELITO_APP="$APP" "$CLI" source sleep
  wait_for_state "source command selects Sleep" "sleep" "*"

  ENDELITO_APP="$APP" "$CLI" pause
  wait_for_state "pause command stops playback" "sleep" "false"

  "$CLI" status | grep -q '^source: sleep (Sleep)$' || fail "status did not report selected source"
  "$CLI" quit || true
  pkill -x Endelito >/dev/null 2>&1 || true
  wait_for_process_exit
fi

printf 'smoke: ok\n'
