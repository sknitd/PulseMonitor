# Pulse Monitor QA Report

**Run date:** 2026-09-25

**Device:** Apple Silicon Mac, macOS 14.4, arm64

**Build:** Apple SDK build, universal arm64 + x86_64, minimum macOS 13.0, locally ad-hoc signed

The native collector was run from the final bundle in `--diagnose` mode, and the packaged `.app` was subsequently opened in the unlocked desktop through the native app surface. Its AppKit/WebKit window rendered live data without a blank view or launch-time crash. The GUI pass exercised the metric pages, process grouping/expansion, settings, pause/resume, project-stop confirmation, export save panel, normal quit/reopen, theme and refresh changes, and real Login Items registration/removal. A status-item popover was not accessible through the desktop automation surface. The Python Playwright suite remains skipped because that dependency is not installed.

After that GUI pass, the native Window menu exposed **Minimize** as disabled. The source now creates the menu after the window and targets the Close and Minimize actions directly to that `NSWindow`. The rebuilt universal `dist` bundle passes the 39 native, 12 JavaScript/UI, and 95 static bundle checks. In the rebuilt app, Minimize was enabled, minimized the window, and Pulse Monitor → Open Pulse Monitor restored a single standard window.

## Verification summary

- `bash build-mac.sh`: passed for arm64 and x86_64 with Apple's installed SDK; no compiler warnings were emitted.
- `tests/validate_bundle.py`: **95 passed, 0 failed**. Both slices are present and target macOS 13.0. The app bundle resources and code-page hashes passed static checks.
- `bash tests/run_tests.sh`: **39 native logic checks passed, 0 failed; 12 JavaScript/UI logic checks passed, 0 failed**. Chromium interaction tests were skipped because Python Playwright is unavailable; no dependencies were installed.
- Live CPU comparison: Pulse and `top` readings were within 2.5 percentage points in a near-concurrent sample; sampling windows differ.
- A live sample returned valid CPU, memory, disk, network, battery, process, project, and thermal data. System-wide GPU utilization remained null while Metal identified the device.
- Disposable Python `http.server` and Node HTTP fixtures were discovered from the final executable. Both ports mapped to their actual PIDs, and both exact working directories were recovered with spaces and non-ASCII characters. The harness sent SIGTERM to both fixtures and removed the temporary directory.
- Initial live GUI pass on 2026-09-25: all dashboard sections showed current samples; GPU utilization remained unavailable. CPU/memory app groups expanded to process rows with PIDs. The Projects page found existing local servers with matching PIDs, ports, and working directories. The stop-review dialog explained that low CPU does not prove a server is unused; it was cancelled, so existing servers were left running.
- Tested server termination with a separate temporary Python HTTP server. The per-server review identified only the selected fixture and explained that it sends SIGTERM. After approval, Pulse reported one termination request and zero skipped/denied; the row disappeared and the fixture exited. Other listed servers were left running.
- GUI settings changed from 2 s to 5 s and back, and System/Light/Dark appearance switched and restored. Pause and resume changed the live-status control. Settings survived a normal quit/reopen. The first GUI session ran for about 20 minutes; after reopening, live history continued for more than 40 minutes. The parent process footprint stayed roughly 37–46 MiB in observed samples; sampled parent CPU readings stayed below 1%. Activity Monitor showed separate WebKit helper processes using additional memory. No sustained increase in the parent process was observed, but helper growth was not tracked from a controlled baseline.
- Native window behavior: full-screen entry and exit worked. Command-W closed the main window while Pulse remained running; Pulse Monitor → Open Pulse Monitor reopened one main window.
- Near-concurrent system memory comparison: Pulse's app, wired, and compressed estimates were close to Activity Monitor's values, accounting for differing units and sampling times.
- The app's Login Items toggle created one real `Pulse Monitor` entry in System Settings and macOS showed its “Login Item Added” notification. Disabling it removed the entry. The app notification switch was enabled for a test and restored to Off afterward.
- Sustained CPU alerts were exercised and appeared in Pulse's alert history. A temporary, isolated app fixture grew its memory use; Pulse described the growth and stated that it is not proof of a leak. With notifications allowed, further CPU alerts appeared in the app history. No Pulse banner or Notification Centre entry was observed, so system notification delivery is not considered verified. Alerts were turned Off and the test history cleared afterward; the fixture and its temporary bundle were removed.
- The native NSSavePanel wrote a live snapshot to a temporary location. The file parsed as JSON, had a valid ISO 8601 timestamp, numeric project PIDs, the expected metric keys, and null GPU utilization. The temporary export was removed after verification.
- `codesign --verify --deep --strict --verbose=2`: passed for the app bundle.
- `security find-identity -v -p codesigning`: **0 valid identities found**.
- `spctl --assess --type execute -vv`: **rejected**. This is an ad-hoc build with no Developer ID identity or notarization.

## Feature results

