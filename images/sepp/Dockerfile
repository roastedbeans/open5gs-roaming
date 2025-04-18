# syntax=docker/dockerfile:1

ARG OPEN5GS_VERSION="v2.7.5"
ARG UBUNTU_VERSION="jammy"

FROM base-open5gs:${OPEN5GS_VERSION} AS builder

FROM ubuntu:${UBUNTU_VERSION}

# build-time arguments
ARG DEBIAN_FRONTEND="noninteractive"

# Install only the essential dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgnutls28-dev \
    libcurl4-gnutls-dev \
    libyaml-dev \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

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
    && mkdir -p /etc/open5gs/default/tls/ \
    && chmod 755 /etc/open5gs/default/tls/

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# use CMD to provide arguments to the script
CMD ["-c", "/etc/open5gs/default/sepp.yaml"]