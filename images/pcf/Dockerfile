# syntax=docker/dockerfile:1

# global build-time arguments for FROM statements
ARG OPEN5GS_VERSION="v2.7.5"
ARG UBUNTU_VERSION="jammy"

FROM base-open5gs:${OPEN5GS_VERSION} AS builder

FROM ubuntu:${UBUNTU_VERSION}

# build-time arguments
ARG DEBIAN_FRONTEND="noninteractive"

RUN apt-get clean 
RUN rm -rf /var/lib/apt/lists/*
RUN apt-get upgrade -y

# install dependencies
RUN apt-get update && apt-get install libgnutls28-dev libgcrypt-dev libtalloc-dev \
    libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libyaml-dev libmongoc-dev -y

# copy executable, default config and libs
COPY --from=builder /open5gs/install/bin/open5gs-pcfd /usr/local/bin/open5gs-pcfd
COPY --from=builder /open5gs/install/etc/open5gs/pcf.yaml /etc/open5gs/default/pcf.yaml
COPY --from=builder /open5gs/install/etc/open5gs/tls/ca.crt /open5gs/install/etc/open5gs/tls/pcf.crt /open5gs/install/etc/open5gs/tls/pcf.key /etc/open5gs/default/tls/
COPY --from=builder /open5gs/install/lib/*/libogscrypt.so.2 /open5gs/install/lib/*/libogsproto.so.2 \
/open5gs/install/lib/*/libogscore.so.2 /open5gs/install/lib/*/libogssbi.so.2 /open5gs/install/lib/*/libogsapp.so.2 \
/open5gs/install/lib/*/libogssbi-openapi.so.2 /open5gs/install/lib/*/libogsdbi.so.2 /open5gs/install/lib/*/libprom.so \
/open5gs/install/lib/*/libogsmetrics.so.2 /usr/local/lib/

# configure dynamically linked libraries
RUN ldconfig

# create directory to store the logs
RUN mkdir -p /var/log/open5gs/

ENTRYPOINT [ "open5gs-pcfd" ]

# use CMD to provide arguments to ENTRYPOINT (can be overridden by user)
CMD [ "-c", "/etc/open5gs/default/pcf.yaml" ]
