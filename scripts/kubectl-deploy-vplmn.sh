#!/bin/bash

# Ordered 5G Core Network Deployment Script for VPLMN
# This script deploys the components of the VPLMN (Visited Public Land Mobile Network) in the proper order
# Exit on error
set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# VPLMN namespace
NAMESPACE="vplmn"

# Base directory for k8s manifests
BASE_DIR="k8s-roaming"

# Get Registry URL from ConfigMap
get_registry_url() {
    if [ -f "$BASE_DIR/env-config.yaml" ]; then
        # Extract registry URL from the env-config.yaml file
        REGISTRY_URL=$(grep "REGISTRY_URL:" "$BASE_DIR/env-config.yaml" | awk '{print $2}' | tr -d ' ')
        echo "$REGISTRY_URL"
    else
        echo "docker.io/vinch05"  # Default if config not found
    fi
}

# Apply global registry config first
apply_registry_config() {
    echo -e "${BLUE}Applying global registry configuration...${NC}"
    if [ -f "$BASE_DIR/env-config.yaml" ]; then
        microk8s kubectl apply -f "$BASE_DIR/env-config.yaml" -n $NAMESPACE
        echo -e "${GREEN}Applied registry configuration successfully${NC}"
    else
        echo -e "${RED}Error: env-config.yaml not found in $BASE_DIR${NC}"
        exit 1
    fi
}

# Function to deploy components from a directory
deploy_components() {
    local dir="$BASE_DIR/$NAMESPACE/$1"
    local component_name=$1
    local registry_url=$(get_registry_url)
    
    echo -e "${BLUE}Deploying $component_name...${NC}"
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo -e "${RED}Error: Directory $dir does not exist${NC}"
        return 1
    fi
    
    # Change to the directory
    cd "$dir"
    
    # Apply configmap if it exists
    if [ -f "configmap.yaml" ]; then
        echo -e "Applying configmap for $component_name..."
        microk8s kubectl apply -f configmap.yaml -n $NAMESPACE
    fi
    
    # Create a temporary deployment file with proper image references
    if [ -f "deployment.yaml" ]; then
        echo -e "Preparing deployment for $component_name..."
        # Create a temporary file
        temp_deployment=$(mktemp)
        
        # Replace the variable reference with the actual registry URL
        # Handle both formats: $(REGISTRY_URL)/image and "$(REGISTRY_URL)image"
        cat deployment.yaml | sed -e "s|\$(REGISTRY_URL)/|${registry_url}/|g" -e "s|\"\$(REGISTRY_URL)|\"${registry_url}|g" > "$temp_deployment"
        
        # Apply the modified deployment
        echo -e "Applying deployment for $component_name..."
        microk8s kubectl apply -f "$temp_deployment" -n $NAMESPACE
        
        # Clean up
        rm "$temp_deployment"
    else
        echo -e "${RED}Warning: No deployment.yaml found for $component_name${NC}"
    fi
    
    # Apply service
    if [ -f "service.yaml" ]; then
        echo -e "Applying service for $component_name..."
        microk8s kubectl apply -f service.yaml -n $NAMESPACE
    else
        echo -e "${RED}Warning: No service.yaml found for $component_name${NC}"
    fi
    
    echo -e "${GREEN}Finished deploying $component_name${NC}"
    echo "----------------------------------------"
    
    # Return to original directory
    cd - > /dev/null
}

# Create namespace if it doesn't exist
echo -e "${BLUE}Creating namespace $NAMESPACE if it doesn't exist...${NC}"
microk8s kubectl create namespace $NAMESPACE --dry-run=client -o yaml | microk8s kubectl apply -f -

# Apply registry config first
apply_registry_config

# Deploy VPLMN components
echo -e "${YELLOW}Deploying VPLMN components...${NC}"

# Step 1: Deploy NRF first
echo -e "${YELLOW}[1/6] Deploying NRF components...${NC}"
deploy_components "nrf"
echo -e "${GREEN}NRF components deployed successfully${NC}"

# Step 2: Deploy UDR/UDM/AUSF
echo -e "${YELLOW}[2/6] Deploying Subscriber Data Management components...${NC}"
deploy_components "udr"
deploy_components "udm"
deploy_components "ausf"
echo -e "${GREEN}Subscriber Data Management components deployed successfully${NC}"

# Step 3: Deploy Policy Functions
echo -e "${YELLOW}[3/6] Deploying Policy components...${NC}"
deploy_components "pcf"
deploy_components "bsf"
deploy_components "nssf"
echo -e "${GREEN}Policy components deployed successfully${NC}"

# Step 4: Deploy Core Network Functions
echo -e "${YELLOW}[4/6] Deploying Core Network Functions...${NC}"
deploy_components "scp"
deploy_components "sepp"
deploy_components "smf"
echo -e "${GREEN}Core Network Functions deployed successfully${NC}"

# Step 5: Deploy UPF
echo -e "${YELLOW}[5/6] Deploying User Plane Function (UPF)...${NC}"
deploy_components "upf"
echo -e "${GREEN}UPF deployed successfully${NC}"

# Step 6: Deploy AMF (last)
echo -e "${YELLOW}[6/6] Deploying Access and Mobility Management Function (AMF)...${NC}"
deploy_components "amf"
echo -e "${GREEN}AMF deployed successfully${NC}"

# Step 7: Deploy MongoDb if needed
echo -e "${YELLOW}[Optional] Deploying MongoDB...${NC}"
if [ -d "$BASE_DIR/$NAMESPACE/mongodb" ]; then
    deploy_components "mongodb"
    echo -e "${GREEN}MongoDB deployed successfully${NC}"
else
    echo -e "${YELLOW}No MongoDB directory found, skipping...${NC}"
fi

# Deploy packet capture if available
echo -e "${YELLOW}Deploying Packet Capture...${NC}"
if [ -d "$BASE_DIR/pcap-logs" ]; then
    deploy_components "../pcap-logs"
    echo -e "${GREEN}Packet Capture deployed successfully${NC}"
else
    echo -e "${YELLOW}No pcap-logs directory found, skipping...${NC}"
fi

# Wait for all pods to be ready
echo -e "${BLUE}Waiting for all pods to be ready...${NC}"
microk8s kubectl wait --for=condition=ready pods --all --namespace=$NAMESPACE --timeout=300s || echo "Some pods may not be ready yet, continuing..."

# Show status of all resources
echo -e "${BLUE}Showing status of all resources in the $NAMESPACE namespace:${NC}"
echo "----------------------------------------"
echo "Pods:"
microk8s kubectl get pods -n $NAMESPACE
echo "----------------------------------------"
echo "Services:"
microk8s kubectl get services -n $NAMESPACE
echo "----------------------------------------"
echo "Deployments:"
microk8s kubectl get deployments -n $NAMESPACE
echo "----------------------------------------"

echo -e "${GREEN}VPLMN Deployment complete${NC}"
echo -e "${BLUE}To check logs, use: microk8s kubectl logs -n $NAMESPACE <pod-name>${NC}" 