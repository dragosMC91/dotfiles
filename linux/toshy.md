# Toshy — Mac-style keybindings on Linux

[Toshy](https://github.com/RedBearAK/toshy) remaps a Linux keyboard to macOS muscle memory
(Cmd+C/V, Cmd+Tab, Cmd+Space, terminal ergonomics, Finder-like file manager shortcuts). It runs
as a set of user-level systemd services, so it's per-user and works on both X11 and Wayland.

Audited **2026-07-26** on CachyOS / KDE Plasma (Wayland). Config file `2026.06.21`,
keymapper `xwaykeyz 1.23.3`.

## TL;DR — two small custom keymaps, everything else default

Every preference toggle is at Toshy's shipped default. The only customizations are a Magnet-style
window-snapping keymap and arrow-key navigation in the Cmd+Tab switcher (see the two
"My custom keymaps" sections). On a new distro: install Toshy, enable its services, then paste
those back in.

## Where Toshy settings can live

Only two places:

| What | Where |
| --- | --- |
| Toggles from the tray icon / Preferences GUI | `~/.config/toshy/toshy_user_preferences.sqlite`, table `config_preferences` |
| Hand-written keymaps / modmaps | the `SLICE_MARK_START: user_*` regions of `~/.config/toshy/toshy_config.py`, e.g. `user_apps` for keymaps (only these regions survive an upgrade) |

Everything else under `~/.config/toshy/` is the upstream repo checkout, replaced on reinstall.

## My preference toggles (all at default)

```sh
sqlite3 -header -column ~/.config/toshy/toshy_user_preferences.sqlite \
  'select name, value from config_preferences order by name;'
```

| Setting | My value | Toshy default |
| --- | --- | --- |
| `autoload_tray_icon` | True | True |
| `gui_dark_theme` | True | True |
| `gui_theme_mode` | auto | auto |
| `override_kbtype` | Auto-Adapt | Auto-Adapt |
| `overlay_mask` | 255 | 255 |
| `optspec_layout` | Disabled | Disabled |
| `forced_numpad` | True | True |
| `altgr_on_menu_key` | True | True |
| `media_arrows_fix` | False | False |
| `multi_lang` | False | False |
| `Caps2Cmd` | False | False |
| `Caps2Esc_Cmd` | False | False |
| `Enter2Ent_Cmd` | False | False |
| `l_cmd_is_sup_and_cmd` | False | False |
| `l_opt_is_sup_and_opt` | False | False |
| `ST3_in_VSCode` | False | False |

Defaults are the `# Default:` comments in `~/.config/toshy/toshy_common/settings_class.py`
(around lines 89–113). `overlay_mask = 255` looks arbitrary but is the default: all 8 overlay
bits set, i.e. `OVL_PRESET_FULL` / `DEFAULT_OVERLAY_MASK` in
`toshy_common/overlay_context.py` — macOS globals, terminal ergo, Finder mods, Enter-to-rename,
browser shortcuts, VSCode shortcuts, dialog ergo, Level3 left-Alt.

(The DB's other table, `mru_layouts`, is just a rolling cache of the last 12 detected keyboard
layouts — not a setting.)

## My custom keymaps: window snapping

macOS used Magnet with Ctrl+Opt+arrows/Enter. KDE's KWin already has the snapping ("Quick Tile",
default `Meta+Left/Right/Up/Down`, maximize toggle `Meta+PgUp`), so this keymap only translates the
Mac muscle memory into those KWin shortcuts. On a PC keyboard that's **Ctrl + Win + key**:

| Keys | Action |
| --- | --- |
| Ctrl+Win+Left / Right | left / right half |
| Ctrl+Win+Up / Down | top / bottom half |
| Ctrl+Win+Enter | maximize (press again to restore) |

Why it lives in Toshy and not in KWin's shortcut settings: Toshy remaps modifiers per app before
KWin sees them. Physical Ctrl becomes Super in GUI apps but stays Left Ctrl in terminals, and Ghostty
can't tell that Left Ctrl from Cmd (Right Ctrl), which its `ctrl+alt+arrow` tab binds rely on. Matching
`LC-` in Toshy keeps Cmd+Opt+arrows free for Ghostty/browser tab switching.

Paste this into the `user_apps` slice of `~/.config/toshy/toshy_config.py`, above
`keymap("User hardware keys", ...)`, then run `toshy-services-restart`:

