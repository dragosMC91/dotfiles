# Insert Code Fence (Raycast)

A Raycast Script Command that types `shift+enter`, ```` ``` ````, `shift+enter` into the focused
text field, so you can start a code block in a chat input without sending the message.

## Setup

1. Raycast → Settings → Extensions → **+** → **Add Script Directory** →
   `~/Documents/dotfiles/raycast/code-fence`
2. Find **Insert Code Fence** in the list and set a **Hotkey** (e.g. `⌥⌘C`).
3. The first time you run it, allow both prompts: **Automation** ("Raycast wants to control
   System Events") and **Accessibility** (System Settings → Privacy & Security). Both can be
   revoked there later.

## Notes

- Before it types, it waits up to ~1s for you to release the hotkey's modifier keys; if they are
  still held after that, it gives up and types nothing.
- Use it via the hotkey. Launching it from Raycast's search bar can race with focus returning to
  the previous app.
- It types into whatever is focused. In a terminal, shift+enter usually acts as plain Enter and
  would run the half-typed command, so don't fire it there.
- It types the backticks with `keystroke`, which assumes a layout where ` is a single key (e.g. US).
  On layouts where ` is a dead key you may get a different result.
- To end with a plain Enter instead, change the last `keyCode(36, { using: "shift down" })` to
  `keyCode(36)`.
