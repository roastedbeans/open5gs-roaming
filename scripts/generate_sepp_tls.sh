#!/bin/bash

# Script to generate TLS certificates for SEPP communications
# This script should be run before starting the containers

CERT_DIR="./tls/sepp"
H_SEPP_DOMAIN="sepp.5gc.mnc001.mcc001.3gppnetwork.org"
V_SEPP_DOMAIN="sepp.5gc.mnc070.mcc999.3gppnetwork.org"

# Create directory structure if it doesn't exist
mkdir -p $CERT_DIR/{h-sepp,v-sepp}

# Generate CA key and certificate
openssl genrsa -out $CERT_DIR/ca.key 4096
openssl req -x509 -new -nodes -key $CERT_DIR/ca.key -sha256 -days 1825 -out $CERT_DIR/ca.crt \
  -subj "/C=US/ST=State/L=City/O=Open5GS/CN=Open5GS CA"

# Function to generate server certificates
generate_server_cert() {
  local domain=$1
  local output_dir=$2
  
  echo "Generating certificates for $domain in $output_dir"
  
  # Generate server key
  openssl genrsa -out $output_dir/server.key 2048
  
  # Generate server CSR
  openssl req -new -key $output_dir/server.key -out $output_dir/server.csr \
    -subj "/C=US/ST=State/L=City/O=Open5GS/CN=$domain"
  
  # Create config file for SAN
  cat > $output_dir/server.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
EOF
  
  # Generate server certificate
  openssl x509 -req -in $output_dir/server.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key \
    -CAcreateserial -out $output_dir/server.crt -days 825 -sha256 \
    -extfile $output_dir/server.ext
    
  # Generate client key and certificate (for mutual TLS)
  openssl genrsa -out $output_dir/client.key 2048
  openssl req -new -key $output_dir/client.key -out $output_dir/client.csr \
    -subj "/C=US/ST=State/L=City/O=Open5GS/CN=client.$domain"
  openssl x509 -req -in $output_dir/client.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key \
    -CAcreateserial -out $output_dir/client.crt -days 825 -sha256
    
  # Copy CA certificate to the output directory
  cp $CERT_DIR/ca.crt $output_dir/ca.crt
  
  # Clean up temporary files
  rm $output_dir/server.csr $output_dir/client.csr $output_dir/server.ext
  
  # Set permissions
  chmod 644 $output_dir/*.crt
  chmod 600 $output_dir/*.key
}

# Generate certificates for Home SEPP
generate_server_cert $H_SEPP_DOMAIN "$CERT_DIR/h-sepp"

# Generate certificates for Visited SEPP
generate_server_cert $V_SEPP_DOMAIN "$CERT_DIR/v-sepp"

echo "Certificate generation complete. Certificates are stored in $CERT_DIR"
echo "Make sure to mount these certificates to the Docker containers." 