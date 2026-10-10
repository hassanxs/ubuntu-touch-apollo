# Rootfs overlay (Mi 10T)

Copy into the Ubuntu Touch rootfs. Things git on Windows can't store as real symlinks/state:

- `ln -s /vendor/firmware_mnt/image /usr/lib/firmware` — Wi-Fi/ADSP/venus firmware lives in the modem partition
  (Android's ueventd adds that search path; UT has no `/lib/firmware`).
- Enable units: `systemctl enable mi-touch-edge.service apollo-wlan-on.service apollo-audio-policy.service`.
- `/var/lib/lxc/android/overrides/vndservicemanager.nosel` — produced by `tools/patch-vsm.py` from the device's own
  `/vendor/bin/vndservicemanager` (MIUI V14.0.4.0, sha256 `a6ad7a43…`). Not committed (proprietary binary).
  It is bind-mounted by `var/lib/lxc/android/pre-start.d/20-vndservicemanager-nosel`, run from
  `etc/systemd/system/lxc-android-config.service.d/10-vndservicemanager-nosel.conf`.
- `audio-hal-stub` is also bind-mounted (over `/vendor/bin/hw/android.hardware.audio.service`) by the same hook.
- AccountsService `DemoEdges2=false` was set on the test device to skip the edge tutorial (optional).
