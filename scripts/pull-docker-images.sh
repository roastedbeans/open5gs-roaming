#!/bin/bash

# Docker Images Pull Script
# Pulls all Open5GS Docker images from docker.io/vinch05

# Source common utilities
source "$(dirname "$0")/common.sh"

# Configuration
readonly DEFAULT_REGISTRY="docker.io/vinch05"
readonly DEFAULT_VERSION="v2.7.5"

# List of all Open5GS components
readonly COMPONENTS=(
    "base-open5gs"
    "amf"
    "ausf"
    "bsf"
    "nrf"
    "nssf"
    "pcf"
    "sepp"
    "smf"
    "udm"
    "udr"
    "upf"
    "webui"
    "networkui"
)

# Additional utility images
readonly UTILITY_IMAGES=(
    "corfr/tcpdump:latest"
)

# Variables
REGISTRY="$DEFAULT_REGISTRY"
VERSION="$DEFAULT_VERSION"
PULL_UTILITIES=true
PARALLEL_PULLS=false

# Show usage information
show_usage() {
    cat << EOF
Docker Images Pull Script

USAGE:
    $0 [OPTIONS] [VERSION]

DESCRIPTION:
    Pulls all Open5GS Docker images from a specified registry

OPTIONS:
    -r, --registry REGISTRY     Docker registry (default: $DEFAULT_REGISTRY)
    -v, --version VERSION       Image version to pull (default: $DEFAULT_VERSION)
    --no-utilities              Skip pulling utility images
    --parallel                  Pull images in parallel (experimental)
    -f, --force                 Force pull even if images exist
    --verbose                   Enable verbose output
    -h, --help                  Show this usage information

POSITIONAL ARGUMENTS:
    VERSION                     Image version (overrides --version)

EXAMPLES:
    $0                          # Pull default version from default registry
    $0 v2.8.0                   # Pull specific version
    $0 -r myregistry.com/open5gs # Pull from custom registry
    $0 --no-utilities           # Skip utility images

COMPONENTS:
$(printf "    %s\n" "${COMPONENTS[@]}")

EOF
}

# Function to check if Docker image exists locally
image_exists() {
    local image="$1"
    docker image inspect "$image" >/dev/null 2>&1
}

# Function to pull a single Docker image
pull_image() {
    local image="$1"
    local force="${2:-false}"
    
    log_info "Pulling $image..."
    
    # Check if image already exists
    if [[ "$force" != "true" ]] && image_exists "$image"; then
        log_warning "Image $image already exists locally (use --force to re-pull)"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would pull: $image"
        return 0
    fi
    
    # Pull the image
    if docker pull "$image"; then
        log_success "Successfully pulled $image"
        return 0
    else
        log_error "Failed to pull $image"
        return 1
    fi
}

