# daemon runs in the background
# run something like tail /var/log/WATT/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/WATT:/var/lib/WATT -v $(pwd)/wallet:/home/WATT --rm -ti WATT:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG WATT_BRANCH=master
ENV WATT_BRANCH=${WATT_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/idjibril/WATT.git /src/WATT && \
    cd /src/WATT && \
    git checkout $WATT_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/WATT /usr/local/bin/WATT && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/WATT && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/WATT && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the WATT service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/WATT WATT && \
    useradd -s /bin/bash -m -d /home/WATT WATT && \
    mkdir -p /etc/services.d/WATT/log && \
    mkdir -p /var/log/WATT && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/WATT/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/WATT/run && \
    echo "cd /var/lib/WATT" >> /etc/services.d/WATT/run && \
    echo "export HOME /var/lib/WATT" >> /etc/services.d/WATT/run && \
    echo "s6-setuidgid WATT /usr/local/bin/WATT" >> /etc/services.d/WATT/run && \
    chmod +x /etc/services.d/WATT/run && \
    chown nobody:nogroup /var/log/WATT && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/WATT/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/WATT/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/WATT" >> /etc/services.d/WATT/log/run && \
    chmod +x /etc/services.d/WATT/log/run && \
    echo "/var/lib/WATT true WATT 0644 0755" > /etc/fix-attrs.d/WATT-home && \
    echo "/home/WATT true WATT 0644 0755" > /etc/fix-attrs.d/WATT-home && \
    echo "/var/log/WATT true nobody 0644 0755" > /etc/fix-attrs.d/WATT-logs

VOLUME ["/var/lib/WATT", "/home/WATT","/var/log/WATT"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/WATT export HOME /home/WATT s6-setuidgid WATT /bin/bash"]