| Feature | Tested | Result | Notes |
|---|---|---|---|
| Launch | Yes | Packaged `.app` opened and rendered live WebKit content | Reopened normally after a native Quit; no blank view or launch-time crash observed. |
| Window UX | Partial | Full-screen entered/exited; Minimize/restore, Command-W close/reopen, and Command-comma Settings all worked | Resize/minimum-size and VoiceOver remain unverified. |
| CPU | Yes | Live reading was within 2.5 percentage points of `top` | Two-second Mach tick delta; per-app and total CPU use different sampling semantics. |
| Memory | Yes | Live app, wired, and compressed estimates were checked near-concurrently against Activity Monitor | Values were close, accounting for unit and sampling-time differences; process totals remain approximate. |
| Disk | Yes | Home-volume capacity and I/O sample returned | I/O is aggregate storage-device activity. |
| Network | Yes | Physical `en*` interfaces returned live counters | No packet inspection; VPN and loopback are excluded. |
| Battery | Yes | Internal battery and power state returned | Charge, cycle count, health, and remaining time appear when macOS provides them. |
| GPU availability | Yes | Utilization remained unavailable | Device identification works; no fabricated system-wide utilization is shown. |
| Processes | Partial | Live GUI table showed app groups, process counts, CPU/memory, and PID rows after expansion; Activity Monitor showed separate app helper processes | Exact per-app grouped totals were not reconciled to Activity Monitor's helper process tree; attribution remains best-effort. |
| Process grouping | Yes | App groups sorted by CPU/memory and expanded into process rows | Unit tests cover same-user helper attribution and cross-user separation. |
| Developer ports | Yes | Python and Node fixtures detected | Actual PID and TCP port associations matched. |
| Working directory | Yes | Exact fixture directories detected | Verified spaces and UTF-8 names; lsof escape decoding has a unit test. |
| App quit | Yes | Normal Quit menu action terminated Pulse; reopening worked. A process quit confirmation was also shown and cancelled. | The process action explains that Pulse requests a normal quit and does not force-kill. Critical system apps and Pulse are excluded by policy. |
| Server stop | Partial | A temporary Python HTTP server was reviewed and stopped through the control; the fixture exited on SIGTERM | Process, port, and working-directory checks matched. Other servers were not stopped. Failure/timeout handling and any force-stop path were not exercised. |
| Menu bar | Partial | Menu-bar mode toggle changed and restored successfully | The status item/popover could not be opened or visually inspected through the available desktop automation surface. |
| Dock visibility | Partial | Menu-bar mode toggle changed activation-policy preference and restored it | Dock icon presence and recovery after relaunch were not independently observed. |
| Launch at login | Yes | One Pulse Monitor entry appeared in System Settings and disappeared when disabled | macOS displayed “Login Item Added”; no reboot/relogin was performed. |
| Alerts | Partial | A sustained CPU alert and a 768 MiB app-memory growth alert both appeared in Pulse history | The memory alert fired after about five minutes and used non-diagnostic wording. Alert history was cleared and settings restored Off with 80%/60 s CPU defaults and a 512 MiB growth threshold; cooldown behavior passed unit tests but GUI spam suppression was not stress-tested. |
| Notifications | Partial | Pulse notification permission was switched Off → On → Off; alert events appeared in Pulse | No Pulse banner or Notification Centre entry was observed, so delivery remains unverified. |
| Settings | Yes | Appearance, refresh interval, alert settings, Dock mode, and login item changed; defaults restored | System appearance, 2 s refresh, alerts Off, Dock mode Off, login item Off. Persistence was checked after quit/reopen. |
| JSON export | Yes | Native save panel wrote and parsed a live JSON snapshot | ISO timestamp, schema, numeric PIDs, and null GPU value checked; temporary file removed. |
| Themes | Yes | System, Light, and Dark selected and rendered | Restored System appearance; system appearance itself was not changed. |
| Universal architecture | Yes | arm64 and x86_64 slices verified | The Mac is Apple Silicon; x86_64 execution on Intel hardware was not possible. |
| Final ZIP | Yes | Extracted app verifies and contains both slices | `unzip -t`, extracted-bundle codesign verification, and lipo architecture verification passed. |
| Code signing | Yes | Ad-hoc signature verifies | No Apple Development or Developer ID identity is installed. |
| Gatekeeper assessment | Yes | Rejected | No notarization; Gatekeeper settings were not changed. |
| Long-run stability | Partial | First GUI session ran about 20 minutes; the reopened session retained live samples for more than 40 minutes | Parent process footprint stayed roughly 37–46 MiB in observed samples. WebKit helpers used additional memory; their growth was not measured from a controlled baseline. Wakeups were not measured. |

## Automated checks

The native suite covers CPU deltas and wraparound, memory pressure and thermal labels, bounded history, runtime/port parsing, process identity and grouping, settings normalization and persistence, alert timing/cooldown, bridge validation, and export schema. The JavaScript suite covers formatting, null/unavailable data, chart names, GPU and disk empty states, and project control labels.

The 95 static bundle checks include binary architecture, deployment target, system framework dependencies, signature hashes, bundle resources, and the production Content Security Policy. They do not substitute for GUI launch, Gatekeeper acceptance, notarization, or Intel hardware testing.
