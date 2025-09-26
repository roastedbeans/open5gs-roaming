# syntax=docker/dockerfile:1

FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies for cicflowmeter
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    libpcap-dev \
    curl \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

# Install uv for dependency management
RUN pip install uv

# Clone cicflowmeter repository
RUN git clone https://github.com/hieulw/cicflowmeter.git .

# Install Python dependencies using uv
RUN uv sync --frozen

# Install additional Python packages for PCAP processing
RUN uv pip install pandas

# Create directory for PCAP files
RUN mkdir -p /pcap

# Copy the PCAP converter script
COPY pcap_converter.py /usr/local/bin/pcap_converter.py
RUN chmod +x /usr/local/bin/pcap_converter.py

# Set working directory for PCAP processing
WORKDIR /pcap

# Add uv environment to PATH and ensure system binaries are available
ENV PATH="/app/.venv/bin:/usr/bin:/usr/local/bin:$PATH"

# Default command
CMD ["python3", "/usr/local/bin/pcap_converter.py", "--help"]
