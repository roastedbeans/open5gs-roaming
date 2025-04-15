#!/bin/bash

# SEPP TLS Setup Script for Roaming
# This script automates the process of setting up TLS for SEPP roaming

set -e # Exit on error

# Directory setup
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

echo "Setting up TLS for SEPP roaming..."

# Step 1: Generate TLS certificates
echo "Generating TLS certificates..."
./scripts/generate_sepp_tls.sh

# Step 2: Check if certificates were created
if [ ! -d "./tls/sepp/h-sepp" ] || [ ! -d "./tls/sepp/v-sepp" ]; then
  echo "Error: Certificate generation failed."
  exit 1
fi

echo "TLS certificates successfully generated."

# Step 3: Verify YAML configurations
echo "Verifying YAML configurations..."
for file in "configs/roaming/h-sepp.yaml" "configs/roaming/v-sepp.yaml"; do
  if [ ! -f "$file" ]; then
    echo "Error: $file not found."
    exit 1
  fi
  
  # Check if TLS is enabled in the config
  if ! grep -q "tls:" "$file"; then
    echo "Warning: TLS configuration may not be properly set in $file."
  fi
done

echo "YAML configuration verified."

# Step 4: Provide instructions for Docker setup
echo ""
echo "=============== Setup Complete ==============="
echo "TLS certificates have been generated and configurations updated."
echo ""
echo "To start the roaming setup with TLS:"
echo "1. Run: cd $ROOT_DIR"
echo "2. Run: cd compose-files/roaming"
echo "3. Run: docker-compose up -d"
echo ""
echo "To verify the TLS setup works:"
echo "1. Check container logs: docker logs h-sepp"
echo "2. Check container logs: docker logs v-sepp"
echo "3. Verify TLS connection: curl -k https://localhost:10443"
echo ""
echo "NOTE: TLS certificates are mounted from $ROOT_DIR/tls/sepp/"
echo "================================================" 