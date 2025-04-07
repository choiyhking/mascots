#!/bin/bash

FC_DIR=$HOME/fc

# $1: workload type
# $2: CPU
# $3: Memory
pushd "$FC_DIR" > /dev/null

./fc_run.sh sri_micro_tcp 2 2048

scp -i ubuntu-24.04.id_rsa ../do_tcp_*.sh root@172.16.0.2:/root/
scp -i ubuntu-24.04.id_rsa fc_guest_init_sri-micro-tcp.sh root@172.16.0.2:/root/
ssh -q -i ubuntu-24.04.id_rsa root@172.16.0.2 "bash /root/fc_guest_init_sri-micro-tcp.sh" 2>&1


if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [stream|rr]"
    exit 1
fi

if [ "$1" == "stream" ]; then
    ssh -i ubuntu-24.04.id_rsa root@172.16.0.2 "bash do_tcp_stream.sh"
elif [ "$1" == "rr" ]; then
    ssh -i ubuntu-24.04.id_rsa root@172.16.0.2 "bash do_tcp_rr.sh"
else
    echo "Wrong option: $1"
    exit 1
fi

scp -i ubuntu-24.04.id_rsa -r root@172.16.0.2:/root/result_tcp_$1 ../results/fc_result_tcp_$1

popd > /dev/null

