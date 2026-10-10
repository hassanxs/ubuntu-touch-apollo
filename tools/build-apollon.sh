#!/bin/bash
# Mi 10T kernel + boot.img via UBports build tools (clean Linux PATH). Log: ~/ut-apollon/logs/
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
P=~/ut-apollon/port; mkdir -p $P ~/ut-apollon/logs; cd $P
[ -e build ] || ln -s ~/ut-guacamole/build-tools build
cp /mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/deviceinfo-apollo deviceinfo
# reuse already-downloaded toolchains from the 7 Pro work
mkdir -p workdir/downloads
for t in linux-x86 build-tools kernel-build-tools android_system_tools_mkbootimg avb; do
  [ -e workdir/downloads/$t ] || ln -s ~/ut-guacamole/port/workdir/downloads/$t workdir/downloads/$t; done
[ -f lineage-apollon.dtb ] || { python3 -I ~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg/unpack_bootimg.py --boot_img /mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/firmware/apollon-lineage-20261003/boot.img --out /tmp/apollon_boot >/dev/null && cp /tmp/apollon_boot/dtb lineage-apollon.dtb; }
ls -l lineage-apollon.dtb
LOG=../logs/kernel-$(date +%H%M%S).log
export KCFLAGS="-Wno-error=fortify-source" DTC_EXT=/usr/bin/dtc
./build/build.sh -k -b workdir > $LOG 2>&1; RC=$?
echo "exit=$RC log=$LOG"
grep -nE 'error:|Error [0-9]|^Cannot|FATAL' $LOG | head -20
tail -4 $LOG
ls -la workdir/tmp/partitions/ 2>/dev/null
