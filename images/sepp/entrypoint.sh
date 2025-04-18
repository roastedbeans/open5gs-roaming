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
    IP_ADDRESS="10.33.33.20"
    OTHER_IP="10.33.33.15"
    OTHER_CERT_PREFIX="sepp2"
else
    SEPP_FQDN="sepp2.localdomain"
    SEPP_PLMN_FQDN="sepp.5gc.mnc070.mcc999.3gppnetwork.org"
    CERT_PREFIX="sepp2"
    OTHER_SEPP="sepp1.localdomain"
    IP_ADDRESS="10.33.33.15"
    OTHER_IP="10.33.33.20"
    OTHER_CERT_PREFIX="sepp1"
fi

# Allow overriding of values through environment variables
SEPP_FQDN=${SEPP_FQDN_OVERRIDE:-"$SEPP_FQDN"}
SEPP_PLMN_FQDN=${SEPP_PLMN_FQDN_OVERRIDE:-"$SEPP_PLMN_FQDN"}
CERT_DAYS=${CERT_DAYS:-3650}
TLS_DIR=${TLS_DIR:-"/etc/open5gs/default/tls"}
CA_DIR="/etc/open5gs/default/ca"

# Ensure directories exist
mkdir -p $TLS_DIR
mkdir -p $CA_DIR

# Add the other SEPP to hosts file for DNS resolution if not already there
if ! grep -q "$OTHER_SEPP" /etc/hosts; then
    echo "Adding $OTHER_SEPP to /etc/hosts for DNS resolution..."
    echo "$OTHER_IP $OTHER_SEPP" >> /etc/hosts
    cat /etc/hosts
fi

# Always regenerate certificates to ensure they're correct
echo "Generating new certificates for $SEPP_FQDN..."

# Create a proper CA certificate
echo "Generating CA certificate..."
# Generate CA private key
openssl genrsa -out "$TLS_DIR/ca.key" 2048

# Generate CA certificate
openssl req -x509 -new -nodes -key "$TLS_DIR/ca.key" -sha256 -days $CERT_DAYS \
    -out "$TLS_DIR/ca.crt" \
    -subj "/CN=open5gs-ca-$CERT_PREFIX" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"

# Create a CSR (Certificate Signing Request) for SEPP
echo "Generating SEPP CSR for $CERT_PREFIX..."
openssl genrsa -out "$TLS_DIR/$CERT_PREFIX.key" 2048
openssl req -new -key "$TLS_DIR/$CERT_PREFIX.key" \
    -out "$TLS_DIR/$CERT_PREFIX.csr" \
    -subj "/CN=$SEPP_FQDN"

# Create a config file for the certificate extensions
cat > "$TLS_DIR/csr.conf" << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SEPP_FQDN
DNS.2 = $SEPP_PLMN_FQDN
DNS.3 = localhost
IP.1 = $IP_ADDRESS
IP.2 = 127.0.0.1
EOF

# Generate SEPP certificate signed by the CA
echo "Signing SEPP certificate with CA..."
openssl x509 -req -in "$TLS_DIR/$CERT_PREFIX.csr" \
    -CA "$TLS_DIR/ca.crt" -CAkey "$TLS_DIR/ca.key" \
    -CAcreateserial -out "$TLS_DIR/$CERT_PREFIX.crt" \
    -days $CERT_DAYS -sha256 \
    -extfile "$TLS_DIR/csr.conf" -extensions v3_req

# Create a certificate chain file
cat "$TLS_DIR/$CERT_PREFIX.crt" "$TLS_DIR/ca.crt" > "$TLS_DIR/$CERT_PREFIX.chain.crt"

# Copy certificates to the shared CA directory
cp "$TLS_DIR/ca.crt" "$CA_DIR/$CERT_PREFIX-ca.crt"
cp "$TLS_DIR/$CERT_PREFIX.crt" "$CA_DIR/$CERT_PREFIX.crt"
cp "$TLS_DIR/$CERT_PREFIX.chain.crt" "$CA_DIR/$CERT_PREFIX.chain.crt"

# Set proper permissions on keys and certificates
chmod 600 "$TLS_DIR/$CERT_PREFIX.key"
chmod 600 "$TLS_DIR/ca.key"
chmod 644 "$TLS_DIR/$CERT_PREFIX.crt"
chmod 644 "$TLS_DIR/ca.crt"
chmod 644 "$TLS_DIR/$CERT_PREFIX.chain.crt"
chmod 644 "$CA_DIR/$CERT_PREFIX-ca.crt"
chmod 644 "$CA_DIR/$CERT_PREFIX.crt"
chmod 644 "$CA_DIR/$CERT_PREFIX.chain.crt"

