#!/bin/bash

# CoreDNS Rewrite Configuration Script for Open5GS
# Adds 3GPP network name rewrite rules to CoreDNS

set -e

# ===============================
# Configuration & Constants
# ===============================

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Helper functions
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

error() { print_color "$RED" "Error: $@"; }
info() { print_color "$BLUE" "$@"; }
success() { print_color "$GREEN" "$@"; }
warning() { print_color "$YELLOW" "$@"; }

# Default values
HPLMN_MNC="001"
HPLMN_MCC="001"
VPLMN_MNC="070"
VPLMN_MCC="999"
DRY_RUN=false
FORCE=false

# Global variables
BACKUP_FILE=""

# ===============================
# Functions
# ===============================

show_usage() {
    cat << EOF
$(info "CoreDNS Rewrite Configuration Script")
Usage: $0 [options]

Options:
  --hplmn-mnc MNC     HPLMN MNC code (default: $HPLMN_MNC)
  --hplmn-mcc MCC     HPLMN MCC code (default: $HPLMN_MCC)
  --vplmn-mnc MNC     VPLMN MNC code (default: $VPLMN_MNC)
  --vplmn-mcc MCC     VPLMN MCC code (default: $VPLMN_MCC)
  --dry-run           Show what would be done without applying
  --force             Skip confirmation prompts
  --backup-only       Only create backup of current config
  --restore FILE      Restore CoreDNS config from backup file
  --status            Show current CoreDNS configuration
  --test              Test DNS resolution after configuration
  --help, -h          Show this help message

Examples:
  $0                                    # Add default rewrite rules
  $0 --hplmn-mnc 001 --hplmn-mcc 001   # Custom HPLMN codes
  $0 --dry-run                         # Preview changes
  $0 --backup-only                     # Just backup current config
  $0 --restore /tmp/coredns-backup.yaml
  $0 --status                          # Show current config
  $0 --test                            # Test DNS resolution

Note: This script requires microk8s kubectl access and cluster-admin permissions.
EOF
}

check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check microk8s
    if ! command -v microk8s >/dev/null 2>&1; then
        error "microk8s is not installed or not in PATH"
        return 1
    fi
    
    # Check kubectl access
    if ! microk8s kubectl get nodes >/dev/null 2>&1; then
        error "Cannot access Kubernetes cluster"
        return 1
    fi
    
    # Check CoreDNS configmap exists
    if ! microk8s kubectl get configmap coredns -n kube-system >/dev/null 2>&1; then
        error "CoreDNS configmap not found in kube-system namespace"
        return 1
    fi
    
    success "Prerequisites check passed"
}

create_backup_file() {
    if [[ -z "$BACKUP_FILE" ]]; then
        BACKUP_FILE="/tmp/coredns-backup-$(date +%Y%m%d-%H%M%S).yaml"
    fi
}

backup_coredns_config() {
    create_backup_file
    info "Creating backup of current CoreDNS configuration..."
    
    if ! microk8s kubectl get configmap coredns -n kube-system -o yaml > "$BACKUP_FILE"; then
        error "Failed to create backup"
        return 1
    fi
    
    if [[ -f "$BACKUP_FILE" ]]; then
        success "Backup created: $BACKUP_FILE"
    else
        error "Failed to create backup file"
        return 1
    fi
}

show_current_config() {
    info "Current CoreDNS configuration:"
    echo "================================"
    if ! microk8s kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | head -20; then
        error "Failed to retrieve CoreDNS configuration"
        return 1
    fi
    echo ""
    echo "================================"
}

generate_rewrite_rules() {
    local hplmn_mnc=$1
    local hplmn_mcc=$2
    local vplmn_mnc=$3
    local vplmn_mcc=$4
    
    cat << EOF
      
      # HPLMN DNS Rewrite Rules (MNC: $hplmn_mnc, MCC: $hplmn_mcc)
      rewrite name nrf.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org nrf.hplmn.svc.cluster.local
      rewrite name scp.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org scp.hplmn.svc.cluster.local
      rewrite name udr.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org udr.hplmn.svc.cluster.local
      rewrite name udm.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org udm.hplmn.svc.cluster.local
      rewrite name ausf.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org ausf.hplmn.svc.cluster.local
      rewrite name sepp.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org sepp.hplmn.svc.cluster.local
      rewrite name sepp1.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org sepp-n32c.hplmn.svc.cluster.local
      rewrite name sepp2.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org sepp-n32f.hplmn.svc.cluster.local
      
      # VPLMN DNS Rewrite Rules (MNC: $vplmn_mnc, MCC: $vplmn_mcc)
      rewrite name nrf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org nrf.vplmn.svc.cluster.local
      rewrite name scp.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org scp.vplmn.svc.cluster.local
      rewrite name udr.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org udr.vplmn.svc.cluster.local
      rewrite name udm.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org udm.vplmn.svc.cluster.local
      rewrite name pcf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org pcf.vplmn.svc.cluster.local
      rewrite name upf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org upf.vplmn.svc.cluster.local
      rewrite name smf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org smf.vplmn.svc.cluster.local
      rewrite name amf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org amf.vplmn.svc.cluster.local
      rewrite name bsf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org bsf.vplmn.svc.cluster.local
      rewrite name nssf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org nssf.vplmn.svc.cluster.local
      rewrite name ausf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org ausf.vplmn.svc.cluster.local
      rewrite name sepp.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org sepp.vplmn.svc.cluster.local
      rewrite name sepp1.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org sepp-n32c.vplmn.svc.cluster.local
      rewrite name sepp2.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org sepp-n32f.vplmn.svc.cluster.local
EOF
}

