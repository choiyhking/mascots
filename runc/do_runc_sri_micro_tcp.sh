#!/bin/bash


CONTAINER_NAME=sri-micro-tcp-runc
IMAGE_NAME=sri-micro-tcp
SERVER_IP=192.168.51.202
CPU=3
MEMORY="4G"

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


if [ "$(sudo docker ps -a -q -f name="^${CONTAINER_NAME}$")" ]; then
    STATUS=$(sudo docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")
    if [ "$STATUS" = "exited" ] || [ "$STATUS" = "created" ]; then
        echo "Container exists but is not running. Starting it..."
        sudo docker start "$CONTAINER_NAME"
    else
        echo "Container '$CONTAINER_NAME' is already running."
    fi
else
    echo "Container does not exist. Creating and starting..."
    sudo docker run -d -q --name ${CONTAINER_NAME} \
	    --cpus="$CPU" \
	    --memory="$MEMORY" \
  	    --memory-swap="$MEMORY" \
	    ${IMAGE_NAME}:latest
fi
	
sleep 5

if [ "$1" == "stream" ]; then
    sudo docker exec "$CONTAINER_NAME" ./in_do_tcp_stream.sh
elif [ "$1" == "rr" ]; then
    sudo docker exec "$CONTAINER_NAME" ./in_do_tcp_rr.sh
else
    echo "Wrong option: $1"
    exit 1
fi


OUTPUT_DIR="result_tcp_$1"
if [ -d "$OUTPUT_DIR" ]; then
    i=1; while [ -d "${OUTPUT_DIR}.$i" ]; do ((i++)); done
    mv "$OUTPUT_DIR" "${OUTPUT_DIR}.$i"
fi

sudo docker cp "$CONTAINER_NAME":/$OUTPUT_DIR ./$OUTPUT_DIR
sudo docker stop "$CONTAINER_NAME"
