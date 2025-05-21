#!/bin/bash

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

MONGODB_YAML="k8s-roaming/hplmn/mongodb/mongodb-statefulset.yaml"
NAMESPACE="hplmn"

# Check if YAML file exists
if [ ! -f "$MONGODB_YAML" ]; then
    echo -e "${RED}Error: $MONGODB_YAML not found.${NC}"
    exit 1
fi

echo -e "${BLUE}Ensuring namespace $NAMESPACE exists...${NC}"
microk8s kubectl create namespace $NAMESPACE --dry-run=client -o yaml | microk8s kubectl apply -f -

echo -e "${BLUE}Applying MongoDB StatefulSet for HPLMN...${NC}"
microk8s kubectl apply -f "$MONGODB_YAML" -n $NAMESPACE

echo -e "${GREEN}MongoDB StatefulSet applied to namespace $NAMESPACE.${NC}" 