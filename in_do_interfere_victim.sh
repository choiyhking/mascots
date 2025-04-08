#!/bin/bash


TEST_TIME=30


if [ "$#" -eq 0 ]; then
	echo "Usage: $0 <load name> <parallel>"
	echo "load name: e.g., tcp-tx"
	echo "parallel: e.g., 5"
	exit 1
fi

if [ -n "$2" ]; then
    OUTPUT_FILE="result_interfere_victim_${1}_${2}"
else
    OUTPUT_FILE="result_interfere_victim_${1}"
fi

rm "$OUTPUT_FILE" > /dev/nunll 2>&1

echo "Starting VICTIM (sysbench)."
echo "  sysbench is running ..."
sysbench cpu --threads=1 --time="$TEST_TIME" --cpu-max-prime=100000 run | awk '
/events per second:/        {eps=$4}
/total number of events:/   {total=$5}
/min:/                      {min=$2}
/avg:/                      {avg=$2}
/max:/                      {max=$2}
/95th percentile:/          {p95=$3}
/sum:/                      {sum=$2}
END {
    printf("%s,%s,%s,%s,%s,%s,%s\n", eps, total, min, avg, max, p95, sum)
}' > "${OUTPUT_FILE}"

echo "VICTIM (sysbench) finished."
