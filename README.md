# Pulse Monitor

Pulse Monitor is an independent macOS system-monitoring app built from this source tree. It is not the Vitals app and is not affiliated with its developer.

## Requirements and installation

- macOS 13 or later. The bundled executable contains arm64 and x86_64 slices.
- The app itself has no third-party runtime dependency. Building from source needs Xcode Command Line Tools and the macOS SDK.
- Build and package the app from source using the commands below. Then unzip `dist/PulseMonitor-macOS13-Universal.zip` and move `Pulse Monitor.app` to `/Applications` or `~/Applications` if desired.

This build is ad-hoc signed. No Developer ID identity was available and it has not been notarized. The recorded Gatekeeper assessment rejected the bundle. A local ad-hoc signature proves only that the bundle's code matches its signature; it does not identify a publisher. Review the source and QA report before deciding whether to open it. Do not disable Gatekeeper or remove quarantine attributes to make it run. Apple's supported user decision flow is described in [Open an app from an unidentified developer](https://support.apple.com/en-us/102445).

The optional `Install Pulse Monitor.command` copies the app beside itself into `~/Applications` after the user types `INSTALL`, verifies the existing signature, and asks macOS to open it. It does not remove quarantine, change Gatekeeper settings, or request administrator access.

Closing the main window hides it while the menu-bar item keeps running. Use Command-Q or the Pulse Monitor menu to quit. Alerts and launch at login start off.

## Features

- Live CPU utilization from Mach tick deltas; logical cores and load averages.
- Memory summary from Mach VM counters, plus per-process physical footprint where readable and RSS fallback otherwise.
- Searchable and sortable app groups with helper processes, optional background group, and a normal application quit request.
- Home-volume capacity and aggregate storage-device read/write rates when counters are available.
- Traffic rates and session totals from physical `en*` interfaces; no packet inspection or per-app network attribution.
- Battery data when macOS exposes an internal battery; otherwise the app shows no battery.
- Metal device name and unified-memory information. System-wide GPU utilization, temperature, watts, and VRAM are not fabricated.
- Current-user development runtimes with TCP listening ports, verified PID association, best-effort working directory, resource use, and uptime.
- Confirmation before a server stop. The app rechecks user, executable path, process start time, and port ownership, then sends SIGTERM. It never force-kills a server.
- Menu-bar popover, adjustable sampling interval, pause/resume, system/light/dark theme, optional Dock hiding, launch-at-login via SMAppService, sustained CPU and memory-growth alerts, and local JSON export.

## Measurement notes

Whole-system CPU is normalized to 0–100%. Per-app CPU is macOS's smoothed `ps` value; one logical core is 100%, so multithreaded apps can exceed 100%. The first sample is unavailable until a second tick exists.

The memory-used figure estimates app, wired, and compressed memory from Mach counters. It is not the sum of app rows. Shared pages and restricted processes make per-app totals differ from Activity Monitor. Available memory is an estimate, not a promise about immediately allocatable memory. Pressure labels follow the macOS/XNU levels; kernel-only Jetsam is shown separately from Critical.

Disk capacity is for the volume containing the home directory. Read/write rates are aggregate storage-driver counters, not per-volume or per-process attribution. Network rates sum physical `en*` interface counters and exclude loopback and VPN interfaces.

Server recognition is based on a current-user listening process whose executable path matches a supported runtime name (Node, Python, Bun, Deno, Ruby, Java, PHP, Go, uvicorn/gunicorn, Vite, or next-server). It does not discover every compiled server, container, UDP-only service, remote host, or full dependency tree. A low CPU label is an observation, not evidence that a server is unused. A port shortcut assumes HTTP. A working directory can be unavailable when macOS or `lsof` cannot provide it.

## Repository layout

- `native/` — Objective-C app lifecycle, macOS collectors, and shared logic.
- `ui/` — WebKit dashboard, styling, and the explicitly labeled demo fixture.
- `packaging/` — installer and opt-in diagnostic commands.
- `tests/` — native and UI logic checks, bundle validation, and the Mac acceptance record.
- `QA_REPORT.md` and `REMAINING_LIMITATIONS.md` — current verification results and known constraints.

## Privacy

Sampling runs locally under the current user. Pulse makes no telemetry uploads, API calls, or account connections. It does not request Accessibility, Full Disk Access, Screen Recording, camera, or microphone permission. Protected process details may be unavailable.

Settings are stored in macOS preferences. Up to 600 history points and 50 alerts stay in memory and clear at quit. A JSON export includes process names, PIDs, app paths, local project directories, ports, and current metrics; review it before sharing. The optional diagnostic command also includes local process and path details and waits for explicit confirmation before writing a file.

## Build and package

Clone the repository and build on a Mac with Xcode Command Line Tools:

```bash
git clone https://github.com/sknitd/PulseMonitor.git
cd PulseMonitor
bash build-mac.sh
bash package-mac.sh
```

The app and archive are written to `dist/`. `build-mac.sh` compiles both architectures against Apple's SDK with a macOS 13.0 deployment target, creates the bundle, applies an ad-hoc signature, and verifies it. It refuses to overwrite an existing `.app`; choose a new output directory or move the prior build yourself. `package-mac.sh` stages the app and documentation into `PulseMonitor-macOS13-Universal.zip`.

## Tests and QA

Run the native Foundation logic suite and JavaScript/UI logic suite with:

```bash
bash tests/run_tests.sh
```

The browser interaction suite runs only when Python Playwright is already installed; the test runner does not install it. Current verified results and the uncompleted macOS GUI checks are listed in [QA_REPORT.md](QA_REPORT.md) and [tests/MAC_ACCEPTANCE.md](tests/MAC_ACCEPTANCE.md). Genuine remaining constraints are in [REMAINING_LIMITATIONS.md](REMAINING_LIMITATIONS.md).

Build outputs under `dist/` are local artifacts and are excluded from the source repository. Attach the ZIP as a GitHub Release asset when publishing a downloadable build.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
