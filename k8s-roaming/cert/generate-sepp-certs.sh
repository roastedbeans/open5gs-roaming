#!/bin/bash

set -e

TLS_DIR="./open5gs_tls"
mkdir -p "$TLS_DIR"

echo "✅ Creating CA..."
openssl genrsa -out $TLS_DIR/ca.key 2048
openssl req -x509 -new -nodes -key $TLS_DIR/ca.key -sha256 -days 365 \
    -out $TLS_DIR/ca.crt -subj "/CN=SEPP Test CA"

# === Function to generate cert ===
generate_cert() {
  NAME=$1
  CN=$2
  echo "🔐 Generating key and cert for $NAME ($CN)..."
  openssl genrsa -out $TLS_DIR/${NAME}.key 2048
  openssl req -new -key $TLS_DIR/${NAME}.key -out $TLS_DIR/${NAME}.csr \
    -subj "/CN=${CN}"
  openssl x509 -req -in $TLS_DIR/${NAME}.csr -CA $TLS_DIR/ca.crt -CAkey $TLS_DIR/ca.key \
    -CAcreateserial -out $TLS_DIR/${NAME}.crt -days 365 -sha256
  rm $TLS_DIR/${NAME}.csr
}

# === HPLMN (mnc001.mcc001) ===
generate_cert "sepp-hplmn-n32c" "sepp1.5gc.mnc001.mcc001.3gppnetwork.org"
generate_cert "sepp-hplmn-n32f" "sepp2.5gc.mnc001.mcc001.3gppnetwork.org"

# === VPLMN (mnc070.mcc999) ===
generate_cert "sepp-vplmn-n32c" "sepp1.5gc.mnc070.mcc999.3gppnetwork.org"
generate_cert "sepp-vplmn-n32f" "sepp2.5gc.mnc070.mcc999.3gppnetwork.org"

echo "✅ All certificates generated in: $TLS_DIR"
ls -l $TLS_DIR