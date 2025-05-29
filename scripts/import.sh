#!/bin/bash

# Script to import Open5GS Docker images into MicroK8s
# This script is tailored for your specific images

# Define colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if registry is enabled
check_registry() {
  echo -e "${BLUE}Checking if MicroK8s registry is enabled...${NC}"
  if ! microk8s status | grep -q "registry: enabled"; then
    echo -e "${BLUE}Enabling MicroK8s registry...${NC}"
    microk8s enable registry
    echo "Waiting for registry to be ready..."
    sleep 10
  fi
  echo -e "${GREEN}Registry is enabled.${NC}"
}

# List of your Open5GS images as shown in docker images output
IMAGES=(
  "sepp:v2.7.5"
  "webui:v2.7.5"
  "networkui:v2.7.5"
  "smf:v2.7.5"
  "udm:v2.7.5"
  "amf:v2.7.5"
  "udr:v2.7.5"
  "upf:v2.7.5"
  "pcf:v2.7.5"
  "nrf:v2.7.5"
  "scp:v2.7.5"
  "ausf:v2.7.5"
  "nssf:v2.7.5"
  "bsf:v2.7.5"
  "base-open5gs:v2.7.5"
)

# Additional utility images
UTIL_IMAGES=(
  "ghcr.io/borjis131/packetrusher:20250225"
  "nicolaka/netshoot:latest"
  "mongo:4.4"
)

# Import Open5GS images to MicroK8s registry
import_open5gs_images() {
  echo -e "${BLUE}Importing Open5GS images to MicroK8s registry...${NC}"
  
  for img in "${IMAGES[@]}"; do
    echo -e "${BLUE}Processing image: $img${NC}"
    
    # Tag the image for the MicroK8s registry
    docker tag $img localhost:32000/$img
    
    # Push to MicroK8s registry
    echo "Pushing to MicroK8s registry: localhost:32000/$img"
    docker push localhost:32000/$img
    
    echo -e "${GREEN}Successfully imported: $img${NC}"
    echo "---------------------------------"
  done
}

# Import utility images
import_util_images() {
  echo -e "${BLUE}Importing utility images to MicroK8s registry...${NC}"
  
  for img in "${UTIL_IMAGES[@]}"; do
    echo -e "${BLUE}Processing image: $img${NC}"
    
    # Extract image name without registry prefix for cleaner names
    img_name=$(echo $img | sed 's|.*/||')
    
    # Tag the image for the MicroK8s registry
    docker tag $img localhost:32000/$img_name
    
    # Push to MicroK8s registry
    echo "Pushing to MicroK8s registry: localhost:32000/$img_name"
    docker push localhost:32000/$img_name
    
    echo -e "${GREEN}Successfully imported: $img${NC}"
    echo "---------------------------------"
  done
}

# Main function
main() {
  echo -e "${BLUE}Starting import of Docker images to MicroK8s...${NC}"
  
  # Check registry status
  check_registry
  
  # Import Open5GS images
  import_open5gs_images
  
  # Import utility images
  import_util_images
  
  # List images in registry
  echo -e "${BLUE}Listing images in MicroK8s registry:${NC}"
  curl -s http://localhost:32000/v2/_catalog | python3 -m json.tool
  
  echo -e "${GREEN}All images have been successfully imported to MicroK8s registry.${NC}"
  echo -e "${BLUE}Use these images in your deployments with image: localhost:32000/image-name:tag${NC}"
}

# Run the main function
main