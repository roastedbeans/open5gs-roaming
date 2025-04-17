#!/bin/bash
set -e

# Environment variables with defaults
SEPP_FQDN=${SEPP_FQDN:-"sepp1.localdomain"}
SEPP_PLMN_FQDN=${SEPP_PLMN_FQDN:-"sepp.5gc.mnc001.mcc001.3gppnetwork.org"}
CERT_DAYS=${CERT_DAYS:-3650}

# Check if certificates should be regenerated
if [ "$REGENERATE_CERTS" = "true" ] || [ ! -f /etc/open5gs/default/tls/sepp1.crt ]; then
    echo "Generating new certificates..."
    
    # Create the CA certificate if it doesn't exist
    if [ ! -f /etc/open5gs/default/tls/ca.crt ]; then
        openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
            -keyout /etc/open5gs/default/tls/ca.key \
            -out /etc/open5gs/default/tls/ca.crt \
            -subj "/CN=open5gs-ca"
    fi
    
    # Generate the SEPP certificate with both domain names
    openssl req -x509 -nodes -days $CERT_DAYS -newkey rsa:2048 \
        -keyout /etc/open5gs/default/tls/sepp1.key \
        -out /etc/open5gs/default/tls/sepp1.crt \
        -subj "/CN=$SEPP_FQDN" \
        -addext "subjectAltName = DNS:$SEPP_FQDN,DNS:$SEPP_PLMN_FQDN"
    
    echo "Certificates generated successfully."
fi

# Print certificate information for verification
echo "Certificate information:"
openssl x509 -in /etc/open5gs/default/tls/sepp1.crt -noout -text | grep -A1 "Subject Alternative Name"

# Pass arguments to the SEPP daemon
exec open5gs-seppd "$@"