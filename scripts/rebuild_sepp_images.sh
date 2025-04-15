#!/bin/bash

# Script to rebuild SEPP Docker images with TLS support

set -e # Exit on error

echo "Rebuilding SEPP Docker images with TLS support..."

# Directory setup
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Navigate to the Docker Compose directory
cd compose-files/roaming

# Stop existing containers if they're running
echo "Stopping existing containers..."
docker-compose down

# Remove shared volume to start fresh
echo "Cleaning up old certificates..."
docker volume rm sepp_shared_certs 2>/dev/null || true

# Rebuild only the SEPP images
echo "Rebuilding SEPP images..."
docker-compose build h-sepp v-sepp

echo "Starting containers..."
docker-compose up -d

# Give containers a moment to start and exchange certificates
echo "Waiting for containers to exchange certificates..."
sleep 10

# Show logs to verify certificate generation
echo "Showing SEPP logs to verify certificate generation..."
echo "========================= HOME SEPP LOGS ========================="
docker-compose logs h-sepp
echo "========================= VISITED SEPP LOGS ========================="
docker-compose logs v-sepp

echo ""
echo "Rebuild complete. SEPP containers should now be running with TLS support."
echo "You can test the connectivity with:"
echo "  curl -k https://localhost:10443  # Home SEPP"
echo "  curl -k https://localhost:20443  # Visited SEPP"
echo ""
echo "To verify secure communication between SEPPs, check logs for successful handshakes:"
echo "  docker logs -f h-sepp | grep 'TLS\|handshake'"
echo "  docker logs -f v-sepp | grep 'TLS\|handshake'" 