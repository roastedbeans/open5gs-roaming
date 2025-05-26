#!/bin/bash

# MicroK8s Cleanup Script for Open5GS
# This script removes hplmn and vplmn namespaces and all their resources

# Exit on error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --force|-f)
      FORCE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--force|-f]"
      echo "  --force, -f: Skip confirmation prompt"
      echo "  --help, -h: Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Display warning and ask for confirmation unless force mode is enabled
if [ "$FORCE" != "true" ]; then
  echo -e "${RED}WARNING: This will delete ALL resources in hplmn and vplmn namespaces${NC}"
  echo -e "${RED}This includes all deployments, services, configmaps, etc.${NC}"
  echo -e "${RED}The namespaces themselves will also be deleted${NC}"
  echo ""
  read -p "Are you sure you want to continue? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
  fi
fi

# Function to clean a namespace
clean_namespace() {
  local namespace=$1
  echo -e "${BLUE}Cleaning namespace $namespace...${NC}"
  
  # Check if namespace exists before attempting to clean it
  if ! microk8s kubectl get namespace $namespace &> /dev/null; then
    echo -e "${GREEN}Namespace $namespace does not exist, skipping...${NC}"
    return 0
  fi
  
  # Delete all resources in the namespace
  echo -e "${YELLOW}Deleting all resources in $namespace...${NC}"
  microk8s kubectl delete all --all -n $namespace --force --grace-period=0 2>/dev/null || true
  microk8s kubectl delete configmap,secret,pvc --all -n $namespace --force --grace-period=0 2>/dev/null || true
  
  # Delete the namespace
  echo -e "${YELLOW}Deleting namespace $namespace...${NC}"
  microk8s kubectl delete namespace $namespace --force --grace-period=0 2>/dev/null || true
  
  # Verify namespace deletion
  if ! microk8s kubectl get namespace $namespace &> /dev/null; then
    echo -e "${GREEN}Namespace $namespace has been removed${NC}"
  else
    echo -e "${YELLOW}Namespace $namespace is stuck in Terminating state. Attempting to remove finalizers...${NC}"
    
    # Get the namespace in JSON format
    NS_JSON=$(microk8s kubectl get namespace $namespace -o json)
    
    # Remove finalizers and update the namespace
    echo "$NS_JSON" | jq '.spec.finalizers = []' > /tmp/ns-without-finalizers.json
    
    # Use kubectl replace or proxy to update the namespace without finalizers
    echo -e "${YELLOW}Removing finalizers from namespace $namespace...${NC}"
    microk8s kubectl proxy &
    PROXY_PID=$!
    sleep 2
    
    # Use curl to update the namespace directly via the API server
    curl -k -H "Content-Type: application/json" -X PUT --data-binary @/tmp/ns-without-finalizers.json http://127.0.0.1:8001/api/v1/namespaces/$namespace/finalize
    
    # Kill the proxy
    kill $PROXY_PID
    
    # Check if namespace is now deleted
    if ! microk8s kubectl get namespace $namespace &> /dev/null; then
      echo -e "${GREEN}Successfully removed namespace $namespace${NC}"
    else
      echo -e "${RED}Failed to remove namespace $namespace. You may need to check for stuck resources manually:${NC}"
      echo -e "${YELLOW}Try running: microk8s kubectl get all -n $namespace${NC}"
      echo -e "${YELLOW}For each stuck resource: microk8s kubectl patch <resource-type>/<resource-name> -n $namespace -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge${NC}"
    fi
  fi
}

# Clean both namespaces
clean_namespace "hplmn"
clean_namespace "vplmn"

echo -e "${GREEN}MicroK8s cleanup operation completed.${NC}" 