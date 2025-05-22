#!/bin/bash

# MongoDB External Access Setup Script
# This script sets up external access to MongoDB in microk8s

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="hplmn"
NODE_PORT="30017"
SERVICE_NAME="mongodb-external"

# Function to show usage
show_usage() {
    echo "MongoDB External Access Setup"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --setup          Create NodePort service for external access"
    echo "  --remove         Remove NodePort service"
    echo "  --status         Show connection status and details"
    echo "  --port-forward   Start kubectl port forwarding (temporary)"
    echo "  --node-port PORT Custom NodePort (default: 30017)"
    echo "  --help           Show this help"
}

# Function to get VM IP
get_vm_ip() {
    # Try multiple methods to get the VM's external IP
    local vm_ip=""
    
    # Method 1: Check for common network interfaces
    vm_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || echo "")
    
    if [ -z "$vm_ip" ]; then
        # Method 2: Get IP from default interface
        vm_ip=$(hostname -I | awk '{print $1}')
    fi
    
    echo "$vm_ip"
}

# Function to create NodePort service
setup_nodeport() {
    echo -e "${BLUE}Setting up NodePort service for MongoDB external access...${NC}"
    
    # Check if service already exists
    if microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME >/dev/null 2>&1; then
        echo -e "${YELLOW}NodePort service already exists. Removing first...${NC}"
        microk8s kubectl delete svc -n $NAMESPACE $SERVICE_NAME
    fi
    
    # Create NodePort service
    cat > /tmp/mongodb-nodeport.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
  namespace: $NAMESPACE
  labels:
    app: mongodb
spec:
  type: NodePort
  ports:
  - port: 27017
    targetPort: 27017
    nodePort: $NODE_PORT
    protocol: TCP
    name: mongodb
  selector:
    app: mongodb
EOF

    microk8s kubectl apply -f /tmp/mongodb-nodeport.yaml
    rm -f /tmp/mongodb-nodeport.yaml
    
    echo -e "${GREEN}NodePort service created successfully${NC}"
}

# Function to remove NodePort service
remove_nodeport() {
    echo -e "${BLUE}Removing NodePort service...${NC}"
    
    if microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME >/dev/null 2>&1; then
        microk8s kubectl delete svc -n $NAMESPACE $SERVICE_NAME
        echo -e "${GREEN}NodePort service removed successfully${NC}"
    else
        echo -e "${YELLOW}NodePort service not found${NC}"
    fi
}

# Function to show status
show_status() {
    echo -e "${BLUE}MongoDB External Access Status${NC}"
    echo "================================"
    
    # Get VM IP
    local vm_ip=$(get_vm_ip)
    echo -e "VM IP Address: ${GREEN}$vm_ip${NC}"
    
    # Check if NodePort service exists
    if microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME >/dev/null 2>&1; then
        local actual_port=$(microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME -o jsonpath='{.spec.ports[0].nodePort}')
        echo -e "NodePort Service: ${GREEN}Active${NC}"
        echo -e "External Port: ${GREEN}$actual_port${NC}"
        echo -e "Connection String: ${YELLOW}mongodb://$vm_ip:$actual_port${NC}"
        echo ""
        echo "Service Details:"
        microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME
    else
        echo -e "NodePort Service: ${RED}Not Found${NC}"
        echo -e "Use: ${YELLOW}$0 --setup${NC} to create the service"
    fi
    
    echo ""
    echo "MongoDB Pod Status:"
    microk8s kubectl get pods -n $NAMESPACE -l app=mongodb
    
    echo ""
    echo -e "${BLUE}Connection Examples:${NC}"
    if microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME >/dev/null 2>&1; then
        local actual_port=$(microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME -o jsonpath='{.spec.ports[0].nodePort}')
        echo "MongoDB Compass: mongodb://$vm_ip:$actual_port"
        echo "MongoDB Shell:   mongo --host $vm_ip --port $actual_port"
        echo "Python:          mongodb://$vm_ip:$actual_port"
    else
        echo "Setup NodePort service first with: $0 --setup"
    fi
}

# Function to start port forwarding
start_port_forward() {
    echo -e "${BLUE}Starting kubectl port forwarding...${NC}"
    echo -e "${YELLOW}This will run in foreground. Press Ctrl+C to stop.${NC}"
    
    local vm_ip=$(get_vm_ip)
    echo -e "MongoDB will be accessible at: ${GREEN}$vm_ip:27017${NC}"
    echo ""
    
    microk8s kubectl port-forward -n $NAMESPACE svc/mongodb 27017:27017 --address=0.0.0.0
}

# Function to test connectivity
test_connectivity() {
    echo -e "${BLUE}Testing MongoDB connectivity...${NC}"
    
    local vm_ip=$(get_vm_ip)
    local test_port=""
    
    # Check if NodePort service exists
    if microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME >/dev/null 2>&1; then
        test_port=$(microk8s kubectl get svc -n $NAMESPACE $SERVICE_NAME -o jsonpath='{.spec.ports[0].nodePort}')
    else
        echo -e "${RED}NodePort service not found. Run with --setup first.${NC}"
        return 1
    fi
    
    # Test if port is open
    if timeout 5 bash -c "</dev/tcp/$vm_ip/$test_port" 2>/dev/null; then
        echo -e "${GREEN}✓ MongoDB is accessible at $vm_ip:$test_port${NC}"
    else
        echo -e "${RED}✗ Cannot connect to MongoDB at $vm_ip:$test_port${NC}"
        echo -e "${YELLOW}Check firewall settings and VM network configuration${NC}"
    fi
}

# Parse arguments
OPERATION=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --setup)
            OPERATION="setup"
            shift
            ;;
        --remove)
            OPERATION="remove"
            shift
            ;;
        --status)
            OPERATION="status"
            shift
            ;;
        --port-forward)
            OPERATION="port-forward"
            shift
            ;;
        --test)
            OPERATION="test"
            shift
            ;;
        --node-port)
            NODE_PORT="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
if [ -z "$OPERATION" ]; then
    show_usage
    exit 1
fi

case $OPERATION in
    "setup")
        setup_nodeport
        echo ""
        show_status
        echo ""
        test_connectivity
        ;;
    "remove")
        remove_nodeport
        ;;
    "status")
        show_status
        ;;
    "port-forward")
        start_port_forward
        ;;
    "test")
        test_connectivity
        ;;
    *)
        echo -e "${RED}Invalid operation${NC}"
        show_usage
        exit 1
        ;;
esac