```python
keymap("User - Magnet-style window snapping", {
    C("Super-Alt-Left"):        C("Super-Left"),                # Left half
    C("Super-Alt-Right"):       C("Super-Right"),               # Right half
    C("Super-Alt-Up"):          C("Super-Up"),                  # Top half
    C("Super-Alt-Down"):        C("Super-Down"),                # Bottom half
    C("Super-Alt-Enter"):       C("Super-Page_Up"),             # Maximize (toggle)
    C("LC-Alt-Left"):           C("Super-Left"),                # Left half (terminals)
    C("LC-Alt-Right"):          C("Super-Right"),               # Right half (terminals)
    C("LC-Alt-Up"):             C("Super-Up"),                  # Top half (terminals)
    C("LC-Alt-Down"):           C("Super-Down"),                # Bottom half (terminals)
    C("LC-Alt-Enter"):          C("Super-Page_Up"),             # Maximize (terminals)
}, when = lambda ctx:
    cnfg.screen_has_focus and
    not ctx_app_is_remote
)
```

The user slices survive Toshy upgrades. Check what differs from the shipped config with:

```sh
diff ~/.config/toshy/default-toshy-config/toshy_config.py ~/.config/toshy/toshy_config.py
```

## My custom keymaps: arrow keys in the Cmd+Tab switcher

Like macOS: hold Cmd, press Tab to open the switcher, then move with the **arrow keys** (not just
repeated Tab). KDE's switcher supports arrows natively; Toshy was breaking it. While Cmd+Tab is
held, Toshy keeps Alt pressed for KDE. But Cmd+Left/Right/Up/Down are remapped to Home/End/
Ctrl+Home/Ctrl+End, and sending those releases Alt, which closes the switcher.

The fix sends Alt+arrow instead, only while the switcher is open. "Open" is detected through
xwaykeyz's internal `_sticky` table, which ties Cmd (Right Ctrl) to a held Left Alt until Cmd is
released. That's a private keymapper detail, so if this stops working after a Toshy upgrade,
check it first.

Paste into the `user_custom_functions` slice:

```python
import xwaykeyz.transform as _xwk_transform

def user_task_switcher_open():
    """True while Cmd+Tab / Cmd+` holds the KDE task switcher open.
    Toshy's `bind` sticks Cmd (RIGHT_CTRL) to a held LEFT_ALT until Cmd is released."""
    return _xwk_transform._sticky.get(Key.RIGHT_CTRL) == Key.LEFT_ALT
```

And into the `user_apps` slice (above the snapping keymap):

```python
keymap("User - Cmd+Tab switcher arrow navigation", {
    C("RC-Left"):               C("Alt-Left"),
    C("RC-Right"):              C("Alt-Right"),
    C("RC-Up"):                 C("Alt-Up"),
    C("RC-Down"):               C("Alt-Down"),
}, when = lambda ctx:
    cnfg.screen_has_focus and
    user_task_switcher_open()
)
```

## Services enabled on this machine

```sh
systemctl --user list-unit-files 'toshy*'
```

All five units are `enabled`. Active on KDE Wayland: `toshy-config`, `toshy-kwin-dbus`,
`toshy-session-monitor`. The `toshy-cosmic-dbus` and `toshy-wlroots-dbus` units stay dead
unless you're on those compositors.

## Reinstalling on a new distro

```sh
git clone https://github.com/RedBearAK/toshy.git ~/toshy
cd ~/toshy && ./setup_toshy.py install   # handles distro packages + DE integration
toshy-services-enable                    # start at login
toshy-services-status
```

The installer prompts for the desktop-environment piece it needs — a KWin script + D-Bus
service on KDE Wayland, a shell extension on GNOME — which is how Toshy learns the focused
window for per-app keymaps. Nothing from this repo needs to be copied over.

## Commands worth remembering

| Command | Purpose |
| --- | --- |
| `toshy-gui` | Preferences GUI (writes the SQLite prefs) |
| `toshy-tray` | tray indicator, same toggles |
| `toshy-services-restart` | reload after editing config or prefs |
| `toshy-services-log` | follow the keymapper log — first stop when a shortcut misbehaves |
| `toshy-env` | dump detected desktop environment / session type |
| `toshy-devices` | list keyboards Toshy is grabbing |
| `toshy-fnmode` | Apple keyboard Fn-key mode |
| `toshy-versions` | component versions |
