#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Pure logic and all AppKit code compile without downloading model weights.
VOICEBAR_PREVIEW=1 swift run VoiceBarCoreTests
VOICEBAR_PREVIEW=1 swift build --product lisan
