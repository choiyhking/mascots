FROM ubuntu:24.10

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y -qq \
    tzdata apt-utils vim git wget build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/choiyhking/netperf.git && \
    cd netperf && \
    wget -O config.guess https://git.savannah.gnu.org/cgit/config.git/plain/config.guess && \
    wget -O config.sub https://git.savannah.gnu.org/cgit/config.git/plain/config.sub && \
    chmod +x config.guess config.sub && \
    ./configure --enable-intervals=yes && \
    make && make install
    
COPY ../do_tcp_*.sh .
RUN chmod +x do_tcp_*.sh

CMD ["sleep", "infinity"]
