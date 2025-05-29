#!/bin/bash

# Script to push Open5GS images to Docker Hub
# Replace DOCKERHUB_USERNAME with your Docker Hub username

DOCKERHUB_USERNAME="your_username"

# Define colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# List of your Open5GS images
OPEN5GS_IMAGES=(
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

# Login to Docker Hub
echo -e "${BLUE}Logging in to Docker Hub...${NC}"
if ! docker login; then
  echo -e "${RED}Failed to log in to Docker Hub. Exiting.${NC}"
  exit 1
fi

# Tag and push images
for img in "${OPEN5GS_IMAGES[@]}"; do
  echo -e "${BLUE}Processing image: $img${NC}"
  
  # Check if image exists locally
  if docker image inspect "$img" &>/dev/null; then
    # Tag the image for Docker Hub
    echo "Tagging: $img → $DOCKERHUB_USERNAME/$img"
    docker tag "$img" "$DOCKERHUB_USERNAME/$img"
    
    # Push to Docker Hub
    echo "Pushing to Docker Hub: $DOCKERHUB_USERNAME/$img"
    if docker push "$DOCKERHUB_USERNAME/$img"; then
      echo -e "${GREEN}Successfully pushed: $DOCKERHUB_USERNAME/$img${NC}"
    else
      echo -e "${RED}Failed to push: $DOCKERHUB_USERNAME/$img${NC}"
    fi
  else
    echo -e "${YELLOW}Image not found locally: $img - Skipping${NC}"
  fi
  echo "---------------------------------"
done

echo -e "${GREEN}All images have been processed.${NC}"
echo -e "${BLUE}You can now update your Kubernetes deployments to use images from docker.io/$DOCKERHUB_USERNAME/image-name:tag${NC}"