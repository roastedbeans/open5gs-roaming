#!/bin/bash

# Open5GS Packet Capture Management Script

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Helper functions
error() { echo -e "${RED}Error: $@${NC}" >&2; }
info() { echo -e "${BLUE}$@${NC}"; }
success() { echo -e "${GREEN}$@${NC}"; }
warning() { echo -e "${YELLOW}$@${NC}"; }

# Default values
NAMESPACE="vplmn"
OUTPUT_DIR="./pcap-logs"
POD_NAME=""
PCAP_FILE_PATH="pcap/sepp.pcap"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace|-n)
            NAMESPACE="$2"
            shift 2
            ;;
        --output|-o)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --pcap-path|-p)
            PCAP_FILE_PATH="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
Usage: $0 [options]

Options:
    --namespace, -n       Kubernetes namespace (default: vplmn)
    --output, -o         Output directory for PCAP files (default: ./pcap-logs)
    --pcap-path, -p      Path to PCAP file in pod (default: pcap/sepp.pcap)
    --help, -h           Show this help message

Examples:
    $0                      # Capture packets from VPLMN SEPP
    $0 -n hplmn            # Capture packets from HPLMN SEPP
    $0 -o /tmp/pcaps       # Save PCAP files to /tmp/pcaps
    $0 -p /tmp/capture.pcap # Use different pcap file path
EOF
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get SEPP pod name
info "Looking for SEPP pod in namespace $NAMESPACE..."

# Try multiple methods to find the pod
POD_NAME=""

# Method 1: Try with app=sepp label
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=sepp -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

# Method 2: Try finding pod with 'sepp' in name
if [[ -z "$POD_NAME" ]]; then
    warning "No pod found with label app=sepp, trying to find pod with 'sepp' in name..."
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep sepp | awk '{print $1}' | head -1 || true)
fi

# Method 3: Try with different selectors
if [[ -z "$POD_NAME" ]]; then
    warning "Trying alternative selectors..."
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -o name 2>/dev/null | grep -i sepp | head -1 | cut -d'/' -f2 || true)
fi

# Method 4: Manual fallback - use the exact pod name we can see
if [[ -z "$POD_NAME" ]]; then
    warning "All methods failed, checking for known SEPP pod pattern..."
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep 'sepp-.*-.*' | awk '{print $1}' | head -1 || true)
fi

if [[ -z "$POD_NAME" ]]; then
    error "No SEPP pod found in namespace $NAMESPACE"
    info "Available pods:"
    kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || error "Failed to list pods - check kubectl configuration"
    exit 1
fi

info "Found SEPP pod: $POD_NAME"

# Check available containers in the pod
info "Checking available containers..."
CONTAINERS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)
info "Available containers: $CONTAINERS"

# Function to try copying from a specific container
try_copy_from_container() {
    local container=$1
    local pod_path=$2
    local output_file=$3
    
    info "Trying to copy from container: $container"
    
    # First check if file exists
    if kubectl exec "$POD_NAME" -c "$container" -n "$NAMESPACE" -- test -f "$pod_path" 2>/dev/null; then
        info "File exists in container $container, copying..."
        if kubectl cp "$POD_NAME:$pod_path" "$output_file" -c "$container" -n "$NAMESPACE" 2>/dev/null; then
            return 0
        else
            warning "Failed to copy from container $container"
            return 1
        fi
    else
        warning "File $pod_path not found in container $container"
        return 1
    fi
}

# Generate output filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/sepp_${NAMESPACE}_${TIMESTAMP}.pcap"

# Try different containers in order of preference
CONTAINER_PRIORITY=("sniffer" "sepp" "tcpdump" "capture")
COPY_SUCCESS=false

for container in "${CONTAINER_PRIORITY[@]}"; do
    if echo "$CONTAINERS" | grep -q "$container"; then
        if try_copy_from_container "$container" "$PCAP_FILE_PATH" "$OUTPUT_FILE"; then
            COPY_SUCCESS=true
            success "PCAP file successfully copied from container: $container"
            break
        fi
    fi
done

# If none of the priority containers worked, try all available containers
if [[ "$COPY_SUCCESS" == false ]]; then
    warning "Priority containers failed, trying all available containers..."
    for container in $CONTAINERS; do
        if try_copy_from_container "$container" "$PCAP_FILE_PATH" "$OUTPUT_FILE"; then
            COPY_SUCCESS=true
            success "PCAP file successfully copied from container: $container"
            break
        fi
    done
fi

# Final check and reporting
if [[ "$COPY_SUCCESS" == true ]]; then
    success "PCAP file saved to: $OUTPUT_FILE"
    
    # Show file info
    if [[ -f "$OUTPUT_FILE" ]]; then
        FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
        info "File size: $FILE_SIZE"
        info "You can analyze this file using: wireshark $OUTPUT_FILE"
    fi
else
    error "Failed to copy PCAP file from any container"
    info "Available containers were: $CONTAINERS"
    info "Tried to find file at: $PCAP_FILE_PATH"
    
    # Show available files for debugging
    warning "Listing available files in /tmp and /pcap directories:"
    for container in $CONTAINERS; do
        info "Container: $container"
        kubectl exec "$POD_NAME" -c "$container" -n "$NAMESPACE" -- find /tmp /pcap /var/log -name "*.pcap" 2>/dev/null || true
    done
    
    exit 1
fi