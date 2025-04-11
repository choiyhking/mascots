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


VICTIM_CONTAINER_NAME="sri-micro-interfere-victim-runc"
VICTIM_IMAGE_NAME="sri-micro-interfere-victim"

LOAD_CONTAINER_PREFIX="sri-micro-interfere-load-runc"
LOAD_IMAGE_NAME="sri-micro-interfere-load"


run_container() {
    local name="$1"
    local image="$2"

    if [ "$(sudo docker ps -a -q -f name="^${name}$")" ]; then
    	STATUS=$(sudo docker inspect -f '{{.State.Status}}' "$name")
    	
        if [ "$STATUS" = "exited" ] || [ "$STATUS" = "created" ]; then
		    echo "Container '$name' already exists. Restarting it."
		    sudo docker start $name > /dev/null
	else
		echo "Container '$name' is already running."
	fi
    else
	    echo "Container does not exist. Creating a new container '$name'."
        sudo docker run -q -d --name "$name" \
            --cpus=1 \
            --memory=1G \
            --memory-swap=1G \
            "$image":latest > /dev/null
    fi
}



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


for i in $(seq 1 "$CONCURRENCY"); do
    run_container "${LOAD_CONTAINER_PREFIX}-$i" "$LOAD_IMAGE_NAME"
done

run_container "$VICTIM_CONTAINER_NAME" "$VICTIM_IMAGE_NAME"

sleep 5

  
echo "================== CONFIGURATION =================="
echo "  Interferer Mode : $MODE"
echo "  Concurrency     : $CONCURRENCY"
echo "  Max Bandwidth   : $MAX"
echo "  Clear Results   : $CLEAR"
echo "===================================================="

if [ "$MODE" == "sysbench" ]; then
    echo "[Run] Victim ..."
    echo "      waiting 10 seconds inside the container for interferers to start."
    sudo docker exec "$VICTIM_CONTAINER_NAME" \
        bash -c "sleep 10 && ./in_do_interfere_victim.sh \"$VICTIM_SERVER_IP\" \"$MODE\" \"\" \"$CONCURRENCY\"" &

    echo "[Run] Interferer (sysbench) ..."
    sudo docker ps --filter "name=^${LOAD_CONTAINER_PREFIX}-" --format "{{.Names}}" \
        | parallel -j 0 "sudo docker exec {} ./in_do_interfere_load.sh $LOAD_SERVER_IP $MODE"
        
    echo "Finished."
    sudo docker cp "$VICTIM_CONTAINER_NAME":/result_interfere_victim_${MODE}_c${CONCURRENCY} ./"$OUTPUT_DIR"/

elif [[ "$MODE" =~ ^(tcp-tx|tcp-rx|udp-tx|udp-rx)$ ]]; then
    for i in $(seq 1 $MAX); do
        BANDWIDTH="$((i * 100))M" # e.g., 500M

        echo "[Run] Victim ..."
        echo "      waiting 10 seconds inside the container for interferers to start."
        sudo docker exec "$VICTIM_CONTAINER_NAME" \
            bash -c "sleep 10 && ./in_do_interfere_victim.sh \"$VICTIM_SERVER_IP\" \"$MODE\" \"$BANDWIDTH\" \"$CONCURRENCY\"" &

        echo "[Run] $CONCURRENCY Interferer ..."
        echo "      iperf $MODE bandwidth=$BANDWIDTH"
        sudo docker ps --filter "name=^${LOAD_CONTAINER_PREFIX}-" --format "{{.Names}}" \
            | parallel -j 0 "sudo docker exec {} ./in_do_interfere_load.sh $LOAD_SERVER_IP $MODE $BANDWIDTH"
        
        echo "Finished."
        sudo docker cp "$VICTIM_CONTAINER_NAME":/result_interfere_victim_${MODE}_${BANDWIDTH}_c${CONCURRENCY} ./"$OUTPUT_DIR"/

        echo ""
        sleep 10
    done
fi

sudo docker ps --filter "name=^"$LOAD_CONTAINER_PREFIX"-" --format "{{.Names}}" \
    | parallel -j 0 "sudo docker stop {}"
sudo docker stop "$VICTIM_CONTAINER_NAME"

