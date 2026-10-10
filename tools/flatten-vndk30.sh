#!/bin/bash
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd ~/ut-apollon/vndk30
rm -rf pl flat; mkdir pl flat
unzip -o -q com.android.vndk.v30.apex apex_payload.img apex_manifest.pb apex_pubkey -d pl 2>/dev/null || unzip -o -q com.android.vndk.v30.apex -d pl
ls -l pl
mkdir -p mnt; sudo mount -o loop,ro pl/apex_payload.img mnt
sudo cp -a mnt/. flat/; sudo umount mnt
sudo chown -R 0:0 flat
ls -la flat; ls flat/etc; du -sh flat; ls flat/lib64 | wc -l
strings flat/apex_manifest.pb | head -3
ls flat/lib64 | grep -E 'graphics.composer@2.2|radio@1.0|libminijail|libandroidicu' 
sudo tar -C flat -cf com.android.vndk.v30.tar . && ls -l com.android.vndk.v30.tar
