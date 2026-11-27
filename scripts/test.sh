#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Pure logic and all AppKit code compile without downloading model weights.
VOICEBAR_PREVIEW=1 swift run "$@" VoiceBarCoreTests
VOICEBAR_PREVIEW=1 swift build "$@" --product lisan
# The listener integration tests import the app and use XCTest from full Xcode.
if xcrun --find xctest >/dev/null 2>&1; then
    VOICEBAR_PREVIEW=1 swift test "$@" --filter ShortcutMonitorTests
else
    echo "Skipping native listener tests (XCTest requires full Xcode)."
fi
