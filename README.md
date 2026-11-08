# VoiceBar

**Hold a key, speak, and let VoiceBar type for you.**

VoiceBar is a small Mac app that turns your speech into text in the app you are using. A tiny orange bar near the bottom of your screen expands while you speak, then shrinks when your text is inserted. It stays out of the way and does not take focus away from your work.

Speech recognition and text cleanup happen on your Mac. After the initial downloads, you can dictate without an internet connection. No account, subscription, or separate AI server is needed.

## Minimum system requirements

| What you need | Requirement |
| --- | --- |
| Mac | **Apple Silicon: M1 or newer.** The current build does not support Intel Macs. |
| macOS | **macOS 14 Sonoma or later** for dictation and basic text cleanup. |
| Intelligent cleanup and custom instructions | **macOS 26 or later**, with Apple Intelligence enabled and its model available on your Mac. |
| Free space | Allow about **3 GB for the speech model setup**. Xcode and Apple Intelligence downloads need additional space. |
| Microphone | A working built-in or external microphone. |
| Internet | Needed to install and download the speech model the first time. Dictation works offline afterward. |
| Permissions | Microphone and Accessibility access; Input Monitoring if needed for the shortcut to work in other apps. |

To check your Mac and macOS version, choose **Apple menu → About This Mac**. Look for **Chip** and the macOS version. If it lists an Intel processor, this build will not run.

A minimum memory (RAM) requirement has not been established through testing. macOS 14 is the app’s configured minimum; older-system compatibility and performance on a base M1 still need testing.

Without Apple Intelligence, VoiceBar still transcribes speech and performs basic punctuation and filler-word cleanup. Custom cleanup instructions require intelligent cleanup.

## Install VoiceBar

**There is no ready-to-install app download yet.** For now, installation means building the app once from this repository using Xcode, Apple’s free app-building software. The steps below walk through that process. Xcode is needed to build VoiceBar, but not to run an already-built copy.

### 1. Install Xcode

1. Install **Xcode 26 or later** from the Mac App Store, using a version compatible with your Mac’s macOS version. Building VoiceBar may require a newer macOS than running it.
2. Open Xcode once and finish any setup steps it requests.
3. Open **Terminal**, which you can find using Spotlight (**Command–Space**, then type “Terminal”).
4. Paste this command and press Return to select Xcode’s tools:

   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

   If asked, enter your Mac login password. Terminal does not show characters while you type the password.

### 2. Download and build VoiceBar

In Terminal, run these commands one line at a time:

```sh
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/sanjuashok/voicebar.git
cd voicebar
./scripts/build-app.sh
```

The first build downloads the components VoiceBar needs and may take several minutes. Wait until you see **Built**, followed by a path ending in **VoiceBar.app**. If the build reports an error, stop there and check that Xcode setup is complete and version 26 or later is selected.

Already have this repository on your Mac? Use that folder instead of cloning a second copy.

### 3. Move the app into Applications

1. In the same Terminal window, run:

   ```sh
   open build
   ```

2. Finder opens a folder containing **VoiceBar.app**. Drag **VoiceBar.app** into **Applications**.
3. Open **VoiceBar** from Applications. Keep using this copy when granting permissions and enabling Launch at Login.

VoiceBar runs from its waveform icon in the **menu bar at the top of your screen**. It does not have a regular app window during everyday use. Click the icon and choose **Settings…** whenever you need to configure it.

This is an early development build and has not been notarized, meaning Apple has not checked this app for distribution. If macOS blocks opening a copy you built from this repository, review the message in **System Settings → Privacy & Security**. Use **Open Anyway** only if you trust that copy.

## First-time setup

### Allow the permissions

Open **VoiceBar menu → Settings…**, then enable the requested access:

| Permission | Why VoiceBar needs it |
| --- | --- |
| **Microphone** | To hear you while you hold the dictation shortcut. |
| **Accessibility** | To put the finished text into your current text field. On newer macOS versions, this page may be called **Device Control and Data Access**. |
| **Input Monitoring**, if requested | To detect the shortcut while you are using another app. |

Use the buttons in VoiceBar Settings to open the relevant macOS settings. Turn on **VoiceBar** in each requested list. Return to VoiceBar, click **Restart VoiceBar**, then **Check Permissions** to confirm access is ready.

### Download the speech model

In VoiceBar Settings, click **Download** beside **Parakeet**. This downloads the files that let VoiceBar recognize speech on your Mac. Keep the app open and allow several minutes. When it says **Downloaded and ready for offline dictation**, you are ready to speak.

