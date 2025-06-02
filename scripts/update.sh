#!/bin/bash

# Script to update deployment files for both HPLMN and VPLMN namespaces
# to use images from the MicroK8s registry

# Define colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Define the namespaces to process
NAMESPACES=("hplmn" "vplmn")

# Registry prefix
REGISTRY="localhost:32000/"

# Create backup of original files
create_backups() {
  local namespace=$1
  echo -e "${BLUE}Creating backups of original deployment files for $namespace...${NC}"
  
  # Check if namespace directory exists
  if [ ! -d "$namespace" ]; then
    echo -e "${YELLOW}Directory $namespace not found. Skipping...${NC}"
    return
  fi
  
  # Create backups directory if it doesn't exist
  mkdir -p "$namespace/backups"
  
  # Find all yaml files and create backups
  find "$namespace" -name "*.yaml" -type f | while read -r file; do
    # Skip files in the backups directory
    if [[ $file == *"/backups/"* ]]; then
      continue
    fi
    
    # Create backup
    cp "$file" "$namespace/backups/$(basename "$file").bak"
    echo "Created backup: $namespace/backups/$(basename "$file").bak"
  done
  
  echo -e "${GREEN}Backups created successfully for $namespace.${NC}"
}

# Update image references in deployment files
update_image_references() {
  local namespace=$1
  echo -e "${BLUE}Updating image references in $namespace deployment files...${NC}"
  
  # Check if namespace directory exists
  if [ ! -d "$namespace" ]; then
    echo -e "${YELLOW}Directory $namespace not found. Skipping...${NC}"
    return
  fi
  
  # Find all yaml files containing Deployment kind
  find "$namespace" -name "*.yaml" -type f | xargs grep -l "kind: Deployment" | while read -r file; do
    # Skip files in the backups directory
    if [[ $file == *"/backups/"* ]]; then
      continue
    fi
    
    echo "Processing file: $file"
    
    # Check if file contains image references
    if grep -q "image:" "$file"; then
      # Update references for Open5GS components
      sed -i -E "s|image: (sepp|webui|networkui|smf|udm|amf|udr|upf|pcf|nrf|ausf|nssf|bsf|base-open5gs):v2.7.5|image: ${REGISTRY}\1:v2.7.5|g" "$file"
      
      # Update utility images
      sed -i "s|image: ghcr.io/borjis131/packetrusher:20250225|image: ${REGISTRY}packetrusher:20250225|g" "$file"
      sed -i "s|image: nicolaka/netshoot:latest|image: ${REGISTRY}netshoot:latest|g" "$file"
      sed -i "s|image: mongo:4.4|image: ${REGISTRY}mongo:4.4|g" "$file"
      
      # Make sure imagePullPolicy is set to IfNotPresent
      if grep -q "image: ${REGISTRY}" "$file"; then
        if ! grep -q "imagePullPolicy: IfNotPresent" "$file"; then
          sed -i "/image: ${REGISTRY}/a \        imagePullPolicy: IfNotPresent" "$file"
        fi
      fi
      
      echo -e "${GREEN}Updated image references in $file${NC}"
    else
      echo -e "${YELLOW}No image references found in $file. Skipping...${NC}"
    fi
  done
  
  echo -e "${GREEN}Completed updating image references for $namespace.${NC}"
}

# Main function
main() {
  echo -e "${BLUE}Starting update of deployment files for HPLMN and VPLMN...${NC}"
  
  # Process each namespace
  for namespace in "${NAMESPACES[@]}"; do
    echo -e "${BLUE}Processing namespace: $namespace${NC}"
    
    # Create backups
    create_backups "$namespace"
    
    # Update image references
    update_image_references "$namespace"
    
    echo -e "${GREEN}Completed processing for $namespace${NC}"
    echo "----------------------------------------"
  done
  
  echo -e "${GREEN}All deployment files have been updated to use MicroK8s registry images.${NC}"
  echo -e "${BLUE}You can now apply these configurations with:${NC}"
  echo "kubectl apply -f hplmn/"
  echo "kubectl apply -f vplmn/"
}

# Run the main function
main