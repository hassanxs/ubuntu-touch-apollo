#!/bin/bash
S=~/wsl-kmod/src/drivers/net/usb
cp $S/cdc_ether.ko $S/rndis_host.ko ~/wsl-kmod/out/
modinfo ~/wsl-kmod/out/cdc_ether.ko | grep vermagic
sudo rmmod rndis_host 2>/dev/null; sudo rmmod cdc_ether 2>/dev/null
sudo modprobe usbnet
sudo insmod ~/wsl-kmod/out/cdc_ether.ko && sudo insmod ~/wsl-kmod/out/rndis_host.ko
lsmod | grep -E 'rndis_host|cdc_ether|usbnet'
echo 1-1:1.0 | sudo tee /sys/bus/usb/drivers_probe >/dev/null 2>&1
sleep 2; sudo dmesg | tail -6
bash /mnt/c/Users/Hassan/Projects/ubuntu-touch-guacamole/wsl-phone-net.sh
