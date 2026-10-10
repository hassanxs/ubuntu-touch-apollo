# Ubuntu Touch port — OnePlus 7 Pro (guacamole)

## Device
- Model: GM1910 (China variant)
- Build: GM1910_11_H.41
- Android: 12
- Kernel: 4.14.180-perf+
- HW ver: GM1910_11
- SoC: Snapdragon 855 (sm8150)
- Bootloader: unknown (check over fastboot)

## Target
- Halium 12 generic approach (halium-generic-adaptation-build-tools)
- Keep stock Android 12 vendor/firmware

## Build host
- Windows 11, Xeon E-2126G (6c), 64 GB RAM
- WSL2 Ubuntu-22.04 — sources live in WSL ext4 (~/ut-guacamole), outputs copied here

## Log
- 2026-09-27: project folder created, environment check done
- 2026-09-27: platform-tools installed (winget). Cloned into WSL ~/ut-guacamole:
  build-tools (halium-generic-adaptation-build-tools main), kernel (LineageOS
  android_kernel_oneplus_sm8150 lineage-19.1), ref device trees (guacamole, sm8150-common).
- 2026-09-27: kernel branch `halium-12` — check-kernel-config -w (275 fixes) + binder
  devices, RNDIS, pstore. Commit b0b4bfea9.
- 2026-09-27: port repo ~/ut-guacamole/port (deviceinfo, build -> ../build-tools).
  Facts: A/B, NO dynamic partitions, boot hdr v2, pagesize 4096, boot 96 MiB,
  system 3.39 GiB, separate dtbo (keep stock), no recovery partition.
- 2026-09-27: phone over adb: serial <redacted>, patch 2022-12-05, active slot _a,
  bootloader LOCKED, oem_unlock_allowed=1. USB: must be in File transfer mode for ADB.
- 2026-09-27: build #1 failed at prepare-compiler-check. Cause: OnePlus Makefile adds
  --param=allow-store-data-races=0; clang-12 + -Werror in cc-option => all probes fail.
  Fixed (kernel commit 6ad60c66f, GCC-only). Rebuild started.
- 2026-09-27: build #2/#3: prepare-compiler-check still failed via build.sh — cause was
  WSL-inherited Windows PATH. make-kernel.sh uses a clean Linux PATH.
  Build #3 failed at dtbo (in-tree dtc can't parse OnePlus overlays, dts/18821/pm8150.dtsi).
  Build #4 with DTC_EXT (Android dtc 1.4.2) => SUCCESS: KERNEL_OBJ/arch/arm64/boot/Image-dtb (62 MB).
  Board dts dir = arch/arm64/boot/dts/18821 (matches ro.boot.prj_version=18821).
- 2026-09-27: UNLOCK BLOCKED. `fastboot flashing unlock` and `fastboot oem unlock` both =>
  "Device cannot be unlocked for technical reason." even with sys.oem_unlock_allowed=1.
  Known OnePlus bug on Android 12 (OOS/H2OS 12) for 7 Pro. Fix: roll back to Android 11,
  unlock there, then (optionally) upgrade back to 12 via local upgrade (stays unlocked).
- 2026-09-27: downgrade route = Local upgrade. Files in firmware/:
  - OnePlus7ProOxygen_21.E.41_OTA_0410_all_2112101752_downgrade_3821c2d4496c48fc.zip
    (EU OOS11 rollback, official s3.amazonaws.com/oxygenos.oneplus.net, 2,501,876,884 bytes)
  - OPLocalUpdate_For_Android12.apk (AndroidFileHost fid <redacted>;
    official oxygenos.oneplus.net link is 403). sha256 57751a3b…81001c.
    Signed by Oplus platform cert SHA256 FC:98:DA:E6…43:86 == phone's framework-res.apk cert.
  - Phone's own updater com.oplus.ota 3.14.16 has no local-install activity.
- 2026-09-27: rolled back to OOS11 (GM1910_21_211210, 2021-12) via Local install; now slot _b.
  `fastboot flashing unlock` => OK. flash.locked=0, verifiedbootstate=orange. UNLOCKED.
