#!/bin/bash

KATA_CONFIG="/opt/kata/share/defaults/kata-containers/configuration.toml"

sudo sed -i "s/^default_vcpus = [0-9]\+/default_vcpus = 2/" "${KATA_CONFIG}"
sudo sed -i "s/^default_memory = [0-9]\+/default_memory = 4096/" "${KATA_CONFIG}"

CONTAINER_NAME=sri-micro-tcp-kata
IMAGE_NAME=sri-micro-tcp

# 이런거 common.h 파일로 통일 
if nc -z -w2 192.168.51.201 12865; then
    echo "✅ netserver is reachable at 192.168.51.201:12865"
else
    echo "❌ netserver not reachable."
    echo "[Run] sudo docker run -d --name sri-micro-tcp-netserver -p 12865:12865 -p 5001:5001 choiyhking/sri-micro-tcp netserver"
    exit 1
fi

sudo docker run -d -q --name ${CONTAINER_NAME} \
		--runtime=io.containerd.kata.v2 \
		${IMAGE_NAME}

	
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [stream|rr]"
    exit 1
fi

if [ "$1" == "stream" ]; then
    sudo docker exec "$CONTAINER_NAME" ./do_tcp_stream.sh
elif [ "$1" == "rr" ]; then
    sudo docker exec "$CONTAINER_NAME" ./do_tcp_rr.sh
else
    echo "Wrong option: $1"
    exit 1
fi

sudo docker cp "$CONTAINER_NAME":/result_tcp_$1 ./kata_result_tcp_$1
