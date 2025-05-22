# Docker Guide for Open5GS

This guide covers building, managing, and deploying Open5GS container images. Whether you're creating custom images or using pre-built ones, this document provides comprehensive Docker workflows.

## 📋 Table of Contents

- [Building Open5GS Images](#building-open5gs-images)
- [Image Management](#image-management)
- [Registry Operations](#registry-operations)
- [Container Deployment](#container-deployment)
- [Troubleshooting](#troubleshooting)

---

## 🔨 Building Open5GS Images

### Prerequisites for Building

```bash
# Install Docker and required tools
sudo apt update
sudo apt install -y docker.io docker-buildx git

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect

# Verify Docker installation
docker --version
docker buildx version
```

### Step 1: Clone and Prepare Open5GS Source

```bash
# Clone the Open5GS repository
git clone https://github.com/open5gs/open5gs.git
cd open5gs

# Checkout specific version (recommended for stability)
git checkout v2.7.5

# Verify the docker directory exists
ls -la docker/
```

### Step 2: Build All Open5GS Images

Open5GS provides a comprehensive build system using Docker Buildx:

```bash
# Build all images using the provided bake file
docker buildx bake

# Alternative: Build specific components only
docker buildx bake amf smf upf nrf

# View built images
docker images | grep open5gs
```

The build process creates these images:

| Component | Local Image Name | Purpose |
|-----------|------------------|---------|
| AMF | `open5gs/amf:latest` | Access & Mobility Management |
| SMF | `open5gs/smf:latest` | Session Management |
| UPF | `open5gs/upf:latest` | User Plane Function |
| NRF | `open5gs/nrf:latest` | Network Repository |
| UDM | `open5gs/udm:latest` | User Data Management |
| UDR | `open5gs/udr:latest` | User Data Repository |
| AUSF | `open5gs/ausf:latest` | Authentication |
| PCF | `open5gs/pcf:latest` | Policy Control |
| SEPP | `open5gs/sepp:latest` | Security Edge |
| SCP | `open5gs/scp:latest` | Service Communication |
| BSF | `open5gs/bsf:latest` | Binding Support |
| NSSF | `open5gs/nssf:latest` | Network Slice Selection |
| WebUI | `open5gs/webui:latest` | Web Management Interface |

### Step 3: Tag Images with Version

After building, the images need proper tagging:

```bash
# Set version for consistency
export VERSION="v2.7.5"

# Tag all Open5GS images with version
docker tag open5gs/amf:latest amf:${VERSION}
docker tag open5gs/smf:latest smf:${VERSION}
docker tag open5gs/upf:latest upf:${VERSION}
docker tag open5gs/nrf:latest nrf:${VERSION}
docker tag open5gs/udm:latest udm:${VERSION}
docker tag open5gs/udr:latest udr:${VERSION}
docker tag open5gs/ausf:latest ausf:${VERSION}
docker tag open5gs/pcf:latest pcf:${VERSION}
docker tag open5gs/sepp:latest sepp:${VERSION}
docker tag open5gs/scp:latest scp:${VERSION}
docker tag open5gs/bsf:latest bsf:${VERSION}
docker tag open5gs/nssf:latest nssf:${VERSION}
docker tag open5gs/webui:latest webui:${VERSION}

# Verify tagged images
docker images | grep ":${VERSION}"
```

---

## 🏗️ Image Management

### Using Pre-built Images

If you prefer using existing images:

```bash
# Pull pre-built images from a registry
./cli.sh pull-images -t v2.7.5

# Or manually pull specific images
docker pull your-registry/amf:v2.7.5
docker pull your-registry/smf:v2.7.5
# ... repeat for all components
```

### Import to MicroK8s Registry

For offline deployments or local development:

```bash
# Import to MicroK8s registry
./cli.sh import-images

# Verify images in MicroK8s
microk8s ctr images list | grep open5gs

# Check registry contents
curl -s http://localhost:32000/v2/_catalog | python3 -m json.tool
```

### Image Inspection and Verification

```bash
# Inspect image details
docker inspect amf:v2.7.5

# Check image layers
docker history amf:v2.7.5

# Verify image functionality
docker run --rm amf:v2.7.5 open5gs-amfd --version
```

---

## 📦 Registry Operations

### Deploy to Docker Hub

#### Method A: Using CLI Script

The project includes an automated script for pushing to Docker Hub:

```bash
# Use the automated CLI command
./cli.sh docker-deploy -u your-dockerhub-username

# The CLI will automatically:
# 1. Prompt for Docker Hub login if needed
# 2. Tag all locally built images
# 3. Push to docker.io/your-username/
# 4. Provide status feedback for each image
```

#### Method B: Manual Docker Hub Push

```bash
# Set your Docker Hub username
export DOCKERHUB_USERNAME="your-username"

# Login to Docker Hub
docker login

# Tag and push each image
docker tag amf:v2.7.5 ${DOCKERHUB_USERNAME}/amf:v2.7.5
docker push ${DOCKERHUB_USERNAME}/amf:v2.7.5

docker tag smf:v2.7.5 ${DOCKERHUB_USERNAME}/smf:v2.7.5
docker push ${DOCKERHUB_USERNAME}/smf:v2.7.5

# Or use a loop for all components:
COMPONENTS=("amf" "smf" "upf" "nrf" "udm" "udr" "ausf" "pcf" "sepp" "scp" "bsf" "nssf" "webui")
VERSION="v2.7.5"

for component in "${COMPONENTS[@]}"; do
    echo "Pushing $component..."
    docker tag ${component}:${VERSION} ${DOCKERHUB_USERNAME}/${component}:${VERSION}
    docker push ${DOCKERHUB_USERNAME}/${component}:${VERSION}
done
```

### Understanding the docker-deploy.sh Script

The provided `docker-deploy.sh` script automates the tagging and pushing process:

```bash
#!/bin/bash
# Located at: scripts/docker-deploy.sh

# Configuration
DOCKERHUB_USERNAME="your_username"  # Will be replaced by CLI

# List of Open5GS images to push
OPEN5GS_IMAGES=(
  "sepp:v2.7.5"
  "webui:v2.7.5" 
  "smf:v2.7.5"
  "udm:v2.7.5"
  "amf:v2.7.5"
  "udr:v2.7.5"
  "upf:v2.7.5"
  "pcf:v2.7.5"
  "nrf:v2.7.5"
  "scp:v2.7.5"
  "ausf:v2.7.5"
  "nssf:v2.7.5"
  "bsf:v2.7.5"
  "base-open5gs:v2.7.5"
)

# Process: Login → Tag → Push each image
for img in "${OPEN5GS_IMAGES[@]}"; do
  # Check if image exists locally
  if docker image inspect "$img" &>/dev/null; then
    # Tag for Docker Hub
    docker tag "$img" "$DOCKERHUB_USERNAME/$img"
    # Push to Docker Hub  
    docker push "$DOCKERHUB_USERNAME/$img"
  fi
done
```

### Private Registry Deployment

For enterprise environments:

```bash
# Login to private registry
docker login your-registry.com

# Tag for private registry
export REGISTRY="your-registry.com"
export USERNAME="your-username"

for component in "${COMPONENTS[@]}"; do
    docker tag ${component}:v2.7.5 ${REGISTRY}/${USERNAME}/${component}:v2.7.5
    docker push ${REGISTRY}/${USERNAME}/${component}:v2.7.5
done
```

---

## 🚀 Container Deployment

### Update Kubernetes Manifests

After building/pushing your images, update the deployment files:

```bash
# Update image references in deployment files
find k8s-roaming/ -name "*.yaml" -type f -exec sed -i \
    's|image: docker.io/.*\/|image: docker.io/your-username/|g' {} \;

# Or use the provided update script
./cli.sh update-configs

# Verify changes
grep -r "image:" k8s-roaming/ | head -5
```

### Test Container Functionality

```bash
# Test individual components
docker run --rm amf:v2.7.5 --help
docker run --rm smf:v2.7.5 --version

# Test with custom config
docker run --rm -v $(pwd)/config:/etc/open5gs amf:v2.7.5 -c /etc/open5gs/amf.yaml
```

### Container Resource Requirements

| Component | Min CPU | Min Memory | Notes |
|-----------|---------|------------|-------|
| AMF | 100m | 256Mi | Access management |
| SMF | 100m | 256Mi | Session management |
| UPF | 200m | 512Mi | User plane traffic |
| NRF | 50m | 128Mi | Service registry |
| UDR | 100m | 256Mi | Database operations |
| UDM | 100m | 256Mi | User management |
| MongoDB | 200m | 512Mi | Database |

---

## 🛠️ Advanced Docker Operations

### Custom Build Options

#### Build with Custom Configuration

```bash
# Build with custom base image
docker buildx bake --set "*.platform=linux/amd64,linux/arm64"

# Build with specific Open5GS commit
git checkout <commit-hash>
docker buildx bake

# Build development version
docker buildx bake --set "*.tags=open5gs/amf:dev"
```

#### Multi-Architecture Builds

```bash
# Enable multi-platform builds
docker buildx create --use --name multiarch

# Build for multiple architectures
docker buildx bake --platform linux/amd64,linux/arm64 --push
```

### Docker Compose Alternative

For simpler deployments, you can use Docker Compose:

```yaml
# docker-compose.yml
version: '3.8'
services:
  mongodb:
    image: mongo:4.4
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
      
  nrf:
    image: your-username/nrf:v2.7.5
    depends_on:
      - mongodb
    volumes:
      - ./config/nrf.yaml:/etc/open5gs/nrf.yaml
      
  # Add other services...
  
volumes:
  mongodb_data:
```

```bash
# Deploy with Docker Compose
docker-compose up -d

# Scale specific services
docker-compose up -d --scale nrf=3
```

---

## 🔧 Troubleshooting

### Common Build Issues

#### Build Failures

```bash
# Check build logs
docker buildx bake --progress plain

# Clean build cache
docker buildx prune

# Build individual components for debugging
docker buildx bake amf --progress plain
```

#### Image Size Issues

```bash
# Check image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Analyze image layers
docker run --rm -it wagoodman/dive:latest your-username/amf:v2.7.5
```

### Registry Issues

#### Push/Pull Problems

```bash
# Check authentication
docker login
cat ~/.docker/config.json

# Verify connectivity
ping docker.io
curl -I https://registry-1.docker.io/v2/

# Check rate limits
docker pull ratelimitpreview/test
```

#### Image Not Found

```bash
# List available tags
curl -s https://registry.hub.docker.com/v2/repositories/your-username/amf/tags/

# Verify local images
docker images | grep your-username
```

### Runtime Issues

#### Container Startup Problems

```bash
# Check container logs
docker logs container-name

# Run container interactively
docker run -it --entrypoint /bin/bash your-username/amf:v2.7.5

# Check file permissions
docker run --rm your-username/amf:v2.7.5 ls -la /opt/open5gs/bin/
```

#### Network Connectivity

```bash
# Test container networking
docker run --rm nicolaka/netshoot ping google.com

# Check port accessibility
docker run --rm your-username/amf:v2.7.5 netstat -tlnp
```

### Performance Optimization

#### Build Performance

```bash
# Use build cache
export DOCKER_BUILDKIT=1

# Parallel builds
docker buildx bake --jobs 4

# Use registry cache
docker buildx bake --cache-from type=registry,ref=your-username/cache
```

#### Runtime Performance

```bash
# Set resource limits
docker run --cpus="0.5" --memory="512m" your-username/amf:v2.7.5

# Monitor resource usage
docker stats
```

---

## 📚 Complete Build and Deploy Workflow

Here's the complete workflow from source to deployment:

```bash
# 1. Clone and build Open5GS
git clone https://github.com/open5gs/open5gs.git
cd open5gs
git checkout v2.7.5
docker buildx bake

# 2. Return to your project directory
cd /path/to/your/open5gs-roaming/

# 3. Tag images with version
export VERSION="v2.7.5"
COMPONENTS=("amf" "smf" "upf" "nrf" "udm" "udr" "ausf" "pcf" "sepp" "scp" "bsf" "nssf" "webui")

for component in "${COMPONENTS[@]}"; do
    docker tag open5gs/${component}:latest ${component}:${VERSION}
done

# 4. Push to Docker Hub using CLI
./cli.sh docker-deploy -u your-dockerhub-username

# 5. Update Kubernetes manifests
./cli.sh update-configs

# 6. Verify images on Docker Hub
echo "Images now available at:"
for component in "${COMPONENTS[@]}"; do
    echo "docker.io/your-dockerhub-username/${component}:v2.7.5"
done
```

---

## 🔗 Related Documentation

- **[← Back to Main README](../README.md)**
- **[Setup Guide](SETUP.md)** - For deployment instructions
- **[Kubernetes Guide](KUBERNETES.md)** - For K8s-specific configurations
- **[Scripts Reference](SCRIPTS.md)** - For automation details
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - For debugging help