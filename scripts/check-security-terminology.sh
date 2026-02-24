#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET_FILES=(
  "README.md"
  "docs/security-architecture.md"
  "docs/index.html"
)

# Keep this list strict and implementation-aligned.
# These phrases indicate stale or misleading security copy.
BANNED_TERMS=(
  "HiveAesCipher"
  "hive_flutter"
  "No internet permission required"
  "opens a completely separate decoy vault containing harmless dummy entries"
)

failed=0

for term in "${BANNED_TERMS[@]}"; do
  if matches=$(grep -RIn --fixed-strings -- "$term" "${TARGET_FILES[@]}"); then
    if [[ -n "$matches" ]]; then
      echo "BANNED TERM FOUND: $term"
      echo "$matches"
      echo
      failed=1
    fi
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "Security terminology check failed."
  exit 1
fi

echo "Security terminology check passed."
