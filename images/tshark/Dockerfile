ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

# Install required packages
RUN apt-get update && apt-get install -y \
    tshark \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/tshark /captures /var/log

# Set working directory
WORKDIR /captures

# Set environment variables
ENV TZ=UTC
ENV LANG=C.UTF-8

# Create a non-root user
RUN useradd -m -s /bin/bash tshark && \
    chown -R tshark:tshark /captures /var/log

# Switch to non-root user
USER tshark

# Command to run tshark
CMD ["tshark", "-c", "/etc/tshark/tshark.yaml"] 