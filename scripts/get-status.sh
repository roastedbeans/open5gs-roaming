#!/bin/bash

# Open5GS Status Script
# Shows the status of all Open5GS deployments

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default namespaces
NAMESPACES=("hplmn" "vplmn")
SHOW_DETAILS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace|-n)
      NAMESPACES=("$2")
      shift 2
      ;;
    --details|-d)
      SHOW_DETAILS=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --namespace, -n NAMESPACE  Show status for specific namespace"
      echo "  --details, -d              Show detailed information"
      echo "  --help, -h                 Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      exit 1
      ;;
  esac
done

# Function to check namespace status
check_namespace_status() {
  local namespace=$1
  
  echo -e "${BLUE}=== $namespace Namespace ===${NC}"
  
  # Check if namespace exists
  if ! microk8s kubectl get namespace "$namespace" &> /dev/null; then
    echo -e "${RED}❌ Namespace $namespace does not exist${NC}"
    echo ""
    return 1
  fi
  
  # Get pods
  local pods=$(microk8s kubectl get pods -n "$namespace" --no-headers 2>/dev/null)
  
  if [ -z "$pods" ]; then
    echo -e "${YELLOW}⚠️  No pods found in $namespace${NC}"
    echo ""
    return 0
  fi
  
  # Count pod statuses
  local total_pods=$(echo "$pods" | wc -l)
  local running_pods=$(echo "$pods" | grep -c "Running" || echo "0")
  local pending_pods=$(echo "$pods" | grep -c "Pending" || echo "0")
  local failed_pods=$(echo "$pods" | grep -c -E "(Error|CrashLoopBackOff|Failed)" || echo "0")
  
  echo -e "${BLUE}📊 Pod Summary:${NC}"
  echo -e "  Total: $total_pods | Running: ${GREEN}$running_pods${NC} | Pending: ${YELLOW}$pending_pods${NC} | Failed: ${RED}$failed_pods${NC}"
  echo ""
  
  # Show pod table
  echo -e "${BLUE}📋 Pods:${NC}"
  microk8s kubectl get pods -n "$namespace" -o wide
  echo ""
  
  # Show services if details requested
  if [ "$SHOW_DETAILS" = "true" ]; then
    echo -e "${BLUE}🌐 Services:${NC}"
    microk8s kubectl get services -n "$namespace"
    echo ""
    
    echo -e "${BLUE}🚀 Deployments:${NC}"
    microk8s kubectl get deployments -n "$namespace"
    echo ""
  fi
  
  return 0
}

# Main execution
echo -e "${BLUE}🔍 Open5GS Status Report${NC}"
echo -e "${BLUE}$(date)${NC}"
echo ""

# Check each namespace
for namespace in "${NAMESPACES[@]}"; do
  check_namespace_status "$namespace"
done

# Overall cluster info
echo -e "${BLUE}=== Cluster Information ===${NC}"
echo -e "${BLUE}📈 MicroK8s Status:${NC}"
microk8s status --wait-ready --timeout 10 || echo -e "${RED}MicroK8s not ready${NC}"
echo ""

echo -e "${BLUE}🗄️ All Open5GS Services:${NC}"
microk8s kubectl get services -A | head -1
microk8s kubectl get services -A | grep -E "(hplmn|vplmn)" || echo "No Open5GS services found"
echo ""

echo -e "${GREEN}✅ Status check completed${NC}" 