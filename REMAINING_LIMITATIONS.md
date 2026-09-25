# Remaining limitations

## Verification still needed

- The native status-item popover and Dock icon visibility were not visually verified. Menu-bar mode toggled on and off in the app, but the desktop automation surface could not address the macOS status-item or Dock UI.
- Pulse's in-app sustained CPU alerts fired. Notification permission was switched on in System Settings for a second alert test, but no Pulse banner or Notification Centre entry was observed. System notification delivery remains unverified; the permission was restored to Off afterward.
- CPU and memory-growth alerts both fired in GUI tests. Cooldown logic passed unit tests, but repeated-trigger suppression was not stress-tested through a prolonged GUI run.
- The server-stop control successfully sent SIGTERM to a temporary test server and the process exited. Failure/timeout handling and GUI termination of an ordinary app were not exercised.
- Full-screen, Minimize/restore, and Command-W close/reopen were verified on the rebuilt `dist` bundle. Resize/minimum-size and VoiceOver navigation still need direct verification.
- The Pulse parent process stayed roughly 37–46 MiB across sampled GUI sessions, but helper-process memory growth and wakeups were not measured from a controlled baseline.
- The Python Playwright interaction suite did not run because Playwright is not installed. The native and JavaScript logic suites passed without installing dependencies.
- Pulse's system-memory summary was compared near-concurrently with Activity Monitor: App Memory was 5.47 GiB versus 5.54 GB, Wired was 3.31 GiB versus 3.31 GB, and Compressed was 6.14 GiB versus 6.13 GB. Units and sample times differ; per-app totals are approximate, and Activity Monitor showed Pulse's Web Content and Graphics/Media helpers as separate processes.
- The x86_64 slice is present and statically verified, but this Apple Silicon Mac cannot exercise it on Intel hardware.

## Distribution status

- The app is ad-hoc signed. This Mac has no valid Developer ID or Apple Development signing identity, and no notarization was submitted. The recorded `spctl` assessment rejected the app. A trusted Developer ID build and Apple notarization are needed for normal Gatekeeper acceptance on other Macs.

## Metric scope

- macOS/Metal device discovery works, but this build has no reliable public system-wide GPU utilization, GPU temperature, VRAM usage, or GPU power counter. Those readings are shown as unavailable.
- CPU totals use tick deltas; process CPU is macOS's smoothed `ps` percentage with one logical core equal to 100%. They can differ because sampling windows and accounting differ.
- Process physical footprint may be unavailable for protected processes and then uses RSS. Process grouping is best-effort and shared pages can make app totals differ from system memory totals.
- Disk capacity describes the home volume; read/write rates aggregate storage-driver counters. Network rates sum physical `en*` interfaces and do not attribute traffic to apps.
- Server discovery is limited to current-user TCP listeners whose executable path matches a recognized runtime. Compiled servers with other names, containers, UDP-only listeners, and remote services may not appear. Low CPU is not evidence that a server is unused.
