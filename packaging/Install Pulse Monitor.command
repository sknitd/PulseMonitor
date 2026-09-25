#!/bin/bash
# Optional, interactive local installer. Never changes global Gatekeeper settings.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$HERE/Pulse Monitor.app"
DEST="$HOME/Applications/Pulse Monitor.app"
finish() { printf '\nPress Return to close…'; read -r _ || true; }
if [[ "$(uname -s)" != Darwin ]]; then echo "This installer is for macOS only."; exit 1; fi
if [[ ! -x "$SOURCE/Contents/MacOS/PulseMonitor" ]]; then
  echo "Keep this installer beside the extracted Pulse Monitor.app bundle."; finish; exit 1
fi
MAJOR="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d. -f1)"
if [[ "$MAJOR" -lt 13 ]]; then echo "Pulse Monitor requires macOS 13 or later."; finish; exit 1; fi
cat <<TXT
Pulse Monitor — local installation

This independently recreated app is NOT Apple-notarized or Developer ID-signed.
Its universal binary was built against Apple's macOS SDK and ad-hoc signed.
Gatekeeper may reject it. Review the included source and QA report before
deciding whether you trust this independent build.

Continuing will:
  • Copy the app to $DEST
  • Verify the existing local ad-hoc code signature
  • Ask macOS to open the copied app without changing security settings

A local signature does not verify the publisher or certify the app as safe.
This installer does not remove quarantine or change Gatekeeper settings.
No administrator password, network download, or third-party runtime is needed.
TXT
printf '\nType INSTALL to approve these steps, or press Return to cancel: '
read -r ANSWER
if [[ "$ANSWER" != INSTALL ]]; then echo "Cancelled. Nothing changed."; finish; exit 0; fi
if [[ -e "$DEST" ]]; then
  echo "An app already exists at $DEST. It will NOT be overwritten."
  echo "Quit and move that copy elsewhere, or install the new app manually."; finish; exit 1
fi
mkdir -p "$HOME/Applications"
/usr/bin/ditto "$SOURCE" "$DEST"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$DEST"
/usr/bin/open "$DEST"
echo "Opened Pulse Monitor. Closing its window leaves the menu-bar monitor running."
echo "To exit completely, choose Pulse Monitor → Quit, or press Command-Q."
finish
