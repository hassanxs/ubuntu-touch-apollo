#!/bin/bash
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SSH="ssh -i $HOME/.ssh/ut_apollo -o UserKnownHostsFile=$HOME/.ssh/known_hosts_ut -o ConnectTimeout=8"
W=~/ut-apollon/androidimg; mkdir -p $W && cd $W
$SSH root@10.15.19.82 'df -h / | tail -1; sha256sum /var/lib/lxc/android/android-rootfs.img'
[ -f android-rootfs.orig.img ] || scp -q -i ~/.ssh/ut_apollo -o UserKnownHostsFile=~/.ssh/known_hosts_ut root@10.15.19.82:/var/lib/lxc/android/android-rootfs.img android-rootfs.orig.img
sha256sum android-rootfs.orig.img
cp android-rootfs.orig.img android-rootfs.new.img
truncate -s +160M android-rootfs.new.img
/sbin/e2fsck -fy android-rootfs.new.img >/dev/null 2>&1 || true
/sbin/resize2fs android-rootfs.new.img 2>&1 | tail -1
mkdir -p m && sudo mount -o loop android-rootfs.new.img m
A=$(sudo find m -maxdepth 3 -type d -name apex -path '*system*' | head -1); [ -z "$A" ] && A=$(sudo find m -maxdepth 2 -type d -name apex | head -1)
echo "apex dir in image: $A"; sudo ls $A | head -30
sudo mkdir -p $A/com.android.vndk.v30
sudo tar -C $A/com.android.vndk.v30 -xzf ~/ut-apollon/vndk30/com.android.vndk.v30.tgz
sudo ls -la $A/com.android.vndk.v30; sudo du -sh $A/com.android.vndk.v30; df -h m | tail -1
sudo umount m
/sbin/e2fsck -fn android-rootfs.new.img 2>&1 | tail -1
ls -l android-rootfs.new.img; sha256sum android-rootfs.new.img
