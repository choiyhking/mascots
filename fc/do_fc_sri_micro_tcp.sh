#!/bin/bash


SERVER_IP="192.168.51.202"
SSH_KEY="ubuntu-24.04.id_rsa"
GUEST_IP="172.16.0.2"


if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [stream | rr]"
    exit 1
fi

if nc -z -w2 "$SERVER_IP" 12865; then
	echo "netserver is reachable at "$SERVER_IP":12865"
else
    echo "netserver not reachable."
    echo "[Run] sudo docker run -d --name sri-micro-tcp-netserver -p 12865:12865 -p 5001:5001 choiyhking/sri-micro-tcp"
    echo "[Run] sudo docker start sri-micro-tcp-netserver"
    echo "[Run] sudo docker exec sri-micro-tcp-netserver netserver"
    exit 1
fi


# Create Firecracker microVM
# $1: workload name 
pgrep [f]irecracker | xargs kill -9 > /dev/null 2>&1
./fc_run.sh sri-micro-tcp

# Guest initialization if this is new rootfs
if [ "$(cat .rootfs_status)" -eq 0 ]; then
    scp -i "$SSH_KEY" ../in_do_tcp_*.sh fc_guest_init_sri-micro-tcp.sh root@"$GUEST_IP":/root/
    ssh -i "$SSH_KEY" root@"$GUEST_IP" "bash /root/fc_guest_init_sri-micro-tcp.sh" > /dev/null 2>&1
fi


if [ "$1" == "stream" ]; then
    ssh -i "$SSH_KEY" root@"$GUEST_IP" "bash in_do_tcp_stream.sh"
elif [ "$1" == "rr" ]; then
    ssh -i "$SSH_KEY" root@"$GUEST_IP" "bash in_do_tcp_rr.sh"
else
    echo "Wrong option: $1"
    exit 1
fi

OUTPUT_DIR="result_tcp_$1"
if [ -d "$OUTPUT_DIR" ]; then
    i=1; while [ -d "${OUTPUT_DIR}.$i" ]; do ((i++)); done
    mv "$OUTPUT_DIR" "${OUTPUT_DIR}.$i"
fi

scp -i "$SSH_KEY" -r root@"$GUEST_IP":/root/"$OUTPUT_DIR" ../"$OUTPUT_DIR"
pgrep [f]irecracker | xargs kill -9 > /dev/null 2>&1
