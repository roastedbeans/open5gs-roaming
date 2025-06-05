# Open5GS 5G Roaming Setup Guide

This guide provides three deployment approaches for Open5GS 5G Core Network with roaming capabilities. Choose based on your needs:

## 📋 Setup Options

| Approach              | Time      | Complexity | Best For                   |
| --------------------- | --------- | ---------- | -------------------------- |
| **🤖 Automated**      | 15-20 min | Low        | First-time users, demos    |
| **🔧 Semi-Automated** | 30-45 min | Medium     | Learning, customization    |
| **📝 Manual**         | 1-2 hours | High       | Production, advanced users |

## Prerequisites

- Ubuntu 22.04 LTS
- Minimum 8GB RAM, 50GB storage, 4 CPU cores
- Root/sudo access

---

## 🤖 Option A: Fully Automated Setup

**One-command deployment for quick testing**

```bash
# Clone repository
git clone https://github.com/your-repo/open5gs-roaming.git
cd open5gs-roaming

# Run complete setup (installs everything)
./scripts/setup-k8s-roaming.sh v2.7.5

# Deploy both networks
./scripts/kubectl-deploy-hplmn.sh
./scripts/kubectl-deploy-vplmn.sh
```

**What the script does:**

1. Installs Docker CE and MicroK8s
2. Pulls Open5GS container images (v2.7.5)
3. Generates TLS certificates for SEPP
4. Creates `hplmn` and `vplmn` namespaces
5. Deploys certificates as Kubernetes secrets

**Verification:**

```bash
# Check cluster status
microk8s status

# Check namespaces and pods
microk8s kubectl get pods -n hplmn
microk8s kubectl get pods -n vplmn
```

---

## 🔧 Option B: Semi-Automated Setup

**Step-by-step with individual scripts**

### Step 1: Install Dependencies

```bash
git clone https://github.com/your-repo/open5gs-roaming.git
cd open5gs-roaming

# Install Docker, Git, GTP5G kernel module
./scripts/install-dep.sh

# ⚠️ Log out and back in for Docker group changes
```

### Step 2: Setup MicroK8s and Images

```bash
# Install MicroK8s and pull images
./scripts/setup-k8s-roaming.sh v2.7.5
```

### Step 3: Deploy MongoDB (Optional)

```bash
# Deploy MongoDB for HPLMN (if using database)
./scripts/mongodb-hplmn.sh
```

### Step 4: Deploy Network Functions

```bash
# Deploy HPLMN components first
./scripts/kubectl-deploy-hplmn.sh

# Wait for HPLMN to stabilize, then deploy VPLMN
sleep 30
./scripts/kubectl-deploy-vplmn.sh
```

### Step 5: Add Subscribers

```bash
# Add test subscribers
./scripts/subscribers.sh --add-range --start-imsi 001011234567891 --end-imsi 001011234567900

# Verify subscribers
./scripts/subscribers.sh --count
```

---

## 📝 Option C: Manual Setup

**Complete control over each step**

### Step 1: Install Docker Manually

```bash
# Remove old Docker versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# Install Docker CE
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Step 2: Install MicroK8s

```bash
# Install MicroK8s
sudo snap install microk8s --classic --channel=1.28/stable
sudo usermod -aG microk8s $USER

# Configure (after logging back in)
microk8s status --wait-ready
microk8s enable dns storage helm3

# Create namespaces
microk8s kubectl create namespace hplmn
microk8s kubectl create namespace vplmn
```

### Step 3: Pull Container Images

```bash
# Pull all Open5GS images
./scripts/pull-docker-images.sh v2.7.5

# Verify images
docker images | grep vinch05
```

### Step 4: Configure CoreDNS

```bash
# Edit CoreDNS for 3GPP network names
microk8s kubectl edit configmap coredns -n kube-system
```

Add DNS rewrite rules (see KUBERNETES.md for complete configuration).

### Step 5: Generate and Deploy Certificates

```bash
# Generate TLS certificates for SEPP
cd k8s-roaming/cert
./generate-sepp-certs.sh

# Deploy certificates as secrets
./scripts/cert-deploy.sh
```

### Step 6: Deploy Components

```bash
# Deploy in order: HPLMN first, then VPLMN
./scripts/kubectl-deploy-hplmn.sh
./scripts/kubectl-deploy-vplmn.sh
```

---

## 🔍 Verification and Testing

### Check Deployment Status

```bash
# Check all pods
microk8s kubectl get pods -A

# Check services
microk8s kubectl get services -n hplmn
microk8s kubectl get services -n vplmn

# Check logs
microk8s kubectl logs -n hplmn deployment/nrf
```

### Test DNS Resolution

```bash
# Test 3GPP FQDN resolution
microk8s kubectl run test-dns --image=nicolaka/netshoot -it --rm -- nslookup nrf.5gc.mnc001.mcc001.3gppnetwork.org
```

### Add Test Subscribers

```bash
# Add subscriber range
./scripts/subscribers.sh --add-range --start-imsi 001011234567891 --end-imsi 001011234567900

# List subscribers
./scripts/subscribers.sh --list
```

---

## 🌐 Access Services

### Web Interfaces

- **Open5GS WebUI**: `http://NODE_IP:30999` (HPLMN)
- **NetworkUI**: `http://NODE_IP:30998` (HPLMN)

### MongoDB Access (if deployed with external access)

```bash
# Setup external MongoDB access
./scripts/mongodb-access.sh --setup --node-port 30017

# Connect to MongoDB
mongo --host NODE_IP --port 30017
```

---

## 🛠️ Post-Deployment Management

### Manage Subscribers

```bash
# Add single subscriber
./scripts/subscribers.sh --add --imsi 001011234567891

# Delete all subscribers
./scripts/subscribers.sh --delete-all

# Count subscribers
./scripts/subscribers.sh --count
```

### Restart Components

```bash
# Restart all pods in namespace
./scripts/restart-pods.sh hplmn
./scripts/restart-pods.sh vplmn
```

### Clean Up

```bash
# Clean MicroK8s
./scripts/microk8s-clean.sh

# Clean Docker
./scripts/docker-clean.sh
```

---

## 📚 Next Steps

- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Docker Management**: See [DOCKER.md](DOCKER.md)
- **Kubernetes Details**: See [KUBERNETES.md](KUBERNETES.md)
- **Script Reference**: See [SCRIPTS.md](SCRIPTS.md)
