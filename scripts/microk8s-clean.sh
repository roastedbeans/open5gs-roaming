#!/bin/bash

# MicroK8s Cleanup Script for Open5GS
# This script removes all Open5GS related resources from a MicroK8s namespace

# Exit on error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default namespace
NAMESPACE="hplmn"
FORCE=false
DELETE_PV=false

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
    --delete-pv)
      DELETE_PV=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--namespace|-n NAMESPACE] [--force|-f] [--delete-pv]"
      echo "  --namespace, -n: Specify the namespace to clean (default: hplmn)"
      echo "  --force, -f: Skip confirmation prompt"
      echo "  --delete-pv: Also delete persistent volumes"
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

# Check if namespace exists
if ! microk8s kubectl get namespace $NAMESPACE &> /dev/null; then
  echo -e "${RED}Error: Namespace $NAMESPACE does not exist${NC}"
  exit 1
fi

# Display warning and ask for confirmation unless force mode is enabled
if [ "$FORCE" != "true" ]; then
  echo -e "${RED}WARNING: This will delete ALL resources in namespace $NAMESPACE${NC}"
  echo -e "${RED}This includes all deployments, services, configmaps, etc.${NC}"
  echo -e "${YELLOW}Data in persistent volumes may be lost${NC}"
  echo ""
  read -p "Are you sure you want to continue? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
  fi
fi

echo -e "${BLUE}Starting cleanup of namespace $NAMESPACE...${NC}"

# List of resource types to delete
RESOURCE_TYPES=(
  "deployments"
  "statefulsets"
  "services"
  "configmaps"
  "persistentvolumeclaims"
  "pods"
  "secrets"
)

# Delete resources by type
for resource_type in "${RESOURCE_TYPES[@]}"; do
  echo -e "${YELLOW}Deleting all $resource_type in namespace $NAMESPACE...${NC}"
  
  # Get resource count
  count=$(microk8s kubectl get $resource_type -n $NAMESPACE -o name 2>/dev/null | wc -l)
  
  if [ "$count" -gt 0 ]; then
    # List resources before deletion
    echo -e "${BLUE}Found $count $resource_type to delete:${NC}"
    microk8s kubectl get $resource_type -n $NAMESPACE --no-headers 2>/dev/null || true
    
    # Delete resources with a grace period of 10 seconds
    microk8s kubectl delete $resource_type --all -n $NAMESPACE --grace-period=10 --timeout=30s 2>/dev/null || true
    echo -e "${GREEN}$resource_type deleted successfully${NC}"
  else
    echo -e "${GREEN}No $resource_type found in namespace $NAMESPACE${NC}"
  fi
  
  echo "----------------------------------------"
done

# Wait a moment for resources to be properly terminated
echo -e "${BLUE}Waiting for resources to terminate...${NC}"
sleep 10

# Check if any pods are still running
if [ $(microk8s kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l) -gt 0 ]; then
  echo -e "${YELLOW}Some pods are still terminating. Force deleting them...${NC}"
  microk8s kubectl delete pods --all --force --grace-period=0 -n $NAMESPACE 2>/dev/null || true
  sleep 5
fi

# Handle persistent volumes
if [ "$DELETE_PV" = "true" ]; then
  echo -e "${YELLOW}Deleting persistent volumes associated with namespace $NAMESPACE...${NC}"
  
  PV_COUNT=$(microk8s kubectl get pv --no-headers 2>/dev/null | grep $NAMESPACE | wc -l)
  
  if [ "$PV_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Found $PV_COUNT persistent volumes to delete:${NC}"
    microk8s kubectl get pv | grep $NAMESPACE || true
    
    # Delete the persistent volumes
    microk8s kubectl get pv -o name | grep $NAMESPACE | xargs -r microk8s kubectl delete
    echo -e "${GREEN}Persistent volumes deleted${NC}"
  else
    echo -e "${GREEN}No persistent volumes found for namespace $NAMESPACE${NC}"
  fi
elif [ "$FORCE" != "true" ]; then
  # Ask about PV deletion if not forced and not already specified
  PV_COUNT=$(microk8s kubectl get pv --no-headers 2>/dev/null | grep $NAMESPACE | wc -l)
  
  if [ "$PV_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Found $PV_COUNT persistent volumes that may be related to namespace $NAMESPACE${NC}"
    microk8s kubectl get pv | grep $NAMESPACE || true
    echo ""
    read -p "Do you want to delete these persistent volumes too? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${BLUE}Deleting persistent volumes...${NC}"
      microk8s kubectl get pv -o name | grep $NAMESPACE | xargs -r microk8s kubectl delete
      echo -e "${GREEN}Persistent volumes deleted${NC}"
    fi
  fi
fi

# Verify cleanup
remaining_resources=0
for resource_type in "${RESOURCE_TYPES[@]}"; do
  count=$(microk8s kubectl get $resource_type -n $NAMESPACE -o name 2>/dev/null | wc -l)
  remaining_resources=$((remaining_resources + count))
done

if [ "$remaining_resources" -eq 0 ]; then
  echo -e "${GREEN}Cleanup complete! All resources have been removed from namespace $NAMESPACE${NC}"
else
  echo -e "${YELLOW}Warning: $remaining_resources resources could not be deleted. You may need to delete them manually${NC}"
  # List remaining resources
  for resource_type in "${RESOURCE_TYPES[@]}"; do
    microk8s kubectl get $resource_type -n $NAMESPACE --no-headers 2>/dev/null || true
  done
fi

echo -e "${GREEN}MicroK8s cleanup operation completed.${NC}"
echo -e "${BLUE}You can now redeploy your applications to namespace $NAMESPACE${NC}" 