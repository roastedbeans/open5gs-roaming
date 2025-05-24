#!/bin/bash

# Set the base directory for certificates
CERT_DIR="scripts/cert/open5gs_tls"

# Verify certificate directory exists
if [ ! -d "$CERT_DIR" ]; then
    echo "Error: Certificate directory '$CERT_DIR' not found!"
    echo "Please run this script from the directory containing $CERT_DIR"
    exit 1
fi

echo "Creating TLS secrets for SEPP components..."

# Function to create secrets for a namespace
create_namespace_secrets() {
    local NAMESPACE=$1
    local PREFIX=$2

    echo "Creating secrets for $NAMESPACE namespace..."

    # Delete existing secrets if they exist
    echo "Removing any existing secrets in $NAMESPACE namespace..."
    microk8s kubectl delete secret sepp-n32c -n $NAMESPACE 2>/dev/null
    microk8s kubectl delete secret sepp-n32f -n $NAMESPACE 2>/dev/null
    microk8s kubectl delete secret sepp-ca -n $NAMESPACE 2>/dev/null

    # Create the N32-C TLS secret
    if [ -f "$CERT_DIR/$PREFIX-n32c.crt" ] && [ -f "$CERT_DIR/$PREFIX-n32c.key" ]; then
        echo "Creating sepp-n32c secret..."
        microk8s kubectl create secret tls sepp-n32c \
            --cert="$CERT_DIR/$PREFIX-n32c.crt" \
            --key="$CERT_DIR/$PREFIX-n32c.key" \
            -n $NAMESPACE
    else
        echo "Warning: N32-C certificates not found for $NAMESPACE"
    fi

    # Create the N32-F TLS secret
    if [ -f "$CERT_DIR/$PREFIX-n32f.crt" ] && [ -f "$CERT_DIR/$PREFIX-n32f.key" ]; then
        echo "Creating sepp-n32f secret..."
        microk8s kubectl create secret tls sepp-n32f \
            --cert="$CERT_DIR/$PREFIX-n32f.crt" \
            --key="$CERT_DIR/$PREFIX-n32f.key" \
            -n $NAMESPACE
    else
        echo "Warning: N32-F certificates not found for $NAMESPACE"
    fi

    # Create the CA secret
    if [ -f "$CERT_DIR/ca.crt" ]; then
        echo "Creating sepp-ca secret..."
        microk8s kubectl create secret generic sepp-ca \
            --from-file="$CERT_DIR/ca.crt" \
            -n $NAMESPACE
    else
        echo "Warning: CA certificate not found"
    fi
}

# Create secrets for VPLMN
create_namespace_secrets "vplmn" "sepp-vplmn"

# Create secrets for HPLMN
create_namespace_secrets "hplmn" "sepp-hplmn"

echo "TLS secrets creation completed!"