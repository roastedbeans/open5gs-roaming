#!/bin/bash
set -e

echo "====== Generating certificates for SEPP containers ======"

# Environment variables with defaults
CERT_DAYS=${CERT_DAYS:-3650}
CA_CN=${CA_CN:-"open5gs-ca"}
SEPP1_FQDN=${SEPP1_FQDN:-"sepp1.localdomain"}
SEPP1_PLMN_FQDN=${SEPP1_PLMN_FQDN:-"sepp.5gc.mnc001.mcc001.3gppnetwork.org"}
SEPP2_FQDN=${SEPP2_FQDN:-"sepp2.localdomain"}
SEPP2_PLMN_FQDN=${SEPP2_PLMN_FQDN:-"sepp.5gc.mnc070.mcc999.3gppnetwork.org"}
TLS_DIR="/certs"

# Ensure TLS directory exists
mkdir -p $TLS_DIR

# Generate CA certificate
echo "Generating CA certificate..."
openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
    -keyout "$TLS_DIR/ca.key" \
    -out "$TLS_DIR/ca.crt" \
    -subj "/CN=$CA_CN" \
    -addext "basicConstraints=critical,CA:TRUE"

# Generate SEPP1 certificate
echo "Generating SEPP1 certificate..."
openssl genrsa -out "$TLS_DIR/sepp1.key" 2048
openssl req -new -key "$TLS_DIR/sepp1.key" \
    -out "$TLS_DIR/sepp1.csr" \
    -subj "/CN=$SEPP1_FQDN"

cat > "$TLS_DIR/sepp1.ext" << EOF
subjectAltName = DNS:$SEPP1_FQDN,DNS:$SEPP1_PLMN_FQDN
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
EOF

openssl x509 -req -in "$TLS_DIR/sepp1.csr" \
    -CA "$TLS_DIR/ca.crt" \
    -CAkey "$TLS_DIR/ca.key" \
    -CAcreateserial \
    -out "$TLS_DIR/sepp1.crt" \
    -days $CERT_DAYS \
    -extfile "$TLS_DIR/sepp1.ext"

# Generate SEPP2 certificate (similar process)
echo "Generating SEPP2 certificate..."
openssl genrsa -out "$TLS_DIR/sepp2.key" 2048
openssl req -new -key "$TLS_DIR/sepp2.key" \
    -out "$TLS_DIR/sepp2.csr" \
    -subj "/CN=$SEPP2_FQDN"

cat > "$TLS_DIR/sepp2.ext" << EOF
subjectAltName = DNS:$SEPP2_FQDN,DNS:$SEPP2_PLMN_FQDN
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
EOF

openssl x509 -req -in "$TLS_DIR/sepp2.csr" \
    -CA "$TLS_DIR/ca.crt" \
    -CAkey "$TLS_DIR/ca.key" \
    -CAcreateserial \
    -out "$TLS_DIR/sepp2.crt" \
    -days $CERT_DAYS \
    -extfile "$TLS_DIR/sepp2.ext"

# Set proper permissions
chmod 600 "$TLS_DIR/sepp1.key" "$TLS_DIR/sepp2.key" "$TLS_DIR/ca.key"
chmod 644 "$TLS_DIR/sepp1.crt" "$TLS_DIR/sepp2.crt" "$TLS_DIR/ca.crt"

# Clean up
rm -f "$TLS_DIR/sepp1.csr" "$TLS_DIR/sepp1.ext" \
       "$TLS_DIR/sepp2.csr" "$TLS_DIR/sepp2.ext"

echo "Certificate generation complete!"
echo "CA certificate info:"
openssl x509 -in "$TLS_DIR/ca.crt" -noout -text | grep -A2 "Subject:"
echo "SEPP1 certificate info:"
openssl x509 -in "$TLS_DIR/sepp1.crt" -noout -text | grep -A2 "Subject:"
echo "SEPP2 certificate info:"
openssl x509 -in "$TLS_DIR/sepp2.crt" -noout -text | grep -A2 "Subject:"

exit 0