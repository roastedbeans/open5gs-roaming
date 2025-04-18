#!/bin/bash
# Use more resilient error handling
set +e

echo "====== SEPP Container Startup ======"

# Detect the SEPP type based on container hostname or environment variable
SEPP_TYPE=${SEPP_TYPE:-"unknown"}

# If SEPP_TYPE not explicitly set, try to detect from hostname
if [ "$SEPP_TYPE" = "unknown" ]; then
    HOSTNAME=$(hostname)
    if [[ "$HOSTNAME" == *"h-sepp"* ]]; then
        SEPP_TYPE="sepp1"
    elif [[ "$HOSTNAME" == *"v-sepp"* ]]; then
        SEPP_TYPE="sepp2"
    else
        # Default to sepp1 if can't detect
        echo "Warning: Could not detect SEPP type from hostname. Defaulting to sepp1."
        SEPP_TYPE="sepp1"
    fi
fi

echo "Detected SEPP type: $SEPP_TYPE"

# Set parameters based on SEPP type
if [ "$SEPP_TYPE" = "sepp1" ]; then
    SEPP_FQDN="sepp1.localdomain"
    SEPP_PLMN_FQDN="sepp.5gc.mnc001.mcc001.3gppnetwork.org"
    SEPP_IP="10.33.33.20"
    CERT_PREFIX="sepp1"
    OTHER_SEPP="sepp2.localdomain"
    OTHER_SEPP_IP="10.33.33.10"
else
    SEPP_FQDN="sepp2.localdomain"
    SEPP_PLMN_FQDN="sepp.5gc.mnc070.mcc999.3gppnetwork.org"
    SEPP_IP="10.33.33.10"
    CERT_PREFIX="sepp2"
    OTHER_SEPP="sepp1.localdomain"
    OTHER_SEPP_IP="10.33.33.20"
fi

# Allow overriding of values through environment variables
SEPP_FQDN=${SEPP_FQDN_OVERRIDE:-"$SEPP_FQDN"}
SEPP_PLMN_FQDN=${SEPP_PLMN_FQDN_OVERRIDE:-"$SEPP_PLMN_FQDN"}
SEPP_IP=${SEPP_IP_OVERRIDE:-"$SEPP_IP"}
TLS_DIR=${TLS_DIR:-"/etc/open5gs/default/tls"}
# Default to true for testing, but should be false in production
DISABLE_VERIFY=${DISABLE_VERIFY:-"false"}

# Add the other SEPP to hosts file for DNS resolution if not already there
if ! grep -q "$OTHER_SEPP" /etc/hosts; then
    echo "Adding $OTHER_SEPP to /etc/hosts for DNS resolution..."
    echo "$OTHER_SEPP_IP $OTHER_SEPP" >> /etc/hosts
    cat /etc/hosts
fi

# Create TLS directory if it doesn't exist
if [ ! -d "$TLS_DIR" ]; then
    echo "Creating TLS directory: $TLS_DIR"
    mkdir -p "$TLS_DIR"
    chmod 755 "$TLS_DIR"
fi

