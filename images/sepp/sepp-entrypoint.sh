#!/bin/bash

# Script to generate TLS certificates and start SEPP

CERT_DIR="/etc/open5gs/tls"
SHARED_DIR="/etc/open5gs/tls/shared"
CA_SHARE_DIR="/shared/certs"

# Create directories
mkdir -p $CERT_DIR $SHARED_DIR

# Check if certificates already exist
if [ ! -f "$CERT_DIR/server.key" ] || [ ! -f "$CERT_DIR/server.crt" ]; then
    echo "Certificates not found. Generating new certificates..."
    
    # Create directory if it doesn't exist
    mkdir -p $CERT_DIR
    
    # Generate CA key and certificate (if not exists)
    if [ ! -f "$CERT_DIR/ca.key" ]; then
        openssl genrsa -out $CERT_DIR/ca.key 4096
        openssl req -x509 -new -nodes -key $CERT_DIR/ca.key -sha256 -days 1825 -out $CERT_DIR/ca.crt \
          -subj "/C=US/ST=State/L=City/O=Open5GS/CN=Open5GS CA"
    fi
    
    # Get hostname which should be the SEPP domain
    SEPP_DOMAIN=$(hostname -f)
    if [ -z "$SEPP_DOMAIN" ]; then
        # Fallback to container hostname if FQDN is not set
        SEPP_DOMAIN=$(hostname)
    fi
    
    echo "Generating certificates for $SEPP_DOMAIN"
    
    # Generate server key
    openssl genrsa -out $CERT_DIR/server.key 2048
    chmod 600 $CERT_DIR/server.key
    
    # Generate server CSR
    openssl req -new -key $CERT_DIR/server.key -out $CERT_DIR/server.csr \
      -subj "/C=US/ST=State/L=City/O=Open5GS/CN=$SEPP_DOMAIN"
    
    # Create config file for SAN
    cat > $CERT_DIR/server.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SEPP_DOMAIN
EOF
    
    # Generate server certificate
    openssl x509 -req -in $CERT_DIR/server.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key \
      -CAcreateserial -out $CERT_DIR/server.crt -days 825 -sha256 \
      -extfile $CERT_DIR/server.ext
    chmod 644 $CERT_DIR/server.crt
    
    # Generate client key and certificate (for mutual TLS)
    openssl genrsa -out $CERT_DIR/client.key 2048
    chmod 600 $CERT_DIR/client.key
    
    openssl req -new -key $CERT_DIR/client.key -out $CERT_DIR/client.csr \
      -subj "/C=US/ST=State/L=City/O=Open5GS/CN=client.$SEPP_DOMAIN"
    
    openssl x509 -req -in $CERT_DIR/client.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key \
      -CAcreateserial -out $CERT_DIR/client.crt -days 825 -sha256
    chmod 644 $CERT_DIR/client.crt
    
    # Clean up temporary files
    rm -f $CERT_DIR/server.csr $CERT_DIR/client.csr $CERT_DIR/server.ext
    
    echo "Certificate generation complete."
else
    echo "Certificates already exist. Using existing certificates."
fi

# Store the CA certificate in shared directory for other SEPPs
if [ -d "$CA_SHARE_DIR" ]; then
    # Save our CA cert to shared directory with our hostname for identification
    if [ -f "$CERT_DIR/ca.crt" ]; then
        SEPP_HOSTNAME=$(hostname)
        echo "Sharing our CA certificate for roaming purposes as $SEPP_HOSTNAME-ca.crt"
        cp "$CERT_DIR/ca.crt" "$CA_SHARE_DIR/$SEPP_HOSTNAME-ca.crt"
        chmod 644 "$CA_SHARE_DIR/$SEPP_HOSTNAME-ca.crt"
    fi
    
    # Look for other SEPPs' CA certificates and import them
    echo "Checking for other SEPPs' CA certificates..."
    mkdir -p "$SHARED_DIR"
    
    # Wait a bit to ensure other containers have time to write their certs
    sleep 5
    
    for cert in "$CA_SHARE_DIR"/*-ca.crt; do
        if [ -f "$cert" ]; then
            PEER_HOSTNAME=$(basename "$cert" | sed 's/-ca.crt//')
            if [ "$PEER_HOSTNAME" != "$(hostname)" ]; then
                echo "Importing CA certificate from $PEER_HOSTNAME"
                cp "$cert" "$SHARED_DIR/$PEER_HOSTNAME-ca.crt"
                # Create a combined CA bundle for verification
                cat "$cert" >> "$CERT_DIR/trusted-ca-bundle.crt"
            fi
        fi
    done
    
    # If we found and imported other CA certs, make them available
    if [ -f "$CERT_DIR/trusted-ca-bundle.crt" ]; then
        echo "Created trusted CA bundle with peer certificates"
        chmod 644 "$CERT_DIR/trusted-ca-bundle.crt"
    fi
else
    echo "Shared certificate directory $CA_SHARE_DIR not found. Skipping certificate exchange."
fi

# List the certificates
echo "Certificate directory contents:"
ls -la $CERT_DIR

# Start SEPP with the provided arguments
echo "Starting SEPP with TLS enabled..."
exec open5gs-seppd "$@" 