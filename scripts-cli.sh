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
KUBECTL_DEPLOY_HPLMN="$SCRIPTS_DIR/kubectl-deploy-hplmn.sh"
KUBECTL_DEPLOY_VPLMN="$SCRIPTS_DIR/kubectl-deploy-vplmn.sh"
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
    echo "  docker-deploy       Deploy Open5GS images to Docker Hub"
    echo "  kubectl-deploy      Deploy Open5GS to Kubernetes/MicroK8s (legacy)"
    echo "  deploy-hplmn        Deploy only HPLMN components"
    echo "  deploy-vplmn        Deploy only VPLMN components"
    echo "  deploy-roaming      Deploy both HPLMN and VPLMN for roaming scenario"
    echo "  docker-clean        Clean Docker resources"
    echo "  microk8s-clean      Clean MicroK8s resources"
    echo "  update              Update configurations or images"
    echo "  import              Import configurations or data"
    echo "  install-dep         Install dependencies"
    echo "  help                Show this help message"
    echo ""
    echo "Options:"
    echo "  --namespace, -n   Specify Kubernetes namespace (default: hplmn)"
    echo "  --username, -u    Docker Hub username for deployment"
    echo "  --registry, -r    Docker registry URL (default: docker.io/vinch05)"
    echo "  --force, -f       Skip confirmation prompts"
    echo "  --tag, -t         Specify image tag (default: v2.7.5)"
    echo "  --delete-pv       Delete persistent volumes (with microk8s-clean)"
    echo ""
    echo "Examples:"
    echo "  $0 docker-deploy -u myusername"
    echo "  $0 deploy-hplmn -r docker.io/myusername"
    echo "  $0 deploy-vplmn -r docker.io/myusername"
    echo "  $0 deploy-roaming -r registry.example.com"
    echo "  $0 docker-clean -f"
    echo "  $0 microk8s-clean -n open5gs --delete-pv"
}

# Update registry configuration in env-config.yaml
update_registry_config() {
    local registry="$1"
    local config_file="k8s-roaming/env-config.yaml"
    
    if [ -f "$config_file" ]; then
        echo -e "${BLUE}Updating registry URL to: ${YELLOW}$registry${NC}"
        sed -i "s|REGISTRY_URL:.*|REGISTRY_URL: $registry|" "$config_file"
        echo -e "${GREEN}Registry URL updated in $config_file${NC}"
    else
        echo -e "${RED}Error: $config_file not found${NC}"
        exit 1
    fi
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

# Legacy Kubernetes/MicroK8s deployment
kubectl_deploy() {
    local namespace="hplmn"
    local registry="docker.io/library"
    local tag="v2.7.5"
    local deploy_roaming=false
    
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
            --roaming)
                deploy_roaming=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    # Update registry in config file
    update_registry_config "$registry"
    
    if [ "$deploy_roaming" = true ]; then
        echo -e "${BLUE}Deploying Open5GS roaming setup (both HPLMN and VPLMN)${NC}"
        echo -e "${BLUE}Using registry: ${YELLOW}$registry${NC}"
        
        # Deploy HPLMN first
        echo -e "${YELLOW}Deploying HPLMN components...${NC}"
        export NAMESPACE="hplmn"
        export TAG="$tag"
        bash "$KUBECTL_DEPLOY"
        
        # Then deploy VPLMN
        echo -e "${YELLOW}Deploying VPLMN components...${NC}"
        export NAMESPACE="vplmn"
        export TAG="$tag"
        bash "$KUBECTL_DEPLOY"
        
        echo -e "${GREEN}Completed deployment of both HPLMN and VPLMN for roaming scenario${NC}"
    else
        echo -e "${BLUE}Deploying Open5GS to MicroK8s namespace: ${YELLOW}$namespace${NC}"
        echo -e "${BLUE}Using registry: ${YELLOW}$registry${NC}"
        
        # Set environment variables for the deployment script
        export NAMESPACE="$namespace"
        export TAG="$tag"
        
        # Execute deployment script
        bash "$KUBECTL_DEPLOY"
    fi
}

# HPLMN-only deployment
deploy_hplmn() {
    local registry="docker.io/library"
    local tag="v2.7.5"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
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
    
    # Update registry in config file
    update_registry_config "$registry"
    
    echo -e "${BLUE}Deploying HPLMN components to MicroK8s${NC}"
    echo -e "${BLUE}Using registry: ${YELLOW}$registry${NC}"
    
    # Make sure the script is executable
    chmod +x "$KUBECTL_DEPLOY_HPLMN"
    
    # Execute the HPLMN deployment script
    bash "$KUBECTL_DEPLOY_HPLMN"
}

# VPLMN-only deployment
deploy_vplmn() {
    local registry="docker.io/library"
    local tag="v2.7.5"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
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
    
    # Update registry in config file
    update_registry_config "$registry"
    
    echo -e "${BLUE}Deploying VPLMN components to MicroK8s${NC}"
    echo -e "${BLUE}Using registry: ${YELLOW}$registry${NC}"
    
    # Make sure the script is executable
    chmod +x "$KUBECTL_DEPLOY_VPLMN"
    
    # Execute the VPLMN deployment script
    bash "$KUBECTL_DEPLOY_VPLMN"
}

# Deploy both HPLMN and VPLMN for roaming
deploy_roaming() {
    local registry="docker.io/library"
    local tag="v2.7.5"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
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
    
    # Update registry in config file
    update_registry_config "$registry"
    
    echo -e "${BLUE}Deploying full roaming setup (HPLMN + VPLMN) to MicroK8s${NC}"
    echo -e "${BLUE}Using registry: ${YELLOW}$registry${NC}"
    
    # Make sure the scripts are executable
    chmod +x "$KUBECTL_DEPLOY_HPLMN"
    chmod +x "$KUBECTL_DEPLOY_VPLMN"
    
    # Deploy HPLMN first
    echo -e "${YELLOW}Step 1: Deploying HPLMN components...${NC}"
    bash "$KUBECTL_DEPLOY_HPLMN"
    
    # Then deploy VPLMN
    echo -e "${YELLOW}Step 2: Deploying VPLMN components...${NC}"
    bash "$KUBECTL_DEPLOY_VPLMN"
    
    echo -e "${GREEN}Completed deployment of both HPLMN and VPLMN for roaming scenario${NC}"
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
        echo -e "${YELLOW}Warning: kubectl-deploy is deprecated. Please use deploy-hplmn, deploy-vplmn, or deploy-roaming instead.${NC}"
        kubectl_deploy "$@"
        ;;
        
    deploy-hplmn)
        deploy_hplmn "$@"
        ;;
        
    deploy-vplmn)
        deploy_vplmn "$@"
        ;;
        
    deploy-roaming)
        deploy_roaming "$@"
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