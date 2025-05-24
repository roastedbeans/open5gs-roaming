#!/bin/bash

# CoreDNS Rewrite Configuration Script for Open5GS
# Adds 3GPP network name rewrite rules to CoreDNS

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Helper functions
error() { echo -e "${RED}Error: $@${NC}" >&2; }
info() { echo -e "${BLUE}$@${NC}"; }
success() { echo -e "${GREEN}$@${NC}"; }
warning() { echo -e "${YELLOW}$@${NC}"; }

# Default values
HPLMN_MNC="001"
HPLMN_MCC="001"
VPLMN_MNC="070"
VPLMN_MCC="999"
DRY_RUN=false
FORCE=false

show_usage() {
    cat << EOF
CoreDNS Rewrite Configuration Script
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
  --test              Test DNS resolution
  --remove            Remove existing rewrite rules
  --help, -h          Show this help message

Examples:
  $0                                    # Add default rewrite rules
  $0 --hplmn-mnc 001 --hplmn-mcc 001   # Custom codes
  $0 --dry-run                         # Preview changes
  $0 --backup-only                     # Just backup
  $0 --remove                          # Remove rules
  $0 --test                            # Test DNS
EOF
}

check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v microk8s >/dev/null 2>&1; then
        error "microk8s is not installed"
        return 1
    fi
    
    if ! microk8s kubectl get nodes >/dev/null 2>&1; then
        error "Cannot access Kubernetes cluster"
        return 1
    fi
    
    if ! microk8s kubectl get configmap coredns -n kube-system >/dev/null 2>&1; then
        error "CoreDNS configmap not found"
        return 1
    fi
    
    success "Prerequisites check passed"
}

backup_coredns() {
    local backup_file="/tmp/coredns-backup-$(date +%Y%m%d-%H%M%S).yaml"
    info "Creating backup: $backup_file"
    
    if microk8s kubectl get configmap coredns -n kube-system -o yaml > "$backup_file"; then
        success "Backup created: $backup_file"
        echo "$backup_file"
    else
        error "Failed to create backup"
        return 1
    fi
}

show_current_config() {
    info "Current CoreDNS configuration:"
    echo "================================"
    microk8s kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}'
    echo ""
    echo "================================"
}

