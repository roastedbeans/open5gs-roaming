#!/bin/bash
set -e

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

# Ensure TLS directory exists
mkdir -p $TLS_DIR

# Add the other SEPP to hosts file for DNS resolution if not already there
if ! grep -q "$OTHER_SEPP" /etc/hosts; then
    echo "Adding $OTHER_SEPP to /etc/hosts for DNS resolution..."
    if [ "$SEPP_TYPE" = "sepp1" ]; then
        echo "$(getent hosts sepp2.localdomain || echo "10.33.33.10 sepp2.localdomain")" >> /etc/hosts
    else
        echo "$(getent hosts sepp1.localdomain || echo "10.33.33.20 sepp1.localdomain")" >> /etc/hosts
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
        -addext "basicConstraints=critical,CA:TRUE"
fi

# Generate the SEPP certificate signed by the CA (not self-signed)
echo "Generating SEPP certificate for $CERT_PREFIX..."

# Generate private key
openssl genrsa -out "$TLS_DIR/$CERT_PREFIX.key" 2048

# Create a CSR (Certificate Signing Request)
openssl req -new -key "$TLS_DIR/$CERT_PREFIX.key" \
    -out "$TLS_DIR/$CERT_PREFIX.csr" \
    -subj "/CN=$SEPP_FQDN"

# Create extensions file
cat > "$TLS_DIR/$CERT_PREFIX.ext" << EOF
subjectAltName = DNS:$SEPP_FQDN,DNS:$SEPP_PLMN_FQDN
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
EOF

# Sign the CSR with the CA
openssl x509 -req -in "$TLS_DIR/$CERT_PREFIX.csr" \
    -CA "$TLS_DIR/ca.crt" \
    -CAkey "$TLS_DIR/ca.key" \
    -CAcreateserial \
    -out "$TLS_DIR/$CERT_PREFIX.crt" \
    -days $CERT_DAYS \
    -extfile "$TLS_DIR/$CERT_PREFIX.ext"

# Clean up CSR and extensions file
rm -f "$TLS_DIR/$CERT_PREFIX.csr" "$TLS_DIR/$CERT_PREFIX.ext"

# Set proper permissions on keys
chmod 600 "$TLS_DIR/$CERT_PREFIX.key"
chmod 600 "$TLS_DIR/ca.key"
chmod 644 "$TLS_DIR/$CERT_PREFIX.crt"
chmod 644 "$TLS_DIR/ca.crt"

echo "Certificates generated successfully."

# Print certificate information for verification
echo "Certificate information for $CERT_PREFIX:"
openssl x509 -in "$TLS_DIR/$CERT_PREFIX.crt" -noout -text | grep -A2 "Subject:"
openssl x509 -in "$TLS_DIR/$CERT_PREFIX.crt" -noout -text | grep -A2 "Subject Alternative Name"
echo "CA certificate information:"
openssl x509 -in "$TLS_DIR/ca.crt" -noout -text | grep -A2 "Subject:"

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
    
    # For troubleshooting, we'll disable verification initially
    # Later this can be removed for production use
    if ! grep -q "verify: false" "$CONFIG_FILE"; then
        sed -i "/client:/a \ \ \ \ \ \ \ \ verify: false" "$CONFIG_FILE"
    fi
    
    echo "Configuration file updated."
    
    # Show diff of changes
    echo "Changes made to configuration:"
    diff -u "${CONFIG_FILE}.bak" "$CONFIG_FILE" || true
fi

# Test DNS resolution
echo "Testing DNS resolution for other SEPP:"
ping -c 1 $OTHER_SEPP || echo "DNS resolution failed, but continuing..."

# Display network information
echo "Network interfaces:"
ip addr show

echo "Starting SEPP daemon..."
# Pass arguments to the SEPP daemon
exec open5gs-seppd "$@"