#!/bin/bash


trap "exit 1" SIGINT

SERVER="192.168.51.202"
TEST_TIME=30
ITER=10

SIZES_SMALL=(1 32 512)
SIZES_BIG=(1K 4K 16K 64K 256K 512K 1M)

# Local Socket Send Size(B) Local Socket Recv Size(B) Request Size(B) Elapsed Time(s) TPS
# Remote Socket Send Size(B) Remote Socket Recv Size(B)

OUTPUT_DIR="result_tcp_rr"
if [ -d "$OUTPUT_DIR" ]; then
    i=1; while [ -d "${OUTPUT_DIR}.$i" ]; do ((i++)); done
    mv "$OUTPUT_DIR" "${OUTPUT_DIR}.$i"
fi

mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE_PREFIX="${OUTPUT_DIR}/result_tcp_rr"


echo "[[ Starting TCP_RR tests ]]"

# (Small, Big) 
echo "Case 1: (Small, Big)"
for RESP_SIZE in "${SIZES_BIG[@]}"; do
    echo "  Req: 32B, Resp: ${RESP_SIZE}B"
    for ((i=1; i<=ITER; i++)); do
        echo "    Run $i..."
        netperf -H "$SERVER" -p 12865 -t TCP_RR -l "$TEST_TIME" -P 0  \
            -- -P 5001 -r 32,"$RESP_SIZE" >> "${OUTPUT_FILE_PREFIX}_32B_${RESP_SIZE}B"
    done
done

# Same size
echo "Case 2: Same size"
for SIZE in "${SIZES_SMALL[@]}" "${SIZES_BIG[@]}"; do
    echo "  Req/Resp: ${SIZE}B"
    for ((i=1; i<=ITER; i++)); do
        echo "    Run $i..."
        netperf -H "$SERVER" -p 12865 -t TCP_RR -l "$TEST_TIME" -P 0 \
            -- -P 5001 -r "$SIZE","$SIZE" >> "${OUTPUT_FILE_PREFIX}_${SIZE}B_${SIZE}B"
    done
done

# (Big, Small)
echo "Case 3: (Big, Small)"
for REQ_SIZE in "${SIZES_BIG[@]}"; do
    echo "  Req: ${REQ_SIZE}B, Resp: 32B"
    for ((i=1; i<=ITER; i++)); do
        echo "    Run $i..."
        netperf -H "$SERVER" -p 12865 -t TCP_RR -l "$TEST_TIME" -P 0 \
            -- -P 5001 -r "$REQ_SIZE",32 >> "${OUTPUT_FILE_PREFIX}_${REQ_SIZE}B_32B"
    done
done

echo "[[ TCP_RR tests finished ]]"
