#!/bin/bash

# Script to pull all Open5GS Docker images from docker.io/vinch05
# Usage: ./pull-docker-images.sh [version]

# Set default version if not provided
VERSION="${1:-v2.7.5}"

echo "🐳 Pulling Open5GS Docker images version ${VERSION} from docker.io/vinch05..."

# List of all Open5GS components
COMPONENTS=(
  "base-open5gs"
  "amf"
  "ausf"
  "bsf"
  "nrf"
  "nssf"
  "pcf"
  "sepp"
  "smf"
  "udm"
  "udr"
  "upf"
  "webui"
)

# Pull each image
for component in "${COMPONENTS[@]}"; do
  echo "Pulling docker.io/vinch05/${component}:${VERSION}..."
  docker pull docker.io/vinch05/${component}:${VERSION}
  
  # Check if pull was successful
  if [ $? -eq 0 ]; then
    echo "✅ Successfully pulled docker.io/vinch05/${component}:${VERSION}"
  else
    echo "❌ Failed to pull docker.io/vinch05/${component}:${VERSION}"
  fi
done

# Pull tcpdump image for network packet capture
echo "Pulling corfr/tcpdump for packet capture..."
docker pull corfr/tcpdump

echo "✅ All images pulled. Use 'docker images' to verify."

# Show all pulled images
echo "📋 List of pulled images:"
docker images | grep -E "vinch05|tcpdump" 