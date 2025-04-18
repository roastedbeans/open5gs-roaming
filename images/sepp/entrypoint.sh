#!/bin/bash
set -e

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
    CERT_PREFIX="sepp1"
    OTHER_SEPP="sepp2.localdomain"
else
    SEPP_FQDN="sepp2.localdomain"
    SEPP_PLMN_FQDN="sepp.5gc.mnc070.mcc999.3gppnetwork.org"
    CERT_PREFIX="sepp2"
    OTHER_SEPP="sepp1.localdomain"
fi

# Allow overriding of values through environment variables
SEPP_FQDN=${SEPP_FQDN_OVERRIDE:-"$SEPP_FQDN"}
SEPP_PLMN_FQDN=${SEPP_PLMN_FQDN_OVERRIDE:-"$SEPP_PLMN_FQDN"}
TLS_DIR=${TLS_DIR:-"/etc/open5gs/default/tls"}
DISABLE_VERIFY=${DISABLE_VERIFY:-"true"}

# Add the other SEPP to hosts file for DNS resolution if not already there
if ! grep -q "$OTHER_SEPP" /etc/hosts; then
    echo "Adding $OTHER_SEPP to /etc/hosts for DNS resolution..."
    if [ "$SEPP_TYPE" = "sepp1" ]; then
        echo "$(getent hosts sepp2.localdomain 2>/dev/null || echo "10.33.33.10 sepp2.localdomain")" >> /etc/hosts
    else
        echo "$(getent hosts sepp1.localdomain 2>/dev/null || echo "10.33.33.20 sepp1.localdomain")" >> /etc/hosts
    fi
    cat /etc/hosts
fi

# Verify certificates exist
if [ ! -f "$TLS_DIR/ca.crt" ] || [ ! -f "$TLS_DIR/$CERT_PREFIX.crt" ] || [ ! -f "$TLS_DIR/$CERT_PREFIX.key" ]; then
    echo "Error: Required certificates not found in $TLS_DIR"
    echo "Missing:"
    [ ! -f "$TLS_DIR/ca.crt" ] && echo "- $TLS_DIR/ca.crt"
    [ ! -f "$TLS_DIR/$CERT_PREFIX.crt" ] && echo "- $TLS_DIR/$CERT_PREFIX.crt"
    [ ! -f "$TLS_DIR/$CERT_PREFIX.key" ] && echo "- $TLS_DIR/$CERT_PREFIX.key"
    echo "Please ensure the cert-manager container has run successfully."
    exit 1
fi

# Display certificate information
echo "Certificate information:"
openssl x509 -in "$TLS_DIR/$CERT_PREFIX.crt" -noout -subject -issuer || echo "Error verifying certificate"

# Update configuration file with the correct paths and settings
CONFIG_FILE="${1#-c }"
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    # Create a backup of the original config
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # Update certificate paths for sepp2
    if [ "$SEPP_TYPE" = "sepp2" ]; then
        echo "Updating certificate paths in config file to use $CERT_PREFIX..."
        sed -i "s|sepp1.key|$CERT_PREFIX.key|g" "$CONFIG_FILE"
        sed -i "s|sepp1.crt|$CERT_PREFIX.crt|g" "$CONFIG_FILE"
    fi
    
    # Make sure sender and receiver are set correctly
    if [ "$SEPP_TYPE" = "sepp1" ]; then
        sed -i "s|sender:.*|sender: $SEPP_FQDN|g" "$CONFIG_FILE"
        sed -i "s|receiver:.*|receiver: sepp2.localdomain|g" "$CONFIG_FILE"
        sed -i "s|https://sepp2.localdomain:8778|https://sepp2.localdomain:7778|g" "$CONFIG_FILE"
        sed -i "s|https://sepp2.localdomain:8779|https://sepp2.localdomain:7779|g" "$CONFIG_FILE"
    else
        sed -i "s|sender:.*|sender: $SEPP_FQDN|g" "$CONFIG_FILE"
        sed -i "s|receiver:.*|receiver: sepp1.localdomain|g" "$CONFIG_FILE"
        sed -i "s|https://sepp1.localdomain:8778|https://sepp1.localdomain:7778|g" "$CONFIG_FILE"
        sed -i "s|https://sepp1.localdomain:8779|https://sepp1.localdomain:7779|g" "$CONFIG_FILE"
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
        fi
        echo "TLS verification enabled"
    fi
    
    echo "Configuration file updated."
fi

# Test connectivity to other SEPP
echo "Testing connectivity to $OTHER_SEPP..."
if command -v ping &> /dev/null; then
    ping -c 1 $OTHER_SEPP || echo "Ping failed, but continuing..."
fi

echo "====== Starting SEPP daemon ======"
echo "Using config file: ${CONFIG_FILE:-"/etc/open5gs/default/sepp.yaml"}"
exec open5gs-seppd "$@"