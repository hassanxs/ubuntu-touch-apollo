#!/bin/bash
# v21 = v19 + Xiaomi cam_sensor open-count fix (no debug)
set -e
M=~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg
O=/mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/out/apollo
NEW=~/ut-apollon/port/workdir/tmp/partitions/boot.img
rm -rf /tmp/v21 /tmp/v21k
python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v6.img --out /tmp/v21 --format mkbootimg > /tmp/v21.args
python3 $M/unpack_bootimg.py --boot_img $NEW --out /tmp/v21k > /dev/null
strings /tmp/v21k/kernel | grep -m1 "Linux version" | cut -c1-90 || true
cp /tmp/v21k/kernel /tmp/v21/kernel
eval python3 $M/mkbootimg.py $(cat /tmp/v21.args) -o $O/boot-apollo-v21.img
ls -l $O/boot-apollo-v21.img; sha256sum $O/boot-apollo-v21.img
