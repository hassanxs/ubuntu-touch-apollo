# Ubuntu Touch port — Xiaomi Mi 10T (apollo) — porting log

Chronological working notes: every problem met while bringing up Ubuntu Touch (Halium 12) on the Mi 10T
and how it was fixed. The README has the current status; this file is the detailed history.

## Device
- Xiaomi Mi 10T, M2007J3SY, codename `apollo` (LineageOS: `apollon`)
- Snapdragon 865 (SM8250, kona), external X55 modem (MHI)
- Stock: MIUI 14 V14.0.4.0.SJDMIXM, Android 12, security patch 2023-06-01, first API 29
- A-only, dynamic partitions (`super`), separate `recovery` partition, boot header v2, page size 4096

## Target
- Halium 12 GSI + Ubuntu Touch 24.04-2.x, UBports halium-generic-adaptation-build-tools (standalone kernel)
- Kernel: LineageOS `android_kernel_xiaomi_sm8250` lineage-23.2 (4.19.325) + Ubuntu Touch patches
- Stock MIUI vendor/firmware kept

## Build host
- Windows 11 + WSL2 Ubuntu 22.04 (sources in WSL ext4 under `~/ut-apollon`)
- Phone access: USB RNDIS (usbipd-win → WSL for the initrd debug shell), SSH over USB or Wi-Fi

## Log
- 2026-10-10: Target: Xiaomi Mi 10T
  M2007J3SY (apollo; LOS official "apollon", builds 2026-10-03). adb serial <redacted> (also on
  wifi adb 10.0.0.218:5555 -> use `adb -s <serial>`). MIUI 14 V14.0.4.0.SJDMIXM, Android 12,
  patch 2023-06-01, kernel 4.19.157, first_api 29, A-only (no slot suffix), dynamic super,
  separate recovery partition, vbmeta + vbmeta_system/vendor/odm/product. Bootloader LOCKED,
  OEM unlocking allowed -> user doing Mi Unlock (expect 168 h wait).
  Plan: LOS lineage-23.2 sm8250 kernel + Halium config; test images on `recovery` partition
  (Vol Up + Power) so normal boots stay on MIUI.
- 2026-10-10: Mi 10T UNLOCKED via Mi Unlock (no wait). flash.locked=0, orange.
  Official LOS 23.2 apollon 20261003 boot/dtbo/recovery.img in firmware/apollon-lineage-20261003
  (sha256 OK). Kernel: LineageOS android_kernel_xiaomi_sm8250 lineage-23.2 @71b13e62f
  (4.19.325) cloned to WSL ~/ut-apollon/kernel-src; LOS boot.img = hdr v2, Image, dtb 1.4 MB,
  cmdline "...reboot=panic_warm androidboot.fstab_suffix=qcom androidboot.init_fatal_reboot_target=recovery".
  LOS config fragments: vendor/kona-perf_defconfig + vendor/debugfs.config +
  vendor/xiaomi/sm8250-common.config + vendor/xiaomi/apollo.config. LLVM only (NO_GCC).
- 2026-10-10: flashed LOS recovery.img to `recovery` ONLY (MIUI boot untouched). Root adb backup
  -> firmware/apollon-backup (25 parts, SHA256SUMS, 371 MB). modemst1/2+fsg are ALL ZERO on this
  phone — real EFS/IMEI is in mdm1m9kefs1/2/3 (external X55 modem), backed up (~2 MB data each).
  super (8704 MiB): system 3350.5, vendor 1648.9, product 1358.3, system_ext 551.8, odm 128 MiB;
  ~1.6 GB free. For UT: drop product/system_ext in fastbootd, grow system.
