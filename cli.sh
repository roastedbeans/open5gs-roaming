#!/bin/bash

# Open5GS Scripts CLI - Organized Version
# A unified interface for Open5GS deployment and management

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

# Paths
readonly SCRIPTS_DIR="./scripts"
readonly VERSION="2.0.0"
readonly DEFAULT_TAG="v2.7.5"

# Script mappings
declare -A SCRIPTS=(
    # Installation & Setup
    ["install-dep"]="install-dep.sh"
    ["setup-roaming"]="setup-k8s-roaming.sh"
    
    # Deployment
    ["kubectl-deploy-hplmn"]="kubectl-deploy-hplmn.sh"
    ["kubectl-deploy-vplmn"]="kubectl-deploy-vplmn.sh"
    ["docker-deploy"]="docker-deploy.sh"
    
    # Image management
    ["pull-images"]="pull-docker-images.sh"
    ["import"]="import.sh"
    ["update"]="update.sh"
    
    # Certificate management
    ["cert-deploy"]="cert-deploy.sh"
    ["cert-generate"]="cert/generate-sepp-certs.sh"
    
    # DNS configuration
    ["coredns-rewrite"]="coredns-rewrite.sh"
    
    # Database management
    ["mongodb-hplmn"]="mongodb-hplmn.sh"
    ["mongodb44-setup"]="mongodb44-setup.sh"
    ["mongodb-access"]="mongodb-access.sh"
    ["subscribers"]="subscribers.sh"
    
    # Management & Monitoring
    ["restart-pods"]="restart-pods.sh"
    ["get-status"]="get-status.sh"
    
    # WebUI
    ["deploy-webui"]="kubectl-deploy-webui.sh"
    ["deploy-networkui"]="kubectl-deploy-networkui.sh"
    
    # Cleanup
    ["microk8s-clean"]="microk8s-clean.sh"
    ["docker-clean"]="docker-clean.sh"
)

# Command categories for help display
declare -A COMMAND_CATEGORIES=(
    ["Installation & Setup"]="install-dep setup-roaming"
    ["Deployment"]="deploy-hplmn deploy-vplmn deploy-roaming docker-deploy"
    ["Image Management"]="pull-images import-images update-configs"
    ["Certificate Management"]="generate-certs deploy-certs"
    ["DNS Configuration"]="coredns-rewrite"
    ["Database Management"]="mongodb-hplmn mongodb-install mongodb-access subscribers"
    ["Management & Monitoring"]="restart-pods get-status"
    ["Cleanup"]="clean-k8s clean-docker"
)

# ===============================
# Helper Functions
# ===============================

print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

error() { print_color "$RED" "Error: $@"; }
info() { print_color "$BLUE" "$@"; }
success() { print_color "$GREEN" "$@"; }
warning() { print_color "$YELLOW" "$@"; }

check_script() {
    local script_name=$1
    local script_path="${SCRIPTS_DIR}/${SCRIPTS[$script_name]}"
    
    if [[ ! -f "$script_path" ]]; then
        error "$script_name script not found at $script_path"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        warning "Making $script_name executable..."
        chmod +x "$script_path" || {
            error "Cannot make $script_name executable"
            return 1
        }
    fi
    echo "$script_path"
}

run_script() {
    local script_name=$1
    shift
    local script_path=$(check_script "$script_name") || return 1
    info "Running: $script_name"
    bash "$script_path" "$@"
}

# ===============================
# Command Functions
# ===============================

# Installation & Setup
cmd_install_dep() { run_script "install-dep" "$@"; }

cmd_setup_roaming() {
    local tag="$DEFAULT_TAG"
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tag) tag="$2"; shift 2 ;;
            *) args+=("$1"); shift ;;
        esac
    done
    
    run_script "setup-roaming" "$tag" "${args[@]}"
}

# Deployment Commands
cmd_deploy_hplmn() {
    local namespace="hplmn"
    local with_mongodb=true
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace) namespace="$2"; shift 2 ;;
            -m|--no-mongodb) with_mongodb=false; shift ;;
            *) args+=("$1"); shift ;;
        esac
    done
    
    if [[ "$with_mongodb" == true ]]; then
        info "Deploying MongoDB for HPLMN..."
        run_script "mongodb-hplmn" -n "$namespace" -f || warning "MongoDB deployment failed, continuing..."
        microk8s kubectl wait --for=condition=ready pods -l app=mongodb \
            --namespace="$namespace" --timeout=120s || warning "MongoDB not ready, continuing..."
    fi
    
    info "Deploying HPLMN components..."
    run_script "kubectl-deploy-hplmn" "${args[@]}"
}

cmd_deploy_vplmn() { run_script "kubectl-deploy-vplmn" "$@"; }

