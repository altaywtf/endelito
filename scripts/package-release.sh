#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

make build

rm -rf dist
mkdir -p dist/Endelito
cp -R build/Endelito.app dist/Endelito/
cp bin/endelito dist/Endelito/
cp README.md LICENSE* dist/Endelito/ 2>/dev/null || true

ARCH="$(uname -m)"
(
  cd dist
  ditto -c -k --sequesterRsrc --keepParent Endelito "endelito-macos-${ARCH}.zip"
)
