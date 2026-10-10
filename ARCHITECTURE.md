# Control boundary

The WidgetKit extension renders the lever and exposes six App Intent buttons. The app and widget call a fixed NSXPC interface on `space.monroe.FanLever.helper`. No client can supply a shell command, filesystem path, arbitrary SMC key or arbitrary RPM. Requests are serialized. The helper accepts only values 0–5, discovers fan limits, validates targets and reads back mode/target before returning selection state. The Auto timer call takes no value: the helper moves its own deadline to the next fixed step below the time left (30, 15, 10, 5, 1 minutes, wrapping to the top), never beyond the current power source's lease, and only while it owns a manual boost. Snapshots advertise `canCycleTimer`; a helper that predates the call omits it, so the widget leaves the countdown unclickable until the updated helper runs.

The daemon uses Apple's SMAppService registration/approval flow. XPC validates the team and exact app/widget identifiers at the listener, and clients require the exact signed helper identifier. The widget has a scoped Mach service lookup exception. This is a locally distributed utility, not an App Store entitlement claim.

The helper records override ownership in a root-owned, no-follow recovery marker before writes. It attempts to restore Auto on the five-minute battery / 30-minute AC deadline, serious/critical thermal pressure, partial-write failure and termination. On crash relaunch, it restores Auto only if its marker exists. Repeated recovery failures remain visible and are retried. There is no promise of recovery while the system or hardware itself is unresponsive.

Snapshot JSON in the app group is presentation cache, never a command channel. The helper returns actual fan mode, actual RPM and target RPM. A cached selected notch is not authoritative for hardware control. Widget refreshes are scheduled every five minutes and after user actions, subject to macOS's reload budget; the windowless host listens for power-source changes and requests a refresh after the helper has adjusted its deadline. It does not poll. The helper independently checks power every two seconds, so timeout enforcement does not depend on widget refresh or the host remaining alive. No new login agent was added.

## Hardware scope and provenance

The 80-byte AppleSMC IOKit packet format and key names were checked against the primary implementations/research below. The C transport here is a minimal implementation with exact layout assertions, firmware-result checks, size/type validation, and a restricted Swift fan API. It probes both `F0md` and `F0Md` mode-key forms at runtime. It never disables thermalmonitord or writes `Ftst`.

- https://github.com/exelban/stats/blob/master/SMC/smc.swift
- https://github.com/agoodkind/macos-smc-fan/blob/main/docs/research.md
- https://developer.apple.com/documentation/servicemanagement/smappservice
- https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
- https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass

Fan control uses an undocumented hardware interface. Compile success and successful sensor reads do not prove privileged writes or visible desktop-widget interaction; those acceptance gates are recorded separately in STATUS.md.

## Widget action routing

`Shared/SetFanIntent.swift` belongs to both the app and widget targets. macOS can route a widget click to the running windowless host, so both bundles must contain generated `SetFanIntent` metadata. `scripts/check-app-intents.py` verifies the built artifacts, including the notch parameter and background execution. Widget-only membership compiled successfully but caused clicks to fail with “There is no metadata for SetFanIntent” when routed to the host.
