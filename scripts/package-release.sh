#!/bin/bash
# Package an already-built, signed Release product. Never register the helper here.
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 || ( $# -eq 4 && "$4" != --preview ) ]]; then
  echo "Usage: $0 <built-app> <output-directory> <release-version> [--preview]" >&2
  exit 2
fi

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_path="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
release_version="$3"
preview=false
[[ $# -eq 4 ]] && preview=true
if [[ ! "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
  echo "Invalid release version" >&2
  exit 2
fi
if [[ "$preview" == true && "$release_version" != *-preview.* ]]; then
  echo "Development-signed downloads must use a -preview.* version" >&2
  exit 2
fi

python3 - "$app_path" "$release_version" <<'PY'
import pathlib, plistlib, subprocess, sys
app = pathlib.Path(sys.argv[1])
with (app / 'Contents/Info.plist').open('rb') as f:
    info = plistlib.load(f)
assert info['CFBundleIdentifier'] == 'space.monroe.FanLever'
assert sys.argv[2].split('-')[0] == info['CFBundleShortVersionString']
assert info['LSMinimumSystemVersion'] == '26.0'
assert info['LSUIElement'] is True
assert subprocess.check_output(['lipo', '-archs', str(app / 'Contents/MacOS/Fan Lever')], text=True).strip() == 'arm64'
print(f"Packaging Fan Lever {info['CFBundleShortVersionString']} build {info['CFBundleVersion']}")
PY

codesign --verify --deep --strict --verbose=2 "$app_path"
expected_team="$(python3 - "$repo_dir/project.yml" <<'PY'
import pathlib, re, sys
match = re.search(r'^\s+DEVELOPMENT_TEAM: ([A-Z0-9]+)$', pathlib.Path(sys.argv[1]).read_text(), re.M)
assert match, 'Missing signing team in project.yml'
print(match[1])
PY
)"
for binary in "$app_path" "$app_path/Contents/PlugIns/FanLeverWidget.appex" "$app_path/Contents/Library/LaunchServices/FanLeverHelper"; do
  codesign --verify --strict "$binary"
  signing_info="$(codesign -d --verbose=4 "$binary" 2>&1)"
  if ! /usr/bin/grep -q "^TeamIdentifier=$expected_team\$" <<< "$signing_info"; then
    echo "Signing team does not match the configured XPC/app-group team: $binary" >&2
    exit 1
  fi
done
python3 "$repo_dir/scripts/check-app-intents.py" "$app_path"
symbols="$(nm -gj "$app_path/Contents/MacOS/Fan Lever")"
if /usr/bin/grep -Eq 'FeedbackSession|FeedbackWindowBridge|FeedbackRecord|FanControlView|FanLeverApp' <<< "$symbols"; then
  echo "Development-only implementation found in Release executable" >&2
  exit 1
fi
if [[ "$preview" != true ]]; then
  spctl --assess --type execute --verbose=2 "$app_path"
fi

mkdir -p "$2"
output_dir="$(cd "$2" && pwd)"
artifact_name="Fan-Lever-${release_version}-macOS-arm64"
for file in "$output_dir/$artifact_name.dmg" "$output_dir/$artifact_name.zip" "$output_dir/SHA256SUMS.txt"; do
  if [[ -e "$file" ]]; then
    echo "Refusing to overwrite $file" >&2
    exit 1
  fi
done
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/fan-lever-package.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
ditto "$app_path" "$stage_dir/Fan Lever.app"
ln -s /Applications "$stage_dir/Applications"
cp "$repo_dir/LICENSE" "$stage_dir/LICENSE.txt"
cp "$repo_dir/THIRD_PARTY_NOTICES.md" "$stage_dir/THIRD_PARTY_NOTICES.md"
python3 - "$stage_dir/Read Me.html" "$release_version" "$preview" <<'PY'
import pathlib, sys
preview = sys.argv[3] == 'true'
notice = ('<aside><strong>Unnotarized preview.</strong> Signed with Apple Development. '
          'If you choose to open it after macOS blocks it, use System Settings → Privacy &amp; Security → Open Anyway for Fan Lever. '
          '<a href="https://support.apple.com/en-us/102445">Apple’s first-open guide</a>.</aside>') if preview else ''
pathlib.Path(sys.argv[1]).write_text('''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Install Fan Lever</title>
<style>body{font:17px/1.6 system-ui,sans-serif;max-width:660px;margin:64px auto;padding:0 28px;color:#182525;background:#f4f8f7}h1{font-size:44px;line-height:1.1;margin-bottom:12px}h2{font-size:23px}a{color:#006b73}aside{background:#e2edeb;padding:18px;border-radius:16px;margin:28px 0}li{margin:12px 0}code{font-size:13px;overflow-wrap:anywhere}footer{margin-top:36px}</style>
<h1>Fan Lever</h1><p>A little more breeze. One click from your desktop.</p>
<p>VERSION · Apple Silicon · macOS 26+</p>NOTICE
<h2>Make yourself at home</h2><ol>
<li>Drag <strong>Fan Lever.app</strong> onto <strong>Applications</strong>.</li>
<li>Open Fan Lever from Applications once. It runs without a window or Dock icon.</li>
<li>Control-click the desktop → <strong>Edit Widgets</strong> → <strong>Fan Lever</strong>. Add small or medium.</li>
<li>Click the widget’s setup message and approve the Fan Lever helper in <strong>System Settings → General → Login Items &amp; Extensions</strong>.</li></ol>
<p>Click a notch to boost the fans. Click Auto to hand cooling back to macOS. Manual settings expire after five minutes on battery or 30 minutes plugged in.</p>
<p>Tested on an M5 Pro MacBook Pro. Other Macs are unverified and may reject fan control. Widget RPM readings are sampled.</p>
<h2>Removing Fan Lever</h2><p>Confirm Auto and disable the helper before deleting the app. In Terminal:</p>
<p><code>'/Applications/Fan Lever.app/Contents/MacOS/Fan Lever' --disable-helper</code></p>
<p>Only after that command succeeds, remove the widget and move the app to Trash.</p>
<footer>Made by <a href="https://monroes.space">Monroe Stone</a> · <a href="https://github.com/StoneHub/fan-lever/blob/main/docs/INSTALL.md">Setup help</a> · <a href="https://github.com/StoneHub/fan-lever/issues">Report an issue</a></footer></html>
'''.replace('VERSION', sys.argv[2]).replace('NOTICE', notice))
PY

hdiutil create -volname "Fan Lever" -srcfolder "$stage_dir" -format UDZO "$output_dir/$artifact_name.dmg"
rm "$stage_dir/Applications"
ditto -c -k --sequesterRsrc "$stage_dir" "$output_dir/$artifact_name.zip"
(cd "$output_dir" && shasum -a 256 "$artifact_name.dmg" "$artifact_name.zip" > SHA256SUMS.txt)
echo "Created DMG, ZIP, and SHA256SUMS.txt in $output_dir"
