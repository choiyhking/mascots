#!/bin/bash


pgrep [f]irecracker | xargs kill -9 > /dev/null 2>&1

# e.g., fc-tap1
COUNT=$(find /sys/class/net/fc* 2> /dev/null | wc -l) # number of FC tap devices
for ((i=1; i<=COUNT; i++))
do
	sudo ip link del "fc-tap${i}" 2> /dev/null 
done


rm fc_rootfs/*
rm fc_config/vm_config_*