# Wait for the other SEPP's CA certificate to be available
echo "Waiting for $OTHER_SEPP's CA certificate..."
for i in {1..30}; do
    if [ -f "$CA_DIR/$OTHER_CERT_PREFIX-ca.crt" ]; then
        echo "Found $OTHER_SEPP's CA certificate"
        
        # Copy other SEPP's CA certificate to our TLS dir for verification
        cp "$CA_DIR/$OTHER_CERT_PREFIX-ca.crt" "$TLS_DIR/$OTHER_CERT_PREFIX-ca.crt"
        
        # Create a combined CA bundle for verification
        cat "$TLS_DIR/ca.crt" "$TLS_DIR/$OTHER_CERT_PREFIX-ca.crt" > "$TLS_DIR/ca-bundle.crt"
        chmod 644 "$TLS_DIR/ca-bundle.crt"
        
        # Check if we can verify the other SEPP's certificate
        if [ -f "$CA_DIR/$OTHER_CERT_PREFIX.crt" ]; then
            echo "Verifying $OTHER_SEPP's certificate..."
            openssl verify -CAfile "$TLS_DIR/$OTHER_CERT_PREFIX-ca.crt" "$CA_DIR/$OTHER_CERT_PREFIX.crt" || echo "Warning: Could not verify $OTHER_SEPP's certificate, but continuing..."
        fi
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "Warning: Could not find $OTHER_SEPP's CA certificate after waiting, proceeding without it..."
        # Create a fallback CA bundle with just our CA
        cp "$TLS_DIR/ca.crt" "$TLS_DIR/ca-bundle.crt"
        chmod 644 "$TLS_DIR/ca-bundle.crt"
    else
        echo "Waiting for $OTHER_SEPP's CA certificate (attempt $i/30)..."
        sleep 2
    fi
done

# Clean up temporary files
rm -f "$TLS_DIR/$CERT_PREFIX.csr" "$TLS_DIR/csr.conf" "$TLS_DIR/ca.srl"

echo "Certificates generated successfully."

# Print certificate information for verification
echo "Certificate information for $CERT_PREFIX:"
openssl x509 -in "$TLS_DIR/$CERT_PREFIX.crt" -noout -text | grep -A2 "Subject:"
openssl x509 -in "$TLS_DIR/$CERT_PREFIX.crt" -noout -text | grep -A2 "Subject Alternative Name"
openssl verify -CAfile "$TLS_DIR/ca.crt" "$TLS_DIR/$CERT_PREFIX.crt" || echo "Certificate verification failed, but continuing..."

# Update configuration file with the correct certificate paths
CONFIG_FILE="${1#-c }"
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    # Create a backup of the original config
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # Update certificate paths for sepp2
    if [ "$SEPP_TYPE" = "sepp2" ]; then
        echo "Updating certificate paths in config file to use $CERT_PREFIX..."
        sed -i "s|sepp1.key|$CERT_PREFIX.key|g" "$CONFIG_FILE"
        sed -i "s|sepp1.crt|$CERT_PREFIX.chain.crt|g" "$CONFIG_FILE"
    else
        # Update to use chain certificate
        sed -i "s|sepp1.crt|$CERT_PREFIX.chain.crt|g" "$CONFIG_FILE"
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
    
    # Make sure CA paths are properly set to use the bundle
    if grep -q "cacert:" "$CONFIG_FILE"; then
        sed -i "s|cacert:.*|cacert: $TLS_DIR/ca-bundle.crt|g" "$CONFIG_FILE"
    else
        # Add CA certificate if it doesn't exist
        sed -i "/key:/a \ \ \ \ \ \ \ \ cacert: $TLS_DIR/ca-bundle.crt" "$CONFIG_FILE"
    fi

    # Add missing server parameters if needed
    if ! grep -q "tls:" "$CONFIG_FILE"; then
        # Add TLS section if missing
        cat >> "$CONFIG_FILE" << EOF

    tls:
      server:
        key: $TLS_DIR/$CERT_PREFIX.key
        cert: $TLS_DIR/$CERT_PREFIX.chain.crt
      client:
        cacert: $TLS_DIR/ca-bundle.crt
        verify: true
EOF
    fi
    
    # Ensure client verification is properly set
    if grep -q "verify:" "$CONFIG_FILE"; then
        sed -i "s|verify:.*|verify: true|g" "$CONFIG_FILE"
    else
        sed -i "/client:/a \ \ \ \ \ \ \ \ verify: true" "$CONFIG_FILE"
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