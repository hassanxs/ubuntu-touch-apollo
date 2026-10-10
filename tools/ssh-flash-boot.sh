#!/bin/bash
# ssh-flash-boot.sh <img> : write a boot image to the phone's boot partition from running Ubuntu Touch (root over SSH), verify, reboot
set -e
IMG="$1"; K="-i $HOME/.ssh/ut_apollo -o UserKnownHostsFile=$HOME/.ssh/known_hosts_ut -o ConnectTimeout=8"
SZ=$(stat -c %s "$IMG"); SUM=$(sha256sum "$IMG" | cut -d' ' -f1); echo "image $SZ bytes $SUM"
scp -q $K "$IMG" root@10.15.19.82:/tmp/boot-new.img
ssh $K root@10.15.19.82 "set -e; B=\$(readlink -f /dev/disk/by-partlabel/boot); echo boot=\$B
  [ \"\$(sha256sum /tmp/boot-new.img | cut -d' ' -f1)\" = $SUM ] || { echo 'RAM copy mismatch'; exit 1; }
  dd if=/tmp/boot-new.img of=\$B bs=4M conv=fsync 2>&1 | tail -1
  RB=\$(head -c $SZ \$B | sha256sum | cut -d' ' -f1); echo readback=\$RB
  [ \"\$RB\" = $SUM ] || { echo 'READBACK MISMATCH - not rebooting'; exit 1; }
  echo verified; sync; (sleep 2; systemctl reboot) >/dev/null 2>&1 &"
echo "reboot requested"
