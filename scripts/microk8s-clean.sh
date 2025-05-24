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
  
  # Delete all resources in the namespace
  microk8s kubectl delete all --all -n $namespace --force --grace-period=0 2>/dev/null || true
  microk8s kubectl delete configmap,secret,pvc --all -n $namespace --force --grace-period=0 2>/dev/null || true
  
  # Delete the namespace
  echo -e "${YELLOW}Deleting namespace $namespace...${NC}"
  microk8s kubectl delete namespace $namespace --force --grace-period=0 2>/dev/null || true
  
  # Verify namespace deletion
  if ! microk8s kubectl get namespace $namespace &> /dev/null; then
    echo -e "${GREEN}Namespace $namespace has been removed${NC}"
  else
    echo -e "${YELLOW}Warning: Namespace $namespace could not be deleted. You may need to delete it manually${NC}"
  fi
}

# Clean both namespaces
clean_namespace "hplmn"
clean_namespace "vplmn"

echo -e "${GREEN}MicroK8s cleanup operation completed.${NC}" 