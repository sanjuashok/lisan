#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-release}"
if [[ "${VOICEBAR_PREVIEW:-0}" != "1" ]]; then
    swift_version="$(swift --version | head -1)"
    if [[ ! "$swift_version" =~ Swift\ version\ ([0-9]+)\.([0-9]+) ]]; then
        echo "Cannot determine the selected Swift toolchain." >&2
        exit 1
    fi
    if (( BASH_REMATCH[1] < 6 || (BASH_REMATCH[1] == 6 && BASH_REMATCH[2] < 2) )); then
        echo "VoiceBar requires Xcode 26+ or current Command Line Tools (Swift 6.2+ and a macOS 26+ SDK)." >&2
        echo "Select it with: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
        echo "For a UI-only preview: VOICEBAR_PREVIEW=1 ./scripts/build-app.sh" >&2
        exit 1
    fi
    sdk_path="$(xcrun --show-sdk-path)"
    if [[ ! -d "$sdk_path/System/Library/Frameworks/FoundationModels.framework" ]]; then
        echo "Select an Xcode 26+ SDK containing FoundationModels." >&2
        exit 1
    fi
fi

swift build -c "$configuration" --product VoiceBar
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app="$(pwd)/build/VoiceBar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/VoiceBar" "$app/Contents/MacOS/VoiceBar"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [[ "${VOICEBAR_PREVIEW:-0}" == "1" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier app.voicebar.preview" "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName VoiceBar Preview" "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName VoiceBar Preview" "$app/Contents/Info.plist"
fi
# SwiftPM places resource bundles next to its executable. Copy them into the app.
for bundle in "$binary_dir"/*.bundle; do
    [[ -d "$bundle" ]] || continue
    cp -R "$bundle" "$app/Contents/Resources/"
done
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --options runtime \
    --entitlements Resources/VoiceBar.entitlements "$app"
echo "Built $app"
echo "Open with: open \"$app\""
