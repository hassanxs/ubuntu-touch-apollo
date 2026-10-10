#!/bin/bash
# v18 = v18 + CONFIG_BT_HCIVHCI
set -e
M=~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg
O=/mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/out/apollo
NEW=~/ut-apollon/port/workdir/tmp/partitions/boot.img
rm -rf /tmp/v18 /tmp/v18k
python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v6.img --out /tmp/v18 --format mkbootimg > /tmp/v18.args
python3 $M/unpack_bootimg.py --boot_img $NEW --out /tmp/v18k > /dev/null
strings /tmp/v18k/kernel | grep -m1 "Linux version" | cut -c1-90 || true
cp /tmp/v18k/kernel /tmp/v18/kernel
eval python3 $M/mkbootimg.py $(cat /tmp/v18.args) -o $O/boot-apollo-v18.img
ls -l $O/boot-apollo-v18.img; sha256sum $O/boot-apollo-v18.img
