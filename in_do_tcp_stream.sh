#!/bin/bash

trap "exit 1" SIGINT

SERVER="192.168.51.201"
TEST_TIME=10
ITER=2
#MESSAGE_SIZES=(32 64 128 256 512 1K 2K 4K 8K 16K 32K 64K 128K 256K 512K 1M)
MESSAGE_SIZES=(32 256 1K 16K 64K 256K 1M)
HZ_LIST=("1 1000" "2 500" "5 200" "10 100")

OUTPUT_DIR="result_tcp_stream"

if [ -d "$OUTPUT_DIR" ]; then
    i=1; while [ -d "${OUTPUT_DIR}.$i" ]; do ((i++)); done
    mv "$OUTPUT_DIR" "${OUTPUT_DIR}.$i"
fi

mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE_PREFIX="${OUTPUT_DIR}/result_tcp_stream"
# Recv Socket Size(B) Send Socket Size(B) Send Message Size(B) Elapsed Time(s) Throughput(KB/s)

echo "[[ Starting TCP_STREAM tests ]]"


for pair in "${HZ_LIST[@]}"; do
    read BURST WAIT <<< "$pair"
    echo "$BURST Hz"
    
    for MSG_SIZE in "${MESSAGE_SIZES[@]}"; do
        echo "  Message size: ${MSG_SIZE}B"
        
        for i in $(seq 1 "$ITER"); do
            echo "    Run $i..."
            netperf -H "$SERVER" -p 12865 -t TCP_STREAM -l "$TEST_TIME" -f K -P 0 \
                    -b "$BURST" -w "$WAIT" \
                    -- -P 5001 -m "$MSG_SIZE" >> "${OUTPUT_FILE_PREFIX}_${BURST}hz_${MSG_SIZE}B"
        done
    done
done

echo "[[ TCP_STREAM tests finished ]]"
