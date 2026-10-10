#!/bin/bash
# gen-udev-apollo.sh : (run on phone) build /tmp/70-apollo.rules from Android ueventd.rc files (UBports porting step)
R=/var/lib/lxc/android/rootfs
cat $R/system/etc/ueventd.rc /android/vendor/ueventd.rc /android/odm/etc/ueventd.rc 2>/dev/null \
 | grep ^/dev | sed -e 's/^\/dev\///' | tr -d '\r' \
 | awk '{printf "ACTION==\"add\", KERNEL==\"%s\", OWNER=\"%s\", GROUP=\"%s\", MODE=\"%s\"\n",$1,$3,$4,$2}' > /tmp/70-apollo.rules.in
# Android names missing on the Ubuntu side -> numeric Android IDs (android_filesystem_config.h), not root:
# the container HALs run with those uids/gids (e.g. the NFC HAL as nfc=1027 needs /dev/nq-nci).
aid() { case "$1" in camera) echo 1006;; log) echo 1007;; wifi) echo 1010;; vpn) echo 1016;; usb) echo 1018;;
  mtp) echo 1024;; drmrpc) echo 1026;; nfc) echo 1027;; uhid) echo 3011;; oem_[0-9]*) echo "${1#oem_}";; *) echo root;; esac; }
map() { case "$1" in graphics) echo android_graphics;; input) echo android_input;; media) echo android_media;; *) if getent passwd "$1" >/dev/null || getent group "$1" >/dev/null; then echo "$1"; else aid "$1"; fi;; esac; }
: > /tmp/70-apollo.rules
while IFS= read -r l; do
  o=$(echo "$l" | awk -F'"' '{print $6}'); g=$(echo "$l" | awk -F'"' '{print $8}')
  echo "$l" | sed -e "s/OWNER=\"$o\"/OWNER=\"$(map $o)\"/" -e "s/GROUP=\"$g\"/GROUP=\"$(map $g)\"/" >> /tmp/70-apollo.rules
done < /tmp/70-apollo.rules.in
wc -l < /tmp/70-apollo.rules
grep -E "kgsl|\"ion\"|dri" /tmp/70-apollo.rules
