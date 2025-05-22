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
KUBECTL_DEPLOY_HPLMN="$SCRIPTS_DIR/kubectl-deploy-hplmn.sh"
KUBECTL_DEPLOY_VPLMN="$SCRIPTS_DIR/kubectl-deploy-vplmn.sh"
DOCKER_DEPLOY="$SCRIPTS_DIR/docker-deploy.sh"

# Image management
PULL_IMAGES="$SCRIPTS_DIR/pull-docker-images.sh"
IMPORT_SCRIPT="$SCRIPTS_DIR/import.sh"
UPDATE_SCRIPT="$SCRIPTS_DIR/update.sh"

# Certificate management
CERT_DEPLOY="$SCRIPTS_DIR/cert-deploy.sh"
CERT_GENERATE="$SCRIPTS_DIR/cert/generate-sepp-certs.sh"

# Database management
MONGODB_HPLMN="$SCRIPTS_DIR/mongodb-hplmn.sh"
MONGODB44_SETUP="$SCRIPTS_DIR/mongodb44-setup.sh"
MONGODB_ACCESS="$SCRIPTS_DIR/mongodb-access.sh"

# Cleanup scripts
MICROK8S_CLEAN="$SCRIPTS_DIR/microk8s-clean.sh"
DOCKER_CLEAN="$SCRIPTS_DIR/docker-clean.sh"

# Subscribers script
SUBSCRIBERS="$SCRIPTS_DIR/subscribers.sh"

# Check if scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo -e "${RED}Error: Scripts directory not found.${NC}"
    exit 1
fi

