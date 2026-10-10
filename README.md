# Fan Lever

A native macOS desktop widget with a glass lever and six clickable notches. Built for Monroe's Apple Silicon Mac; macOS 26 or newer.

| Notch | Action |
| --- | --- |
| Auto | Return both fans to macOS control |
| 1 | 40% of each fan's reported maximum |
| 2 | 55% |
| 3 | 70% |
| 4 | 85% |
| Max | 100% |

Manual targets are clamped to each fan's reported minimum/maximum. Every manual selection lasts 30 minutes, then returns to Auto. The helper also attempts Auto recovery after partial failure, serious/critical thermal pressure, orderly termination and crash relaunch. It does not write SMC diagnostic unlock keys. Other Mac models are unverified and may reject control.

## Use

1. Open **Fan Lever** in Applications.
2. Choose **Enable Fan Control** and approve the helper in macOS **Login Items & Extensions**. This is required for privileged hardware writes.
3. Control-click the desktop → **Edit Widgets** → **Fan Lever**, then add small or medium.
4. Click a notch. The lever reflects confirmed controller mode/target; RPM reports measured speed, which takes time to settle. Widget telemetry is sampled and may be several minutes old; the widget labels its sample age. Open the app for three-second updates.

The widget adopts macOS's system-controlled glass/tinted appearance. Notches are App Intent buttons, not a draggable slider. Clicking the widget background opens the companion app.

To remove the service, open the app and choose **Disable Helper**. It confirms Auto before unregistering. Removing the app without disabling the helper first is not the supported uninstall path.

## Build

Requires Xcode 27, XcodeGen and an Apple Development signing identity for the configured team.

```sh
xcodegen generate
swift test
xcodebuild -project FanLever.xcodeproj -scheme FanLever -configuration Release \
  -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
```

Set the signing team, app group and XPC signing requirement together when building for another developer. Do not remove XPC peer validation. This local build is not an App Store submission or notarized public release.

Development builds integrate DevFeedback at the revision recorded in `Vendor/DevFeedback/PROVENANCE.md`. Release omits its UI and implementation. Feedback covers the companion app; widget layouts must be checked in the actual widget host.

Read-only diagnostics:

```sh
'/Applications/Fan Lever.app/Contents/MacOS/Fan Lever' --probe
'/Applications/Fan Lever.app/Contents/MacOS/Fan Lever' --status
```

The signed host also supports `--select 0` through `--select 5` for explicitly authorized hardware acceptance testing. This changes real fan settings and requires the approved helper.
