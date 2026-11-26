# Rex

Matches the Ghostty setup in `../ghostty/config`. Rex's Ghostty migration only
copies keybinds into `~/.config/rex/init.lua`. Theme and font are app settings,
so set them by hand.

## Theme

1. **Settings › Themes › Import Theme**: pick `themes/Dracula Ghostty`.
   It's Dracula with Ghostty's overrides: text `#deffff`, cursor `#50fa7b`.
2. **Settings › Themes › Dark Mode**:
   - **Dark theme**: the imported theme.
   - **Use extended theme palette**: optional. Turn it on to use the theme's
     colors 16–255.

## Terminal settings

| Where (Settings › Terminal) | Setting | Value | Why |
| --- | --- | --- | --- |
| Typography | Terminal font | MesloLGS NF | `font-family` |
| Typography | Font size | 19 | `font-size` |
| Cursor | Cursor style | Bar | `cursor-style = bar` |
| Cursor | Blink speed | Normal | `cursor-style-blink = true` |
| Colors | Force theme palette for text | Off | Ghostty doesn't remap program colors |
| Colors | Improve text contrast | Off | Ghostty doesn't adjust contrast by default |
| Colors | Use Display P3 color space | Off | Ghostty uses sRGB by default |
| Selection | Foreground / Background | Theme | Uses the theme's selection colors (`#ffffff` on `#44475a`) |

## Keys and actions

`init.lua` is the Rex config. It holds the keybinds migrated from tmux, Herdr
and Ghostty, plus two custom actions. On a new machine:

```sh
mkdir -p ~/.config/rex
ln -s ~/Documents/dotfiles/terminal/rex/init.lua ~/.config/rex/init.lua
```

`ctrl+b r` reloads it. `rex config check` reports errors in it.

| Keys | Action | What it does |
| --- | --- | --- |
| `ctrl+b g` | `lazygit` | Opens lazygit in a new tab, in the focused pane's directory. Same as `prefix g` in tmux. Needs `lazygit` installed. |
| `ctrl+q` | `quote_clipboard` | Pastes the clipboard into the pane as a Markdown quote, `> ` on every line. Copy the text with `cmd+c` first. |

Both actions are also in the command palette (`shift+cmd+p`).

- `ctrl+b` starts a key sequence, so it no longer reaches programs. Press it
  twice to send one. `ctrl+q` doesn't reach programs either.
- `quote_clipboard` pastes one line at a time. Claude Code masks a paste of
  more than 3 lines or 800 characters as `[Pasted text #1 +7 lines]`. For a
  normal paste, paste the same text again to expand it.
- Rex has no way for a script to read the selection, so `quote_clipboard`
  reads the clipboard. Asking the app to copy first needs **Settings › General
  › Remote Control** on, and still gave an empty clipboard.

## Sessions

`start_rex.sh` is the Rex version of `tmux/scripts/start_tmux.sh`: the same
sessions, tabs, working directories and setup commands. It skips any session
that already exists. The one in this repo is a generic example, edit it for
your own sessions.

## No Rex equivalent

- `adjust-cursor-thickness`, `adjust-cursor-height`
- `cursor-click-to-move`
- `middle-click-action = ignore`
- `window-width`, `window-height`
