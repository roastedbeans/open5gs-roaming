#!/bin/bash
set -e

echo "====== SEPP Container Startup ======"

# Install necessary dependencies if they're not already installed
if ! command -v openssl &> /dev/null; then
    echo "Installing dependencies..."
    apt-get update && apt-get install -y openssl
fi

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

# Set certificate parameters based on SEPP type
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
CERT_DAYS=${CERT_DAYS:-3650}
TLS_DIR=${TLS_DIR:-"/etc/open5gs/default/tls"}
SHARED_CA=${SHARED_CA:-"false"}
DISABLE_VERIFY=${DISABLE_VERIFY:-"true"}

# Ensure TLS directory exists
mkdir -p $TLS_DIR

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

# Generate or use the CA certificate
if [ "$SHARED_CA" = "true" ] && [ -f "$TLS_DIR/ca.crt" ] && [ -f "$TLS_DIR/ca.key" ]; then
    echo "Using existing shared CA certificate"
    # Verify the existing CA certificate
    openssl x509 -in "$TLS_DIR/ca.crt" -noout -text | grep -A2 "Subject:" || {
        echo "Invalid CA certificate, regenerating..."
        rm -f "$TLS_DIR/ca.crt" "$TLS_DIR/ca.key"
        SHARED_CA="false"
    }
fi

if [ "$SHARED_CA" != "true" ] || [ ! -f "$TLS_DIR/ca.crt" ] || [ ! -f "$TLS_DIR/ca.key" ]; then
    echo "Generating new CA certificate..."
    openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
        -keyout "$TLS_DIR/ca.key" \
        -out "$TLS_DIR/ca.crt" \
        -subj "/CN=open5gs-ca" \
        -addext "basicConstraints=critical,CA:TRUE" 2>/dev/null || {
            echo "Error creating CA certificate with -addext, trying alternative method..."
            openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
                -keyout "$TLS_DIR/ca.key" \
                -out "$TLS_DIR/ca.crt" \
                -subj "/CN=open5gs-ca"
        }
fi

# Check if SEPP certificate already exists and has the correct CN
if [ -f "$TLS_DIR/$CERT_PREFIX.crt" ]; then
    CURRENT_CN=$(openssl x509 -in "$TLS_DIR/$CERT_PREFIX.crt" -noout -subject | grep -o "CN = [^,]*" | cut -d" " -f3)
    if [ "$CURRENT_CN" = "$SEPP_FQDN" ]; then
        echo "Using existing certificate for $SEPP_FQDN"
        REGENERATE_CERT="false"
    else
        echo "Certificate CN mismatch (expected $SEPP_FQDN, got $CURRENT_CN), regenerating..."
        REGENERATE_CERT="true"
    fi
else
    REGENERATE_CERT="true"
fi

# Generate the SEPP certificate signed by the CA if needed
if [ "$REGENERATE_CERT" = "true" ]; then
    echo "Generating SEPP certificate for $CERT_PREFIX..."

    # Generate private key
    openssl genrsa -out "$TLS_DIR/$CERT_PREFIX.key" 2048

    # Create a CSR (Certificate Signing Request)
    openssl req -new -key "$TLS_DIR/$CERT_PREFIX.key" \
        -out "$TLS_DIR/$CERT_PREFIX.csr" \
        -subj "/CN=$SEPP_FQDN"

    # Try to use extensions file if supported
    if openssl version | grep -q "OpenSSL 1\.[1-9]"; then
        # OpenSSL 1.1.0 and newer supports -addext
        openssl x509 -req -in "$TLS_DIR/$CERT_PREFIX.csr" \
            -CA "$TLS_DIR/ca.crt" \
            -CAkey "$TLS_DIR/ca.key" \
            -CAcreateserial \
            -out "$TLS_DIR/$CERT_PREFIX.crt" \
            -days $CERT_DAYS \
            -addext "subjectAltName = DNS:$SEPP_FQDN,DNS:$SEPP_PLMN_FQDN" \
            -addext "keyUsage = critical,digitalSignature,keyEncipherment" \
            -addext "extendedKeyUsage = serverAuth,clientAuth"
    else
        # Older OpenSSL version, use extensions file
        cat > "$TLS_DIR/$CERT_PREFIX.ext" << EOF
subjectAltName = DNS:$SEPP_FQDN,DNS:$SEPP_PLMN_FQDN
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
EOF

        openssl x509 -req -in "$TLS_DIR/$CERT_PREFIX.csr" \
            -CA "$TLS_DIR/ca.crt" \
            -CAkey "$TLS_DIR/ca.key" \
            -CAcreateserial \
            -out "$TLS_DIR/$CERT_PREFIX.crt" \
            -days $CERT_DAYS \
            -extfile "$TLS_DIR/$CERT_PREFIX.ext"
        
        # Clean up extensions file
        rm -f "$TLS_DIR/$CERT_PREFIX.ext"
    fi

    # Clean up CSR file
    rm -f "$TLS_DIR/$CERT_PREFIX.csr"
fi

# Set proper permissions on keys
chmod 600 "$TLS_DIR/$CERT_PREFIX.key"
chmod 600 "$TLS_DIR/ca.key"
chmod 644 "$TLS_DIR/$CERT_PREFIX.crt"
chmod 644 "$TLS_DIR/ca.crt"

echo "Certificate verification:"
echo "SEPP certificate ($CERT_PREFIX):"
openssl x509 -in "$TLS_DIR/$CERT_PREFIX.crt" -noout -subject -issuer -dates -ext subjectAltName || echo "Error verifying certificate"

echo "CA certificate:"
openssl x509 -in "$TLS_DIR/ca.crt" -noout -subject -issuer -dates || echo "Error verifying CA certificate"

# Link other SEPP certificate if needed
if [ "$SEPP_TYPE" = "sepp1" ] && [ ! -f "$TLS_DIR/sepp2.crt" ]; then
    # Create a dummy sepp2 certificate if not present (will be replaced by real one)
    cp "$TLS_DIR/$CERT_PREFIX.crt" "$TLS_DIR/sepp2.crt"
    echo "Created temporary sepp2 certificate (will be replaced by real one when available)"
elif [ "$SEPP_TYPE" = "sepp2" ] && [ ! -f "$TLS_DIR/sepp1.crt" ]; then
    # Create a dummy sepp1 certificate if not present (will be replaced by real one)
    cp "$TLS_DIR/$CERT_PREFIX.crt" "$TLS_DIR/sepp1.crt"
    echo "Created temporary sepp1 certificate (will be replaced by real one when available)"
fi

# Update configuration file with the correct certificate paths
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
echo "Testing connectivity to $OTHER_SEPP:"
if command -v ping &> /dev/null; then
    ping -c 1 $OTHER_SEPP || echo "Ping failed, but continuing..."
else
    echo "Ping command not available, skipping connectivity test"
fi

# Try netcat to test port connectivity if available
if command -v nc &> /dev/null; then
    echo "Testing port connectivity to $OTHER_SEPP:7778..."
    nc -zv $OTHER_SEPP 7778 || echo "Port 7778 not reachable, but continuing..."
else
    echo "Netcat command not available, skipping port test"
fi

# Display network information if available
if command -v ip &> /dev/null; then
    echo "Network interfaces:"
    ip addr show || echo "Error displaying network interfaces"
else
    echo "ip command not available, skipping network interface display"
fi

echo "====== Starting SEPP daemon ======"
echo "Using config file: ${CONFIG_FILE:-"/etc/open5gs/default/sepp.yaml"}"
# Pass arguments to the SEPP daemon
exec open5gs-seppd "$@"