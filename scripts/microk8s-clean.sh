#!/bin/bash

# MicroK8s Cleanup Script for Open5GS
# This script removes resources in hplmn and vplmn namespaces but preserves the namespaces

# Exit on error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FORCE=false
NAMESPACE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --force|-f)
      FORCE=true
      shift
      ;;
    --namespace|-n)
      NAMESPACE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--force|-f] [--namespace|-n <namespace>]"
      echo "  --force, -f: Skip confirmation prompt"
      echo "  --namespace, -n: Specify a single namespace to clean (default: clean both hplmn and vplmn)"
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
  if [ -z "$NAMESPACE" ]; then
    echo -e "${RED}WARNING: This will delete ALL resources in hplmn and vplmn namespaces${NC}"
  else
    echo -e "${RED}WARNING: This will delete ALL resources in the $NAMESPACE namespace${NC}"
  fi
  echo -e "${RED}This includes all deployments, services, configmaps, etc.${NC}"
  echo -e "${GREEN}Note: The namespaces themselves will be preserved${NC}"
  echo ""
  read -p "Are you sure you want to continue? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
  fi
fi

# Function to clean resources in a namespace but preserve the namespace
clean_namespace_resources() {
  local namespace=$1
  echo -e "${BLUE}Cleaning resources in namespace $namespace...${NC}"
  
  # Check if namespace exists before attempting to clean it
  if ! microk8s kubectl get namespace $namespace &> /dev/null; then
    echo -e "${YELLOW}Namespace $namespace does not exist, skipping...${NC}"
    return 0
  fi
  
  # Delete all resources in the namespace
  echo -e "${YELLOW}Deleting all resources in $namespace...${NC}"
  microk8s kubectl delete all --all -n $namespace --force --grace-period=0 2>/dev/null || true
  microk8s kubectl delete configmap,secret,pvc,serviceaccount,rolebinding,role --all -n $namespace --force --grace-period=0 2>/dev/null || true
  
  echo -e "${GREEN}Resources in namespace $namespace have been cleaned${NC}"
}

# Clean namespaces
if [ -z "$NAMESPACE" ]; then
  # Clean both default namespaces
  clean_namespace_resources "hplmn"
  clean_namespace_resources "vplmn"
else
  # Clean only the specified namespace
  clean_namespace_resources "$NAMESPACE"
fi

echo -e "${GREEN}MicroK8s cleanup operation completed. Namespaces were preserved.${NC}" 