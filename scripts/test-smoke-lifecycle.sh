#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EXECUTABLE="$ROOT/build/Endelito.app/Contents/MacOS/Endelito"

pids() {
  ps -axo pid=,comm= | awk -v executable="$EXECUTABLE" '
    { pid = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); if ($0 == executable) print pid }
  '
}

assert_snapshot() {
  [[ "$(pids)" == "$BEFORE" ]] || { printf 'lifecycle proof: process residue\n' >&2; exit 1; }
}

stop_smoke() {
  if [[ -n "${SMOKE_PID:-}" ]] && kill -0 "$SMOKE_PID" 2>/dev/null; then
    kill -TERM "$SMOKE_PID"
    wait "$SMOKE_PID" || true
  fi
}
trap stop_smoke EXIT

BEFORE="$(pids)"
if ENDELITO_SMOKE_LAUNCH=1 ENDELITO_SMOKE_INJECT_FAILURE=1 "$ROOT/scripts/smoke.sh" >/dev/null 2>&1; then
  printf 'lifecycle proof: injected failure unexpectedly passed\n' >&2
  exit 1
fi
assert_snapshot

ENDELITO_SMOKE_LAUNCH=1 ENDELITO_SMOKE_CAPTURE_DELAY=1 ENDELITO_SMOKE_HOLD_AFTER_LAUNCH=1 "$ROOT/scripts/smoke.sh" >/dev/null 2>&1 &
SMOKE_PID=$!
for _ in $(seq 1 40); do
  [[ "$(pids)" != "$BEFORE" ]] && break
  sleep 0.1
done
[[ "$(pids)" != "$BEFORE" ]] || { printf 'lifecycle proof: app did not launch\n' >&2; exit 1; }
kill -TERM "$SMOKE_PID"
set +e
wait "$SMOKE_PID"
RESULT=$?
set -e
SMOKE_PID=""
[[ "$RESULT" == "143" ]] || { printf 'lifecycle proof: TERM exit was %s\n' "$RESULT" >&2; exit 1; }
assert_snapshot
printf 'lifecycle proof: ok\n'
