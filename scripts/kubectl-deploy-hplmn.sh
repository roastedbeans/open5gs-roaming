#!/bin/bash

# Ordered 5G Core Network Deployment Script for HPLMN
# This script deploys the components of the HPLMN (Home Public Land Mobile Network) in the proper order
# Exit on error
set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# HPLMN namespace
NAMESPACE="hplmn"

# Base directory for k8s manifests
BASE_DIR="k8s-roaming"

# Function to deploy components from a directory
deploy_components() {
    local dir="$BASE_DIR/$NAMESPACE/$1"
    local component_name=$1
    
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
    
    # Apply deployment
    if [ -f "deployment.yaml" ]; then
        echo -e "Applying deployment for $component_name..."
        microk8s kubectl apply -f deployment.yaml -n $NAMESPACE
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

# Deploy HPLMN components
echo -e "${YELLOW}Deploying HPLMN components...${NC}"

# Step 1: Deploy NRF first (Network Repository Function - the service registry)
echo -e "${YELLOW}[1/4] Deploying NRF components (Service Registry)...${NC}"
deploy_components "nrf"
echo -e "${GREEN}NRF components deployed successfully${NC}"

# Step 2: Deploy UDR/UDM/AUSF (User data management and authentication)
echo -e "${YELLOW}[2/4] Deploying Subscriber Data Management components...${NC}"
deploy_components "udr"
deploy_components "udm"
deploy_components "ausf"
echo -e "${GREEN}Subscriber Data Management components deployed successfully${NC}"

# Step 3: Deploy Core Network Functions
echo -e "${YELLOW}[3/4] Deploying Core Network Functions...${NC}"
deploy_components "scp"
deploy_components "sepp"
echo -e "${GREEN}Core Network Functions deployed successfully${NC}"

# Step 4: Deploy MongoDb if needed
echo -e "${YELLOW}[4/5] Deploying MongoDB...${NC}"
if [ -d "$BASE_DIR/$NAMESPACE/mongodb" ]; then
    deploy_components "mongodb"
    echo -e "${GREEN}MongoDB deployed successfully${NC}"
else
    echo -e "${YELLOW}No MongoDB directory found, skipping...${NC}"
fi

# Step 5: Deploy WebUI
echo -e "${YELLOW}[5/6] Deploying WebUI...${NC}"
if [ -d "$BASE_DIR/$NAMESPACE/webui" ]; then
    deploy_components "webui"
    echo -e "${GREEN}WebUI deployed successfully${NC}"
    echo -e "${BLUE}WebUI will be available at: http://NODE_IP:30999${NC}"
else
    echo -e "${YELLOW}No WebUI directory found, skipping...${NC}"
fi

# Step 6: Deploy NetworkUI
echo -e "${YELLOW}[6/6] Deploying NetworkUI...${NC}"
if [ -d "$BASE_DIR/$NAMESPACE/networkui" ]; then
    deploy_components "networkui"
    echo -e "${GREEN}NetworkUI deployed successfully${NC}"
    echo -e "${BLUE}NetworkUI will be available at: http://NODE_IP:30998${NC}"
else
    echo -e "${YELLOW}No NetworkUI directory found, skipping...${NC}"
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

echo -e "${GREEN}HPLMN Deployment complete${NC}"
echo -e "${BLUE}To check logs, use: microk8s kubectl logs -n $NAMESPACE <pod-name>${NC}" 