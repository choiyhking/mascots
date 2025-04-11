#!/bin/bash


export DEBIAN_FRONTEND=noninteractive

apt-get update && \
    apt-get install -y -qq tzdata vim netperf

chmod +x in_do_interfere_victim.sh

