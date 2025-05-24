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
    
    # Database management
    ["mongodb-hplmn"]="mongodb-hplmn.sh"
    ["mongodb44-setup"]="mongodb44-setup.sh"
    ["mongodb-access"]="mongodb-access.sh"
    ["subscribers"]="subscribers.sh"
    
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
    ["Database Management"]="mongodb-hplmn mongodb-install mongodb-access subscribers"
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
            --tag|-t) tag="$2"; shift 2 ;;
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
            --namespace|-n) namespace="$2"; shift 2 ;;
            --no-mongodb) with_mongodb=false; shift ;;
            *) args+=("$1"); shift ;;
        esac
    done
    
    if [[ "$with_mongodb" == true ]]; then
        info "Deploying MongoDB for HPLMN..."
        run_script "mongodb-hplmn" --namespace "$namespace" --force || warning "MongoDB deployment failed, continuing..."
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
            --tag|-t) tag="$2"; shift 2 ;;
            --no-mongodb) with_mongodb=false; shift ;;
            *) shift ;;
        esac
    done
    
    info "Deploying complete roaming setup..."
    
    # Deploy HPLMN
    if [[ "$with_mongodb" == true ]]; then
        cmd_deploy_hplmn --tag "$tag"
    else
        cmd_deploy_hplmn --tag "$tag" --no-mongodb
    fi
    
    sleep 10
    
    # Deploy VPLMN
    cmd_deploy_vplmn --tag "$tag"
    
    success "Completed roaming deployment"
}

cmd_docker_deploy() {
    local username=""
    local tag="$DEFAULT_TAG"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --username|-u) username="$2"; shift 2 ;;
            --tag|-t) tag="$2"; shift 2 ;;
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
    [[ "$1" == "--tag" || "$1" == "-t" ]] && tag="$2"
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

# Database Management
cmd_mongodb_hplmn() { run_script "mongodb-hplmn" "$@"; }
cmd_mongodb_install() { run_script "mongodb44-setup" "$@"; }
cmd_mongodb_access() { run_script "mongodb-access" "$@"; }
cmd_subscribers() { run_script "subscribers" "$@"; }

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
  deploy-hplmn        Deploy HPLMN components [--no-mongodb]
  deploy-vplmn        Deploy VPLMN components
  deploy-roaming      Deploy both HPLMN and VPLMN
  docker-deploy       Publish images to Docker Hub

$(warning "📦 Image Management:")
  pull-images         Pull Open5GS images [--tag VERSION]
  import-images       Import to MicroK8s registry
  update-configs      Update deployment configs

$(warning "🔐 Certificates:")
  generate-certs      Generate TLS certificates
  deploy-certs        Deploy certificates as K8s secrets

$(warning "🗄️ Database:")
  mongodb-hplmn       Deploy MongoDB for HPLMN
  mongodb-install     Install MongoDB 4.4 locally
  mongodb-access      Manage MongoDB external access
  subscribers         Manage subscriber database

$(warning "🧹 Cleanup:")
  clean-k8s           Clean Kubernetes resources
  clean-docker        Clean Docker resources

$(warning "Common Options:")
  --namespace, -n     Kubernetes namespace
  --tag, -t          Image tag (default: $DEFAULT_TAG)
  --force, -f        Skip confirmations
  --help, -h         Show detailed help

$(warning "Examples:")
  $0 setup-roaming --full-setup
  $0 deploy-roaming --tag v2.7.6
  $0 mongodb-access --setup
  $0 subscribers --add-range --start-imsi 001011234567891 --end-imsi 001011234567900

For detailed command help: $0 [command] --help
EOF
}

show_detailed_help() {
    local cmd=$1
    case $cmd in
        mongodb-access)
            cat << EOF
$(info "mongodb-access - MongoDB External Access Management")

Operations:
  --setup              Create NodePort service
  --remove             Remove NodePort service  
  --status             Show connection details
  --port-forward       Start kubectl port forwarding
  --test               Test MongoDB connectivity

Options:
  --node-port PORT     Custom NodePort (default: 30017)

Examples:
  $0 mongodb-access --setup
  $0 mongodb-access --status
  $0 mongodb-access --setup --node-port 31017
EOF
            ;;
        subscribers)
            cat << EOF
$(info "subscribers - Subscriber Database Management")

Operations:
  --add-single         Add single subscriber
  --add-range          Add subscriber range
  --list-subscribers   List all subscribers
  --count-subscribers  Count subscribers
  --delete-all         Delete all subscribers

Examples:
  $0 subscribers --add-single --imsi 001011234567891
  $0 subscribers --add-range --start-imsi 001011234567891 --end-imsi 001011234567900
  $0 subscribers --list-subscribers
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
if [[ "$command" == "--help" || "$command" == "-h" || "$command" == "help" ]]; then
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
    
    # Database
    mongodb-hplmn) cmd_mongodb_hplmn "$@" ;;
    mongodb-install) cmd_mongodb_install "$@" ;;
    mongodb-access) cmd_mongodb_access "$@" ;;
    subscribers) cmd_subscribers "$@" ;;
    
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