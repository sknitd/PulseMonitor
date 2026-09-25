#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/pulse-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Native logic tests need Apple's Foundation SDK." >&2
  exit 1
fi

echo "Building native logic tests with the installed macOS SDK…"
/usr/bin/xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
  -I "$ROOT/native" -framework Foundation "$ROOT/native/PulseLogic.m" "$ROOT/tests/native_logic_tests.m" \
  -o "$TMP/native-logic-tests"
"$TMP/native-logic-tests"

echo "Running JavaScript/UI logic tests…"
node "$ROOT/tests/ui_logic_tests.js"

if python3 -c 'import playwright.sync_api' >/dev/null 2>&1; then
  echo "Running Chromium interaction tests…"
  python3 "$ROOT/tests/ui_tests.py"
else
  echo "SKIP Chromium interaction tests: Python Playwright is not installed; no dependency was added."
fi
