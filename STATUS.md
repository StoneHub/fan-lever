# Project status

Fan Lever 0.1.0 build 8 is the current preview download for Apple Silicon and macOS 26+. Its Release build and 19 controller tests pass, both bundles contain the fan-selection and timer App Intents, and the host/widget/helper signatures validate. The packaged host can read the existing approved helper over XPC. Other Mac models are unverified.

Earlier hardware acceptance on an M5 Pro MacBook Pro running macOS 27.2 verified the behavior below. Packaging this release did not repeat fan-setting writes or first installation on a separate Mac.

## Verified behavior

- Native small and medium desktop widgets with clickable fan notches.
- A readable small layout with separate full RPM readings and an Auto button.
- A windowless companion app; widget actions do not open a control window.
- Signed-peer XPC access to a privileged SMAppService helper.
- Fan-specific minimum/maximum target validation and read-back confirmation.
- Five-minute manual leases on battery and 30-minute leases on AC power. Unplugging shortens an active deadline; reconnecting does not extend it.
- A real five-minute battery lease returned both fans to automatic control at expiry.
- A real widget Max click set both targets to the reported 7,826 RPM limit; both fans reached approximately that speed and were subsequently returned to Auto.
- Earlier Release and Debug builds and 13 controller tests passed. The current Release build passes 19 controller tests and the expanded App Intent metadata check.
- Release excludes the development feedback implementation and control-window UI.

Widget RPM values are sampled and subject to macOS refresh budgets. The helper enforces deadlines independently of widget refreshes.

## Known issue

The widget gallery may retain a white placeholder app icon even when the installed app and extension contain the correct icon and macOS's normal icon lookup resolves it. Registration refreshes and widget-service restarts did not fix this on the tested system. A reboot has not been validated as a fix. Track further findings in [issue #1](https://github.com/StoneHub/fan-lever/issues/1).

## Widget action regression

Build 4 defined `SetFanIntent` only in the widget extension. macOS routed clicks to the running companion app and rejected them because its action metadata was missing. Build 5 moves the intent into shared source compiled by both targets. `scripts/check-app-intents.py` fails on the affected artifact and passes only when both bundles contain the background action and notch parameter. A real desktop-widget click verified the repair.

## Distribution

The repository is MIT-licensed. [0.1.0 preview](https://github.com/StoneHub/fan-lever/releases/tag/v0.1.0-preview.1) provides a DMG, ZIP, and SHA-256 checksums with installation and helper-approval instructions. Both archives preserve the checked Release app unchanged.

This is **Apple Development-signed and unnotarized**. Gatekeeper rejects it under the default policy; users who choose the preview need the per-app first-open exception described in [install help](docs/INSTALL.md#first-open). A normal public release needs a Developer ID identity for the same signing team, notarization, and acceptance on a separate Mac. The blocker, owners, and remaining checks are tracked in [issue #5](https://github.com/StoneHub/fan-lever/issues/5).

The README includes cropped screenshots of the installed desktop widget and the release disk image’s contents. Additional Light/Dark layout previews use sample readings; see [build help](docs/BUILD.md).
