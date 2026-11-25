# lisan

The name is inspired by *Dune*: **lisan** means “tongue” or “voice.” The goal of this repo is to let you use your voice, much like the Lisan al Gaib, to control your computer and get your work done.

**Local-only transcription for now. Cloud transcription is coming later and will always be optional.** Voice commands and broader computer control are planned for future versions.

**Feel like the Kwisatz Haderach. Use lisan.**

lisan is a small Mac app that turns your speech into text in the app you are using. A tiny orange bar near the bottom of your screen expands while you speak, then shrinks when your text is inserted. It stays out of the way and does not take focus away from your work.

Speech recognition and text cleanup happen on your Mac. After the initial downloads, you can dictate without an internet connection. No account, subscription, or separate AI server is needed.

## Minimum system requirements

| What you need | Requirement |
| --- | --- |
| Mac | **Apple Silicon: M1 or newer.** The current build does not support Intel Macs. |
| macOS | **macOS 14 Sonoma or later** for dictation and basic text cleanup. |
| Intelligent cleanup | **macOS 26 or later**, with Apple Intelligence enabled and its model available on your Mac. |
| Free space | Allow about **3 GB for the speech model setup**. Xcode and Apple Intelligence downloads need additional space. |
| Microphone | A working built-in or external microphone. |
| Internet | Needed to install and download the speech model the first time. Dictation works offline afterward. |
| Permissions | Microphone and Accessibility access; Input Monitoring if needed for the shortcut to work in other apps. |

To check your Mac and macOS version, choose **Apple menu → About This Mac**. Look for **Chip** and the macOS version. If it lists an Intel processor, this build will not run.

A minimum memory (RAM) requirement has not been established through testing. macOS 14 is the app’s configured minimum; older-system compatibility and performance on a base M1 still need testing.

Without Apple Intelligence, lisan still transcribes speech and performs basic punctuation and filler-word cleanup.

## Install lisan

**There is no ready-to-install app download yet.** For now, installation means building the app once from this repository using Xcode, Apple’s free app-building software. The steps below walk through that process. Xcode is needed to build lisan, but not to run an already-built copy.

### 1. Install Xcode

1. Install **Xcode 26 or later** from the Mac App Store, using a version compatible with your Mac’s macOS version. Building lisan may require a newer macOS than running it.
2. Open Xcode once and finish any setup steps it requests.
3. Open **Terminal**, which you can find using Spotlight (**Command–Space**, then type “Terminal”).
4. Paste this command and press Return to select Xcode’s tools:

   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

   If asked, enter your Mac login password. Terminal does not show characters while you type the password.

### 2. Download and build lisan

In Terminal, run these commands one line at a time:

```sh
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/sanjuashok/lisan.git
cd lisan
./scripts/build-app.sh
```

The first build downloads the components lisan needs and may take several minutes. Wait until you see **Built**, followed by a path ending in **lisan.app**. If the build reports an error, stop there and check that Xcode setup is complete and version 26 or later is selected.

Already have this repository on your Mac? Use that folder instead of cloning a second copy.

### 3. Move the app into Applications

1. In the same Terminal window, run:

   ```sh
   open build
   ```

2. Finder opens a folder containing **lisan.app**. Drag **lisan.app** into **Applications**.
3. Open **lisan** from Applications. Keep using this copy when granting permissions and enabling Launch at Login.

lisan runs from its waveform icon in the **menu bar at the top of your screen**. Click the icon and choose **Notes** to see saved thoughts, or **Settings…** to configure it. Both live in the same window, with a sidebar for switching between them.

This is an early development build and has not been notarized, meaning Apple has not checked this app for distribution. If macOS blocks opening a copy you built from this repository, review the message in **System Settings → Privacy & Security**. Use **Open Anyway** only if you trust that copy.

## First-time setup

### Allow the permissions

Open **lisan menu → Settings…**, then enable the requested access:

| Permission | Why lisan needs it |
| --- | --- |
| **Microphone** | To hear you while you hold the dictation shortcut. |
| **Accessibility** | To put the finished text into your current text field. On newer macOS versions, this page may be called **Device Control and Data Access**. |
| **Input Monitoring**, if requested | To detect the shortcut while you are using another app. |

Use the buttons in lisan Settings to open the relevant macOS settings. Turn on **lisan** in each requested list, then quit and reopen lisan if needed. Settings checks permissions when it opens and when you return from another app. Permission prompts disappear once access is allowed.

### Download the speech model

In lisan Settings, click **Download** beside **Parakeet**. This downloads the files that let lisan recognize speech on your Mac. Keep the app open and allow several minutes. When it says **Downloaded and ready for offline dictation**, you are ready to speak.

### Choose your shortcut

The default is **Fn / Globe**, usually near the lower-left corner of your keyboard.

For this shortcut, open **System Settings → Keyboard** and set **Press 🌐 key to** to **Do Nothing**. Turn off any macOS Dictation shortcut that uses the same key.

You can instead choose **Control–Option–Space** under **Hold to dictate** in lisan Settings. Hold all three keys together to speak, then release them.

