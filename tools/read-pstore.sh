#!/bin/bash
R="python3 $(cd "$(dirname "$0")" && pwd)/phone-run.py"
L=${LOGS:-$HOME/ut-apollon/logs}; mkdir -p $L
$R "mount -t pstore pstore /sys/fs/pstore 2>/dev/null; ls -la /sys/fs/pstore/"
for f in $($R "ls /sys/fs/pstore/" | tr -s ' \n' '\n' | grep -E 'console|dmesg|pmsg'); do
  $R "cat /sys/fs/pstore/$f" 10 > $L/pstore-$f.txt; echo "== $f: $(wc -l < $L/pstore-$f.txt) lines"
done