update_coredns_config() {
    local hplmn_mnc=$1
    local hplmn_mcc=$2
    local vplmn_mnc=$3
    local vplmn_mcc=$4
    
    info "Updating CoreDNS configuration..."
    
    # Get current config
    local current_config
    if ! current_config=$(microk8s kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}'); then
        error "Failed to retrieve current CoreDNS configuration"
        return 1
    fi
    
    # Check if rewrite rules already exist
    if echo "$current_config" | grep -q "rewrite name.*3gppnetwork.org"; then
        warning "Rewrite rules already exist in CoreDNS configuration"
        if [[ "$FORCE" == false ]]; then
            read -p "Do you want to replace existing rules? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Aborted by user"
                return 0
            fi
        fi
        
        # Remove existing rewrite rules
        current_config=$(echo "$current_config" | sed '/# HPLMN DNS Rewrite Rules/,/sepp-n32f\.vplmn\.svc\.cluster\.local/d')
        current_config=$(echo "$current_config" | sed '/rewrite name.*3gppnetwork\.org/d')
    fi
    
    # Generate new rewrite rules
    local rewrite_rules
    rewrite_rules=$(generate_rewrite_rules "$hplmn_mnc" "$hplmn_mcc" "$vplmn_mnc" "$vplmn_mcc")
    
    # Create updated config by inserting rewrite rules after the "ready" line
    local updated_config
    updated_config=$(echo "$current_config" | awk -v rules="$rewrite_rules" '
        /ready/ { print; print rules; next }
        { print }
    ')
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN - Would apply the following configuration:"
        echo "=================================================="
        echo "$updated_config"
        echo "=================================================="
        return 0
    fi
    
    # Create temporary file with updated config
    local temp_file
    if ! temp_file=$(mktemp); then
        error "Failed to create temporary file"
        return 1
    fi
    
    cat > "$temp_file" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
$updated_config
EOF
    
    # Apply the updated configuration
    if microk8s kubectl apply -f "$temp_file"; then
        rm -f "$temp_file"
        success "CoreDNS configuration updated successfully"
        
        # Restart CoreDNS
        info "Restarting CoreDNS deployment..."
        if ! microk8s kubectl rollout restart deployment/coredns -n kube-system; then
            error "Failed to restart CoreDNS deployment"
            return 1
        fi
        
        # Wait for rollout to complete
        info "Waiting for CoreDNS rollout to complete..."
        if ! microk8s kubectl rollout status deployment/coredns -n kube-system --timeout=60s; then
            warning "CoreDNS rollout may not have completed successfully"
            return 1
        fi
        
        success "CoreDNS has been restarted and updated"
    else
        rm -f "$temp_file"
        error "Failed to apply CoreDNS configuration"
        return 1
    fi
}

restore_coredns_config() {
    local backup_file=$1
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi
    
    info "Restoring CoreDNS configuration from: $backup_file"
    
    if [[ "$FORCE" == false ]]; then
        read -p "Are you sure you want to restore CoreDNS configuration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Restore aborted by user"
            return 0
        fi
    fi
    
    if microk8s kubectl apply -f "$backup_file"; then
        success "CoreDNS configuration restored successfully"
        
        # Restart CoreDNS
        info "Restarting CoreDNS deployment..."
        if ! microk8s kubectl rollout restart deployment/coredns -n kube-system; then
            error "Failed to restart CoreDNS deployment"
            return 1
        fi
        
        if ! microk8s kubectl rollout status deployment/coredns -n kube-system --timeout=60s; then
            warning "CoreDNS rollout may not have completed successfully"
            return 1
        fi
        
        success "CoreDNS has been restarted"
    else
        error "Failed to restore CoreDNS configuration"
        return 1
    fi
}

test_dns_resolution() {
    local hplmn_mnc=${1:-$HPLMN_MNC}
    local hplmn_mcc=${2:-$HPLMN_MCC}
    local vplmn_mnc=${3:-$VPLMN_MNC}
    local vplmn_mcc=${4:-$VPLMN_MCC}
    
    info "Testing DNS resolution..."
    
    # Test HPLMN services
    local hplmn_services=(
        "nrf.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org"
        "scp.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org"
        "udr.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org"
    )
    
    # Test VPLMN services
    local vplmn_services=(
        "nrf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org"
        "amf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org"
        "smf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org"
    )
    
    local test_failed=false
    
    info "Testing HPLMN services..."
    for service in "${hplmn_services[@]}"; do
        local test_pod="dns-test-$(date +%s)-$RANDOM"
        if microk8s kubectl run "$test_pod" --image=nicolaka/netshoot --rm -it --restart=Never -- nslookup "$service" >/dev/null 2>&1; then
            success "✓ $service"
        else
            warning "✗ $service"
            test_failed=true
        fi
        # Cleanup any remaining pods
        microk8s kubectl delete pod "$test_pod" --ignore-not-found >/dev/null 2>&1 || true
    done
    
    info "Testing VPLMN services..."
    for service in "${vplmn_services[@]}"; do
        local test_pod="dns-test-$(date +%s)-$RANDOM"
        if microk8s kubectl run "$test_pod" --image=nicolaka/netshoot --rm -it --restart=Never -- nslookup "$service" >/dev/null 2>&1; then
            success "✓ $service"
        else
            warning "✗ $service"
            test_failed=true
        fi
        # Cleanup any remaining pods
        microk8s kubectl delete pod "$test_pod" --ignore-not-found >/dev/null 2>&1 || true
    done
    
    if [[ "$test_failed" == false ]]; then
        success "DNS resolution testing completed successfully"
    else
        warning "DNS resolution testing completed with some failures"
        info "Note: Failures may be expected if services are not yet deployed"
    fi
}

# ===============================
# Main
# ===============================

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hplmn-mnc)
            if [[ -z "$2" ]]; then
                error "Missing value for --hplmn-mnc"
                exit 1
            fi
            HPLMN_MNC="$2"
            shift 2
            ;;
        --hplmn-mcc)
            if [[ -z "$2" ]]; then
                error "Missing value for --hplmn-mcc"
                exit 1
            fi
            HPLMN_MCC="$2"
            shift 2
            ;;
        --vplmn-mnc)
            if [[ -z "$2" ]]; then
                error "Missing value for --vplmn-mnc"
                exit 1
            fi
            VPLMN_MNC="$2"
            shift 2
            ;;
        --vplmn-mcc)
            if [[ -z "$2" ]]; then
                error "Missing value for --vplmn-mcc"
                exit 1
            fi
            VPLMN_MCC="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --backup-only)
            check_prerequisites
            backup_coredns_config
            exit 0
            ;;
        --restore)
            if [[ -z "$2" ]]; then
                error "Missing backup file for --restore"
                exit 1
            fi
            RESTORE_FILE="$2"
            shift 2
            check_prerequisites
            restore_coredns_config "$RESTORE_FILE"
            exit 0
            ;;
        --status)
            check_prerequisites
            show_current_config
            exit 0
            ;;
        --test)
            check_prerequisites
            test_dns_resolution "$HPLMN_MNC" "$HPLMN_MCC" "$VPLMN_MNC" "$VPLMN_MCC"
            exit 0
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
info "CoreDNS Rewrite Configuration Script"
info "HPLMN: MNC=$HPLMN_MNC, MCC=$HPLMN_MCC"
info "VPLMN: MNC=$VPLMN_MNC, MCC=$VPLMN_MCC"

# Check prerequisites
check_prerequisites

# Create backup (even for dry run)
backup_coredns_config

# Show current configuration 
show_current_config

# Confirm action
if [[ "$FORCE" == false && "$DRY_RUN" == false ]]; then
    echo
    read -p "Do you want to proceed with updating CoreDNS configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Aborted by user"
        exit 0
    fi
fi

# Update configuration
update_coredns_config "$HPLMN_MNC" "$HPLMN_MCC" "$VPLMN_MNC" "$VPLMN_MCC"

if [[ "$DRY_RUN" == false ]]; then
    success "CoreDNS rewrite rules have been configured successfully!"
    info "Backup saved to: $BACKUP_FILE"
    echo
    info "You can now test DNS resolution with:"
    info "  $0 --test"
    echo
    info "If you need to restore the previous configuration:"
    info "  $0 --restore $BACKUP_FILE"
fi 