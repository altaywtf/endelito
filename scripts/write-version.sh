#!/usr/bin/env bash
set -euo pipefail

version="${1:?version is required}"
printf '%s\n' "$version" > VERSION