## Dictate into an app

1. Open an app such as TextEdit and click where you want the text to appear.
2. Hold **Fn / Globe** (or your alternate shortcut). The orange bar expands while it listens.
3. Speak naturally, then release the key.
4. Keep the cursor in place while lisan processes your speech. The text appears and the bar shrinks again.

Press **Escape** to cancel. Recordings stop automatically after two minutes. Opening lisan Settings also cancels a recording or unfinished dictation.

Use **Launch at login** in lisan Settings if you want the app to start when you sign into your Mac. In the menu bar menu, **lisan Enabled** turns dictation on or off; **Quit lisan** closes the app.

## Capture a note

Hold your dictation shortcut when no editable text field is focused. lisan transcribes your speech, shows **Saving as note** with a note icon, and saves the text. If a field is focused, click **Note** in the floating bar while holding the shortcut to save that dictation as a note instead of typing it. Release the shortcut as usual. Escape cancels before saving starts.

Open **lisan menu → Notes** to see your notes, newest first. Each card has a capture timestamp and a copy button. Notes cannot be edited or deleted in this version. Only text is saved; audio is discarded.

Notes are also appended to `~/Documents/Notes/Quick Notes.md`. The folder and file are created when the first note is saved. In **Settings → Your Notes**, choose an existing Markdown file or a new file and folder. **Use default** restores the default path. Changing files affects future notes; all saved cards remain in Lisan.

Timestamps use the local time zone at capture, for example **NOV 24, 2026 · 11:42 AM · EST**. If a Markdown write fails, the note remains in Lisan. Settings shows the error and offers **Retry file writes**, using each pending note's original destination.

## Text cleanup

Text cleanup runs on your Mac. Intelligent cleanup requires macOS 26 or later and available Apple Intelligence; otherwise, basic punctuation and filler-word cleanup is used. Cleanup controls are no longer shown in Settings, and existing saved preferences continue to apply. Its wording can vary, so review important text before sending it.

## If something does not work

### Nothing happens when I hold the shortcut

1. Make sure **lisan Enabled** is checked in the menu.
2. Open lisan **Settings**, and enable any access requested there.
3. Quit and reopen lisan after changing permissions if the shortcut still does not respond.
4. Try **Control–Option–Space** if Fn is being used by macOS or another app.
5. Switch to TextEdit, click in a document, and hold the shortcut while speaking a short phrase. The bar should expand while you speak and insert the text after release.

### Permissions look enabled, but lisan still cannot use them

This can happen after replacing or rebuilding the app. macOS may still recognize the older copy.

If you see **VoiceBar**, that is the old app identity. New builds use a separate **lisan** identity and copy your shortcut and cleanup preferences automatically. Install the new build in Applications, quit any older VoiceBar/lisan copy, and grant permissions to **lisan**. Remove the old **VoiceBar** entry from Accessibility and Input Monitoring where macOS offers a **−** button. Turn on Launch at Login again if you used it before.

1. Quit lisan.
2. Open **System Settings → Privacy & Security**, then the affected permission page.
3. If the page has a list with **−** and **+** buttons, select only **lisan**, remove its old entry, then add **lisan from Applications** again and enable it. For Microphone, toggle lisan’s access off and back on if needed.
4. Reopen lisan from Applications and open Settings. Permission prompts disappear when access is allowed.

If shown, **Show App in Finder** in lisan Settings helps you locate the copy you are running.

### The bar responds, but no text appears

- Confirm that the speech model is downloaded and Microphone and Accessibility are allowed.
- Switch to TextEdit, click in a document, and dictate a short phrase to check insertion.
- Keep the original text field focused while processing. Moving the cursor, editing the field, or switching apps can cancel insertion to avoid putting text in the wrong place.

Editors that do not expose a text cursor use a normal clipboard paste. Keep the original field focused: clicking, typing, scrolling, or switching apps before paste cancels insertion. In editors with limited accessibility data, lisan cannot detect every programmatic cursor change or confirm that text appeared; **Paste sent** means the paste was dispatched but could not be verified. Password fields and secure keyboard input are not supported. Start with TextEdit when checking whether the app is working.

## Privacy and current limits

Audio is held temporarily in memory and discarded after dictation. Speech recognition and cleanup run on your Mac. lisan does not upload audio. Cleanup preferences are saved locally; the last dictation transcript is kept in memory until replaced or the app quits. Notes persist as text in Lisan's local archive and in the selected Markdown file. If you select a cloud-synced folder, that folder's sync service handles the file.

lisan temporarily uses your clipboard to insert text, then restores its previous contents unless you or another app changed the clipboard in the meantime.

This is an early version. Fn dictation and the alternate shortcut have been tested successfully in TextEdit, but compatibility and speed across all Macs and apps have not been established. Voice commands such as “message Ahmed,” Slack navigation, and connections to AI agents are future features.

## For contributors

See the [developer guide](DEVELOPMENT.md) for build details, automated checks, architecture, and performance targets.
