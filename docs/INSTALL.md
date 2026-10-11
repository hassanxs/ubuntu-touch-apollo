# Installing Ubuntu Touch on the Xiaomi Mi 10T (apollo)

> **Alpha / work in progress.** Tested on one device only (M2007J3SY, Mi 10T, global). Installing **erases all
> data** on the phone and replaces Android. You need to be comfortable with `fastboot` and with restoring the phone
> yourself (Mi Flash / stock MIUI fastboot ROM) if something goes wrong. No warranty.

## Prerequisites

| | |
|---|---|
| Device | Xiaomi **Mi 10T** (M2007J3SY, codename `apollo`, LineageOS `apollon`). The Mi 10T Pro shares the codename but is untested. |
| Firmware | Stock **MIUI 14.0.4.0 (SJDMIXM, global, Android 12)** — the image uses this MIUI's `vendor` partition and firmware as-is. Flash that MIUI version first (stock fastboot ROM) if you are on anything else. |
| Bootloader | **Unlocked** (Mi Unlock). |
| Recovery | Official **LineageOS recovery** for `apollon` (download `recovery.img`, `dtbo.img` from <https://download.lineageos.org/devices/apollon>). Tested with the 2026-10-03 build. |
| PC | `fastboot` from Android platform-tools (recent version), `xz` / 7-Zip to unpack. |

## Files (from the GitHub release)

- `rootfs.img.xz` → `rootfs.img` — Ubuntu Touch system image (sparse, for the `system` logical partition)
- `boot.img.xz` → `boot.img` — kernel (LineageOS 4.19 + this repository's patches) and initramfs
- `vbmeta-disabled.img` — empty vbmeta with verification disabled (flags=2), made with AOSP `avbtool`
- `SHA256SUMS` — verify the downloads (`sha256sum -c SHA256SUMS`)

## Steps

1. **Back up everything.** Step 6 formats userdata.
2. Flash LineageOS recovery and its dtbo from the bootloader (Power + Volume down):
   ```
   fastboot flash recovery recovery.img
   fastboot flash dtbo dtbo.img
   fastboot reboot recovery
   ```
3. In LineageOS recovery: **Advanced → Enter fastboot** (userspace fastbootd). Check with `fastboot getvar is-userspace` → `yes`.
4. Make room in the `super` partition and size `system` for Ubuntu Touch (5 GiB):
   ```
   fastboot delete-logical-partition product
   fastboot delete-logical-partition system_ext
   fastboot resize-logical-partition system 5368709120
   ```
5. Flash Ubuntu Touch and disable verified boot:
   ```
   fastboot flash system rootfs.img
   fastboot flash boot boot.img
   fastboot flash vbmeta vbmeta-disabled.img
   ```
   (Copy `rootfs.img` to a local disk first; flashing from a network/WSL path is much slower.)
6. Format userdata as ext4 and reboot:
   ```
   fastboot format:ext4 userdata
   fastboot reboot
   ```
7. First boot takes a few minutes. Ubuntu Touch's setup wizard starts (language, Wi-Fi, passcode).

## Updating to a newer image later

From fastbootd (step 3): flash `rootfs.img` to `system` and `boot.img` to `boot` only — **skip step 6** to keep
your data. Do not use Settings → Updates (there is no official `apollo` build; see README).

## Going back to Android

Flash a stock MIUI fastboot ROM with Mi Flash (this restores `super`, `vbmeta`, `boot`, `dtbo`, `recovery`).
