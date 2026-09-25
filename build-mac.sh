#!/bin/bash
# Rebuild against Apple's installed SDK. No Python/Node/runtime install required.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Run this script on a Mac with Xcode Command Line Tools installed." >&2; exit 1
fi
if ! /usr/bin/xcrun --find clang >/dev/null 2>&1; then
  echo "Install Apple Command Line Tools with: xcode-select --install" >&2; exit 1
fi
OUT="${1:-$ROOT/dist}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
APP="$OUT/Pulse Monitor.app"
if [[ -e "$APP" ]]; then
  echo "A build already exists: $APP" >&2
  echo "Use a new output directory, or remove the old build yourself." >&2; exit 1
fi
TMP="$(mktemp -d "${TMPDIR:-/tmp}/pulse-build.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
for ARCH in arm64 x86_64; do
  echo "Building $ARCH (macOS 13+)…"
  /usr/bin/xcrun --sdk macosx clang \
    -arch "$ARCH" -isysroot "$SDK" -mmacosx-version-min=13.0 \
    -fobjc-arc -fblocks -O2 -Wall -Wextra -Wno-unused-parameter \
    -framework Cocoa -framework WebKit -framework IOKit -framework Metal \
    -framework UserNotifications -framework ServiceManagement -framework UniformTypeIdentifiers \
    "$ROOT/native/main.m" "$ROOT/native/PulseLogic.m" -o "$TMP/PulseMonitor-$ARCH"
done
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/ui"
/usr/bin/lipo -create "$TMP/PulseMonitor-arm64" "$TMP/PulseMonitor-x86_64" -output "$APP/Contents/MacOS/PulseMonitor"
cp "$ROOT/packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/ui/index.html" "$ROOT/ui/app.js" "$ROOT/ui/styles.css" "$APP/Contents/Resources/ui/"
chmod 755 "$APP/Contents/MacOS/PulseMonitor"
/usr/bin/codesign --force --sign - --timestamp=none "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
echo ""
echo "Built and locally ad-hoc signed: $APP"
echo "This is a local signature, not Developer ID signing or Apple notarization."
echo "Launch: open \"$APP\""
