#!/bin/bash
# v13 = v13 + WLAN logs to kernel only for errors
set -e
M=~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg
O=/mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/out/apollo
NEW=~/ut-apollon/port/workdir/tmp/partitions/boot.img
rm -rf /tmp/v13 /tmp/v13k
python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v6.img --out /tmp/v13 --format mkbootimg > /tmp/v13.args
python3 $M/unpack_bootimg.py --boot_img $NEW --out /tmp/v13k > /dev/null
strings /tmp/v13k/kernel | grep -m1 "Linux version" | cut -c1-90 || true
cp /tmp/v13k/kernel /tmp/v13/kernel
eval python3 $M/mkbootimg.py $(cat /tmp/v13.args) -o $O/boot-apollo-v13.img
ls -l $O/boot-apollo-v13.img; sha256sum $O/boot-apollo-v13.img
