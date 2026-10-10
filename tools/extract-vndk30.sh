#!/bin/bash
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
F="/mnt/c/Users/Hassan/Downloads/apollo_global_images_V14.0.4.0.SJDMIXM_20230705.0000.00_12.0_global_8bd90035e5.tgz"
W=~/miui-v14; mkdir -p $W && cd $W
[ -f super.img ] || tar -xzf "$F" --wildcards '*/images/super.img' --strip-components=2
file super.img
if file super.img | grep -q 'sparse'; then [ -f super.raw ] || simg2img super.img super.raw; S=super.raw; else S=super.img; fi
ls -l $S
python3 -I - $S <<'PY'
import struct, sys, os
f = open(sys.argv[1], 'rb'); d = f.read(1 << 20)
h = 4096*3; hsz = struct.unpack_from('<I', d, h+8)[0]; base = h + hsz
def desc(i): return struct.unpack_from('<III', d, h+80+12*i)
po, pn, pe = desc(0); eo, en, ee = desc(1)
exts = [struct.unpack_from('<QIQI', d, base+eo+i*ee) for i in range(en)]
for i in range(pn):
    o = base+po+i*pe; name = d[o:o+36].split(b'\0')[0].decode()
    a, fe, ne, g = struct.unpack_from('<IIII', d, o+36)
    if name != 'system': continue
    out = open('system.img', 'wb')
    for k in range(ne):
        nsec, tt, tdata, tdev = exts[fe+k]
        f.seek(tdata*512); left = nsec*512
        while left:
            b = f.read(min(left, 64 << 20)); out.write(b); left -= len(b)
    out.close(); print("system extracted:", os.path.getsize('system.img'))
PY
file system.img
mkdir -p sysmnt
if file system.img | grep -qi erofs; then which fsck.erofs >/dev/null || sudo apt-get install -y -qq erofs-utils >/dev/null; mkdir -p sysx; fsck.erofs --extract=sysx system.img >/dev/null; R=sysx; else sudo mount -o loop,ro system.img sysmnt; R=sysmnt; fi
ls $R/system/apex 2>/dev/null | grep -i vndk || ls $R/apex 2>/dev/null | grep -i vndk
find $R -name 'com.android.vndk.v30*' 2>/dev/null
mkdir -p ~/ut-apollon/vndk30 && cp $(find $R -name 'com.android.vndk.v30*.apex' | head -1) ~/ut-apollon/vndk30/ && ls -l ~/ut-apollon/vndk30
mountpoint -q sysmnt && sudo umount sysmnt || true
