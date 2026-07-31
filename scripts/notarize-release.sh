#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="${1:-}"
APP="${2:-}"

required=(NOTARY_API_KEY_PATH NOTARY_API_KEY_ID NOTARY_API_ISSUER_ID)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'notarize: %s is required\n' "$name" >&2
    exit 1
  fi
done

if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
  printf 'notarize: release archive is required\n' >&2
  exit 1
fi

if [[ -z "$APP" || ! -d "$APP" ]]; then
  printf 'notarize: packaged app is required\n' >&2
  exit 1
fi

result="$(mktemp)"
log="${result}.log"
cleanup() {
  rm -f "$result" "$log"
}
trap cleanup EXIT

xcrun notarytool submit "$ARCHIVE" \
  --key "$NOTARY_API_KEY_PATH" \
  --key-id "$NOTARY_API_KEY_ID" \
  --issuer "$NOTARY_API_ISSUER_ID" \
  --wait \
  --timeout 90m \
  --output-format plist > "$result"

status="$(plutil -extract status raw -o - "$result")"
submission_id="$(plutil -extract id raw -o - "$result")"

if [[ "$status" != "Accepted" ]]; then
  xcrun notarytool log \
    --key "$NOTARY_API_KEY_PATH" \
    --key-id "$NOTARY_API_KEY_ID" \
    --issuer "$NOTARY_API_ISSUER_ID" \
    "$submission_id" \
    "$log" || true
  cat "$log" >&2
  printf 'notarize: submission %s finished with status %s\n' "$submission_id" "$status" >&2
  exit 1
fi

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"

archive_name="$(basename "$ARCHIVE")"
rm -f "$ARCHIVE"
(cd "$ROOT/dist" && ditto -c -k --sequesterRsrc --keepParent Endelito "$archive_name")

printf 'notarize: accepted submission %s and stapled Endelito.app\n' "$submission_id"
