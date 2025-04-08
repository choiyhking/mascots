#!/bin/bash


TEST_TIME=30
OUTPUT_FILE="result_interfere_victim"

rm "$OUTPUT_FILE"

echo "[[ Starting Interference tests (VICTIM) ]]"
echo "sysbench is running ..."
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

echo "[[ Interference tests (VICTIM) finished ]]"
