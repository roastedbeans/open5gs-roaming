#!/bin/bash

# Open5GS Scripts CLI - Organized Version
# A unified interface for Open5GS deployment and management scripts

# Exit on error
set -e

# Define colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Organized script paths
SCRIPTS_DIR="./scripts"

# Installation & Setup
INSTALL_DEP="$SCRIPTS_DIR/install-dep.sh"
SETUP_ROAMING="$SCRIPTS_DIR/setup-k8s-roaming.sh"

# Deployment scripts
KUBECTL_DEPLOY_HPLMN="$SCRIPTS_DIR/deployment/kubectl-deploy-hplmn.sh"
KUBECTL_DEPLOY_VPLMN="$SCRIPTS_DIR/deployment/kubectl-deploy-vplmn.sh"
DOCKER_DEPLOY="$SCRIPTS_DIR/deployment/docker-deploy.sh"

# Image management
PULL_IMAGES="$SCRIPTS_DIR/images/pull-docker-images.sh"
IMPORT_SCRIPT="$SCRIPTS_DIR/images/import.sh"
UPDATE_SCRIPT="$SCRIPTS_DIR/images/update.sh"

# Certificate management
CERT_DEPLOY="$SCRIPTS_DIR/certificates/cert-deploy.sh"
CERT_GENERATE="$SCRIPTS_DIR/certificates/generate-sepp-certs.sh"

# Database management
MONGODB_HPLMN="$SCRIPTS_DIR/database/mongodb-hplmn.sh"
MONGODB44_SETUP="$SCRIPTS_DIR/database/mongodb44-setup.sh"

# Cleanup scripts
MICROK8S_CLEAN="$SCRIPTS_DIR/cleanup/microk8s-clean.sh"
DOCKER_CLEAN="$SCRIPTS_DIR/cleanup/docker-clean.sh"

# Legacy script paths (for backward compatibility during migration)
LEGACY_KUBECTL_DEPLOY="$SCRIPTS_DIR/kubectl-deploy.sh"
LEGACY_CLEAN="$SCRIPTS_DIR/clean.sh"

# Check if scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo -e "${RED}Error: Scripts directory not found.${NC}"
    exit 1
fi

# Ensure all scripts are executable
find $SCRIPTS_DIR -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Display usage information
show_usage() {
    echo -e "${BLUE}Open5GS Scripts CLI - Organized Version${NC}"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo -e "${YELLOW}📦 Installation & Setup:${NC}"
    echo "  install-dep         Install dependencies (Docker, Git, GTP5G)"
    echo "  setup-roaming       Complete automated setup for k8s-roaming"
    echo ""
    echo -e "${YELLOW}🚀 Deployment Commands:${NC}"
    echo "  deploy-hplmn        Deploy only HPLMN components"
    echo "  deploy-vplmn        Deploy only VPLMN components" 
    echo "  deploy-roaming      Deploy both HPLMN and VPLMN for roaming"
    echo "  docker-deploy       Deploy Open5GS images to Docker Hub"
    echo ""
    echo -e "${YELLOW}📦 Image Management:${NC}"
    echo "  pull-images         Pull all Open5GS images from docker.io/vinch05"
    echo "  import-images       Import images to MicroK8s registry"
    echo "  update-configs      Update deployment configs for MicroK8s registry"
    echo ""
    echo -e "${YELLOW}🔐 Certificate Management:${NC}"
    echo "  generate-certs      Generate TLS certificates for SEPP"
    echo "  deploy-certs        Deploy TLS certificates as Kubernetes secrets"
    echo ""
    echo -e "${YELLOW}🗄️ Database Management:${NC}"
    echo "  mongodb-hplmn       Deploy MongoDB (StatefulSet + Service) for HPLMN"
    echo "  mongodb-install     Install MongoDB 4.4 on host system"
    echo ""
    echo -e "${YELLOW}🧹 Cleanup Commands:${NC}"
    echo "  clean-k8s           Clean MicroK8s resources"
    echo "  clean-docker        Clean Docker resources"
    echo ""
    echo -e "${YELLOW}ℹ️ Information:${NC}"
    echo "  help                Show this help message"
    echo "  version             Show version information"
    echo ""
    echo -e "${RED}⚠️ Deprecated Commands (use alternatives):${NC}"
    echo "  kubectl-deploy      → Use deploy-hplmn, deploy-vplmn, or deploy-roaming"
    echo "  clean               → Use clean-k8s or clean-docker"
    echo ""
    echo "Options:"
    echo "  --namespace, -n     Specify Kubernetes namespace (default: hplmn)"
    echo "  --username, -u      Docker Hub username for deployment"
    echo "  --force, -f         Skip confirmation prompts"
    echo "  --tag, -t           Specify image tag (default: v2.7.5)"
    echo "  --delete-pv         Delete persistent volumes (with clean-k8s)"
    echo "  --full-setup        Use comprehensive setup (with setup-roaming)"
    echo ""
    echo "Examples:"
    echo "  $0 install-dep"
    echo "  $0 setup-roaming --full-setup"
    echo "  $0 deploy-roaming"
    echo "  $0 pull-images -t v2.7.5"
    echo "  $0 docker-deploy -u myusername"
    echo "  $0 clean-k8s -n open5gs --delete-pv"
}

