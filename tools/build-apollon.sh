#!/bin/bash
# build-apollon.sh : quick kernel + boot.img build for the Xiaomi Mi 10T (apollo) with the UBports build tools.
# (Full flashable image: tools/build-image.sh.)
#
#   PORT        build directory with build/ -> halium-generic-adaptation-build-tools (default ~/ut-apollon/port)
#   LOS_BOOT    official LineageOS apollon boot.img, used once to extract the prebuilt dtb
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
REPO=$(cd "$(dirname "$0")/.." && pwd)
PORT=${PORT:-$HOME/ut-apollon/port}
LOGS=${LOGS:-$HOME/ut-apollon/logs}
mkdir -p "$PORT" "$LOGS"; cd "$PORT"
[ -e build ] || { echo "clone halium-generic-adaptation-build-tools to $PORT/build first"; exit 1; }
cp "$REPO/deviceinfo" deviceinfo; sed -i 's/\r$//' deviceinfo
if [ ! -f lineage-apollon.dtb ]; then
    : "${LOS_BOOT:?set LOS_BOOT to the LineageOS apollon boot.img (needed once for the prebuilt dtb)}"
    T=$(mktemp -d)
    python3 -I workdir/downloads/android_system_tools_mkbootimg/unpack_bootimg.py --boot_img "$LOS_BOOT" --out "$T" >/dev/null
    cp "$T/dtb" lineage-apollon.dtb; rm -rf "$T"
fi
if [ -d workdir/downloads/kernel-src/.git ]; then   # keep the build tools' kernel clone in sync
    ( . ./deviceinfo; cd workdir/downloads/kernel-src && git fetch -q origin "$deviceinfo_kernel_source_branch" --depth 5 && git reset -q --hard FETCH_HEAD )
fi
LOG=$LOGS/kernel-$(date +%Y%m%d-%H%M%S).log
export KCFLAGS="-Wno-error=fortify-source" DTC_EXT=/usr/bin/dtc
./build/build.sh -k -b workdir > "$LOG" 2>&1; RC=$?
echo "exit=$RC log=$LOG"
grep -nE 'error:|Error [0-9]|^Cannot|FATAL' "$LOG" | head -20
ls -la workdir/tmp/partitions/ 2>/dev/null
exit $RC
