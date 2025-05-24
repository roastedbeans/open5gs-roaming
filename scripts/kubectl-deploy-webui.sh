#!/bin/bash

# Open5GS WebUI Deployment Script
# Deploys the WebUI component to the HPLMN namespace

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="hplmn"
BASE_DIR="k8s-roaming"
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace|-n)
      NAMESPACE="$2"
      shift 2
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --namespace, -n NAMESPACE  Deploy WebUI to specific namespace (default: hplmn)"
      echo "  --force, -f                Skip confirmation prompt"
      echo "  --help, -h                 Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                         # Deploy WebUI to HPLMN namespace"
      echo "  $0 --namespace hplmn       # Deploy WebUI to HPLMN namespace"
      echo "  $0 --force                 # Deploy without confirmation"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Function to deploy WebUI components
deploy_webui() {
    local webui_dir="$BASE_DIR/$NAMESPACE/webui"
    
    echo -e "${BLUE}Deploying WebUI to namespace: $NAMESPACE${NC}"
    
    # Check if directory exists
    if [ ! -d "$webui_dir" ]; then
        echo -e "${RED}Error: WebUI directory $webui_dir does not exist${NC}"
        echo -e "${YELLOW}WebUI is only available for HPLMN namespace${NC}"
        return 1
    fi
    
    # Create namespace if it doesn't exist
    echo -e "${BLUE}Creating namespace $NAMESPACE if it doesn't exist...${NC}"
    microk8s kubectl create namespace $NAMESPACE --dry-run=client -o yaml | microk8s kubectl apply -f -
    
    # Change to the WebUI directory
    cd "$webui_dir"
    
    # Apply deployment
    if [ -f "deployment.yaml" ]; then
        echo -e "${BLUE}Applying WebUI deployment...${NC}"
        microk8s kubectl apply -f deployment.yaml -n $NAMESPACE
    else
        echo -e "${RED}Error: No deployment.yaml found for WebUI${NC}"
        return 1
    fi
    
    # Apply service
    if [ -f "service.yaml" ]; then
        echo -e "${BLUE}Applying WebUI service...${NC}"
        microk8s kubectl apply -f service.yaml -n $NAMESPACE
    else
        echo -e "${RED}Error: No service.yaml found for WebUI${NC}"
        return 1
    fi
    
    # Return to original directory
    cd - > /dev/null
    
    # Wait for WebUI pod to be ready
    echo -e "${BLUE}Waiting for WebUI pod to be ready...${NC}"
    microk8s kubectl wait --for=condition=ready pods -l app=webui --namespace=$NAMESPACE --timeout=120s || echo "WebUI pod may not be ready yet"
    
    # Get NodePort
    local nodeport=$(microk8s kubectl get service webui -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    
    echo -e "${GREEN}WebUI deployed successfully!${NC}"
    echo -e "${BLUE}Access WebUI at: http://NODE_IP:$nodeport${NC}"
    echo -e "${YELLOW}Default credentials: admin / 1423${NC}"
    
    # Show WebUI pod status
    echo ""
    echo -e "${BLUE}WebUI Pod Status:${NC}"
    microk8s kubectl get pods -n $NAMESPACE -l app=webui
    
    echo ""
    echo -e "${BLUE}WebUI Service:${NC}"
    microk8s kubectl get service webui -n $NAMESPACE
    
    return 0
}

# Main execution
echo -e "${BLUE}Open5GS WebUI Deployment Script${NC}"
echo ""

# Confirmation prompt unless force mode
if [ "$FORCE" != "true" ]; then
  echo -e "${YELLOW}This will deploy WebUI to namespace: $NAMESPACE${NC}"
  echo ""
  read -p "Are you sure you want to continue? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
  fi
fi

# Deploy WebUI
deploy_webui

echo -e "${GREEN}WebUI deployment completed!${NC}" 