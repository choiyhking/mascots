#!/bin/bash


if [ "$#" -eq 0 ]; then
	echo "Usage: $0 <server_IP> <mode> [bandwidth]"
    echo "  <mode>      : sysbench | tcp-tx | tcp-rx | udp-tx | udp-rx"
	echo "  [bandwidth] : [K/M/G]bits/sec. Required for all modes except 'sysbench'"
    exit 1
fi

TEST_TIME=60
SERVER_IP="$1"
MODE="$2"
BANDWIDTH="$3"

run_sysbench() {
	sysbench cpu --threads=1 --time="$TEST_TIME" --cpu-max-prime=100000 run > /dev/null 2>&1
}

run_iperf() {
    local protocol="$1"
    local direction="$2"
    
    local opts="-c $SERVER_IP -t $TEST_TIME -b $BANDWIDTH"

    [ "$protocol" = "udp" ] && opts="$opts -u"

    [ "$direction" = "rx" ] && opts="$opts -R"

    iperf3 $opts > /dev/null 2>&1
}




if [ "$MODE" = "sysbench" ]; then
    run_sysbench
elif [[ "$MODE" =~ ^(tcp|udp)-(tx|rx)$ ]]; then
    protocol="${MODE%%-*}"
    direction="${MODE##*-}"
    run_iperf "$protocol" "$direction"
else
    echo "Invalid mode: $MODE"
    exit 1
fi

