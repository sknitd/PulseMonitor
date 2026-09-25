# macOS GUI acceptance record

**Run date:** 2026-09-25

**Device:** Apple Silicon Mac, macOS 14.4, arm64
**Build:** `dist/Pulse Monitor.app`, universal arm64 + x86_64, minimum macOS 13.0

## Passed on the Mac

- Opened the packaged app. The first window rendered live WebKit content and the JavaScript/native bridge updated the dashboard without a blank view or launch-time crash.
- Viewed Overview, CPU, Memory, Disk, Network, GPU, Battery, Projects, Settings, and Alerts. Live data appeared in available categories; GPU utilization remained explicitly unavailable.
- Expanded an ordinary app's process group and saw its PID and physical-footprint memory row. The process-level quit action showed a normal-quit warning; it was cancelled, leaving the app open.
- On the initial pass, Projects detected existing local servers with PIDs, ports, and working directories. The combined stop-review dialog warned that low CPU does not mean unused; it was cancelled without stopping those servers.
- Started a separate temporary Python HTTP server. Pulse identified the fixture and its working directory. The per-server review named only that fixture and explained SIGTERM behavior. Approved the test stop; Pulse reported one termination request with zero skipped/denied, the row disappeared, and the fixture exited with signal 15. Existing servers were left running.
- Changed refresh from 2 seconds to 5 seconds and back. Selected System, Light, and Dark appearance and restored System. Pause and resume changed the live state.
- Enabled Launch at Login and verified one Pulse Monitor row in System Settings → General → Login Items. Disabled it and verified the row was removed.
- Triggered sustained CPU alert history with a 30-second test duration. Restored the CPU threshold 80%, duration 60 seconds, memory-growth threshold 512 MiB, and Alerts Off after both alert tests below.
- Triggered the five-minute memory-growth warning using a temporary app-group fixture with 768 MiB of touched memory. Pulse reported that app memory use was growing, with the caveat that this is not proof of a leak. Turned alerts Off, cleared the test history, let the fixture exit, and removed its temporary bundle.
- Used the native save panel to export a live snapshot to a temporary location. Parsed the JSON and checked its schema keys, ISO timestamp, numeric project PIDs, and null GPU utilization; removed the temporary file afterward.
- Used Pulse Monitor’s native Quit menu item to terminate the app, then reopened the same bundle successfully. Settings persisted across this relaunch.
- Entered and exited full-screen. Command-W closed the main window without quitting Pulse; Pulse Monitor → Open Pulse Monitor reopened a single main window.
- On the rebuilt `dist` app, Minimize was enabled in the Window menu and minimized the window; Pulse Monitor → Open Pulse Monitor restored one standard window.
- The first GUI session ran about 20 minutes; after reopening, live samples continued for more than 40 minutes. The Pulse parent process stayed roughly 37–46 MiB in observed samples. Activity Monitor showed separate WebKit helper processes using additional memory; helper growth was not tracked from a controlled baseline.
- Compared live system-memory totals near-concurrently with Activity Monitor. App, wired, and compressed estimates were close, accounting for differing units and sampling times.

## Still unverified

- The status-item popover, outside-click dismissal, switching tabs in the popover, and reopening the main window from that item. Menu-bar mode toggled on and off, but the available desktop automation surface could not address the macOS status-item UI.
- The Dock icon's visual disappearance/reappearance and recovery after relaunch. The in-app menu-bar mode setting changed and was restored.
- Pulse notification delivery. The app's Allow Notifications switch was enabled in System Settings for a second alert test and restored to Off. Pulse recorded two further in-app CPU alerts, but no Pulse banner or Notification Centre entry appeared.
- Approval of the app quit confirmation, failure/timeout handling for server termination, and actual termination of an ordinary GUI app. The app quit and original-server stop dialogs were tested and cancelled to preserve user processes; the isolated server fixture was stopped successfully.
- Reconciliation of Pulse's per-app process totals with Activity Monitor's separate Web Content and Graphics/Media helper rows, plus resize/minimum-size and VoiceOver navigation. Full-screen, Minimize/restore, and Command-W close/reopen were exercised.
- Python Playwright interactions; Python Playwright is not installed, and no dependency was installed for this pass.
- x86_64 execution on Intel hardware; only the universal slice was statically verified on this Apple Silicon Mac.

See [QA_REPORT.md](../QA_REPORT.md) for automated checks, live collector measurements, signing, and packaging results, and [REMAINING_LIMITATIONS.md](../REMAINING_LIMITATIONS.md) for distribution and metric-scope limitations.
