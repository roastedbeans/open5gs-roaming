# Open5GS Kubernetes Roaming Setup Guide

This guide provides instructions for manually setting up a complete Open5GS Kubernetes roaming environment.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Docker Setup](#docker-setup)
- [MicroK8s (Kubernetes) Setup](#microk8s-kubernetes-setup)
- [Pulling Docker Images](#pulling-docker-images)
- [Generating TLS Certificates](#generating-tls-certificates)
- [Setting Up Kubernetes Secrets](#setting-up-kubernetes-secrets)
- [Deploying Network Components](#deploying-network-components)
- [Verification and Troubleshooting](#verification-and-troubleshooting)

## Prerequisites

### Hardware Requirements
- Ubuntu 22.04 VM or physical machine
- Minimum 8GB RAM (16GB recommended)
- 4+ CPU cores
- 40GB+ disk space

### Network Requirements
- Internet access to pull Docker images
- No firewall blocking internal pod-to-pod communication
- If using a VM, ensure it's configured with bridge networking

## Docker Setup

Install Docker on Ubuntu 22.04:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group to run docker without sudo
sudo usermod -aG docker $USER

# Apply changes to current session
newgrp docker
```

Verify Docker installation:

```bash
docker --version
docker run hello-world
```

## MicroK8s (Kubernetes) Setup

Install MicroK8s:

```bash
# Install MicroK8s
sudo snap install microk8s --classic --channel=1.28/stable

# Add your user to the microk8s group
sudo usermod -aG microk8s $USER

# Create .kube directory for config
mkdir -p ~/.kube
sudo chown -f -R $USER ~/.kube

# Apply the group changes to current shell (or logout and login again)
newgrp microk8s
```

Configure MicroK8s:

```bash
# Wait for MicroK8s to be ready
microk8s status --wait-ready

# Enable required addons
microk8s enable dns storage helm3

# Create alias for kubectl
echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
source ~/.bashrc

# Create namespaces for HPLMN and VPLMN
kubectl create namespace hplmn
kubectl create namespace vplmn
```

## Pulling Docker Images

Pull all necessary Open5GS component images:

```bash
# Set the version variable
OPEN5GS_VERSION="v2.7.5"

# Pull all required Open5GS component images
for component in base-open5gs amf ausf bsf nrf nssf pcf scp sepp smf udm udr upf webui; do
  echo "Pulling docker.io/vinch05/${component}:${OPEN5GS_VERSION}..."
  docker pull docker.io/vinch05/${component}:${OPEN5GS_VERSION}
done

# Pull tcpdump image for network packet capture
docker pull corfr/tcpdump

# Verify images
docker images | grep -E "vinch05|tcpdump"
```

## Generating TLS Certificates

Generate TLS certificates for secure SEPP communication:

```bash
# Navigate to the cert directory
cd k8s-roaming/cert

# Create script if it doesn't exist
cat > generate-sepp-certs.sh << 'EOF'
#!/bin/bash

set -e

TLS_DIR="./open5gs_tls"
mkdir -p "$TLS_DIR"

echo "✅ Creating CA..."
openssl genrsa -out $TLS_DIR/ca.key 2048
openssl req -x509 -new -nodes -key $TLS_DIR/ca.key -sha256 -days 365 \
    -out $TLS_DIR/ca.crt -subj "/CN=SEPP Test CA"

# === Function to generate cert ===
generate_cert() {
  NAME=$1
  CN=$2
  echo "🔐 Generating key and cert for $NAME ($CN)..."
  openssl genrsa -out $TLS_DIR/${NAME}.key 2048
  openssl req -new -key $TLS_DIR/${NAME}.key -out $TLS_DIR/${NAME}.csr \
    -subj "/CN=${CN}"
  openssl x509 -req -in $TLS_DIR/${NAME}.csr -CA $TLS_DIR/ca.crt -CAkey $TLS_DIR/ca.key \
    -CAcreateserial -out $TLS_DIR/${NAME}.crt -days 365 -sha256
  rm $TLS_DIR/${NAME}.csr
}

# === HPLMN (mnc001.mcc001) ===
generate_cert "sepp-hplmn-n32c" "sepp1.5gc.mnc001.mcc001.3gppnetwork.org"
generate_cert "sepp-hplmn-n32f" "sepp2.5gc.mnc001.mcc001.3gppnetwork.org"

# === VPLMN (mnc070.mcc999) ===
generate_cert "sepp-vplmn-n32c" "sepp1.5gc.mnc070.mcc999.3gppnetwork.org"
generate_cert "sepp-vplmn-n32f" "sepp2.5gc.mnc070.mcc999.3gppnetwork.org"

echo "✅ All certificates generated in: $TLS_DIR"
ls -l $TLS_DIR
EOF

# Make script executable
chmod +x generate-sepp-certs.sh

# Run certificate generation script
./generate-sepp-certs.sh
```

## Setting Up Kubernetes Secrets

Create Kubernetes secrets for TLS certificates:

```bash
# Create secrets for VPLMN
kubectl -n vplmn create secret generic sepp-ca --from-file=ca.crt=./open5gs_tls/ca.crt
kubectl -n vplmn create secret generic sepp-n32c --from-file=key=./open5gs_tls/sepp-vplmn-n32c.key --from-file=cert=./open5gs_tls/sepp-vplmn-n32c.crt
kubectl -n vplmn create secret generic sepp-n32f --from-file=key=./open5gs_tls/sepp-vplmn-n32f.key --from-file=cert=./open5gs_tls/sepp-vplmn-n32f.crt

# Create secrets for HPLMN
kubectl -n hplmn create secret generic sepp-ca --from-file=ca.crt=./open5gs_tls/ca.crt
kubectl -n hplmn create secret generic sepp-n32c --from-file=key=./open5gs_tls/sepp-hplmn-n32c.key --from-file=cert=./open5gs_tls/sepp-hplmn-n32c.crt
kubectl -n hplmn create secret generic sepp-n32f --from-file=key=./open5gs_tls/sepp-hplmn-n32f.key --from-file=cert=./open5gs_tls/sepp-hplmn-n32f.crt
```

## Deploying Network Components

### 1. Deploy HPLMN Components

HPLMN (Home Public Land Mobile Network) components should be deployed first:

```bash
# Navigate to the HPLMN directory
cd ../hplmn

# Deploy core HPLMN components in the correct order
kubectl apply -f nrf/
kubectl apply -f scp/
kubectl apply -f udr/
kubectl apply -f udm/
kubectl apply -f ausf/
kubectl apply -f sepp/

# Wait for HPLMN components to be ready
kubectl -n hplmn wait --for=condition=Ready pods --all --timeout=300s
```

### 2. Deploy VPLMN Components

VPLMN (Visited Public Land Mobile Network) components should be deployed next:

```bash
# Navigate to the VPLMN directory
cd ../vplmn

# Deploy core VPLMN components in the correct order
kubectl apply -f nrf/
kubectl apply -f scp/
kubectl apply -f udr/
kubectl apply -f udm/
kubectl apply -f ausf/
kubectl apply -f pcf/
kubectl apply -f bsf/
kubectl apply -f nssf/
kubectl apply -f sepp/
kubectl apply -f smf/
kubectl apply -f upf/
kubectl apply -f amf/

# Wait for VPLMN components to be ready
kubectl -n vplmn wait --for=condition=Ready pods --all --timeout=300s
```

## Verification and Troubleshooting

### Verify Deployment

Check the status of all pods in both namespaces:

```bash
# Check HPLMN pods
kubectl get pods -n hplmn

# Check VPLMN pods
kubectl get pods -n vplmn

# Check services
kubectl get services -n hplmn
kubectl get services -n vplmn
```

### Check Logs

View logs of key components to verify correct operation:

```bash
# Check NRF logs (network registry function)
kubectl -n hplmn logs -l app=nrf
kubectl -n vplmn logs -l app=nrf

# Check SEPP logs (security edge protection proxy - critical for roaming)
kubectl -n hplmn logs -l app=sepp
kubectl -n vplmn logs -l app=sepp

# Check AMF logs (access and mobility management function)
kubectl -n vplmn logs -l app=amf
```

### Packet Capture

Extract packet captures for analysis (requires Wireshark on your local machine):

```bash
# Create directory for packet captures
mkdir -p ~/pcap-analysis

# Extract PCAP files from SEPP pods
kubectl -n vplmn cp $(kubectl -n vplmn get pod -l app=sepp -o jsonpath='{.items[0].metadata.name}'):/pcap/sepp.pcap ~/pcap-analysis/vplmn-sepp.pcap
kubectl -n hplmn cp $(kubectl -n hplmn get pod -l app=sepp -o jsonpath='{.items[0].metadata.name}'):/pcap/sepp.pcap ~/pcap-analysis/hplmn-sepp.pcap
```

### Cleanup

When you need to remove the deployment:

```bash
# Delete VPLMN components first
kubectl delete namespace vplmn

# Then delete HPLMN components
kubectl delete namespace hplmn
```

## Additional Information

### Network Configuration

The deployment assumes the following network configuration:
- HPLMN: MCC=001, MNC=001
- VPLMN: MCC=999, MNC=070

### Image Version

This deployment uses Open5GS version v2.7.5 by default. To use a different version, modify the `OPEN5GS_VERSION` variable when pulling images.

### Automation Script

You can also use the provided automation scripts:

```bash
# Pull all Docker images
./scripts-cli.sh pull-images

# Deploy the full roaming setup
./scripts-cli.sh deploy-roaming
``` 