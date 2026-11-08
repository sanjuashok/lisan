# lisan developer guide

For installation and everyday use, start with the [README](README.md).

The app’s display name, executable, and build product are `lisan`. Internal Swift targets retain the `VoiceBar` and `VoiceBarCore` names. The existing production bundle identifier (`app.voicebar.mac`) is intentionally retained so the rename keeps the same saved settings and app identity. Model downloads remain in the existing shared cache.

## Build requirements

Use an Apple Silicon Mac with Xcode 26 or later, or Command Line Tools providing Swift 6.2 or later and a macOS 26 or later SDK. The selected Xcode version may require a newer macOS than lisan itself.

The production build uses FluidAudio 0.17.7 and targets macOS 14. Foundation Models cleanup is available only on macOS 26 or later when Apple Intelligence is available.

```sh
./scripts/build-app.sh
```

The app is written to `build/lisan.app`. Install it in `/Applications` before granting permissions or enabling Launch at Login. Launch the app bundle rather than using `swift run lisan`, so macOS associates permissions with the app.

By default the script uses ad-hoc signing. Rebuilding changes the app signature and can invalidate existing privacy permissions. Remove the old lisan entry from the affected privacy list, add the installed copy again, and restart lisan. No permissions database edits are needed.

For a distribution build, set `CODE_SIGN_IDENTITY` to an appropriate signing identity and notarize separately. There is currently no published app download or notarized release.

## Development and verification

```sh
./scripts/test.sh       # Core regression checks and native UI preview compilation
./scripts/build-app.sh  # Production build with the speech engine
```

Core checks cover physical Fn filtering, duplicate events, alternate shortcut release, cleanup preferences and length bounds, meaning preservation, UTF-16 selections, insertion verification, changed cursors, and display geometry. CI runs the checks and compiles the production app without downloading speech model weights.

For a UI-only preview with an older Swift 5.10 toolchain:

```sh
VOICEBAR_PREVIEW=1 ./scripts/build-app.sh
open build/lisan.app --args --settings
# Export the actual SwiftUI bar states:
.build/release/lisan --export-previews build/previews
```

The preview uses a separate bundle identifier and cannot transcribe.

The preview export also includes `brand.png`, showing the Settings header and menu bar icon on light and dark backgrounds. See [icon artwork and generation details](Resources/Branding.md) for the source image and packaging.

### Acceptance targets

These targets require device testing; passing the core checks does not establish them:

| Target | Validation |
| --- | --- |
| Wake-to-visual under 100 ms | Measure physical shortcut input to visible response. |
| Expansion/collapse 150–200 ms | Check animation with and without Reduce Motion. |
| Processing under 3 seconds | Measure 10-second utterances on an M1 Pro, including warm and cold runs. |
| At least 98% insertion success | At least 100 attempts across native and browser/Electron editors, including selected text, emoji, and multiline content. |
| No focus stealing | Switch fields/apps during processing and confirm no unintended insertion. |
| Offline operation | Repeat recognition after setup with networking disabled. |

Also test clipboard preservation, denied/re-granted permissions, cancellation, microphone changes, multiple displays, hidden/side Docks, fullscreen Spaces, and Launch at Login.

## Architecture

- **VoiceBarCore:** shortcut recognition, cleanup prompt construction, basic cleanup, selection snapshots, and bar geometry.
- **VoiceBar:** AppKit/SwiftUI overlay and settings, paired native local/global keyboard monitors, AVAudioEngine recording, FluidAudio inference, Foundation Models cleanup, Accessibility-based target validation, and paste delivery. Keyboard callbacks queue work so target inspection and microphone startup do not block event delivery. Resetting the listener invalidates pending events.
- **Tests:** a standalone regression runner that works without XCTest.

Models remain loaded between dictations for lower latency; no microphone capture runs while idle. Settings and cleanup preferences are stored in local user defaults. Transcripts remain in memory until replaced, cleared, or the app quits.

Voice commands, Slack navigation, agent routing, per-app profiles, and rewriting selected text are future work, not current features.

## Manual checks completed

These checks were performed before the rename, when the app was called VoiceBar.

On November 7, 2026, the installed Apple Silicon build passed a physical Control–Option–Space insertion test in TextEdit and a physical Fn dictation test while TextEdit had focus. lisan reported global shortcut delivery and verified the inserted text. The Fn test reported 2.98 seconds for processing and insertion; the utterance duration was not measured, so this does not establish the 10-second-speech performance target.

These checks do not establish compatibility with every editor, the minimum RAM requirement, or performance on a base M1 Mac or macOS 14.
