#!/bin/bash

# PCAP File Copy Script
# Copies PCAP files from SEPP pods in the VPLMN namespace

# Source common utilities
source "$(dirname "$0")/common.sh"

# Configuration
readonly DEFAULT_NAMESPACE="vplmn"
readonly DEFAULT_PCAP_PATH="pcap/sepp.pcap"
readonly DEFAULT_CONTAINER="sniffer"
readonly OUTPUT_DIR="pcap-logs"

# Variables
NAMESPACE="$DEFAULT_NAMESPACE"
PCAP_PATH="$DEFAULT_PCAP_PATH"
CONTAINER="$DEFAULT_CONTAINER"

# Show usage information
show_usage() {
    cat << EOF
PCAP File Copy Script

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Copies PCAP files from SEPP pods in Kubernetes namespace

OPTIONS:
    -n, --namespace NAMESPACE    Kubernetes namespace (default: $DEFAULT_NAMESPACE)
    -c, --container CONTAINER    Container name (default: $DEFAULT_CONTAINER)
    -p, --path PATH             PCAP file path in container (default: $DEFAULT_PCAP_PATH)
    -o, --output DIR            Output directory (default: $OUTPUT_DIR)
    -f, --force                 Skip confirmation prompts
    -v, --verbose               Enable verbose output
    -h, --help                  Show this usage information

EXAMPLES:
    $0                          # Copy from default VPLMN namespace
    $0 -n hplmn -c sepp         # Copy from HPLMN namespace, sepp container
    $0 --output ./captures      # Copy to custom output directory

EOF
}

# Function to get available pods in the namespace
get_pods() {
    log_info "Fetching pods in the '$NAMESPACE' namespace..."
    
    if ! check_namespace "$NAMESPACE"; then
        die "Namespace '$NAMESPACE' does not exist"
    fi
    
    local pods
    pods=$($KUBECTL_CMD get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -E "(sepp|pcap)" | awk '{print $1}')
    
    if [[ -z "$pods" ]]; then
        log_warning "No SEPP or PCAP-related pods found in namespace '$NAMESPACE'"
        log_info "Available pods in namespace '$NAMESPACE':"
        $KUBECTL_CMD get pods -n "$NAMESPACE"
        return 1
    fi
    
    echo "$pods"
}