- 2026-10-10: Mi 10T kernel ~/ut-apollon/kernel-src branch halium-23.2 @b619902c0 (halium_apollo_defconfig,
  generated with LLVM=1 LLVM_IAS=1 clang r510928 — kconfig probes the compiler). No IGNORE_SKIP_FLAG in
  this kernel and not needed (A10-launch, real ramdisk). deviceinfo-apollo; build-apollon.sh -> boot.img
  built first try. Debug image = boot.img + systempart=NOPE + LOS dtbo as --recovery_dtbo.
  * Flashed to `recovery` partition: bootloader went straight back to fastboot (likely needs AVB footer
    like LOS recovery: testkey_rsa4096). `fastboot boot` (RAM) WORKS on Xiaomi -> use that for tests.
  * initrd debug USB: Windows binds 18d1:d001 to a LeMobile "ADB Recovery" driver; rndiscmp/RNDIS not
    pickable on Win11 26300. Changing VID/PID (1d6b:0104, NCM or RNDIS+os_desc) => gadget never enumerated.
  * SOLUTION: usbipd-win (winget) -> WSL. Needed: `usbipd bind --busid 1-13 --force` (persisted),
    .wslconfig [experimental] hostAddressLoopback=true (mirrored mode), firewall usbipd rule
    RemoteAddress LocalSubnet,127.0.0.1, keep WSL alive (`wsl -- sleep infinity`), `usbipd attach --wsl
    --busid 1-13 --auto-attach`. WSL kernel 6.18.40.1 lacks RNDIS_HOST: built rndis_host.ko AND
    cdc_ether.ko (stock cdc_ether compiles out RNDIS detection) from linux-msft-wsl-6.18.40.1 with
    LOCALVERSION= (else vermagic "+"), full `make modules` for Module.symvers. Modules in ~/wsl-kmod/out.
    Scripts: wsl-rndis-load.sh, wsl-phone-net.sh, phone-run.py (telnet w/ IAC stripping).
  * RESULT: telnet 192.168.2.15 OK. Kernel stable (44 min up). initrd: userdata /dev/sda34 mounted,
    super parsed -> /dev/mapper/{system,vendor,odm,product,system_ext}; stopped only at NOPE systempart.
    pstore ramoops works (4M @0xb0000000). dmesg: logs/apollo/initrd-dmesg-1.txt
