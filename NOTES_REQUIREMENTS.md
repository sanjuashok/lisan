# Notes — product requirements

Status: Implementation authorized and added on Nov 24, 2026. See DEVELOPMENT.md for validation and remaining device checks.
Updated: Nov 24, 2026.

## Capture and routing

- When no text field is focused or available, save the dictated text as a note automatically. No confirmation is required.
- Always show a small, nonblocking **Saving as note** message when saving a note.
- Use a small outlined note/page icon with text lines beside the message (proposed SF Symbol: `note.text`). Match the existing bar's visual style and orange accent.
- Save text only; do not retain the audio recording.
- Use the existing transcription and text cleanup behavior.
- When a text field is focused, normal dictation continues to insert into that field unless the user explicitly chooses a note.

## Explicit note button

- Show a **Save as note** button with the note icon in the floating bar when the user presses Fn to dictate.
- Clicking it routes the current dictation to a note instead of inserting text into the focused field.
- Clearly indicate that note mode is selected for the current dictation.
- The choice applies to that dictation only. It must not insert a duplicate into the text field.
- Keep the existing recording and release behavior; clicking the button must not interrupt capture or lose the transcript.

## File destination and settings

- Append all notes to one Markdown file. Do not create a separate file for each note.
- Default destination: `~/Documents/Notes/Quick Notes.md`.
- If no custom file is selected, use the default destination. Create the default folder and file when needed.
- In **Settings**, let the user choose the destination file and its folder, see the active path, and restore the default destination.
- Append new notes without replacing existing file content.
- Notes must also remain accessible in Lisan's Notes tab across app launches.

## Timestamps

- Give every note a capture timestamp, shown on its card and included with its appended Markdown entry.
- Use the Mac's local time zone at capture time, including the date, time, and time zone abbreviation.
- Use uppercase abbreviated month names. Example: **NOV 24, 2026 · 11:42 AM · EST**.
- Do not show a numeric UTC offset.
- Preserve the original timestamp and time zone when the note is viewed later.

Example Markdown entry:

```markdown
## NOV 24, 2026 · 11:42 AM · EST

The transcribed note text goes here.
```

## App navigation and Notes tab

- Add a left sidebar with **Notes** and **Settings** navigation items.
- Show each note as its own minimal card with the note text, a quiet timestamp, and a copy action.
- Use beautiful, consistent typography aligned with the rest of Lisan, generous spacing, and restrained decoration.
- Copy copies the note text.
- Do not provide editing or deletion in this version.

## Acceptance criteria

1. Dictating with no focused text field creates a note and shows **Saving as note** with the note icon.
2. Dictating into a focused field retains normal insertion behavior.
3. Selecting **Save as note** during dictation saves a note even when a field is focused, without inserting into that field.
4. With no custom destination, notes append to `~/Documents/Notes/Quick Notes.md`.
5. Selecting a custom Markdown destination in Settings routes subsequent notes to that file.
6. Each note includes a local capture date, time, and time zone abbreviation, with an uppercase abbreviated month and no UTC offset.
7. Each saved note appears as an individual card in Notes and remains available after restarting Lisan.
8. Cards support copying only; editing and deletion are absent.
9. Audio recordings are not retained.

## Scope boundary

The user authorized implementation after reviewing these requirements. Installation and live microphone testing are tracked separately from implementation and automated checks.
