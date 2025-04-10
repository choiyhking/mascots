#!/bin/bash


if [ "$#" -eq 0 ]; then
	echo "Usage: $0 <server_IP> <interferer_mode> [bandwidth] <concurrency>"
	echo "  <interferer_mode> : e.g., tcp-tx"
	echo "  [bandwidth]       : e.g., 500M"
    echo "  <concurrency>     : e.g., 4"
	exit 1
fi

TEST_TIME=30
SERVER_IP="$1"
MODE="$2"
BANDWIDTH="$3"
CONCURRENCY="$4"

# Same request/response size
SIZE="1K"

OUTPUT_FILE="result_interfere_victim_${MODE}${BANDWIDTH:+_${BANDWIDTH}}_c${CONCURRENCY}"

netperf -H "$SERVER_IP" -p 12865 -t TCP_RR -l "$TEST_TIME" -P 0 \
            -- -P 5001 -r "$SIZE","$SIZE" \
            | head -1 | awk '{print $NF}' > "$OUTPUT_FILE"

