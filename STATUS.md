# Fan Lever delivery status

Goal: native desktop widget, Liquid Glass appearance, clickable lever notches, actual Auto/Max fan control on Monroe's M5 Pro.

Implemented: app, small/medium WidgetKit extension, signed-peer XPC helper, direct SMC read/write adapter, read-back validation, manual timeout, recovery, and development feedback.

Verified: 10 core tests pass, including different per-fan limits, invalid data, partial failure, failed rollback retry, lease expiry, thermal pressure, invalid notch, ownership recording failure, external changes and recovery despite an RPM sensor read failure. Release and Debug builds succeed. The Release build has no feedback implementation/markers. Feedback runtime inspection found 18 independent app targets and confirmed picking the setup action opens feedback instead of enabling control; full History/export acceptance was not completed because computer-use lost track of the capture window.

Installed: /Applications/Fan Lever.app, version 0.1.0 build 2, signed by team N6GPP46885. Built and installed executable SHA-256 match: 046edf3c67695f2bf973bc32049498c16fa901c89473f3829f76de16fbb1f9f4. Strict bundle signature succeeds. One installed widget registration remains after unregistering development products. The user explicitly approved installation/helper access/Max-to-Auto testing and enabled the macOS background item.

Hardware acceptance: build 1 rejected immediate read-back and restored Auto. Build 2 waits up to 750 ms per mode/target read-back without reissuing writes. On 2026-10-09 at 22:06 EDT, Max set both targets to 7,826 RPM and mode 1. After eight seconds measured speeds were 7,825 and 7,837 RPM. Auto restored mode 0 for both; a later read confirmed targets had returned to system-selected values around 3,700/4,000 RPM. The approved helper remains enabled; fans were left on Auto.

Remaining: actual desktop-widget rendering and button-to-helper acceptance. The computer-use tool times out on Control Center and Notification Center, so Monroe has been asked to add the medium widget from Edit Widgets. Codex owns checking the resulting requests and fixing any widget errors. Private remote backup is being prepared.
