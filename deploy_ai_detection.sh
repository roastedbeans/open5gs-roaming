#!/bin/bash

# AI Detection Docker Deployment Script
# This script helps deploy the AI Detection service on Docker

set -e

echo "🚀 AI Detection Docker Deployment"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    print_status "Checking Docker status..."
    if ! docker ps >/dev/null 2>&1; then
        print_error "Docker daemon is not running!"
        print_error "Please start Docker Desktop and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Navigate to the correct directory
setup_directory() {
    print_status "Setting up deployment directory..."
    DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/compose-files/ai-detection"

    if [ ! -d "$DEPLOY_DIR" ]; then
        print_error "Deployment directory not found: $DEPLOY_DIR"
        exit 1
    fi

    cd "$DEPLOY_DIR"
    print_success "Changed to deployment directory: $(pwd)"
}

# Start the service
start_service() {
    print_status "Starting AI Detection service..."
    docker-compose up -d

    if [ $? -eq 0 ]; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        exit 1
    fi
}

# Check service health
check_service() {
    print_status "Checking service health..."
    sleep 5  # Wait for service to initialize

    # Check if container is running
    if docker-compose ps | grep -q "Up"; then
        print_success "Container is running"

        # Test health endpoint
        print_status "Testing health endpoint..."
        if curl -s http://localhost:8000/health >/dev/null 2>&1; then
            print_success "Health check passed"
        else
            print_warning "Health check failed - service may still be starting"
        fi
    else
        print_error "Container is not running"
        print_status "Checking logs..."
        docker-compose logs ai-detection
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo ""
    echo "📋 Service Usage Information"
    echo "============================"
    echo ""
    echo "Service URL: http://localhost:8000"
    echo ""
    echo "API Endpoints:"
    echo "  GET  /health          - Health check"
    echo "  GET  /models          - List available models"
    echo "  POST /detect          - Single prediction"
    echo "  POST /detect/batch    - Batch predictions"
    echo ""
    echo "Example API calls:"
    echo "  curl http://localhost:8000/health"
    echo ""
    echo '  curl -X POST http://localhost:8000/detect \''
    echo '    -H "Content-Type: application/json" \''
    echo '    -d '\''{"features": [0.1, 0.2, 0.3, 0.4, 0.5] + [0.0] * 71, "model_type": "mlp"}'\'''
    echo ""
    echo "Management Commands:"
    echo "  docker-compose logs -f ai-detection              # Follow logs"
    echo "  docker-compose exec ai-detection ./entrypoint.sh --benchmark  # Run benchmarks"
    echo "  docker-compose exec ai-detection ./entrypoint.sh --monitor    # Performance monitoring"
    echo "  docker-compose down                                   # Stop service"
}

# Main deployment function
main() {
    echo ""
    check_docker
    setup_directory
    start_service
    check_service
    show_usage

    echo ""
    print_success "🎉 AI Detection service deployed successfully!"
    print_status "Service is running at: http://localhost:8000"
}

# Handle command line arguments
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR/compose-files/ai-detection"

case "${1:-}" in
    "stop")
        cd "$COMPOSE_DIR"
        print_status "Stopping AI Detection service..."
        docker-compose down
        print_success "Service stopped"
        ;;
    "restart")
        cd "$COMPOSE_DIR"
        print_status "Restarting AI Detection service..."
        docker-compose restart
        print_success "Service restarted"
        ;;
    "logs")
        cd "$COMPOSE_DIR"
        docker-compose logs -f ai-detection
        ;;
    *)
        main
        ;;
esac
