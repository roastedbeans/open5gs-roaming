#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_NAMESPACE="vplmn"
NAMESPACE="${1:-$DEFAULT_NAMESPACE}"
PCAP_PATH="/pcap/sepp.pcap"
LOCAL_FOLDER="pcap-logs"

echo -e "${BLUE}=== SEPP PCAP Copy Tool ===${NC}"
echo -e "${YELLOW}Using namespace: ${NAMESPACE}${NC}"

# Create local folder if it doesn't exist
echo -e "${YELLOW}Creating folder: ${LOCAL_FOLDER}${NC}"
mkdir -p "$LOCAL_FOLDER"

# Function to get the list of pods in the specified namespace
get_pods() {
    echo -e "${YELLOW}Fetching pods in the ${NAMESPACE} namespace...${NC}"
    
    # Check if namespace exists
    if ! microk8s kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        echo -e "${RED}❌ Namespace '${NAMESPACE}' not found${NC}"
        echo -e "${YELLOW}Available namespaces:${NC}"
        microk8s kubectl get namespaces
        echo -e "${YELLOW}Usage: $0 [namespace] (default: vplmn)${NC}"
        echo -e "${BLUE}  Example: $0 hplmn${NC}"
        echo -e "${BLUE}  Example: $0 vplmn${NC}"
        exit 1
    fi
    
    # Get pods in the namespace
    local pods=$(microk8s kubectl get pods -n "$NAMESPACE" 2>/dev/null)
    if [ -z "$pods" ]; then
        echo -e "${RED}❌ No pods found in namespace: ${NAMESPACE}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Pods in ${NAMESPACE} namespace:${NC}"
    microk8s kubectl get pods -n "$NAMESPACE"
}

# Function to copy the pcap file from the specified pod
copy_pcap() {
    local pod_name
    local file_name
    local timestamp=$(date +%Y%m%d-%H%M%S)

    # Prompt user for pod name
    echo -e "${YELLOW}Enter the pod name (or press Enter to auto-detect SEPP pod):${NC}"
    read -p "> " pod_name
    
    # Auto-detect SEPP pod if not provided
    if [ -z "$pod_name" ]; then
        pod_name=$(microk8s kubectl get pods -n "$NAMESPACE" 2>/dev/null | grep sepp | awk '{print $1}' | head -1)
        if [ -z "$pod_name" ]; then
            echo -e "${RED}❌ No SEPP pod found automatically${NC}"
            echo -e "${YELLOW}Please enter the pod name manually:${NC}"
            read -p "> " pod_name
            if [ -z "$pod_name" ]; then
                echo -e "${RED}❌ Pod name is required${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}✅ Auto-detected SEPP pod: ${pod_name}${NC}"
        fi
    fi

    # Prompt user for file name
    echo -e "${YELLOW}Enter the file name to save as (without extension, or press Enter for default):${NC}"
    read -p "> " file_name
    
    # Use default filename if not provided
    if [ -z "$file_name" ]; then
        file_name="sepp-${NAMESPACE}-${timestamp}"
    fi
    
    local output_file="${LOCAL_FOLDER}/${file_name}.pcap"

    # Check if pod exists
    if ! microk8s kubectl get pod "$pod_name" -n "$NAMESPACE" >/dev/null 2>&1; then
        echo -e "${RED}❌ Pod '${pod_name}' not found in namespace '${NAMESPACE}'${NC}"
        exit 1
    fi

    # Check available containers
    local containers=$(microk8s kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}')
    echo -e "${BLUE}Available containers in pod: ${containers}${NC}"

    # Try to copy from sniffer container first, then from sepp container
    local container="sniffer"
    if ! echo "$containers" | grep -q "sniffer"; then
        echo -e "${YELLOW}⚠️  Sniffer container not found, trying sepp container...${NC}"
        container="sepp"
        if ! echo "$containers" | grep -q "sepp"; then
            echo -e "${RED}❌ Neither sniffer nor sepp container found${NC}"
            exit 1
        fi
    fi

    # Check if pcap file exists in the container
    echo -e "${YELLOW}Checking if pcap file exists in ${container} container...${NC}"
    if ! microk8s kubectl exec "$pod_name" -c "$container" -n "$NAMESPACE" -- test -f "$PCAP_PATH" 2>/dev/null; then
        echo -e "${RED}❌ PCAP file not found at ${PCAP_PATH} in ${container} container${NC}"
        echo -e "${YELLOW}Listing available files in /pcap directory:${NC}"
        microk8s kubectl exec "$pod_name" -c "$container" -n "$NAMESPACE" -- ls -la /pcap/ 2>/dev/null || echo "Cannot access /pcap directory"
        exit 1
    fi

    # Execute the kubectl cp command
    echo -e "${YELLOW}Copying pcap file from pod ${pod_name} (${container} container)...${NC}"
    if microk8s kubectl cp "$pod_name:$PCAP_PATH" "$output_file" -c "$container" -n "$NAMESPACE"; then
        echo -e "${GREEN}✅ Successfully copied to: ${output_file}${NC}"
        
        # Show file info
        if [ -f "$output_file" ]; then
            file_size=$(du -h "$output_file" | cut -f1)
            echo -e "${BLUE}📁 File size: ${file_size}${NC}"
            echo -e "${BLUE}📁 Full path: $(pwd)/${output_file}${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to copy pcap file${NC}"
        exit 1
    fi
}

# Main script execution
if [ "$#" -gt 1 ]; then
    echo -e "${YELLOW}Usage: $0 [namespace] (default: vplmn)${NC}"
    echo -e "${BLUE}  Example: $0 hplmn${NC}"
    echo -e "${BLUE}  Example: $0 vplmn${NC}"
    exit 1
fi

get_pods
echo ""
copy_pcap

echo -e "${GREEN}🎉 Done!${NC}"
