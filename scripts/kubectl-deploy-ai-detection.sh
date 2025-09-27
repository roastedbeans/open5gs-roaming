#!/bin/bash

# AI Detection Service Deployment Script for VPLMN
# This script deploys the AI Detection service to the VPLMN namespace
# Exit on error
set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# VPLMN namespace
NAMESPACE="vplmn"

# Base directory for k8s manifests
BASE_DIR="k8s-roaming"

# Component name
COMPONENT="ai-detection"

echo -e "${BLUE}🚀 Deploying AI Detection Service to VPLMN...${NC}"

# Check if namespace exists
if ! microk8s kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo -e "${RED}Error: Namespace $NAMESPACE does not exist. Please deploy VPLMN core first.${NC}"
    echo -e "${YELLOW}Run: ./kubectl-deploy-vplmn.sh${NC}"
    exit 1
fi

# Change to the component directory
cd "$BASE_DIR/$NAMESPACE/$COMPONENT"

# Apply configmap
if [ -f "configmap.yaml" ]; then
    echo -e "${GREEN}📄 Applying ConfigMap for $COMPONENT...${NC}"
    microk8s kubectl apply -f configmap.yaml -n $NAMESPACE
    echo -e "${GREEN}✅ ConfigMap applied successfully${NC}"
else
    echo -e "${RED}Warning: No configmap.yaml found for $COMPONENT${NC}"
fi

# Apply deployment
if [ -f "deployment.yaml" ]; then
    echo -e "${GREEN}🚀 Applying Deployment for $COMPONENT...${NC}"
    microk8s kubectl apply -f deployment.yaml -n $NAMESPACE
    echo -e "${GREEN}✅ Deployment applied successfully${NC}"
else
    echo -e "${RED}Error: No deployment.yaml found for $COMPONENT${NC}"
    exit 1
fi

# Apply service
if [ -f "service.yaml" ]; then
    echo -e "${GREEN}🌐 Applying Service for $COMPONENT...${NC}"
    microk8s kubectl apply -f service.yaml -n $NAMESPACE
    echo -e "${GREEN}✅ Service applied successfully${NC}"
else
    echo -e "${RED}Warning: No service.yaml found for $COMPONENT${NC}"
fi

# Wait for deployment to be ready
echo -e "${YELLOW}⏳ Waiting for $COMPONENT deployment to be ready...${NC}"
microk8s kubectl wait --for=condition=available --timeout=300s deployment/$COMPONENT -n $NAMESPACE

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 AI Detection Service deployed successfully!${NC}"
    echo -e "${BLUE}📊 Service Information:${NC}"
    echo -e "  • Namespace: $NAMESPACE"
    echo -e "  • Service: ai-detection"
    echo -e "  • Cluster IP: $(microk8s kubectl get svc ai-detection -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')"
    echo -e "  • Port: 8000"
    echo -e "  • NodePort (external): $(microk8s kubectl get svc ai-detection-nodeport -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo 'Not available')"
    echo -e "${BLUE}🔍 Check status:${NC}"
    echo -e "  microk8s kubectl get pods -n $NAMESPACE -l app=ai-detection"
    echo -e "  microk8s kubectl logs -n $NAMESPACE -l app=ai-detection --tail=50"
else
    echo -e "${RED}❌ Deployment failed or timed out${NC}"
    echo -e "${YELLOW}Check status:${NC}"
    echo -e "  microk8s kubectl get pods -n $NAMESPACE"
    echo -e "  microk8s kubectl describe pod -n $NAMESPACE -l app=ai-detection"
    exit 1
fi