cmd_deploy_roaming() {
    local tag="$DEFAULT_TAG"
    local with_mongodb=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tag) tag="$2"; shift 2 ;;
            -m|--no-mongodb) with_mongodb=false; shift ;;
            *) shift ;;
        esac
    done
    
    info "Deploying complete roaming setup..."
    
    # First, configure CoreDNS rewrite rules
    info "Configuring CoreDNS rewrite rules..."
    cmd_coredns_rewrite || {
        error "Failed to configure CoreDNS rewrite rules"
        return 1
    }
    
    # Deploy certificates
    info "Deploying certificates..."
    cmd_deploy_certs || {
        error "Failed to deploy certificates"
        return 1
    }
    
    # Deploy HPLMN
    if [[ "$with_mongodb" == true ]]; then
        info "Deploying HPLMN with MongoDB..."
        cmd_deploy_hplmn -t "$tag"
        
        # Wait for MongoDB to be ready
        info "Waiting for MongoDB to be ready..."
        microk8s kubectl wait --for=condition=ready pods -l app=mongodb \
            --namespace="hplmn" --timeout=180s || {
            error "MongoDB failed to become ready"
            return 1
        }
    else
        info "Deploying HPLMN without MongoDB..."
        cmd_deploy_hplmn -t "$tag" -m
    fi
    
    # Wait for HPLMN NRF to be ready
    info "Waiting for HPLMN NRF to be ready..."
    microk8s kubectl wait --for=condition=ready pods -l app=nrf \
        --namespace="hplmn" --timeout=120s || {
        error "HPLMN NRF failed to become ready"
        return 1
    }
    
    # Wait for HPLMN core services to be ready
    info "Waiting for HPLMN core services to be ready..."
    for service in udr udm ausf; do
        microk8s kubectl wait --for=condition=ready pods -l app=$service \
            --namespace="hplmn" --timeout=120s || {
            error "HPLMN $service failed to become ready"
            return 1
        }
    done
    
    # Deploy VPLMN
    info "Deploying VPLMN..."
    cmd_deploy_vplmn -t "$tag"
    
    # Wait for VPLMN NRF to be ready
    info "Waiting for VPLMN NRF to be ready..."
    microk8s kubectl wait --for=condition=ready pods -l app=nrf \
        --namespace="vplmn" --timeout=120s || {
        error "VPLMN NRF failed to become ready"
        return 1
    }
    
    # Wait for VPLMN core services to be ready
    info "Waiting for VPLMN core services to be ready..."
    for service in udr udm ausf; do
        microk8s kubectl wait --for=condition=ready pods -l app=$service \
            --namespace="vplmn" --timeout=120s || {
            error "VPLMN $service failed to become ready"
            return 1
        }
    done
    
    success "Completed roaming deployment"
}

cmd_docker_deploy() {
    local username=""
    local tag="$DEFAULT_TAG"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--username) username="$2"; shift 2 ;;
            -t|--tag) tag="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$username" ]]; then
        read -p "Enter Docker Hub username: " username
        [[ -z "$username" ]] && { error "Username required"; return 1; }
    fi
    
    local script_path=$(check_script "docker-deploy") || return 1
    local temp_file=$(mktemp)
    cp "$script_path" "$temp_file"
    sed -i "s/DOCKERHUB_USERNAME=\"your_username\"/DOCKERHUB_USERNAME=\"$username\"/" "$temp_file"
    bash "$temp_file"
    rm "$temp_file"
}

# Image Management
cmd_pull_images() {
    local tag="$DEFAULT_TAG"
    [[ "$1" == "-t" || "$1" == "--tag" ]] && tag="$2"
    run_script "pull-images" "$tag"
}

cmd_import_images() { run_script "import" "$@"; }
cmd_update_configs() { run_script "update" "$@"; }

# Certificate Management
cmd_generate_certs() {
    local cert_script="${SCRIPTS_DIR}/${SCRIPTS[cert-generate]}"
    if [[ -f "$cert_script" ]]; then
        chmod +x "$cert_script"
        bash "$cert_script" "$@"
    else
        error "Certificate generation script not found"
        return 1
    fi
}

cmd_deploy_certs() { run_script "cert-deploy" "$@"; }

# DNS Configuration
cmd_coredns_rewrite() { run_script "coredns-rewrite" "$@"; }

# Database Management
cmd_mongodb_hplmn() { run_script "mongodb-hplmn" "$@"; }
cmd_mongodb_install() { run_script "mongodb44-setup" "$@"; }
cmd_mongodb_access() { run_script "mongodb-access" "$@"; }
cmd_subscribers() { run_script "subscribers" "$@"; }

# Management & Monitoring
cmd_restart_pods() { run_script "restart-pods" "$@"; }
cmd_get_status() { run_script "get-status" "$@"; }

# WebUI
cmd_deploy_webui() { run_script "deploy-webui" "$@"; }
cmd_deploy_networkui() { run_script "deploy-networkui" "$@"; }

