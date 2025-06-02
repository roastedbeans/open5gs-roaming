#!/bin/bash

# Docker Cleanup Script for Open5GS
# This script removes all Open5GS related containers and images

# Define colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Flag for force mode (no confirmation)
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --force|-f)
      FORCE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--force|-f]"
      echo "  --force, -f: Skip confirmation prompt"
      echo "  --help, -h: Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Display warning and ask for confirmation unless force mode is enabled
if [ "$FORCE" != "true" ]; then
  echo -e "${RED}WARNING: This will delete ALL Open5GS containers and images${NC}"
  echo -e "${YELLOW}This operation cannot be undone${NC}"
  echo ""
  read -p "Are you sure you want to continue? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
  fi
fi

echo -e "${BLUE}Starting Docker cleanup for Open5GS...${NC}"

# Step 1: Stop and remove all Open5GS containers
echo -e "${YELLOW}Stopping and removing Open5GS containers...${NC}"
CONTAINERS=$(docker ps -a | grep -E 'open5gs|sepp|webui|networkui|smf|udm|amf|udr|upf|pcf|nrf|ausf|nssf|bsf' | awk '{print $1}')

if [ -n "$CONTAINERS" ]; then
  echo -e "${BLUE}Found the following containers to remove:${NC}"
  docker ps -a | grep -E 'open5gs|sepp|webui|networkui|smf|udm|amf|udr|upf|pcf|nrf|ausf|nssf|bsf'
  docker rm -f $CONTAINERS
  echo -e "${GREEN}Containers removed successfully${NC}"
else
  echo -e "${GREEN}No Open5GS containers found${NC}"
fi

echo "----------------------------------------"

# Step 2: Remove all Open5GS images
echo -e "${YELLOW}Removing Open5GS images...${NC}"
IMAGES=$(docker images | grep -E 'open5gs|sepp|webui|networkui|smf|udm|amf|udr|upf|pcf|nrf|ausf|nssf|bsf' | awk '{print $1":"$2}')

if [ -n "$IMAGES" ]; then
  echo -e "${BLUE}Found the following images to remove:${NC}"
  docker images | grep -E 'open5gs|sepp|webui|networkui|smf|udm|amf|udr|upf|pcf|nrf|ausf|nssf|bsf'
  docker rmi -f $IMAGES
  echo -e "${GREEN}Images removed successfully${NC}"
else
  echo -e "${GREEN}No Open5GS images found${NC}"
fi

echo "----------------------------------------"

# Step 3: Remove dangling images (optional)
if [ "$FORCE" != "true" ]; then
  echo -e "${YELLOW}Do you want to remove dangling images as well? (y/N):${NC} "
  read -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Removing dangling images...${NC}"
    docker image prune -f
    echo -e "${GREEN}Dangling images removed${NC}"
  fi
fi

echo -e "${GREEN}Docker cleanup completed successfully.${NC}"
echo -e "${BLUE}You can now rebuild your Open5GS images.${NC}" 