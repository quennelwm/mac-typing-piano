#!/bin/bash
set -euo pipefail
code_root="$(cd "$(dirname "$0")/.." && pwd)"
project_root="$(cd "$code_root/.." && pwd)"
build_root="${TYPING_PIANO_BUILD_ROOT:-$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.8}"
mkdir -p "$build_root"
build_root="$(cd "$build_root" && pwd)"
if [ "$build_root" = "$HOME/Library/Caches/local.typingpiano.trial" ]; then
    printf '%s\n' 'Refusing to overwrite the authorized frozen trial. Use an independent candidate directory.' >&2
    exit 1
fi
case "$build_root" in
    "$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.4"|"$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.5"|"$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.6"|"$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.7")
        printf '%s\n' 'Refusing to overwrite a frozen historical candidate.' >&2
        exit 1 ;;
esac
scratch_path="$build_root/swiftpm"
# The checked-in original bank is verified below; building does not regenerate source assets.
python3 - "$code_root/Assets/placeholder-original.sf2" <<'PY'
import hashlib, pathlib, sys
p = pathlib.Path(sys.argv[1])
assert hashlib.sha256(p.read_bytes()).hexdigest() == "ded7747105075d3b5ed95fed7a0453f638dd27882b80defd1fcc7062c4c700fb"
PY
swift build --build-system native --package-path "$code_root" --scratch-path "$scratch_path" -c release
binary_dir="$(swift build --build-system native --package-path "$code_root" --scratch-path "$scratch_path" -c release --show-bin-path)"
app_path="$build_root/打字钢琴试用.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_dir/TypingPianoProbe" "$app_path/Contents/MacOS/TypingPianoProbe"
cp "$project_root/contracts/keymap.ansi64.playable.v0.2.json" "$app_path/Contents/Resources/"
cp "$code_root/Assets/placeholder-original.sf2" "$app_path/Contents/Resources/"
cp "$code_root/Assets/PLACEHOLDER-LICENSE.txt" "$app_path/Contents/Resources/"
cp "$project_root/Design/UI/SOURCE_AND_LICENSE.md" "$app_path/Contents/Resources/UI-SOURCE-AND-LICENSE.md"
python3 - "$project_root/Design/UI" <<'PYUI'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
manifest = json.loads((root / 'delivery-manifest.json').read_text())
assert manifest['version'] == 'quiet-ivory-u001.0.3'
for item in manifest['files']:
    path = (root / item['path']).resolve()
    assert path.is_relative_to(root.resolve())
    assert path.stat().st_size == item['byteSize']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256']
PYUI
cp "$project_root/Design/UI/theme.candidate.json" "$app_path/Contents/Resources/"
python3 - "$project_root/Design/UI/U-031/reference.json" <<'PYCRYSTAL'
import hashlib, pathlib, sys
assert hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest() == "af135ac20b05c1ac7cd8200765f8cfcc1b257ec16a22a892652ed50e6ccfbdca"
PYCRYSTAL
cp "$project_root/Design/UI/U-031/reference.json" "$app_path/Contents/Resources/crystal-reference.json"
cp "$project_root/Design/UI/U-031/MATERIAL_RECIPE.md" "$app_path/Contents/Resources/CRYSTAL-MATERIAL-RECIPE.md"
python3 - "$project_root/Design/Audio/probes/A-001B" <<'PYVERIFY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
index = json.loads((root / 'trial-index.json').read_text())
assert index['artifactState'] == 'candidate'
for trial in index['trials']:
    folder = (root / trial['manifestFile']).parent
    manifest = json.loads((root / trial['manifestFile']).read_text())
    for item in manifest['files']:
        path = (folder / item['path']).resolve()
        assert path.is_relative_to(folder.resolve())
        assert path.stat().st_size == item['byteSize']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256']
PYVERIFY
mkdir -p "$app_path/Contents/Resources/AudioCandidates"
cp -R "$project_root/Design/Audio/probes/A-001B/." "$app_path/Contents/Resources/AudioCandidates/"
python3 - "$project_root/Design/Audio/trial/A-002T" "$project_root/docs/handoffs/A-002T.md" <<'PYTRIAL'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
assert pathlib.Path(sys.argv[2]).is_file(), 'A-002T handoff required'
index = json.loads((root / 'trial-index.json').read_text())
assert index['artifactState'] == 'candidate'
for trial in index['trials']:
    assert trial['coverageMIDI'] == list(range(33,97))
    folder = (root / trial['manifestFile']).parent
    manifest = json.loads((root / trial['manifestFile']).read_text())
    for item in manifest['files']:
        path = (folder / item['path']).resolve()
        assert path.is_relative_to(folder.resolve())
        assert path.stat().st_size == item['byteSize']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256']
PYTRIAL
mkdir -p "$app_path/Contents/Resources/AudioTrial"
python3 - "$project_root/Design/Audio/trial/A-002T" "$app_path/Contents/Resources/AudioTrial" <<'PYCOPY'
import hashlib, json, pathlib, shutil, sys
source, destination = map(pathlib.Path, sys.argv[1:])
shutil.copy2(source / 'trial-index.json', destination / 'trial-index.json')
folder = source / 'vcsl-steinway-b'
target = destination / folder.name
target.mkdir(exist_ok=True)
for path in folder.iterdir():
    if path.is_file(): shutil.copy2(path, target / path.name)
shutil.copytree(folder / 'licenses', target / 'licenses', dirs_exist_ok=True)
record = {'sourceManifestSHA256': hashlib.sha256((folder/'audio.manifest.json').read_bytes()).hexdigest(), 'excludedSourceDirectories': ['originals', 'samples'], 'note': 'Original source manifest retained for provenance. Original/intermediate WAVs remain in the project; runtime bank, parameters, licenses and source records are packaged.', 'files': []}
for path in sorted(destination.rglob('*')):
    if path.is_file() and path.name != 'runtime-bundle-inventory.json':
        record['files'].append({'path': str(path.relative_to(destination)), 'byteSize': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
(destination/'runtime-bundle-inventory.json').write_text(json.dumps(record, indent=2)+'\n')
PYCOPY
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TypingPianoProbe</string>
<key>CFBundleIdentifier</key><string>local.typingpiano.trial</string>
<key>CFBundleName</key><string>打字钢琴试用</string>
<key>CFBundleVersion</key><string>11</string>
<key>CFBundleShortVersionString</key><string>0.2.8</string>
<key>TypingPianoSingleInstanceProtocol</key><integer>1</integer>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Only our reproducible generated bundle. Desktop file-provider FinderInfo can prevent ad-hoc signing.
# A file provider can add FinderInfo to a newly created signature directory.
# Retry only the generated-bundle signature, bounded; never change system preferences.
# Optional identity is supplied by the caller; never embed identity/certificate details in logs.
sign_identity="${TYPING_PIANO_SIGN_IDENTITY:--}"
probe_signed=false
for attempt in 1 2 3; do
    xattr -cr "$app_path"
    if codesign --force --sign "$sign_identity" "$app_path" >/dev/null 2>&1 && codesign --verify --strict "$app_path" >/dev/null 2>&1; then
        probe_signed=true
        break
    fi
done
if [ "$probe_signed" != true ]; then
    printf '%s\n' 'Generated-bundle signing failed after 3 attempts. Check the selected signing identity and keychain access locally; identity details are omitted.' >&2
    exit 1
fi
# Metadata-free local archive preserves signed bytes if the host later adds FinderInfo.
ditto --norsrc --noextattr --noacl -c -k --keepParent "$app_path" "$build_root/打字钢琴试用.zip"
printf '%s\n' "$app_path"