# Check if script exists and is executable
check_script() {
    local script_path=$1
    local script_name=$2
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}Error: $script_name script not found at $script_path${NC}"
        echo -e "${YELLOW}Please ensure the script exists in the correct location.${NC}"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo -e "${YELLOW}Warning: Making $script_name executable...${NC}"
        chmod +x "$script_path" || {
            echo -e "${RED}Error: Cannot make $script_name executable${NC}"
            return 1
        }
    fi
    return 0
}

# Installation & Setup functions
install_dependencies() {
    echo -e "${BLUE}Installing dependencies...${NC}"
    check_script "$INSTALL_DEP" "install-dep" && bash "$INSTALL_DEP" "$@"
}

setup_roaming() {
    local tag="v2.7.5"
    local use_full_setup=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tag|-t)
                tag="$2"
                shift 2
                ;;
            --full-setup)
                use_full_setup=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}Setting up complete Open5GS k8s-roaming environment...${NC}"
    check_script "$SETUP_ROAMING" "setup-roaming" && bash "$SETUP_ROAMING" "$tag"
}

# Deployment functions
deploy_hplmn() {
    echo -e "${BLUE}Deploying HPLMN components...${NC}"
    check_script "$KUBECTL_DEPLOY_HPLMN" "kubectl-deploy-hplmn" && bash "$KUBECTL_DEPLOY_HPLMN" "$@"
}

deploy_vplmn() {
    echo -e "${BLUE}Deploying VPLMN components...${NC}"
    check_script "$KUBECTL_DEPLOY_VPLMN" "kubectl-deploy-vplmn" && bash "$KUBECTL_DEPLOY_VPLMN" "$@"
}

deploy_roaming() {
    local tag="v2.7.5"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tag|-t)
                tag="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}Deploying complete roaming setup (HPLMN + VPLMN)...${NC}"
    
    # Deploy HPLMN first
    echo -e "${YELLOW}Step 1: Deploying HPLMN components...${NC}"
    deploy_hplmn
    
    # Wait a moment for HPLMN to stabilize
    echo -e "${BLUE}Waiting for HPLMN to stabilize...${NC}"
    sleep 10
    
    # Then deploy VPLMN
    echo -e "${YELLOW}Step 2: Deploying VPLMN components...${NC}"
    deploy_vplmn
    
    echo -e "${GREEN}Completed deployment of both HPLMN and VPLMN for roaming scenario${NC}"
}

docker_deploy() {
    local username=""
    local tag="v2.7.5"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --username|-u)
                username="$2"
                shift 2
                ;;
            --tag|-t)
                tag="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    # Check for required username
    if [ -z "$username" ]; then
        echo -e "${YELLOW}Docker Hub username is required.${NC}"
        read -p "Enter your Docker Hub username: " username
        
        if [ -z "$username" ]; then
            echo -e "${RED}No username provided. Exiting.${NC}"
            return 1
        fi
    fi

    echo -e "${BLUE}Deploying images to Docker Hub as user: ${YELLOW}$username${NC}"
    
    check_script "$DOCKER_DEPLOY" "docker-deploy" || return 1
    
    # Create temporary file with new username
    temp_file=$(mktemp)
    cp "$DOCKER_DEPLOY" "$temp_file"
    sed -i "s/DOCKERHUB_USERNAME=\"your_username\"/DOCKERHUB_USERNAME=\"$username\"/" "$temp_file"
    
    # Execute modified script
    bash "$temp_file"
    rm "$temp_file"
}

