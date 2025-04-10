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


OUTPUT_DIR="result_tcp_rr"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE_PREFIX="${OUTPUT_DIR}/result_tcp_rr"
# Local Socket Send Size(B) Local Socket Recv Size(B) Request Size(B) Elapsed Time(s) TPS
# Remote Socket Send Size(B) Remote Socket Recv Size(B)


SIZES_SMALL=(1 32 512)
SIZES_BIG=(1K 4K 16K 64K 256K 512K 1M)

# (Small, Big) 
for RESP_SIZE in "${SIZES_BIG[@]}"; do
    for ((i=1; i<=ITER; i++)); do
        netperf -H "$SERVER" -p 12865 -t TCP_RR -l "$TEST_TIME" -P 0  \
            -- -P 5001 -r 32,"$RESP_SIZE" >> "${OUTPUT_FILE_PREFIX}_32B_${RESP_SIZE}B"
    done
done

# Same size
for SIZE in "${SIZES_SMALL[@]}" "${SIZES_BIG[@]}"; do
    for ((i=1; i<=ITER; i++)); do
        netperf -H "$SERVER" -p 12865 -t TCP_RR -l "$TEST_TIME" -P 0 \
            -- -P 5001 -r "$SIZE","$SIZE" >> "${OUTPUT_FILE_PREFIX}_${SIZE}B_${SIZE}B"
    done
done

# (Big, Small)
for REQ_SIZE in "${SIZES_BIG[@]}"; do
    for ((i=1; i<=ITER; i++)); do
        netperf -H "$SERVER" -p 12865 -t TCP_RR -l "$TEST_TIME" -P 0 \
            -- -P 5001 -r "$REQ_SIZE",32 >> "${OUTPUT_FILE_PREFIX}_${REQ_SIZE}B_32B"
    done
done

