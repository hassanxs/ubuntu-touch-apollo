#!/bin/bash
# v3: v2 kernel + cmdline (lsm/fw fixes) + ramdisk overlay that archives /sys/fs/pstore of the PREVIOUS boot to userdata
set -e
M=~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg
O=/mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/out/apollo
rm -rf /tmp/v3 && python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v2.img --out /tmp/v3 --format mkbootimg > /tmp/v3.args
rm -rf /tmp/v3r && mkdir /tmp/v3r && cd /tmp/v3r && zcat /tmp/v3/ramdisk | cpio -id scripts/halium 2>/dev/null
python3 - scripts/halium <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
anchor = '\tmount -o discard,$OPTIONS $path /tmpmnt\n'
assert anchor in s, "userdata mount anchor"
block = (anchor +
 '\t# UT-port debug: archive previous boot\'s pstore (console/pmsg) to userdata\n'
 '\tmkdir -p /sys/fs/pstore; mount -t pstore pstore /sys/fs/pstore 2>/dev/null\n'
 '\t_n=$(cat /tmpmnt/pstore-saved/next 2>/dev/null || echo 0); _d=/tmpmnt/pstore-saved/$((_n % 10))\n'
 '\trm -rf $_d; mkdir -p $_d; cp /sys/fs/pstore/* $_d/ 2>/dev/null; date > $_d/saved-at; echo $((_n + 1)) > /tmpmnt/pstore-saved/next; sync\n'
 '\ttell_kmsg "saved previous pstore to $_d"\n')
open(p, 'w').write(s.replace(anchor, block, 1))
PY
grep -n "pstore" scripts/halium | head
( find scripts -type f | cpio -o -H newc -R 0:0 2>/dev/null | gzip -9 ) > /tmp/v3-ovl.gz
zcat /tmp/v3/ramdisk | cpio -itv 2>/dev/null | grep ' scripts/halium$'
cat /tmp/v3/ramdisk /tmp/v3-ovl.gz > /tmp/v3-ramdisk.gz
ARGS=$(cat /tmp/v3.args); ARGS=${ARGS//\/tmp\/v3\/ramdisk/\/tmp\/v3-ramdisk.gz}
eval python3 $M/mkbootimg.py $ARGS -o $O/boot-apollo-v3-logsave.img
ls -l $O/boot-apollo-v3-logsave.img
