#!/bin/bash

TAP_DEV="tap0"
TAP_IP="172.16.0.1"
MASK_SHORT="/30"

# Setup network interface
sudo ip link del "$TAP_DEV" 2> /dev/null || true
sudo ip tuntap add dev "$TAP_DEV" mode tap
sudo ip addr add "${TAP_IP}${MASK_SHORT}" dev "$TAP_DEV"
sudo ip link set dev "$TAP_DEV" up

# Enable IP forwarding
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -P FORWARD ACCEPT

# This tries to determine the name of the host network interface to forward
# VM's outbound network traffic through. If outbound traffic doesn't work,
# double check this returns the correct interface!
HOST_IFACE=$(ip -j route list default |jq -r '.[0].dev')

# Set up microVM internet access
sudo iptables -t nat -D POSTROUTING -o "$HOST_IFACE" -j MASQUERADE || true
sudo iptables -t nat -A POSTROUTING -o "$HOST_IFACE" -j MASQUERADE

# $1: workload name 
# e.g., sri-micro-tcp
DISK_SIZE=10G
ROOTFS_PREFIX=$(ls *.upstream | sed 's/\.squashfs\.upstream$//')
if [ -f "${ROOTFS_PREFIX}-$1.ext4" ]; then
    echo "Already exist!"
else
    sudo chown -R root:root squashfs-root
    truncate -s $DISK_SIZE ${ROOTFS_PREFIX}-$1.ext4
    sudo mkfs.ext4 -d squashfs-root -F ${ROOTFS_PREFIX}-$1.ext4 > /dev/null 2>&1
fi

API_SOCKET="/tmp/firecracker.socket"
KERNEL="fc-Image-custom"
#KERNEL="./$(ls vmlinux* | tail -1)"
ROOTFS="./$(ls *"$1".ext4 | tail -1)"
VCPU=$2
MEM=$3
FC_MAC="06:00:AC:10:00:02"
CONFIG_FILE="vm_config"

jq --arg kernel "$KERNEL" \
   --arg rootfs "$ROOTFS" \
   --argjson vcpu "$VCPU" \
   --argjson mem "$MEM" \
   --arg mac "$FC_MAC" \
   --arg dev "$TAP_DEV" \
   '
   .["boot-source"].kernel_image_path = $kernel
   | .["drives"][0].path_on_host= $rootfs
   | .["machine-config"].vcpu_count = $vcpu
   | .["machine-config"].mem_size_mib = $mem
   | .["network-interfaces"][0].guest_mac = $mac
   | .["network-interfaces"][0].host_dev_name = $dev
   ' "$CONFIG_FILE" > "${CONFIG_FILE}_${1}.json"

sudo rm -f $API_SOCKET
(firecracker --api-sock "${API_SOCKET}" --config-file "${CONFIG_FILE}_${1}.json" > /dev/null 2>&1) &

sleep 5

KEY_NAME=./$(ls *.id_rsa | tail -1)

# Setup internet access in the guest
ssh -i $KEY_NAME root@172.16.0.2  "ip route add default via 172.16.0.1 dev eth0"

# Setup DNS resolution in the guest
ssh -i $KEY_NAME root@172.16.0.2  "echo 'nameserver 155.230.10.2' > /etc/resolv.conf"

# SSH into the microVM
ssh -i $KEY_NAME root@172.16.0.2

# Use `root` for both the login and password.
# Run `reboot` to exit.
