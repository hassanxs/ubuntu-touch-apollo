# Ubuntu Touch for Xiaomi Mi 10T (apollo) — WORK IN PROGRESS

> **Status: WIP / experimental.** Boots to the Lomiri home screen; Wi-Fi + internet, speaker and mic work. Many things don't yet.
> Not ready for daily use. Flashing replaces Android on the device.

| | |
|---|---|
| Device | Xiaomi Mi 10T — M2007J3SY, codename `apollo` (LineageOS: `apollon`) |
| SoC | Qualcomm SM8250 (Snapdragon 865), A-only, dynamic partitions (`super`) |
| Base | Halium 12 generic system image + Ubuntu Touch 24.04-2.x |
| Kernel | LineageOS `android_kernel_xiaomi_sm8250` lineage-23.2 (4.19.325) + [kernel-patches/](kernel-patches/) |
| Vendor | Stock MIUI V14.0.4.0.SJDMIXM (Android 12, vendor VNDK 30) |

## What works / what doesn't

| Feature | Status | Notes |
|---|---|---|
| Boot to Lomiri, display, GPU (Adreno, GLES 3.2) | ✅ | 1080×2400 |
| Touchscreen incl. edge gestures | ✅ | edge filter lowered (`mi-touch-edge.service`) |
| Setup wizard, lock screen, app launcher | ✅ | |
| Wi-Fi scan/connect (QCA6390) | ✅ | wlan0 via `apollo-wlan-on.service` |
| Wi-Fi internet (routes, DNS, browsing) | ✅ | needed ipv4 0.0.0.0-gateway kernel fix (patch 0008) |
| USB networking + SSH (debug) | ✅ | RNDIS 10.15.19.82 |
| Battery level / charging indicator | ✅ | |
| Audio: speaker playback | ✅ | pulseaudio-droid + MIUI HAL |
| Audio: microphone | ✅ | mono `handset-mic` route; level low until ACDB calibration works |
| Audio: earpiece / in-call audio, headset | ❓ | voice calibration (ACDB) fails; needs modem first |
| Sensors (rotation, proximity, light) | ❌ | ADSP/fastrpc not up |
| Modem / SIM detection, network registration | ✅ | oFono binder plugin (`binder.conf`, `apollo.yaml`) |
| Calls, SMS, mobile data | ❓ | not tested yet |
| Bluetooth | ❌ | not tested |
| Camera, video decode (venus) | ❌ | venus firmware load fails |
| Stability | ⚠️ | killing PulseAudio during recording panics the kernel (ADSP SMMU fault) |
| Fingerprint, NFC, vibration, flashlight | ❓ | not tested |
| Suspend / screen-off power | ❓ | screen off/on works |
| Home encryption (fscrypt) | ❌ | userdata lacks `encrypt` feature (warning only) |

## Repository layout

- `deviceinfo` — UBports halium-generic-adaptation-build-tools device config (cmdline must stay < 512 bytes, `systempart` first: Xiaomi ABL ignores the extra cmdline field).
- `kernel-patches/` — `git format-patch` series on top of LineageOS lineage-23.2 `71b13e62f`.
- `overlay/` — files installed into the Ubuntu Touch rootfs (udev rules, systemd units, helpers). See `overlay/README.md`.
- `tools/` — build/flash/debug scripts used during the port (WSL Ubuntu 22.04 host; paths are specific to this setup).
- `docs/porting-log.md` — detailed chronological porting log (all problems and fixes).

## Key fixes so far

1. **Kernel panic at boot** — second MTP gadget instance re-registered `mtp_device` and corrupted `misc_list` (patch 0003).
2. **All block mounts ENOENT** — BPF-LSM default swallowed mount `source`; cmdline `lsm=lockdown,yama,integrity,apparmor` + patch 0002.
3. **Display never came up** — MIUI `vndservicemanager` aborts without SELinux → patched copy bind-mounted (`tools/patch-vsm.py`, not committed: vendor binary); binder rejected calls needing a security context → patch 0004.
4. **Lomiri crash loop** — `/dev/kgsl-3d0` root-only → udev rules generated from `ueventd.rc` (`overlay/etc/udev/rules.d/70-apollo.rules`).
5. **Edge swipes** — Novatek grip filter → `mi-touch-mode 7 1` + re-apply on resume (patch 0005).
6. **Wi-Fi** — firmware path (`/usr/lib/firmware -> /vendor/firmware_mnt/image`), ini path (patch 0007), driver ON at boot.
8. **Audio** — PulseAudio couldn't parse MIUI's audio policy (unknown flags, 24-bit primary output, mics not routed to "primary input") → `apollo-sanitize-apc`.
7. **No IPv4 routes from NetworkManager** — kernel treated RTA_GATEWAY 0.0.0.0 as a real gateway (patch 0008).

## Building (outline)

1. Apply `kernel-patches/` to LineageOS `android_kernel_xiaomi_sm8250` (lineage-23.2 @ `71b13e62f`), branch `halium-23.2`.
2. Build with UBports `halium-generic-adaptation-build-tools` using `deviceinfo` (`tools/build-apollon.sh`).
3. Boot image currently = build-tools boot.img kernel + ramdisk overlay that archives pstore (`tools/make-v3-logsave.sh`, `make-v6.sh`, `make-v13.sh`).
4. System: Halium 12 GSI + VNDK v30 APEX extracted from MIUI `system_ext` (see porting log), `system` partition grown to 6 GiB.

Not yet a reproducible one-command build — the overlay still has to be folded into the image.
