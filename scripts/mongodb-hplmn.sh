#!/bin/bash

# MongoDB Deployment Script for HPLMN
# This script deploys MongoDB StatefulSet and Service for the HPLMN namespace

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default configuration
NAMESPACE="hplmn"
MONGODB_VERSION="4.4"
STORAGE_SIZE="1Gi"
CONFIG_STORAGE="500Mi"
STORAGE_CLASS="microk8s-hostpath"
CREATE_NODEPORT=false
NODE_PORT="30017"
FORCE=false

# Function to show usage
show_usage() {
    echo "MongoDB Deployment Script for HPLMN"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --namespace, -n NAMESPACE    Target namespace (default: hplmn)"
    echo "  --storage-size SIZE          Data storage size (default: 1Gi)"
    echo "  --config-storage SIZE        Config storage size (default: 500Mi)"
    echo "  --storage-class CLASS        Storage class (default: microk8s-hostpath)"
    echo "  --with-nodeport             Create NodePort service for external access"
    echo "  --node-port PORT            NodePort port (default: 30017)"
    echo "  --force, -f                 Skip confirmation prompts"
    echo "  --help, -h                  Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy with defaults"
    echo "  $0 --namespace hplmn --with-nodeport  # Deploy with external access"
    echo "  $0 --storage-size 2Gi --force         # Deploy with larger storage"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    echo -e "${BLUE}Ensuring namespace $NAMESPACE exists...${NC}"
    microk8s kubectl create namespace $NAMESPACE --dry-run=client -o yaml | microk8s kubectl apply -f -
    echo -e "${GREEN}Namespace $NAMESPACE ready${NC}"
}

# Function to create MongoDB StatefulSet
create_statefulset() {
    echo -e "${BLUE}Creating MongoDB StatefulSet...${NC}"
    
    cat > /tmp/mongodb-statefulset.yaml << EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: $NAMESPACE
  labels:
    app: mongodb
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
        - name: mongodb
          image: mongo:$MONGODB_VERSION
          command: ["mongod", "--bind_ip", "0.0.0.0", "--port", "27017"]
          ports:
            - containerPort: 27017
              name: mongodb
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              value: ""
            - name: MONGO_INITDB_ROOT_PASSWORD
              value: ""
          volumeMounts:
            - name: db-data
              mountPath: /data/db
            - name: db-config
              mountPath: /data/configdb
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            exec:
              command:
                - mongo
                - --eval
                - "db.adminCommand('ping')"
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
          readinessProbe:
            exec:
              command:
                - mongo
                - --eval
                - "db.adminCommand('ping')"
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
  volumeClaimTemplates:
    - metadata:
        name: db-data
        labels:
          app: mongodb
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: $STORAGE_CLASS
        resources:
          requests:
            storage: $STORAGE_SIZE
    - metadata:
        name: db-config
        labels:
          app: mongodb
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: $STORAGE_CLASS
        resources:
          requests:
            storage: $CONFIG_STORAGE
EOF

    # Apply StatefulSet
    microk8s kubectl apply -f /tmp/mongodb-statefulset.yaml
    rm -f /tmp/mongodb-statefulset.yaml
    
    echo -e "${GREEN}MongoDB StatefulSet created successfully${NC}"
}

# Function to create MongoDB ClusterIP Service
create_service() {
    echo -e "${BLUE}Creating MongoDB ClusterIP Service...${NC}"
    
    cat > /tmp/mongodb-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: $NAMESPACE
  labels:
    app: mongodb
spec:
  type: ClusterIP
  selector:
    app: mongodb
  ports:
    - name: mongodb
      port: 27017
      targetPort: 27017
      protocol: TCP
EOF

    # Apply Service
    microk8s kubectl apply -f /tmp/mongodb-service.yaml
    rm -f /tmp/mongodb-service.yaml
    
    echo -e "${GREEN}MongoDB ClusterIP Service created successfully${NC}"
}

# Function to create NodePort Service for external access
create_nodeport_service() {
    if [ "$CREATE_NODEPORT" = true ]; then
        echo -e "${BLUE}Creating MongoDB NodePort Service for external access...${NC}"
        
        cat > /tmp/mongodb-nodeport.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: mongodb-external
  namespace: $NAMESPACE
  labels:
    app: mongodb
spec:
  type: NodePort
  selector:
    app: mongodb
  ports:
    - name: mongodb
      port: 27017
      targetPort: 27017
      nodePort: $NODE_PORT
      protocol: TCP
EOF

        # Apply NodePort Service
        microk8s kubectl apply -f /tmp/mongodb-nodeport.yaml
        rm -f /tmp/mongodb-nodeport.yaml
        
        echo -e "${GREEN}MongoDB NodePort Service created successfully${NC}"
        echo -e "${YELLOW}External access available on port $NODE_PORT${NC}"
    fi
}

