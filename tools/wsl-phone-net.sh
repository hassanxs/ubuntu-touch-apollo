#!/bin/bash
# Configure ONLY the phone's RNDIS interface (identified by driver), then probe telnet.
sudo modprobe usbnet 2>/dev/null; sudo modprobe cdc_ether 2>/dev/null
lsmod | grep -q '^rndis_host' || sudo insmod ~/wsl-kmod/out/rndis_host.ko
for n in $(seq 1 15); do
  IF=""
  for d in /sys/class/net/*; do
    drv=$(basename "$(readlink -f $d/device/driver 2>/dev/null)" 2>/dev/null)
    [ "$drv" = rndis_host ] && IF=$(basename $d)
  done
  [ -n "$IF" ] && break; sleep 1
done
[ -z "$IF" ] && { echo "no rndis_host interface"; lsusb; dmesg | tail -15; exit 1; }
echo "phone interface: $IF"
sudo ip link set "$IF" up
ip addr show "$IF" | grep -q 192.168.2.20 || sudo ip addr add 192.168.2.20/24 dev "$IF"
ip -br addr show "$IF"
ping -c 2 -W 2 192.168.2.15 && timeout 4 bash -c '</dev/tcp/192.168.2.15/23' && echo "TELNET PORT OPEN"
