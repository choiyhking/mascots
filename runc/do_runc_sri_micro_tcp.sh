#!/bin/bash


CONTAINER_NAME=sri-micro-tcp-runc
IMAGE_NAME=sri-micro-tcp



if nc -z -w2 192.168.51.201 12865; then
    echo "✅ netserver is reachable at 192.168.51.201:12865"
else
    echo "❌ netserver not reachable."
    echo "[Run] sudo docker run -d --name sri-micro-tcp-netserver -p 12865:12865 -p 5001:5001 choiyhking/sri-micro-tcp netserver"
    exit 1
fi

sudo docker run -d -q --name ${CONTAINER_NAME} \
		--cpus=2 \
		--memory=4G \
		--memory-swap=4G \
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

sudo docker cp "$CONTAINER_NAME":/result_tcp_$1 ./runc_result_tcp_$1
