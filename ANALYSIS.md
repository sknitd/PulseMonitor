# Recording analysis and recreation map

## Scope of the source

The supplied recording is approximately 34 seconds long, square, and 512 × 512 pixels. It is an edited product demonstration with scene changes, explanatory captions, and zoomed windows, rather than a complete walkthrough of every setting. The recording visibly identifies the original product as Vitals.

The observations below come from inspecting extracted frames across the clip. Exact internal algorithms, permissions, persistence, performance overhead, sensor availability and all possible error states cannot be established from a promotional recording alone. Those were explicitly designed for this recreation rather than presented as recovered original behavior.

## Visual structure

The full dashboard uses a compact top bar, icon-and-text pill navigation, generous white margins, rounded pale-gray cards, subdued secondary text and large dark metric values. CPU, memory, network, storage, GPU and battery are distinguished with category accents rather than large saturated backgrounds. Small charts make direction and recent activity visible without overwhelming the main values.

The screen hierarchy is overview first, then metric-specific detail and process/project lists. Memory breakdown rings, per-app totals, helper-process counts and listening ports make the data actionable. The menu-bar version uses the same categories in a narrow layout with fewer details and quick access back to the main window.

Pulse follows that hierarchy and visual language. Its name, icon, assets and implementation are new. The layout is adapted to a usable minimum desktop window width instead of copying text from a 512-pixel video frame. It is an independent recreation, not a byte-for-byte or pixel-perfect copy of unseen source code.

## Workflows and coverage

| Visible idea | Pulse implementation | Explicit boundary |
|---|---|---|
| One-glance system dashboard | Six metric cards, recent charts, breakdown rings and busiest apps | Fixture screenshots are labelled; installed app expects native readings |
| CPU and RAM views | Metric detail, summary statistics, searching and sorting | Different OS metrics may use different averaging intervals |
| App memory including helpers | Group by outer app bundle and ancestor app; expandable per-process list | Protected processes fall back to RSS or may be absent |
| Identify heavy applications | Group totals, process counts, per-app CPU, normal quit request | Does not invent an “energy impact” score or watts from CPU |
| Developer activity and ports | Recognized current-user TCP listeners, working directory and ports | A row is a listener process, not a whole project dependency tree |
| Find forgotten development servers | Observed low-CPU duration with “review stop” actions | Low CPU is not proof of disuse; no automatic cleanup |
| Menu-bar overview | AppKit status item and WebKit-backed native popover | Native popover positioning still needs a Mac test |
| Warn about a busy application | Configurable sustained CPU threshold and duration | Per-app CPU is measured in units of one core |
| Warn about increasing memory | Absolute-plus-relative growth over roughly five minutes | Described as growth, not a confirmed memory leak |
| Light dashboard aesthetics | Light, dark and system themes; matching category colors | Not original branding or proprietary artwork |

## Deliberate additions

The recreation adds explicit unavailable states, a no-internal-battery state, keyboard shortcuts, local JSON export, pause/resume, adjustable refresh interval, configurable alert thresholds, optional launch at login, optional Dock hiding, background-process visibility, a labelled browser-only fixture mode, and an interactive diagnostic helper.

Confirmation dialogs default to Cancel. Stopping developer servers sends SIGTERM only after a fresh identity/ownership check. Application quit is a normal quit request so the target may show a save prompt. Destructive operations are not executed in fixture mode.

## Telemetry decisions

Whole-system CPU uses differences between Mach CPU counters. System memory uses Mach VM counters and sysctl. Per-process memory prefers physical footprint with a clear RSS fallback. App grouping follows bundle paths and same-user parent chains. Disk capacity comes from the home volume; storage throughput comes from aggregate driver counters. Network rates come from physical `en*` interface byte deltas. Battery status comes from power-source APIs, with optional additional driver properties. Metal identifies the GPU device, but this build does not have a supported system-wide GPU utilization counter and shows an unavailable value.

It would be misleading to derive true per-app energy consumption from CPU or RAM alone. Pulse therefore uses “Busiest right now,” not a fabricated power-consumption panel. Hardware-dependent GPU, health, cycle, disk-I/O and pressure readings are explicitly unavailable when missing. Unavailable is not the same as zero.

## Security and data handling

There is no cloud service, login, subscription check, API key requirement, telemetry upload or self-updater. The privileged bridge is available only inside the local WebKit interface; remote navigation is rejected. Application/process names and paths are HTML-escaped. OS programs are invoked by absolute paths and argument arrays, without a shell. No root helper or automatic process-killing rule is installed.

Preferences persist locally; charts and alert history are in memory. Diagnostics and exports are explicit user actions and may contain private names and paths. The app is locally ad-hoc signed, not Developer ID-signed or notarized. The optional installer verifies that signature and does not remove quarantine or change Gatekeeper settings.

## What was validated, and what remains

Both arm64 and x86_64 executable slices compiled with a macOS 13.0 target. Static validation checks the fat container, slice bounds, system dependencies, entry point, minimum OS, ad-hoc code-page hashes and app resources. On 2026-09-24, 39 native logic checks and 12 JavaScript/UI logic checks passed; 95 bundle checks passed. The final executable returned live telemetry and matched `top` within about 2.5 percentage points in a concurrent sample. Python and Node server fixtures were found with correct PID, port, and Unicode/space-containing working directories and were cleaned up.

On 2026-09-25, the unlocked Mac session opened the rebuilt AppKit/WebKit bundle and rendered live data. The GUI pass covered all metric pages, process search/grouping, settings and persistence, login-item registration/removal, export, CPU and memory-growth alerts, full-screen, Minimize/restore, Command-W close/reopen, and a controlled server stop that exited on SIGTERM. Activity Monitor memory counters aligned closely for App Memory, wired, and compressed values. The reopened app retained live samples for more than 40 minutes. The native status-item popover/Dock visuals, actual Pulse notification delivery, GUI termination of an ordinary app, resize/minimum-size/VoiceOver, Playwright interaction suite, Intel execution, and notarized distribution remain unverified. A Minimize-menu target issue found during QA was fixed and verified in the rebuilt bundle. See `QA_REPORT.md` and `REMAINING_LIMITATIONS.md`. The older checked-in browser report is a fixture-only report from an earlier run and is not evidence for this final native build.