# Function to select pod interactively
select_pod() {
    local pods
    if ! pods=$(get_pods); then
        return 1
    fi
    
    local pod_array
    mapfile -t pod_array <<< "$pods"
    
    if [[ ${#pod_array[@]} -eq 1 ]]; then
        echo "${pod_array[0]}"
        return 0
    fi
    
    log_info "Available pods:"
    local i=1
    for pod in "${pod_array[@]}"; do
        echo "  $i) $pod"
        ((i++))
    done
    
    while true; do
        read -p "Select pod (1-${#pod_array[@]}): " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#pod_array[@]} ]]; then
            echo "${pod_array[$((selection-1))]}"
            return 0
        else
            log_error "Invalid selection. Please enter a number between 1 and ${#pod_array[@]}"
        fi
    done
}

# Function to check if file exists in container
check_pcap_file() {
    local pod_name="$1"
    local container="$2"
    local file_path="$3"
    
    log_debug "Checking if file '$file_path' exists in pod '$pod_name', container '$container'"
    
    if $KUBECTL_CMD exec "$pod_name" -c "$container" -n "$NAMESPACE" -- test -f "$file_path" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to copy PCAP file from pod
copy_pcap_file() {
    local pod_name="$1"
    local container="$2"
    local source_path="$3"
    local output_file="$4"
    
    log_info "Copying PCAP file from pod '$pod_name', container '$container'..."
    log_debug "Source: $source_path"
    log_debug "Destination: $output_file"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would copy: $pod_name:$source_path -> $output_file"
        return 0
    fi
    
    if $KUBECTL_CMD cp "$pod_name:$source_path" "$output_file" -c "$container" -n "$NAMESPACE"; then
        log_success "Successfully copied PCAP file to: $output_file"
        
        # Show file information
        if [[ -f "$output_file" ]]; then
            local file_size
            file_size=$(du -h "$output_file" | cut -f1)
            log_info "File size: $file_size"
            log_info "Full path: $(realpath "$output_file")"
        fi
        
        return 0
    else
        log_error "Failed to copy PCAP file"
        return 1
    fi
}

# Main function to handle PCAP copying
copy_pcap() {
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_debug "Created output directory: $OUTPUT_DIR"
    
    # Select pod
    local pod_name
    if ! pod_name=$(select_pod); then
        die "Failed to select pod"
    fi
    
    log_info "Selected pod: $pod_name"
    
    # Check available containers in the pod
    local containers
    containers=$($KUBECTL_CMD get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
    
    if [[ -z "$containers" ]]; then
        die "Failed to get containers for pod '$pod_name'"
    fi
    
    log_debug "Available containers: $containers"
    
    # Try to find the PCAP file in the specified container first
    local found_container=""
    local found_path=""
    
    if echo "$containers" | grep -q "$CONTAINER"; then
        if check_pcap_file "$pod_name" "$CONTAINER" "$PCAP_PATH"; then
            found_container="$CONTAINER"
            found_path="$PCAP_PATH"
        fi
    fi
    
    # If not found, try all containers
    if [[ -z "$found_container" ]]; then
        log_info "PCAP file not found in container '$CONTAINER', trying all containers..."
        
        for container in $containers; do
            if check_pcap_file "$pod_name" "$container" "$PCAP_PATH"; then
                found_container="$container"
                found_path="$PCAP_PATH"
                break
            fi
        done
    fi
    
    # If still not found, try to find any .pcap files
    if [[ -z "$found_container" ]]; then
        log_info "File '$PCAP_PATH' not found, searching for any .pcap files..."
        
        for container in $containers; do
            local pcap_files
            pcap_files=$($KUBECTL_CMD exec "$pod_name" -c "$container" -n "$NAMESPACE" -- find . -name "*.pcap" 2>/dev/null | head -1)
            
            if [[ -n "$pcap_files" ]]; then
                found_container="$container"
                found_path="$pcap_files"
                log_info "Found PCAP file: $found_path in container: $container"
                break
            fi
        done
    fi
    
    if [[ -z "$found_container" ]]; then
        die "No PCAP files found in any container of pod '$pod_name'"
    fi
    
    # Generate output filename
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local filename
    read -p "Enter filename (without extension) [default: sepp-$timestamp]: " filename
    filename="${filename:-sepp-$timestamp}"
    
    local output_file="$OUTPUT_DIR/${filename}.pcap"
    
    # Check if file already exists
    if [[ -f "$output_file" ]] && ! confirm_action "File '$output_file' already exists. Overwrite?"; then
        log_info "Operation cancelled"
        return 0
    fi
    
    # Copy the file
    copy_pcap_file "$pod_name" "$found_container" "$found_path" "$output_file"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -c|--container)
                CONTAINER="$2"
                shift 2
                ;;
            -p|--path)
                PCAP_PATH="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    # Initialize common utilities
    init_common
    
    # Parse arguments
    parse_args "$@"
    
    # Validate inputs
    if [[ -z "$NAMESPACE" ]]; then
        die "Namespace cannot be empty"
    fi
    
    if [[ -z "$CONTAINER" ]]; then
        die "Container name cannot be empty"
    fi
    
    if [[ -z "$PCAP_PATH" ]]; then
        die "PCAP path cannot be empty"
    fi
    
    # Show configuration
    log_info "PCAP Copy Configuration:"
    log_info "  Namespace: $NAMESPACE"
    log_info "  Container: $CONTAINER"
    log_info "  PCAP Path: $PCAP_PATH"
    log_info "  Output Dir: $OUTPUT_DIR"
    
    # Confirm action unless force mode
    if ! confirm_action "Proceed with PCAP file copy?"; then
        log_info "Operation cancelled"
        exit 0
    fi
    
    # Execute main function
    copy_pcap
    
    log_success "PCAP copy operation completed"
}

# Run main function
main "$@"
