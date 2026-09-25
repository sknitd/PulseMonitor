#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/dist}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
APP="$OUT/Pulse Monitor.app"
ZIP="$OUT/PulseMonitor-macOS13-Universal.zip"
if [[ ! -d "$APP" ]]; then
  echo "Build the app first with: bash build-mac.sh \"$OUT\"" >&2
  exit 1
fi
if [[ -e "$ZIP" ]]; then
  echo "Archive already exists: $ZIP" >&2
  echo "Move it elsewhere before creating a replacement." >&2
  exit 1
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
/usr/bin/lipo "$APP/Contents/MacOS/PulseMonitor" -verify_arch arm64 x86_64

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pulse-package.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
STAGE="$TMP/PulseMonitor-macOS13-Universal"
mkdir -p "$STAGE"
/usr/bin/ditto "$APP" "$STAGE/Pulse Monitor.app"
cp "$ROOT/README.md" "$ROOT/QA_REPORT.md" "$ROOT/REMAINING_LIMITATIONS.md" "$STAGE/"
cp "$ROOT/packaging/Install Pulse Monitor.command" "$ROOT/packaging/Collect Diagnostics.command" "$STAGE/"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$STAGE" "$ZIP"
/usr/bin/unzip -tq "$ZIP"
mkdir -p "$TMP/unpacked"
/usr/bin/ditto -x -k "$ZIP" "$TMP/unpacked"
EXTRACTED="$TMP/unpacked/PulseMonitor-macOS13-Universal/Pulse Monitor.app"
test -x "$EXTRACTED/Contents/MacOS/PulseMonitor"
/usr/bin/codesign --verify --deep --strict "$EXTRACTED"
/usr/bin/lipo "$EXTRACTED/Contents/MacOS/PulseMonitor" -verify_arch arm64 x86_64
echo "Archive verified: $ZIP"