generate_rewrite_rules() {
    local hplmn_mnc=$1
    local hplmn_mcc=$2
    local vplmn_mnc=$3
    local vplmn_mcc=$4
    
    cat << EOF

    # Open5GS 3GPP DNS Rewrite Rules
    # HPLMN (MNC: $hplmn_mnc, MCC: $hplmn_mcc)
    rewrite name nrf.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org nrf.hplmn.svc.cluster.local
    rewrite name scp.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org scp.hplmn.svc.cluster.local
    rewrite name udr.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org udr.hplmn.svc.cluster.local
    rewrite name udm.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org udm.hplmn.svc.cluster.local
    rewrite name ausf.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org ausf.hplmn.svc.cluster.local
    rewrite name sepp.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org sepp.hplmn.svc.cluster.local
    rewrite name sepp1.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org sepp-n32c.hplmn.svc.cluster.local
    rewrite name sepp2.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org sepp-n32f.hplmn.svc.cluster.local
    
    # VPLMN (MNC: $vplmn_mnc, MCC: $vplmn_mcc)
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
    current_config=$(microk8s kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}')
    
    # Remove any existing Open5GS rules
    # First remove the entire block if it exists
    current_config=$(echo "$current_config" | sed '/# Open5GS 3GPP DNS Rewrite Rules/,/sepp-n32f\.[vh]plmn\.svc\.cluster\.local/d')
    
    # Then remove any individual rewrite rules that might have been added separately
    current_config=$(echo "$current_config" | sed '/rewrite name.*3gppnetwork\.org/d')
    
    # Remove any empty lines that might have been left behind
    current_config=$(echo "$current_config" | sed '/^[[:space:]]*$/d')
    
    # Generate new rewrite rules
    local rewrite_rules
    rewrite_rules=$(generate_rewrite_rules "$hplmn_mnc" "$hplmn_mcc" "$vplmn_mnc" "$vplmn_mcc")
    
    # Insert rules after the "ready" line
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
    
    # Create a properly formatted YAML patch
    local temp_file
    temp_file=$(mktemp)
    
    # Escape the config for JSON
    local escaped_config
    escaped_config=$(echo "$updated_config" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    cat > "$temp_file" << EOF
{
  "data": {
    "Corefile": "$escaped_config"
  }
}
EOF
    
    # Apply the patch
    if microk8s kubectl patch configmap coredns -n kube-system --type merge --patch-file "$temp_file"; then
        rm -f "$temp_file"
        success "CoreDNS configuration updated"
        
        # Restart CoreDNS
        info "Restarting CoreDNS..."
        microk8s kubectl rollout restart deployment/coredns -n kube-system
        microk8s kubectl rollout status deployment/coredns -n kube-system --timeout=60s
        
        success "CoreDNS restarted successfully"
    else
        rm -f "$temp_file"
        error "Failed to update CoreDNS configuration"
        return 1
    fi
}

remove_rewrite_rules() {
    info "Removing Open5GS rewrite rules..."
    
    local current_config
    current_config=$(microk8s kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}')
    
    # Check if rules exist
    if ! echo "$current_config" | grep -q "# Open5GS 3GPP DNS Rewrite Rules\|rewrite name.*3gppnetwork\.org"; then
        warning "No Open5GS rewrite rules found"
        return 0
    fi
    
    # Remove rules
    local updated_config
    updated_config=$(echo "$current_config" | sed '/# Open5GS 3GPP DNS Rewrite Rules/,/sepp-n32f\.vplmn\.svc\.cluster\.local/d')
    updated_config=$(echo "$updated_config" | sed '/rewrite name.*3gppnetwork\.org/d')
    
    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN - Would remove rewrite rules"
        return 0
    fi
    
    # Apply the change
    local temp_file
    temp_file=$(mktemp)
    
    local escaped_config
    escaped_config=$(echo "$updated_config" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    cat > "$temp_file" << EOF
{
  "data": {
    "Corefile": "$escaped_config"
  }
}
EOF
    
    if microk8s kubectl patch configmap coredns -n kube-system --type merge --patch-file "$temp_file"; then
        rm -f "$temp_file"
        success "Rewrite rules removed"
        
        info "Restarting CoreDNS..."
        microk8s kubectl rollout restart deployment/coredns -n kube-system
        microk8s kubectl rollout status deployment/coredns -n kube-system --timeout=60s
        
        success "CoreDNS restarted"
    else
        rm -f "$temp_file"
        error "Failed to remove rewrite rules"
        return 1
    fi
}

test_dns_resolution() {
    local hplmn_mnc=${1:-$HPLMN_MNC}
    local hplmn_mcc=${2:-$HPLMN_MCC}
    local vplmn_mnc=${3:-$VPLMN_MNC}
    local vplmn_mcc=${4:-$VPLMN_MCC}
    
    info "Testing DNS resolution..."
    
    local services=(
        "nrf.5gc.mnc$hplmn_mnc.mcc$hplmn_mcc.3gppnetwork.org"
        "nrf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org"
        "amf.5gc.mnc$vplmn_mnc.mcc$vplmn_mcc.3gppnetwork.org"
    )
    
    for service in "${services[@]}"; do
        local pod_name="dns-test-$(date +%s)"
        if timeout 10 microk8s kubectl run "$pod_name" --image=nicolaka/netshoot --rm --restart=Never -- nslookup "$service" >/dev/null 2>&1; then
            success "✓ $service"
        else
            warning "✗ $service"
        fi
        microk8s kubectl delete pod "$pod_name" --ignore-not-found >/dev/null 2>&1 || true
    done
    
    success "DNS testing completed"
}

# Main execution
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --hplmn-mnc) HPLMN_MNC="$2"; shift 2 ;;
            --hplmn-mcc) HPLMN_MCC="$2"; shift 2 ;;
            --vplmn-mnc) VPLMN_MNC="$2"; shift 2 ;;
            --vplmn-mcc) VPLMN_MCC="$2"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --force) FORCE=true; shift ;;
            --backup-only)
                check_prerequisites
                backup_coredns
                exit 0
                ;;
            --restore)
                check_prerequisites
                if [[ ! -f "$2" ]]; then
                    error "Backup file not found: $2"
                    exit 1
                fi
                microk8s kubectl apply -f "$2"
                microk8s kubectl rollout restart deployment/coredns -n kube-system
                success "CoreDNS restored and restarted"
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
            --remove)
                check_prerequisites
                backup_coredns
                remove_rewrite_rules
                exit 0
                ;;
            --help|-h) show_usage; exit 0 ;;
            *) error "Unknown option: $1"; show_usage; exit 1 ;;
        esac
    done
    
    # Main execution flow
    info "CoreDNS Rewrite Configuration"
    info "HPLMN: MNC=$HPLMN_MNC, MCC=$HPLMN_MCC"
    info "VPLMN: MNC=$VPLMN_MNC, MCC=$VPLMN_MCC"
    
    check_prerequisites
    
    local backup_file
    backup_file=$(backup_coredns)
    
    if [[ "$FORCE" == false && "$DRY_RUN" == false ]]; then
        echo
        read -p "Proceed with updating CoreDNS? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Aborted"
            exit 0
        fi
    fi
    
    update_coredns_config "$HPLMN_MNC" "$HPLMN_MCC" "$VPLMN_MNC" "$VPLMN_MCC"
    
    if [[ "$DRY_RUN" == false ]]; then
        success "CoreDNS configured successfully!"
        info "Backup: $backup_file"
        info "Test with: $0 --test"
        info "Remove with: $0 --remove"
    fi
}

# Run main function with all arguments
main "$@" 