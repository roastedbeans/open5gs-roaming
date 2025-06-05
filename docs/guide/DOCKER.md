# Docker Guide for Open5GS

This guide covers Docker image management for Open5GS deployment, including building, pulling, and deploying images.

## 📋 Image Options

| Approach              | Time      | Use Case                              |
| --------------------- | --------- | ------------------------------------- |
| **Pre-built Images**  | 5 min     | Quick deployment, testing             |
| **Build from Source** | 30-45 min | Custom modifications, latest features |
| **Push to Registry**  | 10 min    | Share images, production deployment   |

---

## 🚀 Quick Start: Use Pre-built Images

**Recommended for most users**

```bash
# Pull all Open5GS images (version 2.7.5)
./scripts/pull-docker-images.sh v2.7.5

# Verify images
docker images | grep vinch05
```

**Images pulled from docker.io/vinch05**:

- `amf`, `smf`, `upf`, `nrf`, `udm`, `udr`, `ausf`, `pcf`, `sepp`, `bsf`, `nssf`, `webui`, `networkui`
- `base-open5gs` (base image for all components)
- `corfr/tcpdump` (for packet capture)

---

## 🔨 Building Images from Source

### Prerequisites

```bash
# Install Docker and build tools
sudo apt update
sudo apt install -y docker.io docker-buildx git

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Step 1: Clone Open5GS Source

```bash
# Clone Open5GS repository
git clone https://github.com/open5gs/open5gs.git
cd open5gs

# Checkout specific version for stability
git checkout v2.7.5
```

### Step 2: Build All Images

```bash
# Build all Open5GS components using Docker Buildx
docker buildx bake

# Alternative: Build specific components
docker buildx bake amf smf upf nrf
```

### Step 3: Tag Images with Version

```bash
# Set version for consistency
export VERSION="v2.7.5"

# Tag all images with version
COMPONENTS=("amf" "smf" "upf" "nrf" "udm" "udr" "ausf" "pcf" "sepp" "bsf" "nssf" "webui")

for component in "${COMPONENTS[@]}"; do
    docker tag open5gs/${component}:latest ${component}:${VERSION}
done

# Verify tagged images
docker images | grep ":${VERSION}"
```

---

## 📦 Registry Management

### Push to Docker Hub

#### Method A: Automated Script

```bash
# Set your Docker Hub username
export DOCKERHUB_USERNAME="your-username"

# Edit docker-deploy.sh script to use your username
sed -i "s/your_username/$DOCKERHUB_USERNAME/g" scripts/docker-deploy.sh

# Login to Docker Hub
docker login

# Push all images
./scripts/docker-deploy.sh
```

#### Method B: Manual Push

```bash
# Set your Docker Hub username
export DOCKERHUB_USERNAME="your-username"
export VERSION="v2.7.5"

# Login to Docker Hub
docker login

# Tag and push each image
COMPONENTS=("amf" "smf" "upf" "nrf" "udm" "udr" "ausf" "pcf" "sepp" "bsf" "nssf" "webui")

for component in "${COMPONENTS[@]}"; do
    echo "Pushing $component..."
    docker tag ${component}:${VERSION} ${DOCKERHUB_USERNAME}/${component}:${VERSION}
    docker push ${DOCKERHUB_USERNAME}/${component}:${VERSION}
done
```

### Deploy to Private Registry

```bash
# Login to private registry
docker login your-registry.com

# Tag for private registry
for component in "${COMPONENTS[@]}"; do
    docker tag ${component}:${VERSION} your-registry.com/${component}:${VERSION}
    docker push your-registry.com/${component}:${VERSION}
done
```

---

## ⚙️ MicroK8s Integration

### Import Images to MicroK8s

```bash
# Enable MicroK8s registry
microk8s enable registry

# Import images to local registry (for air-gapped deployment)
./scripts/import.sh

# Verify images in MicroK8s
microk8s ctr images list | grep open5gs
```

### Update Manifests for Local Registry

```bash
# Update all deployment files to use local registry
find k8s-roaming/ -name "*.yaml" -type f -exec sed -i \
    's|image: docker.io/vinch05/|image: localhost:32000/|g' {} \;

# Update image pull policy
find k8s-roaming/ -name "*.yaml" -type f -exec sed -i \
    '/image: localhost:32000/a \        imagePullPolicy: IfNotPresent' {} \;
```

---

## 🔍 Image Management

### Inspect Images

```bash
# Check image details
docker inspect vinch05/amf:v2.7.5

# View image layers
docker history vinch05/amf:v2.7.5

# Test image functionality
docker run --rm vinch05/amf:v2.7.5 open5gs-amfd --version
```

### Verify Pulled Images

```bash
# List all Open5GS images
docker images | grep -E "vinch05|open5gs"

# Check image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep vinch05
```

---

## 🧹 Cleanup

### Remove Open5GS Images

```bash
# Remove all Open5GS images
docker images | grep vinch05 | awk '{print $3}' | xargs docker rmi

# Remove unused images
docker image prune -f
```

### Full Docker Cleanup

```bash
# Use cleanup script
./scripts/docker-clean.sh

# Manual cleanup
docker container prune -f
docker image prune -a -f
docker volume prune -f
```

---

## 🛠️ Advanced Workflows

### Custom Image Registry

```bash
# For custom registry deployment
export REGISTRY_URL="your-registry.com"
export PROJECT_NAME="open5gs"

# Tag and push to custom registry
for component in "${COMPONENTS[@]}"; do
    docker tag ${component}:${VERSION} ${REGISTRY_URL}/${PROJECT_NAME}/${component}:${VERSION}
    docker push ${REGISTRY_URL}/${PROJECT_NAME}/${component}:${VERSION}
done

# Update Kubernetes manifests
find k8s-roaming/ -name "*.yaml" -type f -exec sed -i \
    "s|image: docker.io/vinch05/|image: ${REGISTRY_URL}/${PROJECT_NAME}/|g" {} \;
```

### Multi-platform Builds

```bash
# Build for multiple architectures
docker buildx create --name multiplatform --use
docker buildx build --platform linux/amd64,linux/arm64 --tag your-username/amf:v2.7.5 --push .
```

---

## 🔧 Troubleshooting

### Common Issues

#### Image Pull Failures

```bash
# Check Docker daemon status
sudo systemctl status docker

# Test Docker Hub connectivity
docker pull hello-world

# Login issues
docker logout
docker login
```

#### Build Failures

```bash
# Clean build cache
docker buildx prune -f

# Check available space
df -h

# Verify Docker version
docker --version
docker buildx version
```

#### Registry Issues

```bash
# Check MicroK8s registry
microk8s kubectl get service -n container-registry

# Test registry connectivity
curl -s http://localhost:32000/v2/_catalog
```

---

## 📚 Reference

### Default Image Tags

- **Open5GS Version**: v2.7.5
- **MongoDB**: 4.4
- **Base OS**: Ubuntu 22.04

### Registry Information

- **Default Registry**: docker.io/vinch05
- **MicroK8s Registry**: localhost:32000
- **Image Pull Policy**: IfNotPresent (for local registry)

### Useful Commands

```bash
# Check image digest
docker inspect --format='{{index .RepoDigests 0}}' image:tag

# Export/Import images
docker save image:tag | gzip > image.tar.gz
gunzip -c image.tar.gz | docker load

# Check registry catalog
curl -s http://localhost:32000/v2/_catalog | python3 -m json.tool
```
