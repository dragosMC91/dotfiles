# ASUS TUF X570-PLUS: CSM, Resizable BAR and booting CachyOS

Turning CSM on fixed a boot failure, but it silently blocked Resizable BAR on the RX 6800. The
working setup is pure UEFI with Fast Boot off.

Worked out **2026-10-31** on CachyOS (Limine, KDE Plasma Wayland), board BIOS `5013`.

## TL;DR

The working setup is **CSM Disabled, Above 4G Decoding Enabled, Re-Size BAR Enabled, Fast Boot
Disabled**. With it, CachyOS boots normally through Limine and the GPU exposes its full 16 GB to the
CPU (Resizable BAR), up from 256 MB.

The likely reason CSM-off boots now work is that Fast Boot was turned off first, but that isn't
proven.

## The machine

| Part | Detail relevant here |
| --- | --- |
| Motherboard | ASUS TUF GAMING X570-PLUS, BIOS 5013 (Mar 2024) |
| GPU | ASUS TUF RX 6800 Gaming OC, 16 GB, firmware 115-D414S00-101 (Nov 2020), BIOS switch on P |
| CPU | AMD Ryzen 9 3900X (Zen 2) |
| Boot | CachyOS via Limine, pure UEFI (`\EFI\LIMINE\LIMINE_X64.EFI`), Secure Boot off |
| Displays | Dell U2718Q on DisplayPort (main), small sensor panel on HDMI inside the case |

## What happened

Turning CSM on fixed booting but broke Resizable BAR, because the board ignores Above 4G Decoding
and Re-Size BAR while CSM is on.

1. With CSM off (and Fast Boot on), the board showed *"The VGA card is not supported by UEFI
   driver. CSM settings have been changed for better compatibility"* and CachyOS would not boot.
2. CSM was enabled as a workaround, with Boot Device Control = UEFI only, Boot from Network =
   Ignore and Boot from Storage = Ignore. Linux booted again.
3. With CSM on, the board starts the GPU from its legacy firmware. The kernel logged
   `Video device with shadowed ROM` and `Fetched VBIOS from ROM BAR`.
4. The board also set up no address space above 4 GB, so the 16 GB BAR had nowhere to go. The
   kernel logged `BAR=256M`, even though Above 4G Decoding and Re-Size BAR both showed Enabled.
5. Fast Boot was then disabled, but on its own that didn't help: the next boot still showed
   `BAR=256M` with CSM on.
6. CSM was disabled again with Fast Boot already off. The board booted without the VGA warning,
   started the GPU through its UEFI driver (`Fetched VBIOS from VFCT`), and Resizable BAR came up
   at `BAR=16384M`.

This also settles an earlier question: the card's firmware **does** include a UEFI driver. Earlier
checks suggested it might be missing, but they could only see the partial copy that CSM leaves in
memory.

## The winning setup

Press Del at power-on, then F7 for Advanced Mode.

| BIOS setting | Value | Why |
| --- | --- | --- |
| Boot → CSM → Launch CSM | **Disabled** | Required for Resizable BAR; also gives a pure UEFI boot |
| Advanced → PCI Subsystem Settings → Above 4G Decoding | **Enabled** | Lets the board place the GPU's memory above 4 GB |
| Advanced → PCI Subsystem Settings → Re-Size BAR Support | **Enabled** | Exposes the full 16 GB to the CPU |
| Boot → Boot Configuration → Fast Boot | **Disabled** | Gives the GPU and monitors time to initialise; the likely fix for the VGA warning |
| Boot → Boot Option Priorities → #1 | **Limine** | The only boot entry needed; it's UEFI |
| Secure Boot | Off (OS Type: Other OS) | CachyOS isn't signed for Secure Boot |

The CSM sub-options (Boot Device Control, network and storage option ROMs) disappear once CSM is
off, so their values no longer matter.

## How to verify from Linux

None of these need sudo.

```sh
journalctl -b -k | grep -E 'Detected VRAM|Fetched VBIOS'
```

| Expected line | Means |
| --- | --- |
| `Detected VRAM RAM=16368M, BAR=16384M` | Resizable BAR is active |
| `Fetched VBIOS from VFCT` | The GPU started in UEFI mode (CSM is really off) |

If it shows `BAR=256M` or `Fetched VBIOS from ROM BAR`, CSM is back on. That can happen silently
after a BIOS reset or update.

## If it breaks again

If the VGA warning returns, or Linux won't boot, step back to the CSM workaround. Losing Resizable
BAR costs only a few percent in some games.

1. **Can't see the BIOS on the Dell:** on cold boots the BIOS may appear on the sensor panel
   inside the case. From a working Linux session, `systemctl reboot --firmware-setup` restarts
   straight into the BIOS while the Dell is already awake.
2. **VGA warning comes back:** first check that Fast Boot is still Disabled, then retry CSM
   Disabled.
3. **Still failing:** fall back to the old workaround: CSM Enabled, Boot Device Control = UEFI
   only, Network = Ignore, Storage = Ignore. Linux will boot, with `BAR=256M`.
4. **No picture at all and can't reach the BIOS:** power off and short the CLRTC jumper (see the
   board manual) to reset the BIOS to defaults. Then re-apply the table above.

After any BIOS update, re-apply the table above, because updates reset all settings.
