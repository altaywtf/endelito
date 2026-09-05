#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP="$ROOT/build/Endelito.app"
CLI="$ROOT/bin/endelito"
EXECUTABLE="$APP/Contents/MacOS/Endelito"
PLIST="$APP/Contents/Info.plist"
RESOURCES="$APP/Contents/Resources"
STATE="$HOME/Library/Application Support/Endelito/state.json"

fail() {
  printf 'smoke: %s\n' "$*" >&2
  exit 1
}

pids_for_executable() {
  ps -axo pid=,comm= | awk -v executable="$EXECUTABLE" '
    { pid = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); if ($0 == executable) print pid }
  '
}

pid_is_owned_executable() {
  [[ "$(ps -p "$1" -o comm= 2>/dev/null)" == "$EXECUTABLE" ]]
}

new_pids() {
  pids_for_executable | while read -r pid; do
    grep -qx "$pid" <<<"$PREEXISTING_PIDS" || printf '%s\n' "$pid"
  done
}

wait_for_owned_exit() {
  for _ in $(seq 1 20); do
    local alive=0
    for pid in $OWNED_PIDS; do
      pid_is_owned_executable "$pid" && alive=1
    done
    if [[ "$alive" == "0" ]]; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

cleanup_owned() {
  local result=$?
  trap - EXIT INT TERM
  if [[ -z "$OWNED_PIDS" ]]; then
    OWNED_PIDS="$(new_pids)"
  fi
  for pid in $OWNED_PIDS; do
    pid_is_owned_executable "$pid" && kill "$pid" 2>/dev/null || true
  done
  if ! wait_for_owned_exit; then
    for pid in $OWNED_PIDS; do
      pid_is_owned_executable "$pid" && kill -KILL "$pid" 2>/dev/null || true
    done
    if ! wait_for_owned_exit; then
      printf 'smoke: owned app processes remain after KILL\n' >&2
      [[ "$result" -ne 0 ]] || result=1
    fi
  fi
  exit "$result"
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

send_app_command() {
  ENDELITO_APP="$APP" "$CLI" "$@"
}

test -x "$CLI" || fail "missing CLI at $CLI"
test -x "$APP/Contents/MacOS/Endelito" || fail "missing app executable"
test -f "$RESOURCES/EndelitoBridge.js" || fail "missing WebKit bridge script"
test -f "$RESOURCES/sources.json" || fail "missing sources catalog"
test -f "$RESOURCES/AppIcon.icns" || fail "missing app icon"
test -f "$RESOURCES/MenuBarIconTemplate.png" || fail "missing menu bar icon"

"$CLI" --help | grep -q 'Usage: endelito <command>' || fail "CLI help did not render"
"$CLI" --version | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$|^dev$' || fail "CLI version did not render"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST")" = "$(tr -d '[:space:]' < "$ROOT/VERSION")" || fail "app version was not stamped from VERSION"
grep -q "endelito/$(tr -d '[:space:]' < "$ROOT/VERSION")" "$RESOURCES/EndelitoBridge.js" || fail "bridge version was not stamped from VERSION"

test "$(plutil -extract CFBundleIdentifier raw -o - "$PLIST")" = "local.endelito" || fail "unexpected bundle id"
test "$(plutil -extract CFBundleName raw -o - "$PLIST")" = "Endelito" || fail "unexpected bundle name"
test "$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw -o - "$PLIST")" = "endelito" || fail "missing endelito URL scheme"
test "$(plutil -extract LSUIElement raw -o - "$PLIST")" = "true" || fail "app is not menu-bar-only"

if [[ "${ENDELITO_SMOKE_LAUNCH:-0}" == "1" ]]; then
  PREEXISTING_PIDS="$(pids_for_executable)"
  [[ -z "$PREEXISTING_PIDS" ]] || fail "stop the candidate app before cold-launch smoke"
  OWNED_PIDS=""
  trap cleanup_owned EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  rm -f "$STATE"
  # A non-default command must survive cold launch, before any warm-up command.
  send_app_command source sleep
  sleep "${ENDELITO_SMOKE_CAPTURE_DELAY:-0}"
  for _ in $(seq 1 20); do
    OWNED_PIDS="$(new_pids)"
    [[ -n "$OWNED_PIDS" ]] && break
    sleep 0.1
  done
  [[ -n "$OWNED_PIDS" ]] || fail "launched app PID was not found"

  [[ "${ENDELITO_SMOKE_INJECT_FAILURE:-0}" != "1" ]] || fail "injected post-launch failure"
  if [[ "${ENDELITO_SMOKE_HOLD_AFTER_LAUNCH:-0}" == "1" ]]; then
    while :; do sleep 1; done
  fi

  wait_for_state "cold source command selects Sleep" "sleep" "false"
  STATUS_OUTPUT="$("$CLI" status)" || fail "status command failed: $STATUS_OUTPUT"
  grep -q '^Endelito:' <<<"$STATUS_OUTPUT" || fail "status did not read app state: $STATUS_OUTPUT"

  send_app_command source relax
  wait_for_state "source command selects Relax while paused" "relax" "false"

  send_app_command play focus
  wait_for_state "play command selects Focus" "focus" "*"

  send_app_command source sleep
  wait_for_state "source command selects Sleep" "sleep" "*"

  send_app_command pause
  wait_for_state "pause command stops playback" "sleep" "false"

  STATUS_OUTPUT="$("$CLI" status)" || fail "status command failed: $STATUS_OUTPUT"
  grep -q '^source: sleep (Sleep)$' <<<"$STATUS_OUTPUT" || fail "status did not report selected source: $STATUS_OUTPUT"
fi

printf 'smoke: ok\n'
