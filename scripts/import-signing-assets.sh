#!/usr/bin/env bash
set -euo pipefail

required=(
  APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64
  APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD
  APPLE_NOTARY_API_KEY_P8
  APPLE_NOTARY_API_KEY_ID
  RUNNER_TEMP
  GITHUB_OUTPUT
)

for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'signing: %s is required\n' "$name" >&2
    exit 1
  fi
done

certificate_path="$RUNNER_TEMP/endelito-signing.p12"
key_path="$RUNNER_TEMP/AuthKey_${APPLE_NOTARY_API_KEY_ID}.p8"
keychain_path="$RUNNER_TEMP/endelito-signing.keychain-db"
keychain_password="$(openssl rand -hex 32)"

cleanup() {
  rm -f "$certificate_path"
}
trap cleanup EXIT

printf '%s' "$APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64" | base64 -D > "$certificate_path"
printf '%s' "$APPLE_NOTARY_API_KEY_P8" > "$key_path"
chmod 600 "$certificate_path" "$key_path"

security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$certificate_path" \
  -k "$keychain_path" \
  -P "$APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
security list-keychains -d user -s "$keychain_path"
security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$keychain_password" \
  "$keychain_path"

identity="$(security find-identity -v -p codesigning "$keychain_path" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p')"
identity_count="$(printf '%s\n' "$identity" | awk 'NF { count++ } END { print count + 0 }')"

if [[ "$identity_count" != "1" ]]; then
  printf 'signing: expected one Developer ID Application identity, found %s\n' "$identity_count" >&2
  exit 1
fi

printf 'codesign_identity=%s\n' "$identity" >> "$GITHUB_OUTPUT"
printf 'notary_api_key_path=%s\n' "$key_path" >> "$GITHUB_OUTPUT"
printf 'signing: imported one Developer ID Application identity\n'
