#!/bin/bash


# Default values
ITER=10
CPU=1
MEMORY="4G"
CLEAR="no"

for arg in "$@"; do
    case $arg in
        --workload=*)
            WORKLOAD="${arg#*=}" ;;
        --iteration=*)
            ITERATION="${arg#*=}" ;;
        --cpu=*)
            CPU="${arg#*=}" ;;
        --clear=*)
            CLEAR="${arg#*=}" ;;
        --help|-h)
            echo "Usage: $0 <workload> [iteration] [cpu] [clear]"
            echo "  --workload  : stream | rr (required)"
            echo "  --iteration : number of iterations (default: 10)"
            echo "  --cpu       : number of CPUs to assign (default: 1)"
            echo "  --clear     : yes | no (delete existing results, default: no)"
            exit 0 ;;
        *)
            echo "Unknown option: $arg"
            echo "Run with --help for usage."
            exit 1 ;;
    esac
done

if [ -z "$WORKLOAD" ]; then
    echo "Error: --workload is required."
    exit 1
fi


KATA_CONFIG="/opt/kata/share/defaults/kata-containers/configuration.toml"

echo "Set Kata container's CPU and Memory"
sudo sed -i "s/^default_vcpus = [0-9]\+/default_vcpus = ${CPU}/" "${KATA_CONFIG}"
sudo sed -i "s/^default_memory = [0-9]\+/default_memory = ${MEMORY}/" "${KATA_CONFIG}"

echo -n "Updated values: " && grep -E '^default_(vcpus|memory)' "${KATA_CONFIG}" | tr '\n' ' '


CONTAINER_NAME="sri-micro-tcp-kata"
IMAGE_NAME="sri-micro-tcp"


OUTPUT_DIR="result_tcp_$WORKLOAD"
if [ "$CLEAR" == "yes" ]; then
    echo "Delete existing results."
    rm -rf "$OUTPUT_DIR"
    echo "Create new output directory."
    mkdir -p "$OUTPUT_DIR"
fi


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
    sudo docker run -d -q --name ${CONTAINER_NAME} \
	    --runtime=io.containerd.kata.v2 \
	    ${IMAGE_NAME}:latest > /dev/null 
fi


sleep 5
	

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


sudo docker cp "$CONTAINER_NAME":/$OUTPUT_DIR ./$OUTPUT_DIR
sudo docker stop "$CONTAINER_NAME"

