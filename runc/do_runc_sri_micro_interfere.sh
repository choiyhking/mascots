#!/bin/bash


VICTIM_CONTAINER_NAME="sri-micro-interfere-victim-runc"
VICTIM_IMAGE_NAME="sri-micro-interfere-victim"

LOAD_CONTAINER_NAME="sri-micro-interfere-load-runc"
LOAD_IMAGE_NAME="sri-micro-interfere-load"

SERVER_IP="192.168.51.203"
MEMORY="4G"

# Pin network-related interrupts to a specific CPU core
# CPU "0" is default in Jetpack 6 (we can't change this.)
## grep enP8p1s0 /proc/interrupts -> interrupt #: 268
## cat /proc/irq/268/smp_affinity_list -> 0-5
## echo 0 | sudo tee /proc/irq/268/smp_affinity


run_container() {
    local name="$1"
    local image="$2"

    if [ "$(sudo docker ps -a -q -f name="^${name}$")" ]; then
    	STATUS=$(sudo docker inspect -f '{{.State.Status}}' "$name")
    	if [ "$STATUS" = "exited" ] || [ "$STATUS" = "created" ]; then
		echo "Container '$name' already exists."
		sudo docker start $name
	else
		echo "Container '$name' is already running."
	fi
    else
	echo "Container does not exist. Creating container '$name'."
        sudo docker run -q -d --name "$name" \
            --cpuset-cpus="0" \
	    --cpu-period=100000 \
	    --cpu-quota=50000 \
            --memory="$MEMORY" \
            --memory-swap="$MEMORY" \
            "$image":latest
	
    fi
}

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [baseline | tcp-tx | tcp-rx | udp-tx | udp-rx]"
    exit 1
fi


if nc -z -w2 "$SERVER_IP" 5201; then
	echo "iperf3 server reachable at "$SERVER_IP":5201"
else
    echo "iperf3 server not reachable."
    echo "[Hint] iperf3 -s"
    exit 1
fi


OUTPUT_DIR="result_interfere"
if [ -d "$OUTPUT_DIR" ]; then
    i=1; while [ -d "${OUTPUT_DIR}.$i" ]; do ((i++)); done
    mv "$OUTPUT_DIR" "${OUTPUT_DIR}.$i"
fi
mkdir -p "$OUTPUT_DIR"


run_container "$VICTIM_CONTAINER_NAME" "$VICTIM_IMAGE_NAME"
run_container "$LOAD_CONTAINER_NAME" "$LOAD_IMAGE_NAME"

sleep 5

# Maximum of TCP send/recv: ~800Mbps
# Maximum of UDP send: ~1.4Gbps
# Maximum of UDP recv: ~950Mbps
MAX=8

if [ "$1" == "baseline" ]; then
        echo "[[ Running $1 ]]"
	sudo docker exec "$LOAD_CONTAINER_NAME" ./in_do_interfere_load.sh "$1" &
    	sleep 5
	sudo docker exec "$VICTIM_CONTAINER_NAME" ./in_do_interfere_victim.sh "$1"
	sudo docker cp "$VICTIM_CONTAINER_NAME":/result_interfere_victim_$1 ./"$OUTPUT_DIR"/
	sudo docker stop "$LOAD_CONTAINER_NAME"

elif [[ "$1" =~ ^(tcp-tx|tcp-rx|udp-tx|udp-rx)$ ]]; then
	for parallel in $(seq 1 $MAX); do
		echo "[[ Running $1 (w/ parallel=$parallel) ]]"
		
		sudo docker exec "$LOAD_CONTAINER_NAME" ./in_do_interfere_load.sh "$1" "$parallel" & 
		sleep 5

		sudo docker exec "$VICTIM_CONTAINER_NAME" ./in_do_interfere_victim.sh "$1" "$parallel" 
		sudo docker cp "$VICTIM_CONTAINER_NAME":/result_interfere_victim_$1_$parallel ./"$OUTPUT_DIR"/
		sudo docker stop "$LOAD_CONTAINER_NAME"
		sleep 5
		sudo docker start "$LOAD_CONTAINER_NAME" 
		sleep 5
	done
else
	echo "Wrong options."
	exit 1
fi


sudo docker stop "$VICTIM_CONTAINER_NAME"
sudo docker stop "$LOAD_CONTAINER_NAME"
