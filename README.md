# VoiceBar

A native macOS menu bar app for local, hold-to-talk dictation. A small burnt-orange pill expands while you speak, then transcribes, cleans, and inserts text at the original cursor.

## Features

- Hold **Fn / Globe** to record; release to transcribe. **Control–Option–Space** is available as an alternate shortcut.
- A nonactivating, click-through floating bar: 80 × 10 pt idle, 280 × 34 pt active, with a live cream-colored waveform.
- Local Parakeet v3 speech recognition through [FluidAudio](https://github.com/FluidInference/FluidAudio).
- On-device Apple Foundation Models cleanup, with editable cleanup instructions saved locally.
- Conservative filler and punctuation cleanup when intelligent cleanup is disabled or unavailable.
- Cursor and focus validation before pasting, clipboard restoration, and recoverable transcripts.
- Menu bar controls, Launch at Login, and permission diagnostics.

Audio stays in memory and is discarded after dictation. There are no accounts, external inference servers, or Ollama dependencies. Recognition works offline after initial model setup.

## Requirements

- Apple Silicon Mac running macOS 14 or later.
- Xcode 26+ or Apple Command Line Tools with Swift 6.2+ and a macOS 26+ SDK to build production.
- macOS 26+ with Apple Intelligence available for intelligent cleanup and custom cleanup instructions.
- Internet for the initial dependency and speech model downloads. Allow up to 3 GB of free space for model setup.

## Build

```sh
# If necessary, select the installed Xcode toolchain:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

./scripts/build-app.sh
open build/VoiceBar.app
```

The build script creates an ad-hoc signed app at `build/VoiceBar.app`. Move it into `/Applications` before granting permissions or enabling Launch at Login. Run the app bundle rather than `swift run VoiceBar`, so macOS can associate permissions with the app.

For a distribution build, set `CODE_SIGN_IDENTITY` to an appropriate signing identity and notarize separately. This repository does not provide a notarized release.

## Setup

1. Open **Settings** from the VoiceBar menu bar icon.
2. Allow **Microphone** and **Accessibility** access. On newer macOS versions, the Accessibility privacy page may be named **Device Control and Data Access**.
3. If the global shortcut listener is unavailable, open **Input Monitoring** from VoiceBar Settings and enable VoiceBar there.
4. Click **Check Permissions** for a timestamped result. Use **Restart VoiceBar** after changing permissions.
5. Click **Download** to prepare the local speech model.
6. For Fn / Globe, set “Press 🌐 key to” to **Do Nothing** in System Settings → Keyboard and disable conflicting Dictation shortcuts, or choose the alternate VoiceBar shortcut.
7. Focus an editable text field, hold the shortcut, speak, and release.

**Development-build permissions:** rebuilding an ad-hoc signed app can leave macOS showing an enabled entry for an older signature while denying the new build. Remove VoiceBar from that permission list, re-add the installed app using **Show App in Finder**, and restart. Checking permissions alone cannot repair an outdated grant.

## Customize cleanup

In **Settings → Intelligent text cleanup**, enter your preferences in **Cleanup instructions**. For example:

> Keep it casual. Use contractions. Avoid semicolons. Don’t add a final period.

Instructions save automatically on this Mac and apply to subsequent dictations when intelligent cleanup is enabled and available. The field accepts up to 1,000 characters. Leave it blank or click **Reset** to restore the default style.

Custom preferences guide tone, punctuation, capitalization, and formatting. Cleanup still instructs the model to preserve meaning, names, numbers, and factual information, and to treat dictated text as material to edit rather than instructions to execute. Model output can vary; custom preferences are not applied by the basic fallback. Turning intelligent cleanup off is not a verbatim mode: basic filler removal and punctuation cleanup still run.

## Use and recovery

- **Escape** cancels. Recording stops automatically after two minutes.
- Opening Settings, disabling VoiceBar, sleeping, or switching user sessions cancels current recording/processing.
- **Test shortcut without recording** checks one press/release cycle without opening the microphone. Settings distinguishes a shortcut detected globally from one detected only inside VoiceBar. “Global listener installed” describes registration, not a successful cross-app test.
- **Test text insertion** arms a single test: focus another app’s text field and press/release the shortcut to insert “VoiceBar insertion test.”
- If the cursor, field contents, or foreground app changes during processing, insertion is blocked. Use **Copy Last Transcript** from the menu to recover the text.
- Password fields and fields without an accessible text selection are rejected.
- Detailed status is available in Settings; the menu contains controls without a dictation-status banner.

Insertion uses the editor’s normal Paste action and checks the resulting field value when available. It never automatically retries a dispatched paste, since a delayed editor could insert it twice. The previous clipboard contents are restored unless another app or the user changes the clipboard during insertion. Some editors cannot expose enough information to verify the result.

## Development and verification

```sh
./scripts/test.sh       # Core regression checks and native UI preview compilation
./scripts/build-app.sh  # Production build with the speech engine
```

Core checks cover physical Fn filtering, duplicate events, alternate shortcut release, cleanup preferences and length bounds, meaning preservation, UTF-16 selections, insertion verification, changed cursors, and display geometry. CI runs the checks and compiles the production app without downloading speech model weights.

For a UI-only preview with an older Swift 5.10 toolchain:

```sh
VOICEBAR_PREVIEW=1 ./scripts/build-app.sh
open build/VoiceBar.app --args --settings
# Export the actual SwiftUI bar states:
.build/release/VoiceBar --export-previews build/previews
```

The preview uses a separate bundle identifier and cannot transcribe.

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