# Function to pull Open5GS component images
pull_open5gs_images() {
    local failed_images=()
    
    log_info "Pulling Open5GS components (version: $VERSION)..."
    
    for component in "${COMPONENTS[@]}"; do
        local image="$REGISTRY/${component}:${VERSION}"
        
        if ! pull_image "$image" "$FORCE_MODE"; then
            failed_images+=("$image")
        fi
    done
    
    if [[ ${#failed_images[@]} -gt 0 ]]; then
        log_error "Failed to pull the following images:"
        printf "  %s\n" "${failed_images[@]}"
        return 1
    fi
    
    log_success "All Open5GS images pulled successfully"
    return 0
}

# Function to pull utility images
pull_utility_images() {
    if [[ "$PULL_UTILITIES" != "true" ]]; then
        log_info "Skipping utility images (--no-utilities specified)"
        return 0
    fi
    
    log_info "Pulling utility images..."
    local failed_images=()
    
    for image in "${UTILITY_IMAGES[@]}"; do
        if ! pull_image "$image" "$FORCE_MODE"; then
            failed_images+=("$image")
        fi
    done
    
    if [[ ${#failed_images[@]} -gt 0 ]]; then
        log_warning "Failed to pull some utility images:"
        printf "  %s\n" "${failed_images[@]}"
    else
        log_success "All utility images pulled successfully"
    fi
}

# Function to show pulled images
show_pulled_images() {
    log_info "Listing pulled Open5GS images:"
    echo "----------------------------------------"
    
    # Show Open5GS images
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | \
        head -1
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | \
        grep -E "(${REGISTRY//\//\\/}|tcpdump)" || echo "No matching images found"
    
    echo "----------------------------------------"
}

# Function to get image statistics
show_image_stats() {
    local total_images=0
    local total_size=0
    
    log_info "Image statistics:"
    
    # Count Open5GS images
    for component in "${COMPONENTS[@]}"; do
        local image="$REGISTRY/${component}:${VERSION}"
        if image_exists "$image"; then
            ((total_images++))
        fi
    done
    
    # Count utility images
    if [[ "$PULL_UTILITIES" == "true" ]]; then
        for image in "${UTILITY_IMAGES[@]}"; do
            if image_exists "$image"; then
                ((total_images++))
            fi
        done
    fi
    
    log_info "  Total images pulled: $total_images"
    
    # Calculate total size (rough estimate)
    local size_info
    size_info=$(docker images --format "{{.Size}}" | grep -E "[0-9]+(MB|GB)" | head -"$total_images" | \
        awk '{
            if ($1 ~ /GB/) {
                gsub(/GB/, "", $1)
                total += $1 * 1024
            } else if ($1 ~ /MB/) {
                gsub(/MB/, "", $1)  
                total += $1
            }
        }
        END { 
            if (total > 1024) 
                printf "%.2f GB\n", total/1024
            else 
                printf "%.0f MB\n", total
        }')
    
    if [[ -n "$size_info" ]]; then
        log_info "  Estimated total size: $size_info"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            --no-utilities)
                PULL_UTILITIES=false
                shift
                ;;
            --parallel)
                PARALLEL_PULLS=true
                log_warning "Parallel pulls is experimental"
                shift
                ;;
            *)
                # Handle positional arguments and common args
                if [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    VERSION="$1"
                    shift
                elif [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    VERSION="v$1"
                    shift
                else
                    # Let common args parser handle the rest
                    local remaining_args
                    remaining_args=$(parse_common_args "$@")
                    if [[ -n "$remaining_args" ]]; then
                        log_error "Unknown argument: $1"
                        show_usage
                        exit 1
                    fi
                    break
                fi
                ;;
        esac
    done
}

# Validate configuration
validate_config() {
    # Validate registry format
    if [[ ! "$REGISTRY" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
        die "Invalid registry format: $REGISTRY"
    fi
    
    # Validate version format
    if [[ ! "$VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        die "Invalid version format: $VERSION (expected: vX.Y.Z or X.Y.Z)"
    fi
    
    # Ensure version starts with 'v'
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
}

# Main execution
main() {
    # Initialize common utilities
    init_common
    
    # Check Docker availability
    check_docker
    
    # Parse arguments
    parse_args "$@"
    
    # Validate configuration
    validate_config
    
    # Show configuration
    log_info "Docker Pull Configuration:"
    log_info "  Registry: $REGISTRY"
    log_info "  Version: $VERSION"
    log_info "  Components: ${#COMPONENTS[@]}"
    log_info "  Include utilities: $PULL_UTILITIES"
    
    # Confirm action unless force mode
    if ! confirm_action "Proceed with pulling Docker images?"; then
        log_info "Operation cancelled"
        exit 0
    fi
    
    # Pull Open5GS images
    if ! pull_open5gs_images; then
        die "Failed to pull some Open5GS images"
    fi
    
    # Pull utility images
    pull_utility_images
    
    # Show results
    show_pulled_images
    show_image_stats
    
    log_success "Docker image pull operation completed"
    log_info "Use 'docker images' to verify all images"
}

# Run main function
main "$@" 