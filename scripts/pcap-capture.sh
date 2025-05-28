#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="vplmn"
PCAP_PATH="pcap/sepp.pcap"
LOCAL_FOLDER="pcap-logs"

echo -e "${BLUE}=== SEPP PCAP Extractor ===${NC}"

# Create local folder if it doesn't exist
echo -e "${YELLOW}Creating folder: ${LOCAL_FOLDER}${NC}"
mkdir -p "$LOCAL_FOLDER"

# Find SEPP pod
echo -e "${YELLOW}Looking for SEPP pods in namespace: ${NAMESPACE}${NC}"
SEPP_POD=$(kubectl get pods -n "$NAMESPACE" | grep sepp | awk '{print $1}' | head -1)

if [ -z "$SEPP_POD" ]; then
    echo -e "${RED}❌ No SEPP pod found in namespace: ${NAMESPACE}${NC}"
    echo -e "${YELLOW}Available pods:${NC}"
    kubectl get pods -n "$NAMESPACE"
    exit 1
fi

echo -e "${GREEN}✅ Found SEPP pod: ${SEPP_POD}${NC}"

# Check containers in the pod
echo -e "${YELLOW}Checking containers in pod...${NC}"
CONTAINERS=$(kubectl get pod "$SEPP_POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}')
echo -e "${BLUE}Available containers: ${CONTAINERS}${NC}"

# Function to try copying from a container
try_copy() {
    local container=$1
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local output_file="${LOCAL_FOLDER}/sepp-${timestamp}.pcap"
    
    echo -e "${YELLOW}Trying to copy from container: ${container}${NC}"
    
    # Check if file exists first
    if kubectl exec "$SEPP_POD" -c "$container" -n "$NAMESPACE" -- test -f "$PCAP_PATH" 2>/dev/null; then
        echo -e "${GREEN}✅ File exists in ${container} container${NC}"
        
        # Copy the file
        if kubectl cp "${SEPP_POD}:${PCAP_PATH}" "$output_file" -c "$container" -n "$NAMESPACE"; then
            echo -e "${GREEN}✅ Successfully copied to: ${output_file}${NC}"
            
            # Show file info
            file_size=$(du -h "$output_file" | cut -f1)
            echo -e "${BLUE}📁 File size: ${file_size}${NC}"
            echo -e "${BLUE}📁 Full path: $(pwd)/${output_file}${NC}"
            return 0
        else
            echo -e "${RED}❌ Failed to copy from ${container} container${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  File not found in ${container} container${NC}"
        return 1
    fi
}

# Try copying from sniffer container first (most likely location)
if echo "$CONTAINERS" | grep -q "sniffer"; then
    if try_copy "sniffer"; then
        exit 0
    fi
fi

# Try copying from sepp container
if echo "$CONTAINERS" | grep -q "sepp"; then
    if try_copy "sepp"; then
        exit 0
    fi
fi

# If both fail, try all containers
echo -e "${YELLOW}Trying all containers...${NC}"
success=false
for container in $CONTAINERS; do
    if try_copy "$container"; then
        success=true
        break
    fi
done

if [ "$success" = false ]; then
    echo -e "${RED}❌ Failed to find or copy pcap file from any container${NC}"
    echo -e "${YELLOW}Manual check - listing files in containers:${NC}"
    
    for container in $CONTAINERS; do
        echo -e "${BLUE}--- Container: ${container} ---${NC}"
        kubectl exec "$SEPP_POD" -c "$container" -n "$NAMESPACE" -- find . -name "*.pcap" 2>/dev/null || echo "No pcap files found or no access"
    done
    exit 1
fi

echo -e "${GREEN}🎉 Done!${NC}"