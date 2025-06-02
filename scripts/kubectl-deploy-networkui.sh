#!/bin/bash

# Open5GS NetworkUI Deployment Script
# Deploys the NetworkUI component to the HPLMN namespace

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
      echo "  --namespace, -n NAMESPACE  Deploy NetworkUI to specific namespace (default: hplmn)"
      echo "  --force, -f                Skip confirmation prompt"
      echo "  --help, -h                 Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                         # Deploy NetworkUI to HPLMN namespace"
      echo "  $0 --namespace hplmn       # Deploy NetworkUI to HPLMN namespace"
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

# Function to deploy NetworkUI components
deploy_networkui() {
    local networkui_dir="$BASE_DIR/$NAMESPACE/networkui"
    
    echo -e "${BLUE}Deploying NetworkUI to namespace: $NAMESPACE${NC}"
    
    # Check if directory exists
    if [ ! -d "$networkui_dir" ]; then
        echo -e "${RED}Error: NetworkUI directory $networkui_dir does not exist${NC}"
        echo -e "${YELLOW}NetworkUI is only available for HPLMN namespace${NC}"
        return 1
    fi
    
    # Create namespace if it doesn't exist
    echo -e "${BLUE}Creating namespace $NAMESPACE if it doesn't exist...${NC}"
    microk8s kubectl create namespace $NAMESPACE --dry-run=client -o yaml | microk8s kubectl apply -f -
    
    # Change to the NetworkUI directory
    cd "$networkui_dir"
    
    # Apply deployment
    if [ -f "deployment.yaml" ]; then
        echo -e "${BLUE}Applying NetworkUI deployment...${NC}"
        microk8s kubectl apply -f deployment.yaml -n $NAMESPACE
    else
        echo -e "${RED}Error: No deployment.yaml found for NetworkUI${NC}"
        return 1
    fi
    
    # Apply service
    if [ -f "service.yaml" ]; then
        echo -e "${BLUE}Applying NetworkUI service...${NC}"
        microk8s kubectl apply -f service.yaml -n $NAMESPACE
    else
        echo -e "${RED}Error: No service.yaml found for NetworkUI${NC}"
        return 1
    fi
    
    # Return to original directory
    cd - > /dev/null
    
    # Wait for NetworkUI pod to be ready
    echo -e "${BLUE}Waiting for NetworkUI pod to be ready...${NC}"
    microk8s kubectl wait --for=condition=ready pods -l app=networkui --namespace=$NAMESPACE --timeout=120s || echo "NetworkUI pod may not be ready yet"
    
    # Get NodePort
    local nodeport=$(microk8s kubectl get service networkui -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    
    echo -e "${GREEN}NetworkUI deployed successfully!${NC}"
    echo -e "${BLUE}Access NetworkUI at: http://NODE_IP:$nodeport${NC}"
    echo -e "${YELLOW}Default credentials: admin / 1423${NC}"
    
    # Show NetworkUI pod status
    echo ""
    echo -e "${BLUE}NetworkUI Pod Status:${NC}"
    microk8s kubectl get pods -n $NAMESPACE -l app=networkui
    
    echo ""
    echo -e "${BLUE}NetworkUI Service:${NC}"
    microk8s kubectl get service networkui -n $NAMESPACE
    
    return 0
}

# Main execution
echo -e "${BLUE}Open5GS NetworkUI Deployment Script${NC}"
echo ""

# Confirmation prompt unless force mode
if [ "$FORCE" != "true" ]; then
  echo -e "${YELLOW}This will deploy NetworkUI to namespace: $NAMESPACE${NC}"
  echo ""
  read -p "Are you sure you want to continue? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
  fi
fi

# Deploy NetworkUI
deploy_networkui

echo -e "${GREEN}NetworkUI deployment completed!${NC}" 