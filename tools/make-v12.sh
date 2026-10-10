#!/bin/bash
# v12 = v12 + ipv4 0.0.0.0 gateway fix (NetworkManager routes)
set -e
M=~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg
O=/mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/out/apollo
NEW=~/ut-apollon/port/workdir/tmp/partitions/boot.img
rm -rf /tmp/v12 /tmp/v12k
python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v6.img --out /tmp/v12 --format mkbootimg > /tmp/v12.args
python3 $M/unpack_bootimg.py --boot_img $NEW --out /tmp/v12k > /dev/null
strings /tmp/v12k/kernel | grep -m1 "Linux version" | cut -c1-90 || true
cp /tmp/v12k/kernel /tmp/v12/kernel
eval python3 $M/mkbootimg.py $(cat /tmp/v12.args) -o $O/boot-apollo-v12.img
ls -l $O/boot-apollo-v12.img; sha256sum $O/boot-apollo-v12.img
