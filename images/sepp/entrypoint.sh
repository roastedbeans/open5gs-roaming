#!/bin/bash
set -e

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
else
    SEPP_FQDN="sepp2.localdomain"
    SEPP_PLMN_FQDN="sepp.5gc.mnc070.mcc999.3gppnetwork.org"
    CERT_PREFIX="sepp2"
fi

# Allow overriding of values through environment variables
SEPP_FQDN=${SEPP_FQDN_OVERRIDE:-"$SEPP_FQDN"}
SEPP_PLMN_FQDN=${SEPP_PLMN_FQDN_OVERRIDE:-"$SEPP_PLMN_FQDN"}
CERT_DAYS=${CERT_DAYS:-3650}
TLS_DIR=${TLS_DIR:-"/etc/open5gs/default/tls"}

# Ensure TLS directory exists
mkdir -p $TLS_DIR

# Check if certificates should be regenerated
if [ "$REGENERATE_CERTS" = "true" ] || [ ! -f "$TLS_DIR/$CERT_PREFIX.crt" ]; then
    echo "Generating new certificates for $SEPP_FQDN..."
    
    # Create the CA certificate if it doesn't exist
    if [ ! -f "$TLS_DIR/ca.crt" ]; then
        echo "Generating CA certificate..."
        openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
            -keyout "$TLS_DIR/ca.key" \
            -out "$TLS_DIR/ca.crt" \
            -subj "/CN=open5gs-ca"
    fi
    
    # Generate the SEPP certificate with both domain names
    echo "Generating SEPP certificate for $CERT_PREFIX..."
    openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
        -keyout "$TLS_DIR/$CERT_PREFIX.key" \
        -out "$TLS_DIR/$CERT_PREFIX.crt" \
        -subj "/CN=$SEPP_FQDN" \
        -addext "subjectAltName = DNS:$SEPP_FQDN,DNS:$SEPP_PLMN_FQDN"
    
    echo "Certificates generated successfully."
fi

# Print certificate information for verification
echo "Certificate information for $CERT_PREFIX:"
openssl x509 -in "$TLS_DIR/$CERT_PREFIX.crt" -noout -text | grep -A1 "Subject Alternative Name"

# Update configuration file with the correct certificate paths if needed
CONFIG_FILE="${1#-c }"
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    # Only try to update if there's an indication it might be needed
    if grep -q "sepp1.key" "$CONFIG_FILE" && [ "$SEPP_TYPE" = "sepp2" ]; then
        echo "Updating certificate paths in config file to use $CERT_PREFIX..."
        sed -i "s|sepp1.key|$CERT_PREFIX.key|g" "$CONFIG_FILE"
        sed -i "s|sepp1.crt|$CERT_PREFIX.crt|g" "$CONFIG_FILE"
    fi
fi

# Pass arguments to the SEPP daemon
exec open5gs-seppd "$@"