### Choose your shortcut

The default is **Fn / Globe**, usually near the lower-left corner of your keyboard.

For this shortcut, open **System Settings → Keyboard** and set **Press 🌐 key to** to **Do Nothing**. Turn off any macOS Dictation shortcut that uses the same key.

You can instead choose **Control–Option–Space** under **Hold to dictate** in VoiceBar Settings. Hold all three keys together to speak, then release them.

## Dictate into an app

1. Open an app such as TextEdit and click where you want the text to appear.
2. Hold **Fn / Globe** (or your alternate shortcut). The orange bar expands while it listens.
3. Speak naturally, then release the key.
4. Keep the cursor in place while VoiceBar processes your speech. The text appears and the bar shrinks again.

Press **Escape** to cancel. Recordings stop automatically after two minutes. Opening VoiceBar Settings also cancels a recording or unfinished dictation.

Use **Launch at Login** in the VoiceBar menu if you want the app to start when you sign into your Mac. **VoiceBar Enabled** turns dictation on or off; **Quit VoiceBar** closes the app.

## Customize text cleanup

Open **VoiceBar Settings**, turn on **Intelligent text cleanup**, and enter your preferences in **Cleanup instructions**. For example:

> Keep the tone professional and natural. Use bullet points for clear lists or multiple distinct items. Do not use em-dashes. Preserve my meaning and keep the wording concise.

Your instructions save automatically and apply to future dictations. You can enter up to 1,000 characters. Leave the box blank or click **Reset** to use the default style.

Intelligent cleanup requires macOS 26 or later and available Apple Intelligence. Its wording can vary, so review important text before sending it. Turning intelligent cleanup off still leaves basic punctuation and filler-word cleanup on; it does not produce an exact word-for-word transcript.

## If something does not work

### Nothing happens when I hold the shortcut

1. Make sure **VoiceBar Enabled** is checked in the menu.
2. Open **Settings → Check Permissions**, and enable any missing access.
3. Click **Restart VoiceBar** after changing permissions.
4. Try **Control–Option–Space** if Fn is being used by macOS or another app.
5. Click **Test shortcut without recording**, switch to another app, then physically hold and release your shortcut. This checks the bar without using your microphone.

“Global listener installed” means VoiceBar has set up shortcut detection. A successful test in another app confirms that it actually receives your key presses.

### Permissions look enabled, but VoiceBar still cannot use them

This can happen after replacing or rebuilding the app. macOS may still recognize the older copy.

1. Quit VoiceBar.
2. Open **System Settings → Privacy & Security**, then the affected permission page.
3. If the page has a list with **−** and **+** buttons, select only **VoiceBar**, remove its old entry, then add **VoiceBar from Applications** again and enable it. For Microphone, toggle VoiceBar’s access off and back on if needed.
4. Reopen VoiceBar from Applications and click **Check Permissions**.

If shown, **Show App in Finder** in VoiceBar Settings helps you locate the copy you are running.

### The bar responds, but no text appears

- Check the status at the top of VoiceBar Settings for an explanation.
- Confirm that the speech model is downloaded and Microphone and Accessibility are allowed.
- Try **Test text insertion**, switch to TextEdit, click in its document, then press and release your shortcut. It should insert **“VoiceBar insertion test.”** without recording audio.
- Keep the original text field focused while processing. Moving the cursor, editing the field, or switching apps can cancel insertion to avoid putting text in the wrong place.
- If **Copy Last Transcript** appears in the VoiceBar menu, use it to copy your last result and paste it yourself.

Password fields and some apps’ text fields are not supported. Some editors also prevent VoiceBar from confirming whether a paste succeeded. Start with TextEdit when checking whether the app is working.

## Privacy and current limits

Audio is held temporarily in memory and discarded after dictation. Speech recognition and cleanup run on your Mac. VoiceBar does not upload audio. Cleanup preferences are saved locally; the last transcript is kept in memory until replaced, cleared from the menu, or the app quits.

VoiceBar temporarily uses your clipboard to insert text, then restores its previous contents unless you or another app changed the clipboard in the meantime.

This is an early version. Fn dictation and the alternate shortcut have been tested successfully in TextEdit, but compatibility and speed across all Macs and apps have not been established. Voice commands such as “message Ahmed,” Slack navigation, and connections to AI agents are future features.

## For contributors

See the [developer guide](DEVELOPMENT.md) for build details, automated checks, architecture, and performance targets.