- 2026-10-10: INSTALL to Mi 10T: fastbootd (LOS recovery) delete product+system_ext, resize system 4 GiB,
  flash system (UT rootfs), boot, LOS dtbo, vbmeta flags=2, format:ext4 userdata. NOTE: usbipd bound
  18d1:d001 also grabs fastbootd (same VID:PID) -> don't keep auto-attach running while flashing.
  First boot: initrd panic, ALL block-device mounts fail "No such file or directory" (ext4 & vfat,
  userdata too — the "mounting /dev/sda34" line also silently failed). tmpfs mounts fine.
  ROOT CAUSE: kernel has backported stackable LSM + BPF LSM (CONFIG_LSM=...,bpf; dmesg "LSM support
  for eBPF active"). include/linux/lsm_hook_defs.h has LSM_HOOK(int, 0, fs_context_parse_param) ->
  BPF default 0 "consumes" the mount "source" param when SELinux is not active -> fc->source NULL ->
  vfs_get_tree returns -ENOENT. Upstream fix: 5.17 "security: Fix the default value of
  fs_context_parse_param hook" (-ENOPARAM). Android hides it (SELinux runs first).
  FIX (cmdline): apparmor=1 lsm=lockdown,yama,integrity,apparmor  (no bpf). -> out/apollo/boot-apollo-lsmfix.img
  TODO: also patch kernel default to -ENOPARAM.
  Side lessons: my full unpack/repack of ramdisks as non-root broke them (all repacked variants failed);
  use ORIGINAL ramdisk + appended root-owned overlay cpio instead. `fastboot boot` does not take effect
  once boot partition is bootable on this Xiaomi ABL. Writing boot from the initrd shell over USB net
  works: push-boot.sh (nc + sha256 + dd + readback) then `echo b > /proc/sysrq-trigger`.
  LOS kernel has no USB_CONFIGFS_RNDIS (only NCM) -> no debug shell with it.
- 2026-10-10: after LSM fix, UT boots into systemd + Android container. Crash #2 (~8.7s):
  "ipa3_pil_load_ipa_fws: Unable to PIL load FW for ipa_fws" -> ipa_assert BUG. ipa_fws.* is in
  /vendor/firmware (395 files); modem partition (vfat) has 482 images (/vendor/firmware_mnt/image).
  FIX: cmdline firmware_class.path=/vendor/firmware. (TODO: modem/adsp images symlinks in overlay.)
  Crash #3 (~14.7s): Oops in configfs mkdir -> usb_get_function_instance -> ptp_alloc_inst ->
  alloc_inst_mtp_ptp(false): fi_mtp->dev = _mtp_dev (NULL) then mutex_init(&dev->read_mutex).
  FIX: kernel commit 6a3ee957b (f_mtp: -ENODEV if PTP before MTP) + LSM default -ENOPARAM backport.
  Screen brightness changed during that boot (display stack touching backlight).
  pstore now has pmsg-ramoops (Android userspace log) too.
- 2026-10-10: *** UBUNTU TOUCH RUNS on Mi 10T *** (boot-apollo-v3-logsave.img = kernel 5c97545ae +
  cmdline lsm/fw fixes + initrd overlay that archives previous pstore to userdata/pstore-saved/N).
  UT USB networking: 1209:0004 "Remote NDIS based Internet Sharing Device" auto-binds on Windows;
  phone 10.15.19.82, PC gets 10.15.19.x via DHCP. SSH enabled by: symlink ssh.service into
  multi-user.target.wants (both rootfs and userdata system-data/etc/systemd/system) + key
  ~/.ssh/ut_apollo (WSL) in user-data/phablet/.ssh and system-data/root/.ssh. Helper: ut-ssh.sh
  (root@10.15.19.82); run remote scripts via `ut-ssh.sh bash -s < remote/x.sh`.
  Display dark because vendor.qti.hardware.display.composer-service can't link
  android.hardware.graphics.composer@2.2.so. ROOT CAUSE: vendor ro.vndk.version=30, Halium 12 GSI has
  only VNDK v31/v32 (linkerconfig: "Unable to access VNDK APEX /apex/com.android.vndk.v30").
  Same cause for audio, qcrild (radio@1.0), adbd, media, etc. Mir also logs
  "dlopen failed: eglSubDriverAndroid.so" (vendor/lib64/egl has it - check later).
  NEXT: get com.android.vndk.v30.apex (stock MIUI V14.0.4.0.SJDMIXM system) into the container.
- Open TODOs: deviceinfo_dtb list after 1st build,
  verify systempart=/dev/disk/by-partlabel/system_a works with halium initrd.

## 2026-10-10 — Mi 10T: from boot loop to Lomiri home screen

Boot images: v7 (f_mtp fix) → v8 (+binder) → **v9 (current, kernel g12942f7a5)** = v6 ramdisk/cmdline + new kernel (`make-v9.sh`).

1. **Boot loop / panic at ~15 s** — `list_add corruption` in `misc_register()` from `acc_alloc_inst` (f_accessory).
   Cause: a 2nd MTP function instance re-ran `__mtp_setup()` → `misc_register()` on the already registered
   `mtp_device` re-inits its list node → misc_list corrupted. Kernel fix: refuse 2nd MTP instance (-EBUSY).
2. **vndservicemanager aborts** (`Check failed: selinux_status_open(true) >= 0`, SELinux not active under UT).
   System servicemanager can't replace it (vendor clients send VNDR parcel headers → "Mixing copies of libbinder").
   Fix: `patch-vsm.py` → `vndservicemanager.nosel` (NOP the 2 CHECKs, access checks always allow), installed at
   `/var/lib/lxc/android/overrides/` and bind-mounted over `rootfs/vendor/bin/vndservicemanager` by
   `pre-start.d/20-vndservicemanager-nosel`, run from systemd drop-in
   `lxc-android-config.service.d/10-vndservicemanager-nosel.conf` (pre-start.d only runs if rootfs writable).
3. **binder rejects calls to context managers** (dmesg `transaction failed 29201/-22 line 3351`): Android 11
   servicemanagers set FLAT_BINDER_FLAG_TXN_SECURITY_CTX; AppArmor can't give a secctx → BR_FAILED_REPLY.
   Kernel fix: deliver without secctx. After 2+3: QTI composer registers, LSC: 1080x2400, GLES 3.2 Adreno.
4. **Lomiri crash loop** (SIGSEGV in strstr after `eglInitialize ... EGL_BAD_ALLOC`): phablet couldn't open
   `/dev/kgsl-3d0` (root 0600). Fix: `/etc/udev/rules.d/70-apollo.rules` generated from system+vendor ueventd.rc
   (`gen-udev-apollo.sh`, android group names mapped, unknown → root). 271 rules.
5. Edge-swipe tutorial skipped: AccountsService `com.lomiri.shell.AccountsService.DemoEdges2=false`.
6. **Left/right edge swipes hard**: Novatek grip/edge filter. `mi-touch-mode 7 1` (ioctl on /dev/xiaomi-touch,
   Touch_Edge_Filter=1) via `mi-touch-edge.service`; kernel re-applies it after resume (fw is reloaded on resume).

All userspace fixes were applied live on the phone AND saved under `overlay-apollo/` → must go into the build overlay.
Known open: Wi-Fi (no networks), audio HAL, sensors (QMI/adsprpc "Transport endpoint is not connected"), modem/MHI,
bluetooth, fscrypt not enabled on userdata (session warning only).

### Wi-Fi (QCA6390, built-in qcacld-3.0 + cnss2) — working (boot image v11, kernel g922e7aecb)
1. Firmware not found (`mhi_fw_load_handler ... ret:-2`): amss20.bin/m3.bin/bdwlan/regdb live in
   `/vendor/firmware_mnt/image/qca6390/` (Android ueventd adds that dir). Fix: `/usr/lib/firmware -> /vendor/firmware_mnt/image`
   (kernel searches /lib/firmware after firmware_class.path=/vendor/firmware). Should also help venus/cvp (still fails, TODO).
2. qcacld logs only went to cnss_diag netlink → kernel patch: always print_to_console (qdf_trace.c).
3. Probe failed: `Failed to read file wlan/qca_cld/WCNSS_qcom_cfg.ini` — generic link dangles on MIUI vendor.
   Fix: `DYNAMIC_SINGLE_CHIP := qca6390` in qcacld configs/qca6390_defconfig → uses wlan/qca_cld/qca6390/*.
4. Nothing writes ON to /dev/wlan on UT → `apollo-wlan-on.service` (+ /usr/local/sbin/apollo-wlan-on), waits for
   cnss "Calibration completed successfully", writes ON until wlan0 exists.
Result: wlan0 + p2p0, NetworkManager scan OK.
5. **No routes on wlan0 → DNS fails** (`unable to configure IPv4 route`, NM trace: "Nexthop has invalid gateway",
   ENETUNREACH even for the subnet route). Nexthop backport in this 4.19 tree sets fc_gw_family=AF_INET for any
   RTA_GATEWAY; NM 1.46 sends RTA_GATEWAY 0.0.0.0. Kernel fix (upstream behaviour): only set family if gw != 0.
   Boot image v12 (kernel gc5b0caf59). Verified after reboot: auto-connect, default route, DNS, ping OK.

### Audio (pulseaudio-modules-droid, HAL audio.primary.kona in-process) — speaker + mic working
- Audio HAL no longer crash-loops (after vndservicemanager/binder fixes). ADSP online ("Q6 is Up").
- Speaker playback OK (user heard it) even before any change: PA fell back to defaults because it could not parse MIUI's
  `/vendor/etc/audio/audio_policy_configuration.xml` (parser stops at first unknown flag).
- Mic: (1) unknown flags AUDIO_OUTPUT_FLAG_VIRTUAL_DEEP_BUFFER / AUDIO_INPUT_FLAG_INCALL_UPLINK_DOWNLINK /
  AUDIO_INPUT_FLAG_VOIP_RECORD → drop those mixPorts; (2) primary output PCM_24_BIT_PACKED unsupported by droid sink →
  declare PCM_16_BIT; (3) MIUI's "primary input" route lacks Built-In Mic → add Built-In Mic/Back Mic (else PA picks
  FM tuner = digital silence). Script `apollo-sanitize-apc`, bind-mounted by `apollo-audio-policy.service`.
- Open: ACDB init fails for voice cal (`msm_audio_ion_import: dma_buf_get failed`, cal type 4/5) → affects calls only?
  32-bit effect libs not loadable (64-bit pulseaudio) — harmless. Wi-Fi debug logging (patch 0006) floods dmesg → limit to errors.
- Mic follow-up: stereo capture → HAL picks `handset-stereo-dmic-ef` (only hiss) → sanitizer forces primary input
  to mono 48 kHz → `handset-mic`. Verified: speaker→mic loopback rms ~1600 vs quiet ~55; user's voice audible in
  playback (low level, ~1 ft away; mic gain/ACDB calibration still missing).
- **Kernel panic hazard**: killing pulseaudio during an active capture → ADSP SMMU context fault (SID 0x1801,
  adsp_tbu) → `BUG()` in arm-smmu.c (fault not marked non-fatal) → reboot. Only restart PA while idle. TODO: mark
  audio CB faults non-fatal or find why the buffer is unmapped while the DSP still writes.
- Background `parecord` started from an ssh session that then exits yields a few seconds of zeros (stalls) — test artefact.
- v13 (kernel g76af3c434): qcacld prints only errors to dmesg. Verified after clean reboot: wlan auto-connect + DNS,
  audio-policy service, edge filter, speaker sink + mono mic source all come up.

### Telephony (oFono + ofono-binder-plugin → MIUI qcrild IRadio@1.5 slot1/slot2)
- oFono had no modems: wrapper picks ril (socket /dev/socket/rild, absent) unless `device-info get OfonoPlugin` = binder.
  Fix: `/etc/deviceinfo/devices/apollo.yaml` (OfonoPlugin: binder, PrettyName, GridUnit) +
  `/etc/ofono/binder.conf` ([slot1] path=/ril_0, [slot2] path=/ril_1; "Missing path for slot" otherwise).
- Result: /ril_0 + /ril_1 online, SIMs present (giffgaff UK), slot2 registered roaming on Jazz PK (GSM). Data not
  attached (RoamingAllowed=0). Calls/SMS/data not yet tested (needs user consent: roaming costs).
- Mobile data: Onic/Ufone SIM, LTE registered, APN ufone.pinternet auto-provisioned; manual context activation →
  rmnet_data2 10.208.x, ping OK over LTE.
- Calls: incoming call rings in UI (no ringtone sound yet) and can be answered.
  1. No audio at all: voice never started (vsid state 1). IQcRilAudio bridge `audiosystem-passthrough-qti` (user unit)
     exited 2: it derives slots from /etc/ofono/ril_subscription.conf `[ril_N] transport=binder:name=slotN`.
     Rewrote that file (oFono itself uses binder.conf) → call_state=2 → voice_start_usecase OK → downlink works.
  2. No uplink: ACDB "allocate_cal_block failed" was caused by the Android container's own audio HAL
     (vendor.audio-hal, defined first by MIUI init.qcom.rc so Halium's init.disabled.rc can't disable it) registering
     calibration blocks with ITS fds first; pulseaudio's HAL then hit `dma_buf_get` on foreign fd numbers
     (debug: fd=18 file=anon_inode:[eventfd]). Fix: idle stub bind-mounted over
     /vendor/bin/hw/android.hardware.audio.service (pre-start hook). Then `ACDB -> init done!`.
  3. With working ACDB, MIUI default fluence (voice-dmic-ef) is required for uplink (handset-mic path is 2-ch in
     MIUI overlay). persist.vendor.audio.fluence.* back to true. → two-way call audio OK (user confirmed).
- Kernel debug commits (msm_audio_ion fd logging, audio_calibration ALLOCATE logging) are in v15 — drop before release.
- Ringtone: lomiri-telephony-service-approver plays it via media-hub; media-hub-server aborted
  ("apparmor::Context cannot be created for empty name") because getsockopt(SO_PEERSEC) on unix sockets gave
  ENOPROTOOPT (mainline 4.19 AppArmor has no af_unix peer labels; Ubuntu kernels carry SAUCE patches).
  Kernel fix: fall back to the peer cred label (patch "apparmor: report the peer cred label for unix sockets").
  User confirmed: ringtone + two-way audio.
- v17 (kernel g0737b3a0f): clean (debug commits dropped). Verified after reboot: SO_PEERSEC=unconfined, audio-hal
  stub bound, ACDB init done, no dma_buf errors, Wi-Fi, Onic registered, qti bridge + media-hub active.
- SMS: outgoing OK; incoming lost once the modem registered on IMS by itself (first Ufone SMS right after SIM
  insert arrived via SGs). oFono IMS Registration=disabled can't deregister the modem. Fix: binder.conf
  `extPlugin=qti` (ofono-binder-plugin-ext-qti → vendor.qti.hardware.radio.ims IImsRadio/imsradioN). Then IMS
  Registered/VoiceCapable/SmsCapable=true → incoming SMS received + VoLTE calls still OK (user confirmed).
  ext plugin hex-dumps every transaction (~460 lines/min) → ofono drop-in Environment=GUTIL_LOG_DEFAULT=warning.

### Bluetooth (bluebinder → vendor IBluetoothHci, QCA6390)
- bluebinder_wait.sh needs exactly one `init.svc.*bluetooth` = running; MIUI runs vendor.bluetooth-1-0-qti and
  vendor.xiaomi.cit.bluetooth → waits forever → BT toggles back off. Drop-in waits for vendor.bluetooth-1-0-qti only.
- `/dev/vhci` missing → CONFIG_BT_HCIVHCI=y (defconfig). v18 (kernel g322d25c18): hci0 UP, powered, scan finds devices.
- TODO: bluebinder_post.sh "Failed to get bluetooth address" (no ro.*bt.bdaddr_path); controller reports FF:DD:01:BF:EA:B2.

### Flashlight / camera
- Flashlight (ayatana-indicator-power): qcom led:torch_N + led:switch_0 → "led short/open fault" (unpopulated
  channel). Xiaomi `flashlight` LED class (0..750) works: apollo.yaml FlashlightSysfsPath=/sys/class/leds/flashlight/
  brightness, SimpleEnableValue 400; udev rule 71-apollo-torch.rules chmods it for phablet. User confirmed.
- Camera: app opens, black preview. CamX: CSLAcquireDeviceHW Sensor0 failed; kernel "cam_sensor: Not in right state
  to aquire 0" — only camera.provider holds the nodes → double acquire inside MIUI CamX/MiCamX pipelines with a
  non-MIUI client. TODO (camxoverridesettings / Xiaomi ext disable).
- Camera WORKS (v21, kernel gf0980ca26): back + front preview and photos (user confirmed).
  1. CVP/venus/cdsp offline: firmware requested from the Android container (no /lib/firmware in its mount ns) →
     kernel patch: firmware_loader also searches /vendor/firmware_mnt/image. venus, cvpss, cdsp now ONLINE.
  2. Black preview: build uses techpack/camera-xiaomi-cas, whose cam_sensor subdev close calls
     cam_sensor_shutdown() on EVERY close (clears is_probe_succeed). Device enumeration on UT (~37 s after boot,
     VIDIOC_QUERYCAP sweep) reset the provider's probe → CAM_ACQUIRE_DEV "Not in right state". Kernel patch: count
     opens, shut down only on last close.
  3. Also set persist.vendor.camera.clientname=com.android.camera (container prop, persistent in /data/property);
     probably not required after (2) — re-test before relying on it.
- Video recording: starts, app hangs after stop (TODO).
- Video recording WORKS (4K/H.264 + audio, user confirmed, played back in gallery). Recorder hung creating its
  AudioSource: audiosystem-passthrough-af could not register media.audio_flinger ("Failed to add ... -2147483647")
  because libgbinder defaulted to the Android 8-10 AIDL protocol. Fix: /etc/gbinder.d/50-apollo.conf ApiLevel=32.
  Verified oFono (IMS) + bluebinder still OK after restart.
- storaged crash-looped (bad_alloc in uid_monitor) → idle stub via pre-start hook.
- TODO: MIUI camxoverridesettings enables verbose CamX logging (logInfoMask/overrideLogLevels) → floods logcat.
- Bluetooth audio WORKS (A2DP to "Wave ANC" buds, user confirmed). Pairing from Settings only bonded the buds' LE
  companion channel (UUID 0xae00, adv flags 0x06 = BR/EDR not supported); the classic BR/EDR side has another
  address (embedded in the LE manufacturer data). Paired it via bluetoothctl (`transport bredr` scan) → A2DP sink.
  Known issue: dual-mode buds may need classic pairing; Settings UI pairs the LE identity.

### 2026-10-11 — Install image (overlaystore) built and flashed
- tools/build-image.sh: build.sh + prepare-fake-ota + system-image-from-ota + VNDK v30 into android-rootfs.img.
  deviceinfo: LOS defconfig fragments + halium.config (verified identical config), console=tty0, 5120M rootfs.
- Overlay layout: merged dirs (.halium-overlay-dir), units in /usr/lib/systemd/system (/etc/systemd/system and
  /etc/udev/rules.d are UT writable paths), udev rules over /usr/lib/udev/rules.d/70-android.rules, /etc/gbinder.conf.
- vndservicemanager patched at boot (apollo-patch-vsm) — first flash failed: /run is noexec and the bind inherits it
  → vndservicemanager restart loop → no composer, no modem. Fix: hook mounts its own exec tmpfs at /run/apollo.
- Backup of the previous working system/boot/misc: WSL ~/ut-apollon/backup-20261011 (sha256 verified).
- Flashing tip: copy rootfs.img to a Windows-local dir before `fastboot flash system` (134 s vs 632 s over \wsl$).
- Verified after clean boot: overlay (11 mounts), container hook, Lomiri, Wi-Fi, Onic+IMS, audio devices,
  AudioFlinger bridge, Bluetooth, coprocessors ONLINE.
- 2026-10-11: removed persist.vendor.camera.clientname (leftover experiment) → camera photo (back/front) + video
  still work after reboot: the Xiaomi cam_sensor kernel patch alone fixes the camera; nothing needed in the image.
