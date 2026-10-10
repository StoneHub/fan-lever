# Install Fan Lever

Apple Silicon, macOS 26 or later. Fan control has been tested on an M5 Pro MacBook Pro; other hardware is unverified. Macs without fans cannot use it.

## Download

Get the DMG from [GitHub Releases](https://github.com/StoneHub/fan-lever/releases/tag/v0.1.0-preview.1). Open it and drag **Fan Lever.app** onto **Applications**. A ZIP is available if you prefer: expand it, then move the app into Applications. Launch the copy in Applications, rather than the copy on the disk image.

The release also includes `SHA256SUMS.txt`. To verify a downloaded file, place the checksum file beside it and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

The checksum file lists both downloads. If you downloaded only one, the other will be reported as missing; your chosen file must report `OK`.

## First open

**The current release is a preview, signed with Apple Development and not notarized by Apple.** Gatekeeper does not accept it under its default policy. It has been tested locally; first installation on a separate Mac has not been verified.

If you choose to open this preview, launch the app once, then go to **System Settings → Privacy & Security** and look for **Open Anyway** for Fan Lever. Confirm the app’s name before proceeding. See [Apple’s instructions for opening apps safely](https://support.apple.com/en-us/102445). Managed Macs may prohibit this exception.

Fan Lever runs without a Dock icon or window. After opening it:

1. Control-click the desktop → **Edit Widgets** → **Fan Lever**.
2. Add a small or medium widget.
3. Click **Click to enable fan control**. This registers the privileged helper and opens the macOS approval settings when approval is needed.
4. Approve Fan Lever in **System Settings → General → Login Items & Extensions**. This helper needs permission to write fan settings.
5. Click a notch. The lever shows the confirmed setting; actual fan speed takes time to settle.

If the setup message remains, open `fanlever://setup` and check the helper’s approval. The widget gallery may show a placeholder icon; [issue #1](https://github.com/StoneHub/fan-lever/issues/1) tracks it.

## Controls

Auto returns control to macOS. Notches 1–4 request 40%, 55%, 70%, and 85% of each fan’s reported maximum; Max requests 100%. Targets are clamped to the fan’s reported minimum and maximum.

Manual settings expire after five minutes on battery or 30 minutes on AC power. Click **Auto in** to cycle to the next step below the remaining time: 30, 15, 10, 5, then 1 minute, wrapping to 30. Battery uses only 5 and 1. Unplugging limits the remaining time to five minutes; reconnecting does not extend it.

RPM values may be several minutes old because macOS controls widget refreshes. Click the widget background to request a refresh. Safety deadlines are enforced by the helper, independently of the display.

## Update

Click **Auto**, close the disk image if it is open, and replace the app in Applications with the new release. Open the updated app once. Keep its location in Applications so macOS can find the embedded helper. If setup is requested again, use the widget’s setup message.

## Uninstall

Disable the helper before removing the app. In Terminal:

```sh
'/Applications/Fan Lever.app/Contents/MacOS/Fan Lever' --disable-helper
```

This must succeed: it confirms Auto before unregistering the service. Then remove the desktop widget and move Fan Lever.app to the Trash. If disabling fails, keep the app installed and resolve the error first.

[Monroe’s website](https://monroes.space) · [Report an issue](https://github.com/StoneHub/fan-lever/issues)
