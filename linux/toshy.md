# Toshy — Mac-style keybindings on Linux

[Toshy](https://github.com/RedBearAK/toshy) remaps a Linux keyboard to macOS muscle memory
(Cmd+C/V, Cmd+Tab, Cmd+Space, terminal ergonomics, Finder-like file manager shortcuts). It runs
as a set of user-level systemd services, so it's per-user and works on both X11 and Wayland.

Audited **2026-07-26** on CachyOS / KDE Plasma (Wayland). Config file `2026.06.21`,
keymapper `xwaykeyz 1.23.3`.

## TL;DR — I have not customized anything

Every setting is at Toshy's shipped default. The Mac-like behavior comes entirely from Toshy's
out-of-the-box config, so porting to another distro needs **no config restore at all** — just
install Toshy and enable its services.

## Where Toshy settings can live

Only two places:

| What | Where |
| --- | --- |
| Toggles from the tray icon / Preferences GUI | `~/.config/toshy/toshy_user_preferences.sqlite`, table `config_preferences` |
| Hand-written keymaps / modmaps | the `SLICE_MARK_START: user_custom_*` regions of `~/.config/toshy/toshy_config.py` (only these regions survive an upgrade) |

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

## My custom keymaps: none

`~/.config/toshy/toshy_config.py` is byte-identical to the shipped default, so the
`user_custom_lists`, `user_custom_functions` and `user_custom_modmaps` slices are empty:

```sh
diff -q ~/.config/toshy/default-toshy-config/toshy_config.py \
        ~/.config/toshy/toshy_config.py      # exit 0 == unmodified
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