# Image management functions
pull_images() {
    local tag="v2.7.5"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tag|-t)
                tag="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}Pulling Docker images (tag: $tag)...${NC}"
    check_script "$PULL_IMAGES" "pull-docker-images" && bash "$PULL_IMAGES" "$tag"
}

import_images() {
    echo -e "${BLUE}Importing images to MicroK8s registry...${NC}"
    check_script "$IMPORT_SCRIPT" "import" && bash "$IMPORT_SCRIPT" "$@"
}

update_configs() {
    echo -e "${BLUE}Updating deployment configurations for MicroK8s registry...${NC}"
    check_script "$UPDATE_SCRIPT" "update" && bash "$UPDATE_SCRIPT" "$@"
}

# Certificate management functions
generate_certs() {
    echo -e "${BLUE}Generating TLS certificates for SEPP...${NC}"
    
    # Check if we're in the right directory or need to navigate
    if [ -f "$CERT_GENERATE" ]; then
        check_script "$CERT_GENERATE" "generate-sepp-certs" && bash "$CERT_GENERATE" "$@"
    else
        # Try relative path from certificates directory
        local cert_script="./scripts/cert/generate-sepp-certs.sh"
        if [ -f "$cert_script" ]; then
            echo -e "${YELLOW}Using certificate script at: $cert_script${NC}"
            chmod +x "$cert_script"
            bash "$cert_script" "$@"
        else
            echo -e "${RED}Error: Certificate generation script not found${NC}"
            echo -e "${YELLOW}Please ensure generate-sepp-certs.sh exists in scripts/certificates/ or scripts/cert/${NC}"
            return 1
        fi
    fi
}

deploy_certs() {
    echo -e "${BLUE}Deploying TLS certificates as Kubernetes secrets...${NC}"
    check_script "$CERT_DEPLOY" "cert-deploy" && bash "$CERT_DEPLOY" "$@"
}

# Database management functions
mongodb_hplmn() {
    echo -e "${BLUE}Deploying MongoDB for HPLMN (StatefulSet + Service)...${NC}"
    check_script "$MONGODB_HPLMN" "mongodb-hplmn" && bash "$MONGODB_HPLMN" "$@"
}

mongodb_install() {
    echo -e "${BLUE}Installing MongoDB 4.4 on host system...${NC}"
    check_script "$MONGODB44_SETUP" "mongodb44-setup" && bash "$MONGODB44_SETUP" "$@"
}

# Cleanup functions
clean_k8s() {
    echo -e "${BLUE}Cleaning MicroK8s resources...${NC}"
    check_script "$MICROK8S_CLEAN" "microk8s-clean" && bash "$MICROK8S_CLEAN" "$@"
}

clean_docker() {
    echo -e "${BLUE}Cleaning Docker resources...${NC}"
    check_script "$DOCKER_CLEAN" "docker-clean" && bash "$DOCKER_CLEAN" "$@"
}

# Deprecated command handlers
handle_deprecated_kubectl_deploy() {
    echo -e "${RED}⚠️ WARNING: 'kubectl-deploy' command is deprecated.${NC}"
    echo -e "${YELLOW}Please use one of the following alternatives:${NC}"
    echo -e "${YELLOW}  • ./cli.sh deploy-hplmn     - Deploy HPLMN only${NC}"
    echo -e "${YELLOW}  • ./cli.sh deploy-vplmn     - Deploy VPLMN only${NC}"
    echo -e "${YELLOW}  • ./cli.sh deploy-roaming   - Deploy both networks${NC}"
    echo ""
    read -p "Continue with legacy deployment? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$LEGACY_KUBECTL_DEPLOY" ]; then
            echo -e "${YELLOW}Running legacy kubectl-deploy...${NC}"
            bash "$LEGACY_KUBECTL_DEPLOY" "$@"
        else
            echo -e "${RED}Error: Legacy script not found. Please use the new commands.${NC}"
            return 1
        fi
    else
        echo -e "${BLUE}Operation cancelled. Use the new deployment commands.${NC}"
        return 0
    fi
}

