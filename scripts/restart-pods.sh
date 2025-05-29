#!/bin/bash

# Kubernetes Pod Restart Script
# Restarts all pods in specified namespaces or all Open5GS namespaces

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default namespaces for Open5GS
DEFAULT_NAMESPACES=("hplmn" "vplmn")
SELECTED_NAMESPACES=()
FORCE=false
WAIT_TIMEOUT=300

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--namespace)
      SELECTED_NAMESPACES+=("$2")
      shift 2
      ;;
    -a|--all)
      SELECTED_NAMESPACES=("${DEFAULT_NAMESPACES[@]}")
      shift
      ;;
    -H|--hplmn)
      SELECTED_NAMESPACES+=("hplmn")
      shift
      ;;
    -V|--vplmn)
      SELECTED_NAMESPACES+=("vplmn")
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -t|--timeout)
      WAIT_TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -n, --namespace NS      Restart pods in specific namespace"
      echo "  -a, --all              Restart pods in all Open5GS namespaces (hplmn, vplmn)"
      echo "  -H, --hplmn            Restart pods in hplmn namespace only"
      echo "  -V, --vplmn            Restart pods in vplmn namespace only"
      echo "  -f, --force            Skip confirmation prompt"
      echo "  -t, --timeout SEC      Wait timeout for pods (default: 300s)"
      echo "  -h, --help             Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 -a                   # Restart all Open5GS pods"
      echo "  $0 -H                   # Restart HPLMN pods only"
      echo "  $0 -n custom-namespace  # Restart pods in custom namespace"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      echo "Use -h for usage information"
      exit 1
      ;;
  esac
done

# If no namespaces specified, use all defaults
if [ ${#SELECTED_NAMESPACES[@]} -eq 0 ]; then
  SELECTED_NAMESPACES=("${DEFAULT_NAMESPACES[@]}")
fi

# Function to check if namespace exists
check_namespace() {
  local namespace=$1
  if ! microk8s kubectl get namespace "$namespace" &> /dev/null; then
    echo -e "${YELLOW}Warning: Namespace $namespace does not exist, skipping...${NC}"
    return 1
  fi
  return 0
}

# Function to restart pods in a namespace
restart_namespace_pods() {
  local namespace=$1
  
  echo -e "${BLUE}Processing namespace: $namespace${NC}"
  
  # Check if namespace exists
  if ! check_namespace "$namespace"; then
    return 1
  fi
  
  # Get all deployments in the namespace
  local deployments=$(microk8s kubectl get deployments -n "$namespace" -o name 2>/dev/null)
  
  if [ -z "$deployments" ]; then
    echo -e "${YELLOW}No deployments found in namespace $namespace${NC}"
    return 0
  fi
  
  echo -e "${BLUE}Found deployments in $namespace:${NC}"
  microk8s kubectl get deployments -n "$namespace"
  echo ""
  
  # Restart each deployment
  echo -e "${BLUE}Restarting deployments in $namespace...${NC}"
  for deployment in $deployments; do
    deployment_name=$(echo "$deployment" | cut -d'/' -f2)
    echo -e "${YELLOW}Restarting $deployment_name...${NC}"
    
    if microk8s kubectl rollout restart "$deployment" -n "$namespace"; then
      echo -e "${GREEN}✓ $deployment_name restart initiated${NC}"
    else
      echo -e "${RED}✗ Failed to restart $deployment_name${NC}"
    fi
  done
  
  echo ""
  echo -e "${BLUE}Waiting for pods to be ready in $namespace...${NC}"
  
  # Wait for rollout to complete
  for deployment in $deployments; do
    deployment_name=$(echo "$deployment" | cut -d'/' -f2)
    echo -e "${YELLOW}Waiting for $deployment_name rollout...${NC}"
    
    if microk8s kubectl rollout status "$deployment" -n "$namespace" --timeout="${WAIT_TIMEOUT}s"; then
      echo -e "${GREEN}✓ $deployment_name is ready${NC}"
    else
      echo -e "${RED}✗ $deployment_name rollout timed out${NC}"
    fi
  done
  
  echo ""
  echo -e "${BLUE}Current pod status in $namespace:${NC}"
  microk8s kubectl get pods -n "$namespace"
  echo "----------------------------------------"
  
  return 0
}

# Main execution
echo -e "${BLUE}Open5GS Pod Restart Script${NC}"
echo -e "${BLUE}Namespaces to restart: ${SELECTED_NAMESPACES[*]}${NC}"
echo ""

# Confirmation prompt unless force mode
if [ "$FORCE" != "true" ]; then
  echo -e "${YELLOW}This will restart all pods in the following namespaces:${NC}"
  for ns in "${SELECTED_NAMESPACES[@]}"; do
    echo -e "  - $ns"
  done
  echo ""
  read -p "Are you sure you want to continue? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
  fi
fi

echo -e "${BLUE}Starting pod restart operation...${NC}"
echo ""

# Process each namespace
for namespace in "${SELECTED_NAMESPACES[@]}"; do
  restart_namespace_pods "$namespace"
  echo ""
done

echo -e "${GREEN}Pod restart operation completed!${NC}"
echo -e "${BLUE}All specified namespaces have been processed.${NC}" 