#!/bin/bash


if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <workload> <iteration> <CPU> [clear]"
    echo "  <workload>  : stream | rr"
    echo "  <iteration> : number of iterations for each test (default=10)"
    echo "  <CPU>       : default is '1'"
    echo "  [clear]     : yes | no (Delete existing results. Default is 'no')"
    exit 1
fi

CONTAINER_NAME="sri-micro-tcp-runc"
IMAGE_NAME="sri-micro-tcp"


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

WORKLOAD="$1"
CLEAR="${4:-no}"
OUTPUT_DIR="result_tcp_$WORKLOAD"
if [ "$CLEAR" == "yes" ]; then
    echo "Delete existing results."
    rm -rf "$OUTPUT_DIR"
    echo "Create new output directory."
    mkdir -p "$OUTPUT_DIR"
fi


CPU="${3:-1}"
MEMORY="4G"

if [ "$(sudo docker ps -a -q -f name="^${CONTAINER_NAME}$")" ]; then
    STATUS=$(sudo docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")
    
    if [ "$STATUS" = "exited" ] || [ "$STATUS" = "created" ]; then
        echo "Container '$CONTAINER_NAME' already exists. Restarting it."
        sudo docker start "$CONTAINER_NAME" > /dev/null
    else
        echo "Container '$CONTAINER_NAME' is already running."
    fi
else
    echo "Container does not exist. Creating a new container '$CONTAINER_NAME'"
    sudo docker run -d -q --name "${CONTAINER_NAME}" \
	    --cpus="$CPU" \
	    --memory="$MEMORY" \
  	    --memory-swap="$MEMORY" \
	    ${IMAGE_NAME}:latest > /dev/null
fi
	
sleep 5


ITER="${2:-10}"

if [ "$WORKLOAD" == "stream" ]; then
    echo "[Run] TCP_STREAM $ITER times ..."
    sudo docker exec "$CONTAINER_NAME" ./in_do_tcp_stream.sh $SERVER_IP $ITER
elif [ "$WORKLOAD" == "rr" ]; then
    echo "[Run] TCP_RR $ITER times ..."
    sudo docker exec "$CONTAINER_NAME" ./in_do_tcp_rr.sh $SERVER_IP $ITER
else
    echo "Invalid workload: $WORKLOAD"
    exit 1
fi
echo "Finished."


sudo docker cp "$CONTAINER_NAME":/$OUTPUT_DIR ./$OUTPUT_DIR
sudo docker stop "$CONTAINER_NAME"

