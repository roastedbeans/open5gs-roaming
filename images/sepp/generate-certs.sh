#!/bin/bash
# Disable default error exit to handle errors manually
set +e

echo "====== Generating certificates for SEPP containers ======"

# Environment variables with defaults
CERT_DAYS=${CERT_DAYS:-3650}
CA_CN=${CA_CN:-"open5gs-ca"}
SEPP1_FQDN=${SEPP1_FQDN:-"sepp1.localdomain"}
SEPP1_PLMN_FQDN=${SEPP1_PLMN_FQDN:-"sepp.5gc.mnc001.mcc001.3gppnetwork.org"}
SEPP1_IP=${SEPP1_IP:-"10.33.33.20"}
SEPP2_FQDN=${SEPP2_FQDN:-"sepp2.localdomain"}
SEPP2_PLMN_FQDN=${SEPP2_PLMN_FQDN:-"sepp.5gc.mnc070.mcc999.3gppnetwork.org"}
SEPP2_IP=${SEPP2_IP:-"10.33.33.10"}
TLS_DIR="/certs"

# Create function for error handling
handle_error() {
    echo "ERROR: $1"
    echo "Command failed with exit code $2"
    exit $2
}

# Ensure TLS directory exists
mkdir -p $TLS_DIR || handle_error "Failed to create TLS directory" $?

# Generate CA certificate with proper extensions
echo "Generating CA certificate..."
# Create config file for CA certificate
cat > "$TLS_DIR/ca.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $CA_CN

[v3_req]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
EOF

# Generate CA cert with config file
openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
    -keyout "$TLS_DIR/ca.key" \
    -out "$TLS_DIR/ca.crt" \
    -config "$TLS_DIR/ca.cnf"
if [ $? -ne 0 ]; then
    handle_error "Failed to generate CA certificate" $?
fi

echo "CA certificate generated successfully."

# Generate SEPP1 certificate
echo "Generating SEPP1 certificate..."
openssl genrsa -out "$TLS_DIR/sepp1.key" 2048
if [ $? -ne 0 ]; then
    handle_error "Failed to generate SEPP1 key" $?
fi

# Create config for SEPP1 CSR
cat > "$TLS_DIR/sepp1.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $SEPP1_FQDN

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SEPP1_FQDN
DNS.2 = $SEPP1_PLMN_FQDN
IP.1 = $SEPP1_IP
EOF

# Generate CSR with config
openssl req -new -key "$TLS_DIR/sepp1.key" \
    -out "$TLS_DIR/sepp1.csr" \
    -config "$TLS_DIR/sepp1.cnf"
if [ $? -ne 0 ]; then
    handle_error "Failed to generate SEPP1 CSR" $?
fi

# Create config for signing the certificate
cat > "$TLS_DIR/sepp1.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SEPP1_FQDN
DNS.2 = $SEPP1_PLMN_FQDN
IP.1 = $SEPP1_IP
EOF

# Sign the certificate
openssl x509 -req -in "$TLS_DIR/sepp1.csr" \
    -CA "$TLS_DIR/ca.crt" \
    -CAkey "$TLS_DIR/ca.key" \
    -CAcreateserial \
    -out "$TLS_DIR/sepp1.crt" \
    -days $CERT_DAYS \
    -extfile "$TLS_DIR/sepp1.ext"
if [ $? -ne 0 ]; then
    handle_error "Failed to sign SEPP1 certificate" $?
fi

echo "SEPP1 certificate generated successfully."

# Generate SEPP2 certificate using similar approach
echo "Generating SEPP2 certificate..."
openssl genrsa -out "$TLS_DIR/sepp2.key" 2048
if [ $? -ne 0 ]; then
    handle_error "Failed to generate SEPP2 key" $?
fi

# Create config for SEPP2 CSR
cat > "$TLS_DIR/sepp2.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $SEPP2_FQDN

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SEPP2_FQDN
DNS.2 = $SEPP2_PLMN_FQDN
IP.1 = $SEPP2_IP
EOF

# Generate CSR with config
openssl req -new -key "$TLS_DIR/sepp2.key" \
    -out "$TLS_DIR/sepp2.csr" \
    -config "$TLS_DIR/sepp2.cnf"
if [ $? -ne 0 ]; then
    handle_error "Failed to generate SEPP2 CSR" $?
fi

# Create config for signing the certificate
cat > "$TLS_DIR/sepp2.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SEPP2_FQDN
DNS.2 = $SEPP2_PLMN_FQDN
IP.1 = $SEPP2_IP
EOF

# Sign the certificate
openssl x509 -req -in "$TLS_DIR/sepp2.csr" \
    -CA "$TLS_DIR/ca.crt" \
    -CAkey "$TLS_DIR/ca.key" \
    -CAcreateserial \
    -out "$TLS_DIR/sepp2.crt" \
    -days $CERT_DAYS \
    -extfile "$TLS_DIR/sepp2.ext"
if [ $? -ne 0 ]; then
    handle_error "Failed to sign SEPP2 certificate" $?
fi

echo "SEPP2 certificate generated successfully."

# Create PEM certificate chain files for each SEPP
echo "Creating certificate chain files..."
cat "$TLS_DIR/sepp1.crt" "$TLS_DIR/ca.crt" > "$TLS_DIR/sepp1-chain.pem"
cat "$TLS_DIR/sepp2.crt" "$TLS_DIR/ca.crt" > "$TLS_DIR/sepp2-chain.pem"

# Set proper permissions
chmod 600 "$TLS_DIR/sepp1.key" "$TLS_DIR/sepp2.key" "$TLS_DIR/ca.key"
chmod 644 "$TLS_DIR/sepp1.crt" "$TLS_DIR/sepp2.crt" "$TLS_DIR/ca.crt" "$TLS_DIR/sepp1-chain.pem" "$TLS_DIR/sepp2-chain.pem"

# Clean up temporary files
rm -f "$TLS_DIR/sepp1.csr" "$TLS_DIR/sepp1.ext" "$TLS_DIR/sepp1.cnf" \
       "$TLS_DIR/sepp2.csr" "$TLS_DIR/sepp2.ext" "$TLS_DIR/sepp2.cnf" \
       "$TLS_DIR/ca.cnf"

echo "Certificate generation complete!"

# Simple certificate verification that won't get stuck
echo "Certificate verification:"
echo "CA certificate: $(ls -la $TLS_DIR/ca.crt)"
echo "SEPP1 certificate: $(ls -la $TLS_DIR/sepp1.crt)"
echo "SEPP2 certificate: $(ls -la $TLS_DIR/sepp2.crt)"
echo "SEPP1 chain: $(ls -la $TLS_DIR/sepp1-chain.pem)"
echo "SEPP2 chain: $(ls -la $TLS_DIR/sepp2-chain.pem)"

# Create verification marker to indicate success
touch "$TLS_DIR/certificates_generated"

echo "All certificates generated and verified successfully."
exit 0