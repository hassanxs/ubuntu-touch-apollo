#!/bin/bash
# v17 = v6 ramdisk/cmdline + clean kernel (all fixes through apparmor SO_PEERSEC, no debug)
set -e
M=~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg
O=/mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/out/apollo
NEW=~/ut-apollon/port/workdir/tmp/partitions/boot.img
rm -rf /tmp/v17 /tmp/v17k
python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v6.img --out /tmp/v17 --format mkbootimg > /tmp/v17.args
python3 $M/unpack_bootimg.py --boot_img $NEW --out /tmp/v17k > /dev/null
strings /tmp/v17k/kernel | grep -m1 "Linux version" | cut -c1-90 || true
cp /tmp/v17k/kernel /tmp/v17/kernel
eval python3 $M/mkbootimg.py $(cat /tmp/v17.args) -o $O/boot-apollo-v17.img
ls -l $O/boot-apollo-v17.img; sha256sum $O/boot-apollo-v17.img
