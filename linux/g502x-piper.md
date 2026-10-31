# Logitech G502 X — DPI on Linux (Piper)

KDE's pointer speed bottoms out at libinput's minimum, so to slow the mouse down further, lower
the DPI on the mouse itself with [Piper](https://github.com/libratbag/piper) (a GUI for the
`ratbagd` daemon from libratbag).

Set up **2026-10-30** on CachyOS / KDE Plasma (Wayland), `libratbag 0.18`, `piper 0.8`.

## TL;DR

- Piper writes the DPI to the **mouse's onboard memory**. Set it once; it survives reboots and
  power cycles and needs nothing running afterwards.
- Piper only needs `ratbagd` while you're changing settings:

```sh
sudo systemctl start ratbagd      # before opening Piper
piper
sudo systemctl stop ratbagd       # when done (optional)
```

- `sudo systemctl enable --now ratbagd` starts it on every boot and
  `sudo systemctl disable --now ratbagd` stops that.

## Install

```sh
sudo pacman -S piper              # pulls in libratbag / ratbagd
sudo cp linux/libratbag/logitech-g502-x-lightspeed-receiver.device /usr/share/libratbag/
sudo systemctl restart ratbagd
ratbagctl list                    # should print "Logitech G502 X LS"
```

## Why the extra `.device` file

Through the Lightspeed receiver (`046d:c545`) the mouse identifies itself as **`046d:409f`**
("Logitech G502 X LS"). libratbag 0.18 only knows the G502 X by its cable IDs (`c098`, `c099`),
so without the extra file `ratbagd` ignores it and Piper shows *"Cannot find any devices"*.

`linux/libratbag/logitech-g502-x-lightspeed-receiver.device` adds the `409f` match. It isn't owned
by any package, so updates don't remove it. If a future libratbag ships `409f` itself, delete it.

- `.device` files are key-files: a stray line without `=` (e.g. a pasted `EOF`) makes the file
  invalid, so the device silently isn't matched.
- `ratbagd` reads the files at startup, so restart it after adding or editing one.

Without the file, a workaround is to plug the mouse in by cable (`c098` is supported), set the
DPI in Piper, then go back to wireless.

## Sharing the mouse with macOS

Onboard memory travels with the mouse, so the DPI set here also applies on the Mac unless
G HUB is running there in software mode (G HUB then applies its own profile and ignores the
onboard DPI). Without G HUB, compensate with the macOS tracking speed instead.
