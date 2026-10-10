#!/bin/bash
# v11 = v11 + qcacld qca6390 ini path fix
set -e
M=~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg
O=/mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/out/apollo
NEW=~/ut-apollon/port/workdir/tmp/partitions/boot.img
rm -rf /tmp/v11 /tmp/v11k
python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v6.img --out /tmp/v11 --format mkbootimg > /tmp/v11.args
python3 $M/unpack_bootimg.py --boot_img $NEW --out /tmp/v11k > /dev/null
strings /tmp/v11k/kernel | grep -m1 "Linux version" | cut -c1-90 || true
cp /tmp/v11k/kernel /tmp/v11/kernel
eval python3 $M/mkbootimg.py $(cat /tmp/v11.args) -o $O/boot-apollo-v11.img
ls -l $O/boot-apollo-v11.img; sha256sum $O/boot-apollo-v11.img
