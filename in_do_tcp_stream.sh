#!/bin/bash


trap "exit 1" SIGINT

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <server_IP> <iteration>"
    echo "  <iteration> : number of iterations for each test (default=10)"
    exit 1
fi


SERVER="$1"
ITER="${2:-10}"
TEST_TIME=60

MESSAGE_SIZES=(32 64 128 256 512 1K 2K 4K 8K 16K 32K 64K 128K 256K 512K 1M)
HZ_LIST=("1 1000" "1 500" "1 200" "1 100")

OUTPUT_DIR="result_tcp_stream"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE_PREFIX="${OUTPUT_DIR}/result_tcp_stream"
# Recv Socket Size(B) Send Socket Size(B) Send Message Size(B) Elapsed Time(s) Throughput(KB/s)


for pair in "${HZ_LIST[@]}"; do
    read BURST WAIT <<< "$pair"
    
    for MSG_SIZE in "${MESSAGE_SIZES[@]}"; do
        for i in $(seq 1 "$ITER"); do
            netperf -H "$SERVER" -p 12865 -t TCP_STREAM -l "$TEST_TIME" -f K -P 0 \
                    -b "$BURST" -w "$WAIT" \
                    -- -P 5001 -m "$MSG_SIZE" >> "${OUTPUT_FILE_PREFIX}_${BURST}hz_${MSG_SIZE}B"
        done
    done
done
