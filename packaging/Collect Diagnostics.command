#!/bin/bash
# Explicit, local-only troubleshooting. Does not upload any information.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/Pulse Monitor.app"
[[ -d "$HOME/Applications/Pulse Monitor.app" ]] && APP="$HOME/Applications/Pulse Monitor.app"
if [[ "$(uname -s)" != Darwin ]]; then echo "Run this on macOS."; exit 1; fi
if [[ ! -x "$APP/Contents/MacOS/PulseMonitor" ]]; then echo "Pulse Monitor.app was not found beside this script or in ~/Applications."; exit 1; fi
cat <<'TXT'
Diagnostics will run two local samples and write a new text file on your Desktop.
It includes your Mac model, OS version, process/app names, local paths, ports,
and resource usage. Review/redact it before sharing. Nothing is uploaded.
TXT
printf '\nType DIAGNOSE to continue: '; read -r ANSWER
[[ "$ANSWER" == DIAGNOSE ]] || exit 0
OUT="$HOME/Desktop/Pulse-Diagnostics-$(date '+%Y%m%d-%H%M%S').txt"
{
  echo 'Pulse Monitor diagnostic — review private paths before sharing'
  date
  /usr/bin/sw_vers
  /usr/bin/uname -m
  /usr/bin/file "$APP/Contents/MacOS/PulseMonitor"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP" 2>&1
  echo '--- Native sample follows; this can take several seconds ---'
  "$APP/Contents/MacOS/PulseMonitor" --diagnose 2>&1
} > "$OUT"
echo "Saved locally: $OUT"
printf '\nPress Return to close…'; read -r _ || true
