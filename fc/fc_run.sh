#!/bin/bash


# Default values
CPU=1
MEMORY=4096
DISK=5G
CONCURRENCY=1
API_SOCKET="/tmp/firecracker.socket"
KEY_NAME="ubuntu-24.04.id_rsa"
chmod 600 $KEY_NAME
SSH="ssh -o StrictHostKeyChecking=no -i $KEY_NAME root@"

for arg in "$@"; do
    case $arg in
        --workload=*)
            WORKLOAD="${arg#*=}" ;;
        --cpu=*)
            CPU="${arg#*=}" ;;
        --memory=*)
            MEMORY="${arg#*=}" ;;
        --disk=*)
            DISK="${arg#*=}" ;;
        --concurrency=*)
            CONCURRENCY="${arg#*=}" ;;
        --help|-h)
            echo "Usage: $0 <workload> [cpu] [memory] [disk] [concurrency]"
            echo "  --workload    : e.g., sri-micro-tcp (required)"
            echo "  --cpu         : number of CPUs to assign (default: 1)"
            echo "  --memory      : size of memory to assign (default: 4096(MB))"
            echo "  --disk        : size of disk to assign (default: 5G)"
            echo "  --concurrency : number of concurrent instances (default: 1, max: 5)"
            exit 0 ;;
        *)
            echo "Unknown option: $arg"
            echo "Run with --help for usage."
            exit 1 ;;
    esac
done

if [ -z "$WORKLOAD" ]; then
    echo "Error: --workload is required."
    echo "Run with --help for usage."
    exit 1
fi


############################################################################################################
# Subnet: 172.16.0.0/30, 172.16.0.4/30, ...                                                                #
# There are 4 available IPs in one subnet.                                                                 #
# For example, 172.16.0.0/30                                                                               #  
# 172.16.0.0: Network address. Used to identify the subnet. Cannot be assigned as an IP.                   # 
# 172.16.0.1: Usable host IP -> Assigned to "tap" device                                                   #
# 172.16.0.2: Usable host IP -> Assigned to "guest" microVM                                                #
# 172.16.0.3: Broadcast IP. Used to send messages to all hosts in the subnet. Cannot be assigned as an IP. #
############################################################################################################

IP_PREFIX="172.16"
MASK_SHORT="/30"
A=4 # /30 subnet 

# Enable IP forwarding
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -P FORWARD ACCEPT > /dev/null 2>&1

HOST_IFACE=$(ip -j route list default | jq -r '.[0].dev')

# Set up microVM internet access
sudo iptables -t nat -D POSTROUTING -o "$HOST_IFACE" -j MASQUERADE > /dev/null 2>&1 || true
sudo iptables -t nat -A POSTROUTING -o "$HOST_IFACE" -j MASQUERADE 

CONFIG_DIR="fc_config"
mkdir -p "${CONFIG_DIR}"

ROOTFS_DIR="fc_rootfs"
mkdir -p "${ROOTFS_DIR}"

> fc_ip_list # Reset microVM IP list
> fc_pid_list # Reset microVM PID list
for ((i=1; i<=CONCURRENCY; i++)); do
    echo "Creating Firecracker microVM-[${i}] ..."
    TAP_DEV="fc-tap${i}"
    TAP_IP=${IP_PREFIX}.$(((A * (i - 1) + 1) / 256)).$(((A * (i - 1) + 1) % 256))
    GUEST_IP=${IP_PREFIX}.$(((A * (i - 1) + 2) / 256)).$(((A * (i - 1) + 2) % 256))
    # Guest IP is obtained by converting the last 4 hexa groups of the MAC into decimals.
    FC_MAC=$(printf '06:00:AC:10:00:%02x' $((2 + 4 * (i - 1))))

    echo "$GUEST_IP" >> fc_ip_list

    echo "  Setup network interface."
    # Setup network interface
    sudo ip link del "$TAP_DEV" > /dev/null 2>&1 || true
    sudo ip tuntap add dev "$TAP_DEV" mode tap
    sudo ip addr add "${TAP_IP}${MASK_SHORT}" dev "$TAP_DEV"
    sudo ip link set dev "$TAP_DEV" up


    # Create rootfs
    ROOTFS_PREFIX=$(ls *.upstream | sed 's/\.squashfs\.upstream$//')
    ROOTFS="${ROOTFS_DIR}/${ROOTFS_PREFIX}-${WORKLOAD}-${i}.ext4"
    if [ -f "${ROOTFS}" ]; then
        echo "  Rootfs already exists!"
        echo 1 > .rootfs_status
        #sudo rm ${ROOTFS}
    else
        echo "  Create new rootfs."
        echo 0 > .rootfs_status
        sudo chown -R root:root squashfs-root
        truncate -s $DISK ${ROOTFS}
        sudo mkfs.ext4 -d squashfs-root -F ${ROOTFS} > /dev/null 2>&1
    fi  


    # Create configuration
    BASE_CONFIG="${CONFIG_DIR}/vm_config" # This is base configuration
    NEW_CONFIG="${BASE_CONFIG}_${WORKLOAD}_${i}.json"
    KERNEL="fc-Image-custom"
    FC_MAC=$(printf '06:00:AC:10:00:%02x' $((2 + 4 * (i - 1))))

    jq --arg kernel "$KERNEL" \
       --arg rootfs "$ROOTFS" \
       --argjson cpu "$CPU" \
       --argjson mem "$MEMORY" \
       --arg dev "$TAP_DEV" \
       --arg mac "$FC_MAC" \
       '
       .["boot-source"].kernel_image_path = $kernel
       | .["drives"][0].path_on_host= $rootfs
       | .["machine-config"].vcpu_count = $cpu
       | .["machine-config"].mem_size_mib = $mem
       | .["network-interfaces"][0].host_dev_name = $dev
       | .["network-interfaces"][0].guest_mac = $mac
       ' "$BASE_CONFIG" > "${NEW_CONFIG}"
    echo "  Configuration is created as ${NEW_CONFIG}"
   
    echo "  Start Firecracker microVM ..."
    sudo rm -f $API_SOCKET
    (firecracker --api-sock "${API_SOCKET}" --config-file "${NEW_CONFIG}" > /dev/null 2>&1) &
    echo "$!" > fc_pid_list 
    #(firecracker --api-sock "${API_SOCKET}" --config-file "${NEW_CONFIG}")

    sleep 5

    echo "    Setup Internet access in the guest ..." 
    # Setup internet access in the guest
    ${SSH}${GUEST_IP} "ip addr add ${GUEST_IP}/30 dev eth0" > /dev/null 2>&1
    ${SSH}${GUEST_IP} "ip link set eth0 up"
    ${SSH}${GUEST_IP} "ip route add default via ${TAP_IP} dev eth0" > /dev/null 2>&1

    echo "    Setup DNS resolution in the guest ..."
    # Setup DNS resolution in the guest
    ${SSH}${GUEST_IP} "echo 'nameserver 155.230.10.2' > /etc/resolv.conf"
done

echo "Current Firecracker microVM IP list:"
cat fc_ip_list

# SSH into the microVM
# ssh -i $KEY_NAME root@${GUEST_IP}

# Use `root` for both the login and password.
# Run `reboot` to exit.