# Ensure all scripts are executable
find $SCRIPTS_DIR -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Display usage information
show_usage() {
    echo -e "${BLUE}Open5GS Scripts CLI - Comprehensive Version${NC}"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo -e "${YELLOW}📦 Installation & Setup:${NC}"
    echo "  install-dep         Install dependencies (Docker, Git, GTP5G kernel module)"
    echo "  setup-roaming       Complete automated setup for k8s-roaming environment"
    echo ""
    echo -e "${YELLOW}🚀 Deployment Commands:${NC}"
    echo "  deploy-hplmn        Deploy only HPLMN components to Kubernetes"
    echo "  deploy-vplmn        Deploy only VPLMN components to Kubernetes" 
    echo "  deploy-roaming      Deploy both HPLMN and VPLMN for roaming scenario"
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
    echo "  mongodb-hplmn       Deploy and configure MongoDB for HPLMN"
    echo "  mongodb-install     Install MongoDB 4.4 on host system"
    echo "  mongodb-access      Set up MongoDB external access"
    echo "  subscribers         Manage subscribers in MongoDB database"
    echo ""
    echo -e "${YELLOW}🧹 Cleanup Commands:${NC}"
    echo "  clean-k8s           Clean MicroK8s resources (pods, services, etc.)"
    echo "  clean-docker        Clean Docker resources (containers, images, volumes)"
    echo ""
    echo -e "${YELLOW}ℹ️ Information:${NC}"
    echo "  help                Show this help message"
    echo "  version             Show version information"
    echo ""
    echo -e "${RED}⚠️ Deprecated Commands (use alternatives):${NC}"
    echo "  kubectl-deploy      → Use deploy-hplmn, deploy-vplmn, or deploy-roaming"
    echo "  clean               → Use clean-k8s or clean-docker"
    echo ""
    echo -e "${YELLOW}Detailed Command Descriptions:${NC}"
    echo ""
    
    # Installation & Setup
    echo -e "${BLUE}install-dep${NC}"
    echo "  Installs required dependencies for Open5GS deployment, including:"
    echo "  - Docker and Docker Compose"
    echo "  - Git"
    echo "  - GTP5G kernel module"
    echo "  - MicroK8s (optional)"
    echo "  Usage: $0 install-dep [--with-k8s] [--no-confirm]"
    echo ""
    
    echo -e "${BLUE}setup-roaming${NC}"
    echo "  Performs complete setup for 5G roaming environment with:"
    echo "  - MicroK8s configuration"
    echo "  - MongoDB setup"
    echo "  - Certificate generation"
    echo "  - DNS and network configuration"
    echo "  Usage: $0 setup-roaming [--tag VERSION] [--full-setup]"
    echo ""
    
    # Deployment Commands
    echo -e "${BLUE}deploy-hplmn${NC}"
    echo "  Deploys Home PLMN (HPLMN) components to Kubernetes, including:"
    echo "  - Core Network Functions (AMF, SMF, UPF, etc.)"
    echo "  - MongoDB database"
    echo "  - SEPP for roaming"
    echo "  Usage: $0 deploy-hplmn [--namespace NAMESPACE] [--tag VERSION] [--no-mongodb]"
    echo "  Options:"
    echo "    --no-mongodb      Skip MongoDB deployment"
    echo ""
    
    echo -e "${BLUE}deploy-vplmn${NC}"
    echo "  Deploys Visited PLMN (VPLMN) components to Kubernetes, including:"
    echo "  - Core Network Functions for visited network"
    echo "  - SEPP for roaming"
    echo "  Usage: $0 deploy-vplmn [--namespace NAMESPACE] [--tag VERSION]"
    echo ""
    
    echo -e "${BLUE}deploy-roaming${NC}"
    echo "  Deploys both HPLMN and VPLMN components for complete roaming scenario"
    echo "  Usage: $0 deploy-roaming [--tag VERSION] [--no-mongodb]"
    echo "  Options:"
    echo "    --no-mongodb      Skip MongoDB deployment in HPLMN"
    echo ""
    
    echo -e "${BLUE}docker-deploy${NC}"
    echo "  Publishes Open5GS container images to Docker Hub"
    echo "  Usage: $0 docker-deploy --username DOCKERHUB_USERNAME [--tag VERSION]"
    echo ""
    
    # Image Management
    echo -e "${BLUE}pull-images${NC}"
    echo "  Pulls all Open5GS component images from docker.io/vinch05"
    echo "  Components: amf, ausf, bsf, nrf, nssf, pcf, scp, sepp, smf, udm, udr, upf, webui"
    echo "  Usage: $0 pull-images [--tag VERSION]"
    echo ""
    
    echo -e "${BLUE}import-images${NC}"
    echo "  Imports pulled Docker images into MicroK8s registry"
    echo "  Usage: $0 import-images [--tag VERSION]"
    echo ""
    
    echo -e "${BLUE}update-configs${NC}"
    echo "  Updates Kubernetes deployment YAML files to use MicroK8s registry"
    echo "  Usage: $0 update-configs [--tag VERSION]"
    echo ""
    
    # Certificate Management
    echo -e "${BLUE}generate-certs${NC}"
    echo "  Generates TLS certificates for SEPP N32 interface"
    echo "  Usage: $0 generate-certs"
    echo ""
    
    echo -e "${BLUE}deploy-certs${NC}"
    echo "  Deploys generated certificates as Kubernetes secrets"
    echo "  Usage: $0 deploy-certs [--namespace NAMESPACE]"
    echo ""
    
    # Database Management
    echo -e "${BLUE}mongodb-hplmn${NC}"
    echo "  Deploys and configures MongoDB for HPLMN"
    echo "  Usage: $0 mongodb-hplmn [--namespace NAMESPACE]"
    echo ""
    
    echo -e "${BLUE}mongodb-install${NC}"
    echo "  Installs MongoDB 4.4 on host system (for direct DB access)"
    echo "  Usage: $0 mongodb-install"
    echo ""
    
    echo -e "${BLUE}mongodb-access${NC}"
    echo "  Sets up external access to MongoDB running in Kubernetes"
    echo "  Operations:"
    echo "    --setup          Create NodePort service for external access"
    echo "    --remove         Remove NodePort service"
    echo "    --status         Show connection status and details"
    echo "    --port-forward   Start kubectl port forwarding (temporary)"
    echo "    --test           Test connectivity to MongoDB"
    echo "  Options:"
    echo "    --node-port PORT Custom NodePort (default: 30017)"
    echo "  Usage examples:"
    echo "    $0 mongodb-access --setup"
    echo "    $0 mongodb-access --status"
    echo "    $0 mongodb-access --remove"
    echo "    $0 mongodb-access --port-forward"
    echo "    $0 mongodb-access --setup --node-port 31017"
    echo ""
    
    echo -e "${BLUE}subscribers${NC}"
    echo "  Manages subscriber information in the MongoDB database"
    echo "  Operations:"
    echo "    - Add single subscriber"
    echo "    - Add range of subscribers"
    echo "    - List all subscribers"
    echo "    - Count subscribers"
    echo "    - Delete all subscribers"
    echo "  Usage: $0 subscribers [OPERATION] [OPTIONS]"
    echo "  Examples:"
    echo "    $0 subscribers --add-single --imsi 001011234567891"
    echo "    $0 subscribers --add-range --start-imsi 001011234567891 --end-imsi 001011234567900"
    echo "    $0 subscribers --list-subscribers"
    echo "    $0 subscribers --count-subscribers"
    echo "    $0 subscribers --delete-all"
    echo ""
    
    # Cleanup Commands
    echo -e "${BLUE}clean-k8s${NC}"
    echo "  Cleans Kubernetes resources created by deployment scripts"
    echo "  Usage: $0 clean-k8s [--namespace NAMESPACE] [--delete-pv]"
    echo ""
    
    echo -e "${BLUE}clean-docker${NC}"
    echo "  Cleans Docker resources including containers, networks, and volumes"
    echo "  Usage: $0 clean-docker [--force]"
    echo ""
    
    echo -e "${YELLOW}Common Options:${NC}"
    echo "  --namespace, -n     Specify Kubernetes namespace (default: hplmn or vplmn)"
    echo "  --username, -u      Docker Hub username for deployment"
    echo "  --force, -f         Skip confirmation prompts"
    echo "  --tag, -t           Specify image tag (default: v2.7.5)"
    echo "  --delete-pv         Delete persistent volumes (with clean-k8s)"
    echo "  --full-setup        Use comprehensive setup (with setup-roaming)"
    echo ""
    echo -e "${YELLOW}Example Workflows:${NC}"
    echo "  1. First-time complete setup:"
    echo "     $0 install-dep"
    echo "     $0 setup-roaming --full-setup"
    echo "     $0 deploy-roaming"
    echo ""
    echo "  2. Update existing deployment:"
    echo "     $0 pull-images --tag v2.7.6"
    echo "     $0 import-images --tag v2.7.6"
    echo "     $0 clean-k8s"
    echo "     $0 deploy-roaming --tag v2.7.6"
    echo ""
    echo "  3. Deploy with separate MongoDB setup:"
    echo "     $0 mongodb-hplmn --namespace hplmn"
    echo "     $0 deploy-hplmn --namespace hplmn --no-mongodb"
    echo ""
    echo "  4. Setup MongoDB external access:"
    echo "     $0 mongodb-access --setup         # Create NodePort service"
    echo "     $0 mongodb-access --status        # Get connection information"
    echo "     # Connect using MongoDB Compass with the connection string"
    echo ""
    echo "  5. Add subscribers to database:"
    echo "     $0 subscribers --add-range --start-imsi 001011234567891 --end-imsi 001011234567900"
    echo ""
    echo "  6. Clean up resources:"
    echo "     $0 clean-k8s --delete-pv"
    echo "     $0 clean-docker --force"
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
    local namespace="hplmn"
    local with_mongodb=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace|-n)
                namespace="$2"
                shift 2
                ;;
            --no-mongodb)
                with_mongodb=false
                shift
                ;;
            --tag|-t)
                # Handle tag option but we don't use it directly in this function
                # Just passing it to underlying scripts
                shift 2
                ;;
            *)
                # Pass other arguments through
                break
                ;;
        esac
    done
    
    echo -e "${BLUE}Deploying HPLMN components in namespace: $namespace...${NC}"
    
    # First deploy MongoDB if requested
    if [ "$with_mongodb" = true ]; then
        echo -e "${YELLOW}Step 1: Deploying MongoDB for HPLMN...${NC}"
        if check_script "$MONGODB_HPLMN" "mongodb-hplmn"; then
            bash "$MONGODB_HPLMN" --namespace "$namespace"
            
            # Wait for MongoDB to be ready
            echo -e "${BLUE}Waiting for MongoDB to be ready...${NC}"
            microk8s kubectl wait --for=condition=ready pods -l app=mongodb --namespace="$namespace" --timeout=120s || {
                echo -e "${YELLOW}Warning: MongoDB pods not ready within timeout, but continuing...${NC}"
            }
        else
            echo -e "${RED}Error: MongoDB setup script not found, continuing without MongoDB${NC}"
        fi
    fi
    
    # Then deploy other HPLMN components
    echo -e "${YELLOW}Step 2: Deploying core network components...${NC}"
    check_script "$KUBECTL_DEPLOY_HPLMN" "kubectl-deploy-hplmn" && bash "$KUBECTL_DEPLOY_HPLMN" "$@"
}

