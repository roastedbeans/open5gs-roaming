#!/bin/bash

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SERVICE_YAML="k8s-roaming/hplmn/mongodb/service.yaml"
NAMESPACE="hplmn"

echo -e "${BLUE}Applying MongoDB Service for HPLMN...${NC}"
microk8s kubectl apply -f "$SERVICE_YAML" -n $NAMESPACE

echo -e "${GREEN}MongoDB Service applied to namespace $NAMESPACE.${NC}"
echo -e "${GREEN}MongoDB is now accessible at NodePort 30017.${NC}" 