# Function to check if certificates files exist
check_certs() {
    if [ -f "$TLS_DIR/ca.crt" ] && [ -f "$TLS_DIR/$CERT_PREFIX.crt" ] && [ -f "$TLS_DIR/$CERT_PREFIX.key" ]; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

# Wait for certificates to be available (timeout after 60 seconds)
echo "Waiting for certificates to be available..."
TIMEOUT=60
WAITED=0

while [ $WAITED -lt $TIMEOUT ]; do
    if check_certs; then
        echo "Certificates found!"
        break
    fi
    echo "Waiting for certificates... (${WAITED}s)"
    sleep 5
    WAITED=$((WAITED+5))
done

# Check if certificates exist after waiting
if ! check_certs; then
    echo "Error: Required certificates not found in $TLS_DIR after waiting $TIMEOUT seconds"
    echo "Missing:"
    [ ! -f "$TLS_DIR/ca.crt" ] && echo "- $TLS_DIR/ca.crt"
    [ ! -f "$TLS_DIR/$CERT_PREFIX.crt" ] && echo "- $TLS_DIR/$CERT_PREFIX.crt"
    [ ! -f "$TLS_DIR/$CERT_PREFIX.key" ] && echo "- $TLS_DIR/$CERT_PREFIX.key"
    echo "Please ensure the cert-manager container has run successfully."
    exit 1
fi

# Check for certificate chain file, if not present, create it
if [ ! -f "$TLS_DIR/$CERT_PREFIX-chain.pem" ]; then
    echo "Certificate chain file not found, creating it..."
    cat "$TLS_DIR/$CERT_PREFIX.crt" "$TLS_DIR/ca.crt" > "$TLS_DIR/$CERT_PREFIX-chain.pem"
    chmod 644 "$TLS_DIR/$CERT_PREFIX-chain.pem"
fi

# Simplified certificate information - less likely to hang
echo "Certificate files:"
ls -la $TLS_DIR/ca.crt $TLS_DIR/$CERT_PREFIX.crt $TLS_DIR/$CERT_PREFIX.key $TLS_DIR/$CERT_PREFIX-chain.pem || echo "Warning: Could not list certificate files"

# Update configuration file with the correct paths and settings
CONFIG_FILE="${1#-c }"
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    # Create a backup of the original config
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # Update certificate paths 
    if [ "$SEPP_TYPE" = "sepp2" ]; then
        echo "Updating certificate paths in config file to use $CERT_PREFIX..."
        sed -i "s|sepp1.key|$CERT_PREFIX.key|g" "$CONFIG_FILE"
        sed -i "s|sepp1.crt|$CERT_PREFIX.crt|g" "$CONFIG_FILE"
    fi
    
    # Use certificate chain file instead of individual certificate if available
    if [ -f "$TLS_DIR/$CERT_PREFIX-chain.pem" ]; then
        echo "Using certificate chain file for better security..."
        sed -i "s|$CERT_PREFIX.crt|$CERT_PREFIX-chain.pem|g" "$CONFIG_FILE"
    fi
    
    # Make sure sender and receiver are set correctly
    if [ "$SEPP_TYPE" = "sepp1" ]; then
        sed -i "s|sender:.*|sender: $SEPP_FQDN|g" "$CONFIG_FILE"
        sed -i "s|receiver:.*|receiver: sepp2.localdomain|g" "$CONFIG_FILE"
        # Ensure correct URIs for N32c and N32f
        sed -i "s|https://sepp2.localdomain:[0-9]\+|https://sepp2.localdomain:7778|g" "$CONFIG_FILE"
        sed -i "/n32f:/!s|uri: https://sepp2.localdomain:[0-9]\+|uri: https://sepp2.localdomain:7778|g" "$CONFIG_FILE"
        sed -i "/n32f:/s|uri: https://sepp2.localdomain:[0-9]\+|uri: https://sepp2.localdomain:7779|g" "$CONFIG_FILE"
    else
        sed -i "s|sender:.*|sender: $SEPP_FQDN|g" "$CONFIG_FILE"
        sed -i "s|receiver:.*|receiver: sepp1.localdomain|g" "$CONFIG_FILE"
        # Ensure correct URIs for N32c and N32f
        sed -i "s|https://sepp1.localdomain:[0-9]\+|https://sepp1.localdomain:7778|g" "$CONFIG_FILE"
        sed -i "/n32f:/!s|uri: https://sepp1.localdomain:[0-9]\+|uri: https://sepp1.localdomain:7778|g" "$CONFIG_FILE"
        sed -i "/n32f:/s|uri: https://sepp1.localdomain:[0-9]\+|uri: https://sepp1.localdomain:7779|g" "$CONFIG_FILE"
    fi
    
    # Add or update TLS verification setting based on DISABLE_VERIFY
    if [ "$DISABLE_VERIFY" = "true" ]; then
        if grep -q "verify:" "$CONFIG_FILE"; then
            sed -i "s|verify:.*|verify: false|g" "$CONFIG_FILE"
        else
            sed -i "/client:/a \ \ \ \ \ \ \ \ verify: false" "$CONFIG_FILE"
        fi
        echo "TLS verification disabled for testing"
    else
        if grep -q "verify:" "$CONFIG_FILE"; then
            sed -i "s|verify:.*|verify: true|g" "$CONFIG_FILE"
        else
            sed -i "/client:/a \ \ \ \ \ \ \ \ verify: true" "$CONFIG_FILE"
        fi
        echo "TLS verification enabled"
    fi
    
    echo "Configuration file updated."
else
    echo "Warning: No configuration file found or specified. Using default."
fi

# Test connectivity to other SEPP
echo "Testing connectivity to $OTHER_SEPP..."
ping -c 1 $OTHER_SEPP || echo "Ping failed, but continuing..."

# Simple TLS connectivity test - don't rely on openssl client functionality
echo "Checking for TLS port connectivity to $OTHER_SEPP:7778..."
timeout 2 bash -c "</dev/tcp/$OTHER_SEPP/7778" 2>/dev/null && \
    echo "TCP connectivity test successful" || \
    echo "TCP connectivity test failed, but continuing..."

echo "====== Starting SEPP daemon ======"
echo "Using config file: ${CONFIG_FILE:-"/etc/open5gs/default/sepp.yaml"}"
exec open5gs-seppd "$@"