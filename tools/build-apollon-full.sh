#!/bin/bash
# Full Mi 10T build: device tarball -> fake OTA (UT 24.04-2.x rootfs + Halium 12 GSI) -> rootfs.img
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd ~/ut-apollon/port
cp /mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/deviceinfo-apollo deviceinfo
LOG=../logs/full-$(date +%H%M%S).log
export KCFLAGS="-Wno-error=fortify-source" DTC_EXT=/usr/bin/dtc
./build/build.sh -b workdir -o out > $LOG 2>&1; RC=$?
echo "build.sh exit=$RC log=$LOG"; tail -2 $LOG; ls -la out/
[ $RC -eq 0 ] || exit $RC
rm -rf ota
./build/prepare-fake-ota.sh out/device_apollo.tar.xz ota >> $LOG 2>&1; RC=$?
echo "prepare-fake-ota exit=$RC"; [ $RC -eq 0 ] || { tail -8 $LOG; exit $RC; }
./build/system-image-from-ota.sh ota/ubuntu_command out >> $LOG 2>&1; RC=$?
echo "system-image-from-ota exit=$RC"; tail -4 $LOG
ls -la out/
/sbin/e2fsck -fn out/rootfs.img 2>&1 | tail -1