- 2026-09-27: booted TWRP 3.6.2_11-0 from RAM; dd backups in firmware/backup/ (SHA256SUMS):
  modemst1/2, fsg (all-zero, normal), fsc, persist, devinfo, boot/dtbo/vbmeta/vendor a+b.
- 2026-09-27: phone updating via OTA: 11.0.9.1 GM21BA (EU) next, then OOS12.
- 2026-09-27: build.sh failures explained: deviceinfo_kernel_arch="arm64" => toolchain prefix
  arm64-linux-android- (doesn't exist) => every cc-option failed. Removed (defaults aarch64).
  disable_modules=true breaks overlaystore touch => set false.
  Stock boot_b: plain Image (no OnePlus hdr), dtb in hdr v2 field -> kernel_image_name=Image,
  deviceinfo_dtb = 20 dtbs (18865,18821,19801,18857,19863 x 4). out/boot.img built.
- 2026-09-27: phone now OOS12 GM1910_11_H.40 on slot _b (Android 12 vendor). Slot _a = UT slot:
  system_a = UT rootfs (flashed w/ `fastboot -S 256M`; default chunking failed w/ USB error),
  boot_a = out/boot.img, dtbo_a = out/dtbo.img (built from kernel *.dtbo), vbmeta_a = flags=2.
  vendor_a/firmware on slot a = OOS 11.0.9.1 (Android 11) — needs A12 later.
- 2026-09-27: FIRST BOOTS: UT kernel starts (USB drops) then resets to fastboot within ~10 s,
  on both slot b (stock OOS12 dtbo) and slot a (our dtbo). ro.boot.bootreason=bootloader.
  Bootloader auto-falls back to slot b => Android 12 OK. TWRP 3.6.2_11 and 3.7.1_12 also
  bounce to fastboot on the OOS12 slot. pstore ramoops exists (0xA9800000) but needs root to read;
  no SYSTEM_LAST_KMSG in dropbox.
  Recovery if stuck on slot a: fastboot set_active b.
- 2026-09-27: bisect: building boot-stocktest.img = same source, ORIGINAL lineage defconfig.
- 2026-09-28: KEY FINDINGS
  * `fastboot boot` (RAM) is unreliable on the OOS12 ABL: TWRP 3.7.1_12 and official LOS 23.2
    recovery both bounce to fastboot that way. Invalidates earlier RAM-boot tests.
  * Normal boot of slot a stops in fastboot (retry count untouched) — SAR device; ABL adds
    skip_initramfs etc. on normal boot. Boot via "Recovery mode" (fastboot menu or
    `fastboot reboot recovery`) boots boot_a with its ramdisk.
  * Official LOS 23.2 (20260921) boot.img flashed to boot_a + LOS dtbo_a, recovery mode => WORKS
    (root adb). Kernel 4.14.357-openela g0521dc291. LOS kernel has no PSTORE, no /dev/mem.
  * Our lineage-19.1 Halium kernel, flashed + recovery mode + own dtbo => crashes ~10 s.
- 2026-09-28: PIVOT to lineage-23.2 kernel (~/ut-guacamole/kernel-23.2, branch halium-23.2):
  merged sm8150-perf_defconfig + oplus.config + oplus_non_dynamic.config -> vendor/halium_guacamole_defconfig,
  check-kernel-config -w, binder/RNDIS/pstore, CONFIG_INITRAMFS_IGNORE_SKIP_FLAG=y.
  LLVM=1 + lld, clang r510928. DTB = prebuilt from LOS boot.img (lineage-23.2.dtb).
  dtbo_a should be official LOS 23.2 dtbo.img.
- 2026-09-28: 23.2 Halium kernel built OK (needed DTC_EXT=/usr/bin/dtc 1.6.1 and
  KCFLAGS=-Wno-error=fortify-source for qcacld; kernel src symlink kernel-lineage23 because
  setup_repositories strips text after the last dot). out/boot-2332.img, out/boot-2332-debug.img.
  TEST: boot_a=boot-2332-debug + LOS dtbo_a, reboot recovery => NO crash, but HANGS on the
  unlocked-warning screen, no USB at all (no RNDIS) for 6+ min.
  !! STUCK: slot a active + INITRAMFS_IGNORE_SKIP_FLAG => every boot (normal or recovery) runs the
  hanging kernel. Power+VolUp restarts (Qualcomm logo, vibrate) but lands on slot a again; holding
  VolUp / "press power to pause boot" did not reach fastboot; slot retry fallback did NOT trigger.
  Escape options: other key combos, or drain battery then VolUp+Power while plugging USB.
  LESSON: never leave a possibly-hanging image on the ACTIVE slot. Test only images with an escape
  (e.g. LOS recovery ramdisk hybrid), and set_active b right after flashing where possible.
  Prepared: out/boot-hybrid-ourkernel-losramdisk.img (our 23.2 kernel + LOS recovery ramdisk + LOS
  dtb/cmdline) to get root adb + /sys/fs/pstore from our kernel.
- 2026-09-28: DISCOVERY: the "hang" was NOT a hang. After a cable replug Windows showed
  USB\VID_18D1&PID_D001\HALIUM_INITRD_DEBUG_TELNET_ON_PORT_23_ON_RNDIS0_192.168.2.15 — i.e. our
  lineage-23.2 Halium kernel + halium initrd BOOT FINE (display just stays on the bootloader's
  last frame). Windows bound it to "Android ADB Recovery Interface"; needs manual driver switch to
  Microsoft "Remote NDIS Compatible Device" to reach telnet 192.168.2.15:23.
  => Kernel side WORKS. Next port attempt: boot-2332.img (real systempart) + fix RNDIS driver.
- 2026-09-28: user chose to restore stock via MSM (EDL). Package E:\MSM (from
  onepluscommunityserver.com EU_GM21BA/R): guacamole_21_E.01_211210.ops (MD5 9064dc53…106a OK,
  build_path SM8150/18821_R/.../OXYGEN_EU), OOS 11.0.5.1 GM21BA. Used "MsmDownloadTool V4.0.exe"
  (reports V5.1.70); the _factory.exe was flagged by Defender (VirTool:Win32/VMProtect) — not used.
  9008 driver: Microsoft Update Catalog "Qualcomm HS-USB QDLoader 9008" (Win10+), cab signed by
  Microsoft, .cat signed by MS Hardware Compatibility Publisher -> firmware/qdloader9008-driver/.
  (A separately-sourced Qualcomm installer failed with Code 52 — removed.)
  MSM Upgrade mode => Download Complete in 315 s. Phone now stock OOS11 EU, wiped, relocked.
  To resume porting: OOS11 => `fastboot flashing unlock` works directly (unlock bug is A12 only).
- 2026-09-28: 7 Pro restored OK (IMEI shows). User switching target device (7 Pro buttons loose)
  to OnePlus 7T Pro 5G McLaren HD1925 (T-Mobile), codename hotdogg / OnePlus7TProNR:
  serial <redacted>, OOS12 HD1925_11_F.05 (2023-08), patch 2022-12-05, ro.boot.prj_version=19861,
  slot _b, dynamic partitions (super + vbmeta_system), separate recovery_a/b, locked,
  sys.oem_unlock_allowed=1. Kernel-23.2 drivers reference 19861 but no dts/19861 dir -> use stock DTB.
  No official LOS for hotdogg (hotdog/hotdogb are official).
  `fastboot oem get_unlock_code`: PCBA <redacted>,
  code <redacted>
  -> request token at https://www.oneplus.com/us/unlock_token (~1 week). Then:
     fastboot flash cust-unlock unlock_code.bin ; fastboot oem unlock
- 2026-10-10: OnePlus never sent the 7T Pro 5G token -> dropped. New target: Xiaomi Mi 10T
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
