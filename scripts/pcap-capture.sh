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
        --help|-h)
            cat << EOF
Usage: $0 [options]

Options:
    --namespace, -n    Kubernetes namespace (default: vplmn)
    --output, -o      Output directory for PCAP files (default: ./pcap-logs)
    --help, -h        Show this help message

Examples:
    $0                    # Capture packets from VPLMN SEPP
    $0 -n hplmn          # Capture packets from HPLMN SEPP
    $0 -o /tmp/pcaps     # Save PCAP files to /tmp/pcaps
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
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=sepp -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
if [[ -z "$POD_NAME" ]]; then
    error "No SEPP pod found in namespace $NAMESPACE"
    exit 1
fi

info "Found SEPP pod: $POD_NAME"

# Copy PCAP file from the pod
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/sepp_${NAMESPACE}_${TIMESTAMP}.pcap"

info "Copying PCAP file from pod..."
kubectl cp "$POD_NAME:/pcap/sepp.pcap" "$OUTPUT_FILE" sniffer -n $NAMESPACE

if [[ $? -eq 0 ]]; then
    success "PCAP file saved to: $OUTPUT_FILE"
    info "You can analyze this file using Wireshark or tcpdump"
else
    error "Failed to copy PCAP file"
    exit 1
fi 