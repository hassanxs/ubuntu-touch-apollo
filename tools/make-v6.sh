#!/bin/bash
# v6 = v3 ramdisk/kernel + compact cmdline (systempart first, <512 chars) + systemd/journald -> kmsg
set -e
M=~/ut-guacamole/port/workdir/downloads/android_system_tools_mkbootimg
O=/mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/out/apollo
rm -rf /tmp/v6 && python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v3-logsave.img --out /tmp/v6 --format mkbootimg > /tmp/v6.args
CMD="systempart=/dev/mapper/system androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 loop.max_part=7 cgroup.memory=nokmem,nosocket reboot=panic_warm androidboot.fstab_suffix=qcom apparmor=1 lsm=lockdown,yama,integrity,apparmor firmware_class.path=/vendor/firmware printk.devkmsg=on systemd.log_target=kmsg systemd.journald.forward_to_kmsg=1"
echo "cmdline length: ${#CMD}"
[ ${#CMD} -lt 512 ] || { echo "TOO LONG"; exit 1; }
python3 - "$CMD" <<'PY'
import sys, re
cmd = sys.argv[1]
a = open('/tmp/v6.args').read()
a = re.sub(r"--cmdline '[^']*'", "--cmdline '" + cmd + "'", a)
open('/tmp/v6.args', 'w').write(a)
PY
eval python3 $M/mkbootimg.py $(cat /tmp/v6.args) -o $O/boot-apollo-v6.img
rm -rf /tmp/v6c; python3 $M/unpack_bootimg.py --boot_img $O/boot-apollo-v6.img --out /tmp/v6c | grep -E '^(additional )?command line args' | cut -c1-120
