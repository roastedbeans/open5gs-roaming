ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

# Set environment variables to automatically accept prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages with automatic yes to prompts
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    tshark \
    python3 \
    python3-pip \
    python3-yaml \
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

# Add a startup script to read YAML config and execute tshark
COPY tshark-wrapper.py /usr/local/bin/tshark-wrapper.py
RUN chmod +x /usr/local/bin/tshark-wrapper.py

# Switch to non-root user
USER tshark

# Command to run using our wrapper
CMD ["python3", "/usr/local/bin/tshark-wrapper.py", "/etc/tshark/tshark.yaml"]