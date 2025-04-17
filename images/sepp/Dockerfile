# syntax=docker/dockerfile:1

# global build-time arguments for FROM statements
ARG OPEN5GS_VERSION="v2.7.5"
ARG UBUNTU_VERSION="jammy"

FROM base-open5gs:${OPEN5GS_VERSION} AS builder

FROM ubuntu:${UBUNTU_VERSION}

# build-time arguments
ARG DEBIAN_FRONTEND="noninteractive"

# install dependencies
RUN apt-get update && apt-get install libgnutls28-dev libgcrypt-dev libtalloc-dev \
    libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libyaml-dev \
    openssl ca-certificates -y

# copy executable, default config and libs
COPY --from=builder /open5gs/install/bin/open5gs-seppd /usr/local/bin/open5gs-seppd
COPY --from=builder /open5gs/install/etc/open5gs/sepp1.yaml /etc/open5gs/default/sepp.yaml
COPY --from=builder /open5gs/install/lib/*/libogsproto.so.2 /open5gs/install/lib/*/libogscore.so.2 \
/open5gs/install/lib/*/libogssbi.so.2 /open5gs/install/lib/*/libogsapp.so.2 /open5gs/install/lib/*/libogssbi-openapi.so.2 \
/open5gs/install/lib/*/libogscrypt.so.2 /usr/local/lib/

# configure dynamically linked libraries
RUN ldconfig

# create directory to store the logs and certs
RUN mkdir -p /var/log/open5gs/ \
    && mkdir -p /etc/open5gs/default/tls/

# Generate certificates with multiple domain names
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/open5gs/default/tls/sepp1.key \
    -out /etc/open5gs/default/tls/sepp1.crt \
    -subj "/CN=sepp1.localdomain" \
    -addext "subjectAltName = DNS:sepp1.localdomain,DNS:sepp.5gc.mnc001.mcc001.3gppnetwork.org" \
    && openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/open5gs/default/tls/ca.key \
    -out /etc/open5gs/default/tls/ca.crt \
    -subj "/CN=open5gs-ca"

# Create a script to generate certificates at runtime (optionally)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# use CMD to provide arguments to the script
CMD ["-c", "/etc/open5gs/default/sepp.yaml"]