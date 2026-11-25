# lisan developer guide

For installation and everyday use, start with the [README](README.md).

The app’s display name, executable, and build product are `lisan`. Internal Swift targets retain the `VoiceBar` and `VoiceBarCore` names. The production bundle identifier is `app.lisan.mac`; preview uses `app.lisan.preview`. On first launch, each identity copies the shortcut, enabled state, and cleanup preferences from its corresponding `app.voicebar.*` domain without overwriting new settings. Setup is shown again because privacy permissions and Launch at Login must be granted for the new identity. Model downloads remain in the existing shared cache.

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

The preview export also includes `brand.png`, populated and empty Notes windows in light/dark mode, `notes-settings.png`, and `saving-note.png`. Notes fixtures use an in-memory store and do not create real notes or export files. Scroll views and file controls render through an offscreen AppKit host. See [icon artwork and generation details](Resources/Branding.md) for the source image and packaging.

The build and test scripts forward optional arguments to SwiftPM. In an already restricted host that cannot create SwiftPM's nested sandbox, use `--disable-sandbox`; the host's filesystem restrictions still apply. Set `CLANG_MODULE_CACHE_PATH` and `SWIFT_MODULECACHE_PATH` to writable temporary directories if the normal compiler caches are read-only.

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

### Editor compatibility checks

Text insertion requests `AXManualAccessibility` and `AXEnhancedUserInterface` when an editor does not expose a selection. It follows focused descendants and allows a normal Command–V paste without requiring a readable AX value or selection, provided a text-field role or editable attribute identifies an editor. A missing focus tree or a non-editor routes to Notes. Known fields retain element, value, and selection validation. Partially exposed editors use the front app, the window when available, and input/app-activation monitors; programmatic cursor changes cannot be detected if the editor exposes no selection data. Password fields and secure keyboard input are rejected before capture and paste, never treated as automatic notes. Unreadable results report **Paste sent**, not verified insertion.

After installing the new build, manually check TextEdit, the ChatGPT desktop composer, and Slack in a browser: an empty composer, selected text replacement, emoji, multiline text, and a pre-existing clipboard. During processing, click another field, type, switch windows, and switch away then back; these must cancel insertion. Check a password field separately. ChatGPT and Slack compatibility remains unverified until these live checks pass.

## Architecture

- **VoiceBarCore:** shortcut recognition, cleanup prompt construction, basic cleanup, selection snapshots, and bar geometry.
- **VoiceBar:** AppKit/SwiftUI overlay and settings, a passive session keyboard listener with paired native local/global fallback monitors, AVAudioEngine recording, FluidAudio inference, Foundation Models cleanup, Accessibility-based target validation, and paste delivery. Keyboard callbacks queue work so target inspection and microphone startup do not block event delivery. Resetting the listener invalidates pending events.
- **Tests:** a standalone regression runner that works without XCTest.

Models remain loaded between dictations for lower latency; no microphone capture runs while idle. Settings, the notes destination, and cleanup preferences are stored in local user defaults. Ordinary dictation transcripts remain in memory until replaced, cleared, or the app quits. Notes persist separately as described below.

## Notes

`VoiceNote` stores text, capture date, original time-zone identifier, and a preformatted timestamp so travel and daylight-saving changes do not relabel old cards. `NotesRepository` serializes I/O on an actor, commits an atomic JSON archive under Application Support / bundle identifier / `notes.json`, then appends to the configured Markdown file. A failed append leaves a pending local note. Hidden Markdown identifiers make retries safe after a crash between the append and archive update. Retries retain each note's original destination. A corrupt archive is reported without overwriting it.

The floating panel becomes mouse-interactive only during a real recording; it never becomes key. Choosing Note stops target monitoring and clears the insertion target for that session. Normal field insertion keeps its existing validation and does not turn a failed or stale-target paste into a duplicate note. Opening the app window cancels unfinished recording/transcription; once a note write has committed, the note is retained. No audio is written to disk.

Notes regression groups cover local timestamps/DST, Unicode, persistence after restart, append preservation, custom destinations, failed exports, duplicate-free retries/crash recovery, serialized saves, corrupt archives, cancellation, and focus classification. On Nov 24, 2026, all 15 existing core checks and the Notes checks passed, and the native preview compiled. Light/dark Notes, empty state, file controls, and the recording bar were visually inspected. The production packaging attempt was blocked by a DNS/download failure for the upstream `NemoTextProcessing.xcframework.zip` GitHub artifact.

Current Nov 24 validation: authorized network access resolved the Nemo artifact and the production app was built and installed in `/Applications/lisan.app` (`app.lisan.mac`). Installed signatures and executable equality were verified. The original installed app is preserved at `build/pre-notes-install.VcKK4e/lisan.app`. Subsequent builds required refreshing stale macOS permission entries; the last launched build reported Microphone, Accessibility, and Input Monitoring all allowed.

