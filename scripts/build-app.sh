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
        echo "lisan requires Xcode 26+ or current Command Line Tools (Swift 6.2+ and a macOS 26+ SDK)." >&2
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

swift build -c "$configuration" --product lisan
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app="$(pwd)/build/lisan.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/lisan" "$app/Contents/MacOS/lisan"
cp Resources/Info.plist "$app/Contents/Info.plist"
# Package the same artwork for Finder/Dock and the Settings header. Native
# tools produce the standard icon sizes without another build dependency.
icon_source="$(pwd)/Sources/VoiceBar/Brand/lisan-icon.png"
iconset="$(pwd)/build/lisan.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$icon_source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$icon_source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/lisan.icns"
cp "$icon_source" "$app/Contents/Resources/lisan-icon.png"
if [[ "${VOICEBAR_PREVIEW:-0}" == "1" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier app.voicebar.preview" "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName lisan preview" "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName lisan preview" "$app/Contents/Info.plist"
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