# Cleanup
cmd_clean_k8s() { run_script "microk8s-clean" "$@"; }
cmd_clean_docker() { run_script "docker-clean" "$@"; }

# ===============================
# Help System
# ===============================

show_usage() {
    cat << EOF
$(info "Open5GS Scripts CLI v$VERSION")
Usage: $0 [command] [options]

$(warning "📦 Installation & Setup:")
  install-dep         Install dependencies (Docker, Git, GTP5G)
  setup-roaming       Complete automated k8s-roaming setup

$(warning "🚀 Deployment:")
  deploy-hplmn        Deploy HPLMN components [-m]
  deploy-vplmn        Deploy VPLMN components
  deploy-roaming      Deploy both HPLMN and VPLMN
  docker-deploy       Publish images to Docker Hub

$(warning "📦 Image Management:")
  pull-images         Pull Open5GS images [-t VERSION]
  import-images       Import to MicroK8s registry
  update-configs      Update deployment configs

$(warning "🔐 Certificates:")
  generate-certs      Generate TLS certificates
  deploy-certs        Deploy certificates as K8s secrets

$(warning "🌐 DNS Configuration:")
  coredns-rewrite     Configure CoreDNS rewrite rules for 3GPP names

$(warning "🗄️ Database:")
  mongodb-hplmn       Deploy MongoDB for HPLMN
  mongodb-install     Install MongoDB 4.4 locally
  mongodb-access      Manage MongoDB external access
  subscribers         Manage subscriber database

$(warning "🔧 Management & Monitoring:")
  restart-pods        Restart pods in Open5GS namespaces
  get-status          Show status of Open5GS deployments

$(warning "🌐 WebUI:")
  deploy-webui        Deploy Open5GS WebUI (HPLMN only)
  deploy-networkui     Deploy Open5GS NetworkUI

$(warning "🧹 Cleanup:")
  clean-k8s           Clean Kubernetes resources
  clean-docker        Clean Docker resources

$(warning "Common Options:")
  -n, --namespace     Kubernetes namespace
  -t, --tag          Image tag (default: $DEFAULT_TAG)
  -f, --force        Skip confirmations
  -h, --help         Show detailed help

$(warning "Examples:")
  $0 setup-roaming -f
  $0 deploy-roaming -t v2.7.6
  $0 mongodb-access -s
  $0 subscribers -a -s 001011234567891 -e 001011234567900
  copy sepp.pcap | kubectl cp <pod-name>:/pcap/sepp.pcap ./pcap-logs/sepp.pcap -c sniffer -n vplmn
  remove sepp.pcap | kubectl delete -f ./pcap-logs/sepp.pcap

For detailed command help: $0 [command] -h
EOF
}

show_detailed_help() {
    local cmd=$1
    case $cmd in
        mongodb-access)
            cat << EOF
$(info "mongodb-access - MongoDB External Access Management")

Operations:
  -s, --setup              Create NodePort service
  -r, --remove             Remove NodePort service  
  -S, --status             Show connection details
  -p, --port-forward       Start kubectl port forwarding
  -T, --test               Test MongoDB connectivity

Options:
  -P, --node-port PORT     Custom NodePort (default: 30017)

Examples:
  $0 mongodb-access -s
  $0 mongodb-access -S
  $0 mongodb-access -s -P 31017
EOF
            ;;
        subscribers)
            cat << EOF
$(info "subscribers - Subscriber Database Management")

Operations:
  -a, --add-single         Add single subscriber
  -r, --add-range          Add subscriber range
  -l, --list              List all subscribers
  -c, --count             Count subscribers
  -d, --delete-all        Delete all subscribers

Examples:
  $0 subscribers -a -i 001011234567891
  $0 subscribers -r -s 001011234567891 -e 001011234567900
  $0 subscribers -l
EOF
            ;;
        restart-pods)
            cat << EOF
$(info "restart-pods - Restart Kubernetes Pods")

Operations:
  -a, --all               Restart pods in all Open5GS namespaces
  -H, --hplmn             Restart pods in HPLMN namespace only
  -V, --vplmn             Restart pods in VPLMN namespace only
  -n, --namespace NS      Restart pods in specific namespace
  -f, --force             Skip confirmation prompt
  -t, --timeout SEC      Wait timeout for pods (default: 300s)

Examples:
  $0 restart-pods -a
  $0 restart-pods -H
  $0 restart-pods -n custom-ns -f
EOF
            ;;
        get-status)
            cat << EOF
$(info "get-status - Show Open5GS Status")

Operations:
  -n, --namespace NS      Show status for specific namespace
  -d, --details          Show detailed information (services, deployments)

Examples:
  $0 get-status
  $0 get-status -d
  $0 get-status -n hplmn
