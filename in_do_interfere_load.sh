#!/bin/bash


TEST_TIME=60
SERVER_IP="192.168.51.203"
BADNWIDTH=100
# Maximum of TCP send/recv: ~800Mbps
# Maximum of UDP send: ~1.4Gbps
# Maximum of UDP recv: ~950Mbps

run_baseline() {
	echo "Starting INTERFERER."
	echo "  sysbench is running ..."
	sysbench cpu --threads=1 --time="$TEST_TIME" --cpu-max-prime=100000 run > /dev/null 2>&1
	echo "INTERFERER finished."
}

tcp_sender() {
	echo "Starting INTERFERER."
	echo "  TCP sender is running ..."
	iperf3 -c "$SERVER_IP" -t "$TEST_TIME" -b "$BANDWIDTH" -P "$2" > /dev/null 2>&1
	echo "INTERFERER finished."
}

tcp_receiver() {
	# -R: reverse mode (server sends, client receives)
	echo "Starting INTERFERER."
	echo "  TCP receiver is running ..."
	iperf3 -c "$SERVER_IP" -R -t "$TEST_TIME" -b "$BANDWIDTH" -P "$2" > /dev/null 2>&1
	echo "INTERFERER finished."
}

udp_sender() {
	echo "Starting INTERFERER."
	echo "  UDP sender is running ..."
	iperf3 -c "$SERVER_IP" -u -t "$TEST_TIME" -b "$BANDWIDTH" -P "$2" > /dev/null 2>&1
	echo "INTERFERER finished."
}

udp_receiver() {
	# -R: reverse mode (server sends, client receives)
	echo "Starting INTERFERER."
	echo "  UDP receiver is running ..."
	iperf3 -c "$SERVER_IP" -u -R -t "$TEST_TIME" -b "$BANDWIDTH" -P "$2" > /dev/null 2>&1
	echo "INTERFERER finished."
}


if [ "$#" -eq 0 ]; then
	echo "Usage: $0 [baseline | tcp-tx | tcp-rx | udp-tx | udp-rx] <parallel>"
	exit 1
fi

case "$1" in
    baseline)
	run_baseline
	;;
    tcp-tx) 
        tcp_sender
        ;;
    tcp-rx)
        tcp_receiver
        ;;
    udp-tx)
	udp_sender
        ;;
    udp-rx)
        udp_receiver
        ;;
    *)
        echo "Wrong option: $1"
        exit 1
        ;;
esac
