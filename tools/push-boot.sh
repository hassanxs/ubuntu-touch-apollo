#!/bin/bash
# push-boot.sh <image> : send image to phone RAM over USB net, verify, dd to boot partition, verify, reboot
set -e
IMG="$1"; R="python3 /mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/phone-run.py"
SZ=$(stat -c %s "$IMG"); PCSUM=$(sha256sum "$IMG" | cut -d' ' -f1); echo "image $SZ bytes sha256 $PCSUM"
$R "rm -f /tmp/boot.img; (nc -l -p 9000 > /tmp/boot.img &) ; sleep 1; echo listening" 2
sleep 1; nc -q 2 192.168.2.15 9000 < "$IMG"; sleep 2
PHSUM=$($R "sha256sum /tmp/boot.img" 8 | grep -oE '^[0-9a-f]{64}')
echo "phone RAM sha256 $PHSUM"; [ "$PHSUM" = "$PCSUM" ] || { echo "MISMATCH - aborting, boot partition untouched"; exit 1; }
$R "dd if=/tmp/boot.img of=/dev/disk/by-partlabel/boot bs=4M 2>&1 | tail -1; sync" 15
RB=$($R "dd if=/dev/disk/by-partlabel/boot bs=4M 2>/dev/null | head -c $SZ | sha256sum" 15 | grep -oE '^[0-9a-f]{64}')
echo "boot partition readback sha256 $RB"; [ "$RB" = "$PCSUM" ] || { echo "READBACK MISMATCH - not rebooting"; exit 1; }
echo "verified OK"
