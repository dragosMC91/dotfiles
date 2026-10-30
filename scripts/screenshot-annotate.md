# Screenshot Annotate

Screenshot-and-annotate workflow triggered via **Cmd+Shift+2** through Raycast.

## How it works

An Apple Shortcut ("AnnotateScreenshot") orchestrates two steps:

![AnnotateScreenshot shortcut](img/screenshot_2026-04-28_12-21-53.png)

1. **Take Interactive screenshot** — uses the macOS Shortcuts "Take Screenshot" action with Custom selection, letting you drag a region on screen.
2. **Run Shell Script** — pipes the screenshot PNG to `~/.local/bin/screenshot-annotate.sh` via stdin.

The bash script then:

- Saves the PNG to `~/Downloads/screenshots/` with a timestamp filename.
- Opens it in Preview and activates the annotation toolbar (Cmd+Shift+A).
- Waits for Preview to close (user annotates and saves with Cmd+S, then closes).
- Copies the final image to the clipboard in two flavors at once: a **file reference** (`furl`, like Finder's "Copy") and the **PNG bitmap** (`public.png`). The file reference lets it paste as a path in terminals that can't receive image bitmaps (e.g. Claude Code in Ghostty, which lacks the OSC 5522 image-transport protocol), while the bitmap keeps inline-image paste working in native apps like Slack.
- If the screenshot step was cancelled (empty file), cleans up and exits silently.

> Note: there is a ~1s gap after you close Preview before the clipboard is updated (the copy step loads the AppKit framework via `osascript`). Pasting immediately can yield the previous image — wait a beat.

## Setup

1. **Install the script:**
   ```
   mkdir -p ~/Downloads/screenshots ~/.local/bin
   cp scripts/screenshot-annotate.sh ~/.local/bin/screenshot-annotate.sh
   chmod +x ~/.local/bin/screenshot-annotate.sh
   ```

2. **Create the Apple Shortcut** named "AnnotateScreenshot" with:
   - "Take Interactive screenshot" (Selection: Custom)
   - "Run Shell Script" — command: `/bin/bash ~/.local/bin/screenshot-annotate.sh`, Shell: zsh, Input: Screenshot, Pass Input: to stdin

3. **Raycast** — bind the shortcut to Cmd+Shift+2.

4. **macOS permissions** (System Settings > Privacy & Security):
   - Accessibility: Shortcuts app, Shortcuts Events
   - Screen Recording: Shortcuts app

The screenshot capture lives in the Shortcut (not the bash script) because giving bash direct screen recording access is avoided.