handle_deprecated_clean() {
    echo -e "${RED}⚠️ WARNING: 'clean' command is deprecated.${NC}"
    echo -e "${YELLOW}Please use one of the following alternatives:${NC}"
    echo -e "${YELLOW}  • ./cli.sh clean-k8s       - Clean MicroK8s resources${NC}"
    echo -e "${YELLOW}  • ./cli.sh clean-docker    - Clean Docker resources${NC}"
    echo ""
    
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: Missing target for clean command${NC}"
        echo -e "${YELLOW}Legacy usage was: $0 clean [docker|k8s] [options]${NC}"
        return 1
    fi
    
    target=$1
    shift
    
    case $target in
        docker)
            echo -e "${YELLOW}Redirecting to clean-docker...${NC}"
            clean_docker "$@"
            ;;
        k8s|kubernetes|microk8s)
            echo -e "${YELLOW}Redirecting to clean-k8s...${NC}"
            clean_k8s "$@"
            ;;
        *)
            echo -e "${RED}Unknown target: $target${NC}"
            echo -e "${YELLOW}Use: ./cli.sh clean-k8s or ./cli.sh clean-docker${NC}"
            return 1
            ;;
    esac
}

# Version information
show_version() {
    echo -e "${BLUE}Open5GS Scripts CLI - Organized Version${NC}"
    echo -e "${GREEN}Version: 2.0.0${NC}"
    echo -e "${YELLOW}Default Open5GS Version: v2.7.5${NC}"
    echo -e "${BLUE}Reorganized script structure with improved maintainability${NC}"
}

# Main command parser
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

command=$1
shift

case $command in
    # Installation & Setup
    install-dep)
        install_dependencies "$@"
        ;;
    setup-roaming)
        setup_roaming "$@"
        ;;
        
    # Deployment Commands
    deploy-hplmn)
        deploy_hplmn "$@"
        ;;
    deploy-vplmn)
        deploy_vplmn "$@"
        ;;
    deploy-roaming)
        deploy_roaming "$@"
        ;;
    docker-deploy)
        docker_deploy "$@"
        ;;
        
    # Image Management
    pull-images)
        pull_images "$@"
        ;;
    import-images)
        import_images "$@"
        ;;
    update-configs)
        update_configs "$@"
        ;;
        
    # Certificate Management
    generate-certs)
        generate_certs "$@"
        ;;
    deploy-certs)
        deploy_certs "$@"
        ;;
        
    # Database Management
    mongodb-hplmn)
        mongodb_hplmn "$@"
        ;;
    mongodb-install)
        mongodb_install "$@"
        ;;
        
    # Cleanup Commands
    clean-k8s)
        clean_k8s "$@"
        ;;
    clean-docker)
        clean_docker "$@"
        ;;
        
    # Information Commands
    help)
        show_usage
        ;;
    version)
        show_version
        ;;
        
    # Deprecated Commands (with warnings)
    kubectl-deploy)
        handle_deprecated_kubectl_deploy "$@"
        ;;
    clean)
        handle_deprecated_clean "$@"
        ;;
        
    # Legacy aliases for backward compatibility
    cert-deploy)
        echo -e "${YELLOW}Note: 'cert-deploy' is now 'deploy-certs'${NC}"
        deploy_certs "$@"
        ;;
    microk8s-clean)
        echo -e "${YELLOW}Note: 'microk8s-clean' is now 'clean-k8s'${NC}"
        clean_k8s "$@"
        ;;
    docker-clean)
        echo -e "${YELLOW}Note: 'docker-clean' is now 'clean-docker'${NC}"
        clean_docker "$@"
        ;;
        
    *)
        echo -e "${RED}Unknown command: $command${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac

exit 0