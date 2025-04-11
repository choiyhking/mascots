#!/bin/bash


# Default values
CONCURRENCY=1
MAX=1 # Maximum bandwidth is ~800Mbps
CLEAR="no"

for arg in "$@"; do
    case $arg in
        --load_mode=*)
            MODE="${arg#*=}" ;;
        --concurrency=*)
            CONCURRENCY="${arg#*=}" ;;
        --max_bandwidth=*)
            MAX="${arg#*=}" ;;
        --clear=*)
            CLEAR="${arg#*=}" ;;
        --help|-h)
            echo "Usage: $0 <load_mode> [concurrency] [bandwidth] [clear]"
            echo "  --load_mode     : sysbench | tcp-tx | tcp-rx | udp-tx | udp-rx (required)"
            echo "  --concurrency   : number of concurrent instances (default: 1, max: 5)"
            echo "  --max_bandwidth : max bandwidth value N → N*100M (default: 1, max: 8)"
            echo "  --clear         : yes | no (delete existing results, default: no)"
            exit 0 ;;
        *)
            echo "Unknown option: $arg"
            echo "Run with --help for usage."
            exit 1 ;;
    esac
done

if [ -z "$MODE" ]; then
    echo "Error: --load_mode is required."
    echo "Run with --help for usage."
    exit 1
fi



SSH_KEY="ubuntu-24.04.id_rsa"
GUEST_IP="172.16.0.2"
SSH="ssh -i ${SSH_KEY} root@${GUEST_IP}"


VICTIM_SERVER_IP="192.168.51.201"
if nc -z -w2 "$VICTIM_SERVER_IP" 12865; then
	echo "netserver reachable at "$VICTIM_SERVER_IP":12865"
else
    echo "netserver not reachable."
    echo "[Hint] netserver"
    exit 1
fi

LOAD_SERVER_IP="192.168.51.203"
if nc -z -w2 "$LOAD_SERVER_IP" 5201; then
    echo "iperf3 server reachable at "$LOAD_SERVER_IP":5201"
else
    echo "iperf3 server not reachable."
    echo "[Hint] iperf3 -s"
    exit 1
fi

OUTPUT_DIR="result_interfere"
if [ "$CLEAR" == "yes" ]; then
    echo "Delete existing results."
    rm -rf "$OUTPUT_DIR"
    echo "Create new output directory."
    mkdir -p "$OUTPUT_DIR"
fi

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