Live checks verified real microphone note capture, the resulting note card, its matching local `NOV 24, 2026 · 4:31 PM · EST` timestamp in `~/Documents/Notes/Quick Notes.md`, text-only copying into TextEdit, and persistence after app restart. On the installed passive-listener build, the user held Fn in TextEdit, dictated “Save this as a note only,” clicked Note and released Fn. The user confirmed TextEdit was unchanged. The archive gained one exported note whose ID, text and timestamp (6:56 PM EST) matched the single appended entry in the custom Markdown file. The existing file content was preserved, the default file checksum was unchanged, and Settings confirmed the default destination was restored.

TextEdit insertion succeeded once with an app-attributed **Text insertion verified** result after setting the system Globe action to **Do Nothing**, but subsequent activation failed. The panel now joins other apps' Stage Manager/full-screen sets and is brought forward without activation during active states. Troubleshooting exposes current status, permissions, app/time attribution, and a bounded in-memory modifier-event history (no typed text). Recent failed attempts showed no TextEdit modifier events reaching the AppKit listener. Fn release reconciliation through another modifier event preserves physical-key/arrow filtering and passed its new regression check, but did not resolve the observed failure.

The latest source/build adds a passive session event tap, with the existing paired AppKit monitors retained as fallback. Only one path feeds the recognizer, keyboard callbacks defer audio/AX work, disabled taps are re-enabled, and no key is consumed or rewritten. All **16 core checks and 7 Notes groups passed**, the native preview compiled, and the production build completed. **This latest build is now installed at `/Applications/lisan.app`; signature and executable equality were verified, and all three permissions were refreshed and confirmed allowed. The user confirmed two consecutive TextEdit dictations showed the bar and inserted text. Diagnostics independently recorded repeated System-scope Fn down/up events in TextEdit at 6:41 PM. The last paste result remained unverified by AX, so insertion success is based on the user’s observation and the visible document, not an app verification claim.** The preceding installed version is backed up at `build/pre-session-listener.HBMJ6o/lisan.app`.

Additional compatibility and failure-path checks remain for ChatGPT/Slack fields, Escape/silence, and Documents denial and retry. Core tests and offscreen previews do not establish these end-to-end behaviors.

Voice commands, Slack navigation, agent routing, per-app profiles, and rewriting selected text are future work, not current features.

## Manual checks completed

These checks were performed before the rename, when the app was called VoiceBar.

On November 7, 2026, the installed Apple Silicon build passed a physical Control–Option–Space insertion test in TextEdit and a physical Fn dictation test while TextEdit had focus. lisan reported global shortcut delivery and verified the inserted text. The Fn test reported 2.98 seconds for processing and insertion; the utterance duration was not measured, so this does not establish the 10-second-speech performance target.

These checks do not establish compatibility with every editor, the minimum RAM requirement, or performance on a base M1 Mac or macOS 14.

### OpenWhispr comparison (Nov 24, 2026)

Reviewed OpenWhispr commit `62546b70a552d9dcb915b71f7c08c135ccbe3a2b` in a temporary checkout, without executing it. Its [`macos-globe-listener.swift`](https://github.com/OpenWhispr/openwhispr/blob/62546b70a552d9dcb915b71f7c08c135ccbe3a2b/resources/macos-globe-listener.swift) uses the same NSEvent global flags-change monitor, detects Fn flag transitions without requiring key code 63, and cancels bare-Fn capture when another key interrupts it. It also temporarily suppresses the macOS Globe action, with recovery of the user's original setting. Lisan's physical-key filter intentionally protects against arrow/function-key false triggers, so the broader filter has not been copied without event evidence. No OpenWhispr implementation code was copied.

System Settings inspection found this Mac's Globe action still set to **Show Emoji & Symbols**, while macOS Dictation was off. With explicit user approval, the Globe action was changed to **Do Nothing** in System Settings and the displayed value was verified. After that change, the user confirmed that the bar appeared and dictated text replaced the selection in TextEdit. Lisan’s diagnostics independently reported **Text insertion verified** with a global shortcut release in **TextEdit at 5:23:12 PM**. This was a single successful test, not a durable resolution: Fn activation failed again afterward. The preceding panel change alone had not resolved it. Later modifier history contained no TextEdit event during a failed attempt, so the next implementation targets event delivery rather than removing the physical-key filter. The passive-listener build described above is not copied from OpenWhispr; it is installed and passed the user’s two consecutive TextEdit activation/insertion attempts, with System-scope Fn events confirmed in diagnostics. Longer-term reliability and sleep/wake behavior remain unmeasured.
