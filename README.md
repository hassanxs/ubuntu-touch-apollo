# Ubuntu Touch for Xiaomi Mi 10T (apollo) — WORK IN PROGRESS

> **Status: WIP / experimental.** Boots to the Lomiri home screen; Wi-Fi, mobile data, calls, SMS, audio, Bluetooth, camera (photo + video), flashlight, auto-brightness, proximity and fingerprint enrolment work. Many things don't yet.
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
| Wi-Fi scan/connect (QCA6390) | ✅ | wlan0 via `apollo-wlan-on.service`; 5 GHz 802.11ac 2x2 80 MHz = 866.7 Mbit/s link (chip also does 802.11ax) |
| Wi-Fi internet (routes, DNS, browsing) | ✅ | needed ipv4 0.0.0.0-gateway kernel fix (patch 0008) |
| USB file transfer (MTP) | ✅ | default USB mode; copied files both ways with Windows |
| USB networking + SSH (debug) | ✅ | RNDIS 10.15.19.82 (`usb_moded_util -s developer_mode`) |
| Battery level / charging indicator | ✅ | level steady, no jumps |
| Screenshots (Vol up + Vol down), hardware buttons | ✅ | |
| Audio: speaker playback | ✅ | pulseaudio-droid + MIUI HAL |
| Audio: microphone | ✅ | mono `handset-mic` route; level low until ACDB calibration works |
| Audio: earpiece / headset | ✅ / ❓ | earpiece OK in calls; headset not tested |
| Sensors: rotation, light (auto-brightness) | ✅ | sensorfw HIDL; repowerd profile `config-apollo.xml` enables auto-brightness |
| Proximity sensor (screen off in calls) | ✅ | Elliptic ultrasound: audio HAL control socket passed to PulseAudio (`apollo-audio-hw-socket`) |
| Modem / SIM detection, network registration | ✅ | oFono binder plugin (`binder.conf`, `apollo.yaml`) |
| Mobile data (LTE) | ✅ | tested with Onic/Ufone (APN auto-provisioned) |
| Voice calls (incoming, two-way audio) | ✅ | needs `ril_subscription.conf` (IQcRilAudio bridge) + container audio HAL stubbed |
| Ringtone on incoming call | ✅ | media-hub needed AppArmor SO_PEERSEC for unix sockets (kernel patch) |
| SMS send / receive | ✅ | incoming SMS arrive over IMS → `extPlugin=qti` in `binder.conf` |
| VoLTE (IMS) | ✅ | via ofono-binder-plugin-ext-qti |
| Outgoing calls | ✅ | |
| Bluetooth (on, scan, pairing) | ✅ | bluebinder waits for the HAL and the modem (factory BD address from modem NV) + CONFIG_BT_HCIVHCI |
| Bluetooth audio (A2DP) | ✅ | dual-mode buds: Settings may pair only the LE side; pair the classic (BR/EDR) side, see porting log |
| Camera: photos (back + front) | ✅ | Xiaomi sensor driver close fix + firmware path fix (kernel) |
| Camera: video recording (with sound) | ✅ | libgbinder ApiLevel=32 so the AudioFlinger bridge registers |
| Video playback (venus) | ✅ | gallery playback OK |
| Stability | ⚠️ | killing PulseAudio during recording panics the kernel (ADSP SMMU fault); Camera app segfaults on exit (harmless) |
| Flashlight | ✅ | Xiaomi `flashlight` LED via device-info |
| Vibration | ❌ | aw8697 probes; waveform RAM not loaded at boot, still no output after reload (see porting log) |
| GPS | ✅ | outdoor fix in ~45-70 s (cold start; XTRA assistance unavailable: no DNS/network for the container's location daemon) |
| Fingerprint (enroll) | ✅ | FPC HAL via biometryd; needed AppArmor D-Bus mediation (kernel patches 0016-0017) |
| Fingerprint unlock | ✅ | lock screen |
| NFC (read tags) | ✅ | nfcd + binder plugin; YubiKey read as Type 4A/NDEF. Needed /dev/nq-nci owned by nfc (1027) |
| Suspend / screen-off power | ✅ / ❓ | incoming call wakes the screen-off phone (no cable); battery drain not measured |
| Home encryption (fscrypt) | ⚪ | optional, not enabled: userdata lacks the ext4 `encrypt` flag (one-way `tune2fs` change, deliberately skipped) |

## System updates (OTA)

The image is configured for `system-image.ubports.com`, channel `24.04-2.x/arm64/android9plus/daily`, device `apollo`
(build number 0). UBports publishes no `apollo` device in that channel (checked 2026-10-11: `index.json` returns 404),
so Settings → Updates finds nothing and is harmless. If an official `apollo` build ever appears there, do **not**
install it over this port without checking it: it would replace this kernel/overlay. Update by flashing a newer
image from this repository instead.

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
10. **Ringtone / media-hub** — AppArmor reported no peer label on unix sockets → media-hub aborted (kernel patch).
9. **Calls** — IQcRilAudio bridge config, container audio HAL stubbed (it broke ACDB calibration for PulseAudio's HAL).
8. **Audio** — PulseAudio couldn't parse MIUI's audio policy (unknown flags, 24-bit primary output, mics not routed to "primary input") → `apollo-sanitize-apc`.
7. **No IPv4 routes from NetworkManager** — kernel treated RTA_GATEWAY 0.0.0.0 as a real gateway (patch 0008).
11. **Fingerprint / Settings crash** — libapparmor saw AppArmor as disabled (`enabled` param printed `1`, not `Y`) and the kernel lacked `features/dbus` → dbus-daemon had no AppArmor mediation → biometryd 0.4.0 aborted (patches 0016-0017).

## Building

Follows the UBports porting guide (standalone kernel + Halium 12 GSI, `deviceinfo_use_overlaystore`).

1. Kernel: LineageOS `android_kernel_xiaomi_sm8250` (lineage-23.2 @ `71b13e62f`) + `kernel-patches/`, branch `halium-23.2`.
   `deviceinfo_kernel_defconfig` = LineageOS' own fragments + `halium.config` (the Ubuntu Touch options, patch in the series).
2. `tools/build-image.sh` stages `overlay/`, runs the build tools (`build.sh`, `prepare-fake-ota.sh`,
   `system-image-from-ota.sh`) and adds the VNDK v30 APEX (extracted from MIUI V14.0.4.0 `system_ext` with
   `tools/extract-vndk30.sh` + `tools/flatten-vndk30.sh`; proprietary, not in this repo) to the Halium `android-rootfs.img`.
3. Output: `boot.img` (boot partition) and `rootfs.img` (system partition, grown to 6 GiB in `super`).
4. Flash from LineageOS recovery's fastbootd: `fastboot flash system rootfs.img`, `fastboot flash boot boot.img`
   (userdata is kept). Tested 2026-10-11: all features in the table come up from the image alone.
