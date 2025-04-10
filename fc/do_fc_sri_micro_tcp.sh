#!/bin/bash


if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <workload> <iteration> <CPU> [clear]"
    echo "  <workload>  : stream | rr"
    echo "  <iteration> : number of iterations for each test (default=10)"
    echo "  <CPU>       : default is '1'"
    echo "  [clear]     : yes | no (Delete existing results. Default is 'no')"
    exit 1
fi


SSH_KEY="ubuntu-24.04.id_rsa"
GUEST_IP="172.16.0.2"
SSH="ssh -i ${SSH_KEY} root@${GUEST_IP}"


SERVER_IP="192.168.51.201"
if nc -z -w2 "$SERVER_IP" 12865; then
	echo "netserver reachable at "$SERVER_IP":12865"
else
    echo "netserver not reachable."
    echo "[Hint] sudo docker run -d --name sri-micro-tcp-netserver -p 12865:12865 -p 5001:5001 sri-micro-tcp:latest"
    echo "[Hint] sudo docker start sri-micro-tcp-netserver"
    echo "[Hint] sudo docker exec sri-micro-tcp-netserver netserver"
    exit 1
fi


CLEAR="${4:-no}"
OUTPUT_DIR="result_tcp_$WORKLOAD"
if [ "$CLEAR" == "yes" ]; then
    echo "Delete existing results."
    rm -rf "$OUTPUT_DIR"
    echo "Create new output directory."
    mkdir -p "$OUTPUT_DIR"
fi

WORKLOAD="$1"
CPU="${3:-1}"
MEM=4096
DISK="10G"

echo "Creating Firecracker microVM ..."
echo "  CPU=$CPU / MEM=$MEM / DISK=$DISK" 
pgrep [f]irecracker | xargs kill -9 > /dev/null 2>&1
./fc_run.sh $WORKLOAD $CPU $MEM $DISK

# Guest initialization if this is new rootfs
if [ "$(cat .rootfs_status)" -eq 0 ]; then
    scp -i "$SSH_KEY" \
        ../config.guess config.sub in_do_tcp_*.sh fc_guest_init_sri-micro-tcp.sh \
        root@"$GUEST_IP":/root/
    $SSH "bash /root/fc_guest_init_sri-micro-tcp.sh" > /dev/null 2>&1
fi


ITER="${2:-10}"

if [ "$WORKLOAD" == "stream" ]; then
    echo "[Run] TCP_STREAM $ITER times ..."
    $SSH "bash in_do_tcp_stream.sh $SERVER_IP $ITER"

elif [ "$WORKLOAD" == "rr" ]; then
    echo "[Run] TCP_RR $ITER times ..."
    $SSH "bash in_do_tcp_rr.sh $SERVER_IP $ITER"

else
    echo "Invalid workload: $WORKLOAD"
    exit 1
fi


if scp -q -i "$SSH_KEY" -r root@"$GUEST_IP":/root/"$OUTPUT_DIR" ./"$OUTPUT_DIR"; then
    echo "Results are successfully copied."
else
    echo "SCP failed."
fi

echo "Terminating all running Firecracker microVMs ..."
pgrep [f]irecracker | xargs kill -9 > /dev/null 2>&1

