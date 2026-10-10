# Project status

Fan Lever 0.1.0 build 5 has been built, signed, installed and exercised on an Apple Silicon MacBook Pro with an M5 Pro, running macOS 27.2. The deployment target is macOS 26. Other Mac models are unverified.

## Verified behavior

- Native small and medium desktop widgets with clickable fan notches.
- A readable small layout with separate full RPM readings and an Auto button.
- A windowless companion app; widget actions do not open a control window.
- Signed-peer XPC access to a privileged SMAppService helper.
- Fan-specific minimum/maximum target validation and read-back confirmation.
- Five-minute manual leases on battery and 30-minute leases on AC power. Unplugging shortens an active deadline; reconnecting does not extend it.
- A real five-minute battery lease returned both fans to automatic control at expiry.
- A real widget Max click set both targets to the reported 7,826 RPM limit; both fans reached approximately that speed and were subsequently returned to Auto.
- Release and Debug builds, 13 controller tests, and the built-artifact App Intent metadata check pass.
- Release excludes the development feedback implementation and control-window UI.

Widget RPM values are sampled and subject to macOS refresh budgets. The helper enforces deadlines independently of widget refreshes.

## Known issue

The widget gallery may retain a white placeholder app icon even when the installed app and extension contain the correct icon and macOS's normal icon lookup resolves it. Registration refreshes and widget-service restarts did not fix this on the tested system. A reboot has not been validated as a fix. Track further findings in [issue #1](https://github.com/StoneHub/fan-lever/issues/1).

## Widget action regression

Build 4 defined `SetFanIntent` only in the widget extension. macOS routed clicks to the running companion app and rejected them because its action metadata was missing. Build 5 moves the intent into shared source compiled by both targets. `scripts/check-app-intents.py` fails on the affected artifact and passes only when both bundles contain the background action and notch parameter. A real desktop-widget click verified the repair.

## Distribution

The repository is MIT-licensed source. The tested app uses local Apple Development signing. No notarized public binary release has been published.