deploy_vplmn() {
    echo -e "${BLUE}Deploying VPLMN components...${NC}"
    check_script "$KUBECTL_DEPLOY_VPLMN" "kubectl-deploy-vplmn" && bash "$KUBECTL_DEPLOY_VPLMN" "$@"
}

deploy_roaming() {
    local tag="v2.7.5"
    local with_mongodb=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tag|-t)
                tag="$2"
                shift 2
                ;;
            --no-mongodb)
                with_mongodb=false
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}Deploying complete roaming setup (HPLMN + VPLMN)...${NC}"
    
    # Deploy HPLMN first with MongoDB if requested
    echo -e "${YELLOW}Step 1: Deploying HPLMN components...${NC}"
    if [ "$with_mongodb" = true ]; then
        deploy_hplmn --tag "$tag"
    else
        deploy_hplmn --tag "$tag" --no-mongodb
    fi
    
    # Wait a moment for HPLMN to stabilize
    echo -e "${BLUE}Waiting for HPLMN to stabilize...${NC}"
    sleep 10
    
    # Then deploy VPLMN
    echo -e "${YELLOW}Step 2: Deploying VPLMN components...${NC}"
    deploy_vplmn --tag "$tag"
    
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
    echo -e "${BLUE}Configuring MongoDB for HPLMN...${NC}"
    check_script "$MONGODB_HPLMN" "mongodb-hplmn" && bash "$MONGODB_HPLMN" "$@"
}

mongodb_install() {
    echo -e "${BLUE}Installing MongoDB 4.4 on host system...${NC}"
    check_script "$MONGODB44_SETUP" "mongodb44-setup" && bash "$MONGODB44_SETUP" "$@"
}

mongodb_access() {
    echo -e "${BLUE}Setting up external access to MongoDB running in Kubernetes...${NC}"
    check_script "$MONGODB_ACCESS" "mongodb-access" && bash "$MONGODB_ACCESS" "$@"
}

# Subscriber management function
manage_subscribers() {
    echo -e "${BLUE}Managing subscribers in HPLMN...${NC}"
    check_script "$SUBSCRIBERS" "subscribers" && bash "$SUBSCRIBERS" "$@"
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
    mongodb-access)
        mongodb_access "$@"
        ;;
    subscribers)
        manage_subscribers "$@"
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