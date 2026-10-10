#!/bin/bash
# build-image.sh : build flashable boot.img + rootfs.img (system partition) for the Xiaomi Mi 10T (apollo).
#
# Runs in a Linux shell (WSL Ubuntu 22.04 here). Needs:
#   PORT    UBports halium-generic-adaptation-build-tools checkout layout (build/ -> build-tools)
#   KERNEL  kernel tree = LineageOS android_kernel_xiaomi_sm8250 lineage-23.2 + kernel-patches/ (branch halium-23.2),
#           referenced by deviceinfo_kernel_source
#   VNDK30  com.android.vndk.v30 (flattened, tar.gz) extracted from the MIUI V14.0.4.0 system_ext image
#           (tools/extract-vndk30.sh, tools/flatten-vndk30.sh) - proprietary, not in this repo
# Output: $PORT/out/boot.img and $PORT/out/rootfs.img (+ sha256sums)
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

REPO=$(cd "$(dirname "$0")/.." && pwd)
PORT=${PORT:-$HOME/ut-apollon/port}
VNDK30=${VNDK30:-$HOME/ut-apollon/vndk30/com.android.vndk.v30.tgz}
LOGDIR=${LOGDIR:-$HOME/ut-apollon/logs}
mkdir -p "$LOGDIR"; LOG=$LOGDIR/image-$(date +%Y%m%d-%H%M%S).log
echo "log: $LOG"
[ -f "$VNDK30" ] || { echo "missing $VNDK30"; exit 1; }

cd "$PORT"
cp "$REPO/deviceinfo" deviceinfo
sed -i 's/\r$//' deviceinfo

echo "== 1. stage overlay"
rm -rf overlay; mkdir -p overlay/system
( cd "$REPO/overlay" && tar --exclude=./README.md -cf - . ) | tar -C overlay/system -xf -
S=overlay/system
find $S -type f -exec sed -i 's/\r$//' {} +
W=$S/usr/lib/systemd/system/multi-user.target.wants; mkdir -p $W
for u in mi-touch-edge apollo-wlan-on apollo-audio-policy; do ln -sf ../$u.service $W/$u.service; done
chmod 755 $S/usr/local/bin/* $S/usr/local/sbin/* $S/var/lib/lxc/android/pre-start.d/* $S/var/lib/lxc/android/overrides/*
find $S -type f -name '.halium-overlay-dir' -exec chmod 644 {} +
find $S | sort > "$LOGDIR/overlay-files.txt"

echo "== 2. kernel, boot.img, device tarball (build.sh)"
if [ -d workdir/downloads/kernel-src/.git ]; then   # build-tools keep a clone; sync it with deviceinfo_kernel_source
    ( cd workdir/downloads/kernel-src && git fetch -q origin "$(. ./../../../deviceinfo; echo $deviceinfo_kernel_source_branch)" --depth 5 && git reset -q --hard FETCH_HEAD && git log --oneline -1 )
fi
export KCFLAGS="-Wno-error=fortify-source" DTC_EXT=/usr/bin/dtc
./build/build.sh -b workdir -o out >> "$LOG" 2>&1 || { tail -20 "$LOG"; exit 1; }

echo "== 3. fake OTA + system image"
rm -rf ota
./build/prepare-fake-ota.sh out/device_apollo.tar.xz ota >> "$LOG" 2>&1 || { tail -20 "$LOG"; exit 1; }
./build/system-image-from-ota.sh ota/ubuntu_command out >> "$LOG" 2>&1 || { tail -20 "$LOG"; exit 1; }

echo "== 4. add VNDK v30 to the Halium android-rootfs.img inside rootfs.img"
T=$(mktemp -d); trap 'sudo umount -q $T/root $T/android 2>/dev/null || true; rm -rf $T' EXIT
mkdir -p $T/root $T/android
sudo mount -o loop out/rootfs.img $T/root
AIMG=$T/root/var/lib/lxc/android/android-rootfs.img
[ -f "$AIMG" ] || { echo "no android-rootfs.img in rootfs.img"; exit 1; }
sudo cp "$AIMG" $T/android.img; sudo chown "$(id -u)" $T/android.img
truncate -s +200M $T/android.img
/sbin/e2fsck -fy $T/android.img >> "$LOG" 2>&1 || true
/sbin/resize2fs $T/android.img >> "$LOG" 2>&1
sudo mount -o loop $T/android.img $T/android
A=$T/android/system/apex
[ -d "$A" ] || { echo "no system/apex in android image"; exit 1; }
sudo mkdir -p $A/com.android.vndk.v30
sudo tar -C $A/com.android.vndk.v30 -xzf "$VNDK30"
sudo umount $T/android
/sbin/e2fsck -fn $T/android.img >> "$LOG" 2>&1
sudo cp $T/android.img "$AIMG"
sudo umount $T/root
/sbin/e2fsck -fn out/rootfs.img >> "$LOG" 2>&1

cd out
sha256sum boot.img rootfs.img | tee SHA256SUMS
ls -la boot.img rootfs.img
echo "done"