EOF
            ;;
        deploy-webui)
            cat << EOF
$(info "deploy-webui - Deploy Open5GS WebUI")

Operations:
  -n, --namespace NS      Deploy to specific namespace (default: hplmn)
  -f, --force             Skip confirmation prompt

Examples:
  $0 deploy-webui
  $0 deploy-webui -f
  $0 deploy-webui -n hplmn

Note: WebUI is only available for HPLMN namespace and connects to HPLMN MongoDB
Access: http://NODE_IP:30999 (default credentials: admin / 1423)
EOF
            ;;
        deploy-networkui)
            cat << EOF
$(info "deploy-networkui - Deploy Open5GS NetworkUI")

Operations:
  -n, --namespace NS      Deploy to specific namespace (default: hplmn)
  -f, --force             Skip confirmation prompt

Examples:
  $0 deploy-networkui
  $0 deploy-networkui -f
  $0 deploy-networkui -n hplmn

Note: NetworkUI is only available for HPLMN namespace and connects to HPLMN MongoDB
Access: http://NODE_IP:30998 (default credentials: admin / 1423)
EOF
            ;;
        coredns-rewrite)
            cat << EOF
$(info "coredns-rewrite - Configure CoreDNS Rewrite Rules")

Operations:
  -H, --hplmn-mnc MNC     HPLMN MNC code (default: 001)
  -M, --hplmn-mcc MCC     HPLMN MCC code (default: 001)  
  -v, --vplmn-mnc MNC     VPLMN MNC code (default: 070)
  -m, --vplmn-mcc MCC     VPLMN MCC code (default: 999)
  -d, --dry-run           Preview changes without applying
  -f, --force             Skip confirmation prompts
  -b, --backup-only       Create backup without changes
  -r, --restore FILE      Restore from backup file
  -s, --status            Show current CoreDNS config
  -t, --test              Test DNS resolution

Examples:
  $0 coredns-rewrite                  # Add default rules
  $0 coredns-rewrite -d              # Preview changes
  $0 coredns-rewrite -H 001 -M 001
  $0 coredns-rewrite -b              # Backup only
  $0 coredns-rewrite -t              # Test DNS resolution

Note: Configures 3GPP FQDN to Kubernetes service name mappings in CoreDNS
EOF
            ;;
        *)
            warning "No detailed help available for: $cmd"
            ;;
    esac
}

# ===============================
# Main
# ===============================

# Initialize
[[ ! -d "$SCRIPTS_DIR" ]] && { error "Scripts directory not found"; exit 1; }
find "$SCRIPTS_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Parse command
[[ $# -eq 0 ]] && { show_usage; exit 0; }

command=$1
shift

# Handle help requests
if [[ "$command" == "-h" || "$command" == "--help" || "$command" == "help" ]]; then
    if [[ -n "$1" ]]; then
        show_detailed_help "$1"
    else
        show_usage
    fi
    exit 0
fi

# Execute command
case $command in
    # Installation & Setup
    install-dep) cmd_install_dep "$@" ;;
    setup-roaming) cmd_setup_roaming "$@" ;;
    
    # Deployment
    deploy-hplmn) cmd_deploy_hplmn "$@" ;;
    deploy-vplmn) cmd_deploy_vplmn "$@" ;;
    deploy-roaming) cmd_deploy_roaming "$@" ;;
    docker-deploy) cmd_docker_deploy "$@" ;;
    
    # Image Management
    pull-images) cmd_pull_images "$@" ;;
    import-images) cmd_import_images "$@" ;;
    update-configs) cmd_update_configs "$@" ;;
    
    # Certificates
    generate-certs) cmd_generate_certs "$@" ;;
    deploy-certs) cmd_deploy_certs "$@" ;;
    
    # DNS Configuration
    coredns-rewrite) cmd_coredns_rewrite "$@" ;;
    
    # Database
    mongodb-hplmn) cmd_mongodb_hplmn "$@" ;;
    mongodb-install) cmd_mongodb_install "$@" ;;
    mongodb-access) cmd_mongodb_access "$@" ;;
    subscribers) cmd_subscribers "$@" ;;
    
    # Management & Monitoring
    restart-pods) cmd_restart_pods "$@" ;;
    get-status) cmd_get_status "$@" ;;
    
    # WebUI
    deploy-webui) cmd_deploy_webui "$@" ;;
    deploy-networkui) cmd_deploy_networkui "$@" ;;
    
    # Cleanup
    clean-k8s) cmd_clean_k8s "$@" ;;
    clean-docker) cmd_clean_docker "$@" ;;
    
    # Info
    version) success "Open5GS Scripts CLI v$VERSION (Default tag: $DEFAULT_TAG)" ;;
    
    # Unknown
    *)
        error "Unknown command: $command"
        show_usage
        exit 1
        ;;
esac