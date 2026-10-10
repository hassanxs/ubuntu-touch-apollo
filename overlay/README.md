# Rootfs overlay (Mi 10T)

Installed by the UBports build tools (`deviceinfo_use_overlaystore="true"`) into `/opt/halium-overlay`.
At boot `mount-halium-overlay.service` (before `sysinit.target`) bind-mounts every file onto the same
path in the rootfs; a file whose target does not exist is skipped. Directories containing a
`.halium-overlay-dir` marker are merged with overlayfs instead, so they can add new files.

| Path | How it is applied | Purpose |
|---|---|---|
| `etc/gbinder.conf` | file bind (replaces stock comment-only file) | libgbinder ApiLevel=32 (AudioFlinger bridge → video recording) |
| `etc/ofono/` | merged dir | `binder.conf` (binder RIL + qti IMS ext), `ril_subscription.conf` (IQcRilAudio slots for call audio) |
| `etc/deviceinfo/devices/apollo.yaml` | merged dir | OfonoPlugin=binder, grid unit, flashlight LED |
| `usr/lib/udev/rules.d/70-android.rules` | file bind over the stock empty placeholder | device permissions from MIUI ueventd.rc + torch LED |
| `usr/lib/systemd/system/` | merged dir | units, drop-ins (lxc-android-config, ofono, bluebinder) and enable links |
| `usr/lib/systemd/user/pulseaudio.service.d/` | merged dir | start PulseAudio via `apollo-pa-launch` (audio HAL control socket) |
| `usr/local/bin`, `usr/local/sbin` | merged dirs | helpers (touch edge mode, Wi-Fi on, audio policy sanitizer, vndservicemanager patcher) |
| `usr/share/repowerd/device-configs/` | merged dir | `config-apollo.xml`: auto-brightness curve (repowerd picks `config-<ro.product.device>.xml`) |
| `var/lib/lxc/android/pre-start.d/`, `overrides/` | merged dirs | container pre-start hook + idle stub |

Notes
- `/etc/systemd/system` and `/etc/udev/rules.d` are *writable paths* on Ubuntu Touch (bind-mounted from
  userdata), so nothing is overlaid there - units live in `/usr/lib/systemd/system`.
- The systemd enable links (`multi-user.target.wants`) are created by `tools/build-image.sh`
  (git on Windows can't store symlinks).
- No proprietary binary is shipped: the patched `vndservicemanager` is generated at boot into `/run/apollo`
  from the device's own `/vendor/bin/vndservicemanager` by `usr/local/sbin/apollo-patch-vsm`.
- Proximity is Elliptic ultrasound: the sensor HAL asks the audio HAL (inside PulseAudio) to start ultrasound over
  `/dev/socket/audio_hw_socket`. `apollo-audio-hw-socket` (root) binds that socket and passes the fd to
  `apollo-pa-launch`, which exports `ANDROID_SOCKET_audio_hw_socket` + `PULSE_PASSED_FD`; the hook drops the
  `socket` line from the stubbed audio service's .rc.
- The container pre-start hook also bind-mounts `audio-hal-stub` over the container's audio HAL
  (it breaks ACDB calibration of PulseAudio's HAL) and over `storaged` (crash loop).
- Files must have LF line endings (a CRLF hook script breaks the Android container start).
- Not in the overlay (per-user, optional): AccountsService `DemoEdges2=false` skips the edge tutorial.
