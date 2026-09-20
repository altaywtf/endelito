#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP="$ROOT/build/Endelito.app"
PLIST="$APP/Contents/Info.plist"
RESOURCES="$APP/Contents/Resources"

fail() {
  printf 'smoke: %s\n' "$*" >&2
  exit 1
}

test -x "$APP/Contents/MacOS/Endelito" || fail "missing app executable"
test -f "$RESOURCES/EndelitoBridge.js" || fail "missing WebKit bridge script"
test -f "$RESOURCES/sources.json" || fail "missing sources catalog"
test -f "$RESOURCES/AppIcon.icns" || fail "missing app icon"
test -f "$RESOURCES/MenuBarIconTemplate.png" || fail "missing menu bar icon"

test "$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST")" = "$(tr -d '[:space:]' < "$ROOT/VERSION")" || fail "app version was not stamped from VERSION"
grep -q "endelito/$(tr -d '[:space:]' < "$ROOT/VERSION")" "$RESOURCES/EndelitoBridge.js" || fail "bridge version was not stamped from VERSION"

test "$(plutil -extract CFBundleIdentifier raw -o - "$PLIST")" = "local.endelito" || fail "unexpected bundle id"
test "$(plutil -extract CFBundleName raw -o - "$PLIST")" = "Endelito" || fail "unexpected bundle name"
test "$(plutil -extract LSUIElement raw -o - "$PLIST")" = "true" || fail "app is not menu-bar-only"

codesign --verify --deep --strict "$APP"

printf 'smoke: ok\n'