# Function to wait for MongoDB to be ready
wait_for_mongodb() {
    echo -e "${BLUE}Waiting for MongoDB to be ready...${NC}"
    
    # Wait for StatefulSet to be ready
    if microk8s kubectl wait --for=condition=ready pods -l app=mongodb --namespace=$NAMESPACE --timeout=180s; then
        echo -e "${GREEN}MongoDB is ready!${NC}"
        
        # Test MongoDB connectivity
        echo -e "${BLUE}Testing MongoDB connectivity...${NC}"
        local mongodb_pod=$(microk8s kubectl get pods -n $NAMESPACE -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
        
        if microk8s kubectl exec -n $NAMESPACE $mongodb_pod -- mongo --eval "db.adminCommand('ping')" &>/dev/null; then
            echo -e "${GREEN}MongoDB connectivity test passed${NC}"
        else
            echo -e "${YELLOW}Warning: MongoDB connectivity test failed, but pod is ready${NC}"
        fi
    else
        echo -e "${RED}Error: MongoDB failed to become ready within timeout${NC}"
        echo -e "${YELLOW}Check pod status with: microk8s kubectl get pods -n $NAMESPACE -l app=mongodb${NC}"
        return 1
    fi
}

# Function to show deployment status
show_status() {
    echo -e "${BLUE}MongoDB Deployment Status:${NC}"
    echo "========================================"
    
    echo -e "${BLUE}Pods:${NC}"
    microk8s kubectl get pods -n $NAMESPACE -l app=mongodb
    
    echo -e "${BLUE}Services:${NC}"
    microk8s kubectl get services -n $NAMESPACE -l app=mongodb
    
    echo -e "${BLUE}StatefulSet:${NC}"
    microk8s kubectl get statefulset -n $NAMESPACE mongodb
    
    echo -e "${BLUE}Persistent Volume Claims:${NC}"
    microk8s kubectl get pvc -n $NAMESPACE
    
    if [ "$CREATE_NODEPORT" = true ]; then
        local vm_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' 2>/dev/null || hostname -I | awk '{print $1}')
        echo ""
        echo -e "${YELLOW}External Access Information:${NC}"
        echo "Connection String: mongodb://$vm_ip:$NODE_PORT"
        echo "MongoDB Compass: mongodb://$vm_ip:$NODE_PORT"
        echo "MongoDB Shell: mongo --host $vm_ip --port $NODE_PORT"
    fi
    
    echo "========================================"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace|-n)
            NAMESPACE="$2"
            shift 2
            ;;
        --storage-size)
            STORAGE_SIZE="$2"
            shift 2
            ;;
        --config-storage)
            CONFIG_STORAGE="$2"
            shift 2
            ;;
        --storage-class)
            STORAGE_CLASS="$2"
            shift 2
            ;;
        --with-nodeport)
            CREATE_NODEPORT=true
            shift
            ;;
        --node-port)
            NODE_PORT="$2"
            CREATE_NODEPORT=true
            shift 2
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
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

# Confirmation prompt unless force mode
if [ "$FORCE" != true ]; then
    echo -e "${YELLOW}MongoDB Deployment Configuration:${NC}"
    echo "Namespace: $NAMESPACE"
    echo "MongoDB Version: $MONGODB_VERSION"
    echo "Data Storage: $STORAGE_SIZE"
    echo "Config Storage: $CONFIG_STORAGE"
    echo "Storage Class: $STORAGE_CLASS"
    echo "External Access: $([ "$CREATE_NODEPORT" = true ] && echo "Yes (Port: $NODE_PORT)" || echo "No")"
    echo ""
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Deployment cancelled${NC}"
        exit 0
    fi
fi

# Main deployment process
echo -e "${BLUE}Starting MongoDB deployment for namespace: $NAMESPACE${NC}"

# Execute deployment steps
create_namespace
create_statefulset
create_service
create_nodeport_service
wait_for_mongodb
show_status

echo -e "${GREEN}MongoDB deployment completed successfully!${NC}"
echo -e "${BLUE}You can now connect other Open5GS components to: mongodb.${NAMESPACE}.svc.cluster.local:27017${NC}"

if [ "$CREATE_NODEPORT" = true ]; then
    echo -e "${YELLOW}External access is configured. Remember to configure firewall if needed:${NC}"
    echo "sudo ufw allow $NODE_PORT"
fi