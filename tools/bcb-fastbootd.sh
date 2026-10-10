#!/bin/bash
# Back up misc, then write a bootloader_message: command=boot-recovery, recovery="recovery\n--fastboot\n"
R="python3 $(cd "$(dirname "$0")" && pwd)/phone-run.py"
B=${BACKUP:?set BACKUP to your partition backup directory (contains misc.img)}
$R "M=\$(readlink -f /dev/disk/by-partlabel/misc); echo misc=\$M; dd if=\$M of=/tmp/misc.img bs=4096 2>/dev/null; ls -l /tmp/misc.img; head -c 64 \$M | hexdump -C | head -4" 8
( cd $B && timeout 30 nc -l -p 9101 > misc-before-bcb.img ) &
sleep 1; $R "nc 192.168.2.20 9101 < /tmp/misc.img; echo sent" 15; wait
ls -l $B/misc-before-bcb.img
$R "M=\$(readlink -f /dev/disk/by-partlabel/misc); dd if=/dev/zero of=\$M bs=2048 count=1 conv=notrunc 2>/dev/null; printf 'boot-recovery' | dd of=\$M bs=1 seek=0 conv=notrunc 2>/dev/null; printf 'recovery\n--fastboot\n' | dd of=\$M bs=1 seek=64 conv=notrunc 2>/dev/null; sync; head -c 96 \$M | hexdump -C" 10
