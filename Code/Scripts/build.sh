#!/bin/bash
set -euo pipefail
code_root="$(cd "$(dirname "$0")/.." && pwd)"
project_root="$(cd "$code_root/.." && pwd)"
python3 "$code_root/Scripts/generate_placeholder.py"
swift build --build-system native --package-path "$code_root" -c release
binary_dir="$(swift build --build-system native --package-path "$code_root" -c release --show-bin-path)"
app_path="$code_root/build/TypingPianoProbe.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_dir/TypingPianoProbe" "$app_path/Contents/MacOS/TypingPianoProbe"
cp "$project_root/contracts/keymap.ansi64.v0.1.json" "$app_path/Contents/Resources/"
cp "$code_root/Assets/placeholder-original.sf2" "$app_path/Contents/Resources/"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TypingPianoProbe</string>
<key>CFBundleIdentifier</key><string>local.typingpiano.probe</string>
<key>CFBundleName</key><string>Typing Piano M0 Probe</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.0.1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Only our reproducible generated bundle. Desktop file-provider FinderInfo can prevent ad-hoc signing.
# A file provider can add FinderInfo to a newly created signature directory.
# Retry only the generated-bundle signature, bounded; never change system preferences.
probe_signed=false
for attempt in 1 2 3; do
    xattr -cr "$app_path"
    if codesign --force --sign - "$app_path" && codesign --verify --strict "$app_path"; then
        probe_signed=true
        break
    fi
done
if [ "$probe_signed" != true ]; then
    printf '%s\n' 'Local generated-bundle signing failed after 3 attempts.' >&2
    exit 1
fi
# Metadata-free local archive preserves signed bytes if the host later adds FinderInfo.
ditto --norsrc --noextattr --noacl -c -k --keepParent "$app_path" "$code_root/build/TypingPianoProbe.zip"
printf '%s\n' "$app_path"
