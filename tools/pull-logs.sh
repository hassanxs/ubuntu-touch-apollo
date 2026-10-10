#!/bin/bash
R="python3 $(cd "$(dirname "$0")" && pwd)/phone-run.py"
L=${LOGS:-$HOME/ut-apollon/logs}/pull-$(date +%H%M%S); mkdir -p $L
$R "mkdir -p /tmp/u; grep -q ' /tmp/u ' /proc/mounts || mount -t ext4 /dev/sda34 /tmp/u; ls /tmp/u/system-data/var/log/ 2>&1 | head -30; ls -la /tmp/u/system-data/var/log/journal/* 2>&1 | tail -6; ls /tmp/u/pstore-saved 2>&1; cat /tmp/u/pstore-saved/next 2>&1" 8
$R "cd /tmp/u; tar -czf /tmp/logs.tgz system-data/var/log/journal system-data/var/log/lightdm pstore-saved 2>/dev/null; ls -l /tmp/logs.tgz" 30
( cd $L && timeout 60 nc -l -p 9100 > logs.tgz ) &
sleep 1
$R "nc 192.168.2.20 9100 < /tmp/logs.tgz; echo sent" 30
wait
ls -l $L/logs.tgz && tar -tzf $L/logs.tgz | head -20 && tar -C $L -xzf $L/logs.tgz && echo "extracted to $L"
