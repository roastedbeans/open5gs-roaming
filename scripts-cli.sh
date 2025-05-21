#!/bin/bash

# Open5GS Scripts CLI
# A unified interface for Open5GS deployment and management scripts

# Exit on error
set -e

# Define colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script paths
SCRIPTS_DIR="./scripts"
DOCKER_DEPLOY="$SCRIPTS_DIR/docker-deploy.sh"
KUBECTL_DEPLOY="$SCRIPTS_DIR/kubectl-deploy.sh"
DOCKER_CLEAN="$SCRIPTS_DIR/docker-clean.sh"
MICROK8S_CLEAN="$SCRIPTS_DIR/microk8s-clean.sh"
UPDATE_SCRIPT="$SCRIPTS_DIR/update.sh"
IMPORT_SCRIPT="$SCRIPTS_DIR/import.sh"
INSTALL_DEP="$SCRIPTS_DIR/install-dep.sh"

# Check if scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo -e "${RED}Error: Scripts directory not found.${NC}"
    exit 1
fi

# Ensure all scripts are executable
chmod +x $SCRIPTS_DIR/*.sh 2>/dev/null || true

# Display usage information
show_usage() {
    echo -e "${BLUE}Open5GS Scripts CLI${NC}"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  docker-deploy    Deploy Open5GS images to Docker Hub"
    echo "  kubectl-deploy   Deploy Open5GS to Kubernetes/MicroK8s"
    echo "  docker-clean     Clean Docker resources"
    echo "  microk8s-clean   Clean MicroK8s resources"
    echo "  update           Update configurations or images"
    echo "  import           Import configurations or data"
    echo "  install-dep      Install dependencies"
    echo "  help             Show this help message"
    echo ""
    echo "Options:"
    echo "  --namespace, -n   Specify Kubernetes namespace (default: hplmn)"
    echo "  --username, -u    Docker Hub username for deployment"
    echo "  --registry, -r    Docker registry URL (default: docker.io/library)"
    echo "  --force, -f       Skip confirmation prompts"
    echo "  --tag, -t         Specify image tag (default: v2.7.5)"
    echo "  --delete-pv       Delete persistent volumes (with microk8s-clean)"
    echo ""
    echo "Examples:"
    echo "  $0 docker-deploy -u myusername"
    echo "  $0 kubectl-deploy -n open5gs -r docker.io/myusername"
    echo "  $0 docker-clean -f"
    echo "  $0 microk8s-clean -n open5gs --delete-pv"
}

# Docker deployment with custom username
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

    echo -e "${BLUE}Deploying Open5GS images to Docker Hub as user: ${YELLOW}$username${NC}"
    
    # Create temporary file with new username
    temp_file=$(mktemp)
    cp "$DOCKER_DEPLOY" "$temp_file"
    sed -i "s/DOCKERHUB_USERNAME=\"your_username\"/DOCKERHUB_USERNAME=\"$username\"/" "$temp_file"
    
    # Execute modified script
    bash "$temp_file"
    rm "$temp_file"
}

# Kubernetes/MicroK8s deployment
kubectl_deploy() {
    local namespace="hplmn"
    local registry="docker.io/library"
    local tag="v2.7.5"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace|-n)
                namespace="$2"
                shift 2
                ;;
            --registry|-r)
                registry="$2"
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
    
    echo -e "${BLUE}Deploying Open5GS to MicroK8s namespace: ${YELLOW}$namespace${NC}"
    echo -e "${BLUE}Using registry: ${YELLOW}$registry${NC}"
    
    # Set environment variables for the deployment script
    export NAMESPACE="$namespace"
    export REGISTRY="$registry"
    export TAG="$tag"
    
    # Execute deployment script
    bash "$KUBECTL_DEPLOY"
}

# Main command parser
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

command=$1
shift

case $command in
    docker-deploy)
        docker_deploy "$@"
        ;;
        
    kubectl-deploy)
        kubectl_deploy "$@"
        ;;
        
    docker-clean)
        echo -e "${BLUE}Cleaning Docker resources...${NC}"
        bash "$DOCKER_CLEAN" "$@"
        ;;
        
    microk8s-clean)
        echo -e "${BLUE}Cleaning MicroK8s resources...${NC}"
        bash "$MICROK8S_CLEAN" "$@"
        ;;
        
    clean)
        echo -e "${YELLOW}Warning: The 'clean' command is deprecated.${NC}"
        echo -e "${YELLOW}Please use 'docker-clean' or 'microk8s-clean' instead.${NC}"
        
        if [ $# -eq 0 ]; then
            echo -e "${RED}Error: Missing target for clean command${NC}"
            echo -e "${YELLOW}Usage: $0 clean [docker|k8s] [options]${NC}"
            exit 1
        fi
        
        target=$1
        shift
        
        case $target in
            docker)
                echo -e "${BLUE}Cleaning Docker resources...${NC}"
                bash "$DOCKER_CLEAN" "$@"
                ;;
                
            k8s|kubernetes|microk8s)
                echo -e "${BLUE}Cleaning Kubernetes/MicroK8s resources...${NC}"
                bash "$MICROK8S_CLEAN" "$@"
                ;;
                
            *)
                echo -e "${RED}Unknown target: $target${NC}"
                echo -e "${YELLOW}Usage: $0 clean [docker|k8s] [options]${NC}"
                exit 1
                ;;
        esac
        ;;
        
    update)
        echo -e "${BLUE}Running update script...${NC}"
        bash "$UPDATE_SCRIPT" "$@"
        ;;
        
    import)
        echo -e "${BLUE}Running import script...${NC}"
        bash "$IMPORT_SCRIPT" "$@"
        ;;
        
    install-dep)
        echo -e "${BLUE}Installing dependencies...${NC}"
        bash "$INSTALL_DEP" "$@"
        ;;
        
    help)
        show_usage
        ;;
        
    *)
        echo -e "${RED}Unknown command: $command${NC}"
        show_usage
        exit 1
        ;;
esac

exit 0 