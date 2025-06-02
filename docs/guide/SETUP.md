# Open5GS Setup Guide

This guide provides three different approaches to deploy Open5GS 5G Core Network with roaming capabilities. Choose the approach that best fits your needs and expertise level.

## 📋 Setup Options Overview

| Approach | Time | Complexity | Control | Best For |
|----------|------|------------|---------|----------|
| **🤖 Fully Automated** | 15-20 min | Low | Limited | First-time users, demos |
| **🔧 Semi-Automated** | 30-45 min | Medium | Moderate | Learning, customization |
| **📝 Manual** | 1-2 hours | High | Complete | Production, advanced users |

---

## 🤖 Option A: Fully Automated Setup

**Best for**: First-time users, quick demos, testing environments

This approach uses the comprehensive automation script that handles everything from dependency installation to full deployment.

### Prerequisites Check

```bash
# Verify Ubuntu 22.04
lsb_release -a

# Check system resources
free -h        # Minimum 8GB RAM
df -h          # Minimum 50GB free space
nproc          # Minimum 4 CPU cores
```

### Single Command Deployment

```bash
# 1. Clone the repository
git clone https://github.com/your-repo/open5gs-roaming.git
cd open5gs-roaming

# 2. Make CLI executable
chmod +x cli.sh

# 3. Run complete automated setup (15-20 minutes)
./cli.sh setup-roaming --full-setup

# 4. Deploy both networks
./cli.sh deploy-roaming
```

### What the Automated Setup Does

The `setup-roaming` script automatically:

1. **Installs Dependencies** (`install-dep.sh`)
   - Docker CE with buildx
   - MicroK8s 1.28 with required addons
   - Git and OpenSSL tools
   - GTP5G kernel module

2. **Configures MicroK8s**
   - Enables DNS, storage, helm3 addons
   - Creates `hplmn` and `vplmn` namespaces
   - Sets up kubectl alias

3. **Pulls Container Images** (`pull-docker-images.sh`)
   - Downloads all Open5GS v2.7.5 images
   - Pulls utility images (tcpdump, netshoot, mongo)

4. **Generates TLS Certificates** (`generate-sepp-certs.sh`)
   - Creates CA and component certificates
   - Generates SEPP N32 interface certificates

5. **Deploys Certificates** (`cert-deploy.sh`)
   - Creates Kubernetes secrets in both namespaces
   - Mounts certificates for SEPP components

### Quick Verification

```bash
# Check MicroK8s status
microk8s status

# Verify namespaces
microk8s kubectl get namespaces

# Check certificates
microk8s kubectl get secrets -n hplmn | grep sepp
microk8s kubectl get secrets -n vplmn | grep sepp

# Verify images
docker images | grep open5gs
```

---

## 🔧 Option B: Semi-Automated Setup (CLI-Guided)

**Best for**: Learning the deployment process, customization needs, production preparation

This approach uses the CLI with individual commands, giving you control over each step while still leveraging automation.

### Step 1: Environment Preparation

```bash
# Clone repository
git clone https://github.com/your-repo/open5gs-roaming.git
cd open5gs-roaming
chmod +x cli.sh

# Install system dependencies
./cli.sh install-dep

# ⚠️ IMPORTANT: Log out and back in for Docker group changes
```

### Step 2: Container Image Management

#### Option 2A: Use Pre-built Images

```bash
# Pull pre-built images
./cli.sh pull-images -t v2.7.5

# Import images to MicroK8s (for air-gapped deployment)
./cli.sh import-images

# Update configurations to use local registry
./cli.sh update-configs
```

#### Option 2B: Build Your Own Images

See **[DOCKER.md](DOCKER.md)** for complete build instructions, then:

```bash
# After building, deploy to registry
./cli.sh docker-deploy -u your-dockerhub-username

# Update manifests to use your images
find k8s-roaming/ -name "*.yaml" -type f -exec sed -i \
    's|image: docker.io/.*\/|image: docker.io/your-username/|g' {} \;
```

### Step 3: MicroK8s Setup and Configuration

```bash
# Install MicroK8s
sudo snap install microk8s --classic --channel=1.28/stable
sudo usermod -aG microk8s $USER

# Log out and back in, then configure
microk8s status --wait-ready
microk8s enable dns storage helm3

# Create namespaces
microk8s kubectl create namespace hplmn
microk8s kubectl create namespace vplmn

# Configure CoreDNS (see KUBERNETES.md for details)
microk8s kubectl edit configmap coredns -n kube-system
```

### Step 4: Certificate Management

```bash
# Generate TLS certificates for SEPP N32 interfaces
./cli.sh generate-certs

# Verify certificates generated
ls -la scripts/cert/open5gs_tls/

# Deploy certificates as Kubernetes secrets
./cli.sh deploy-certs

# Verify secrets created
microk8s kubectl get secrets -n hplmn
microk8s kubectl get secrets -n vplmn
```

### Step 5: Database Deployment

```bash
# Deploy MongoDB for HPLMN
./cli.sh mongodb-hplmn

# Wait for MongoDB to be ready
microk8s kubectl wait --for=condition=ready pods -l app=mongodb -n hplmn --timeout=120s

# Setup external access (optional)
./cli.sh mongodb-access --setup

# Verify MongoDB status
./cli.sh mongodb-access --status
```

### Step 6: Network Function Deployment

```bash
# Deploy HPLMN components first
./cli.sh deploy-hplmn

# Wait for HPLMN stabilization
sleep 30
microk8s kubectl get pods -n hplmn

# Deploy VPLMN components
./cli.sh deploy-vplmn

# Final verification
microk8s kubectl get pods -n vplmn
```

### Step 7: Subscriber Management

```bash
# Add test subscribers
./cli.sh subscribers --add-range --start-imsi 001011234567891 --end-imsi 001011234567900

# Verify subscribers
./cli.sh subscribers --count-subscribers
./cli.sh subscribers --list-subscribers
```

---

## 📝 Option C: Manual Setup (Complete Control)

**Best for**: Advanced users, production deployments, custom configurations, learning internals

This approach gives you complete control over every aspect of the deployment.

### Step 1: Manual Dependency Installation

#### Install Docker

```bash
# Remove old Docker versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# Update and install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure Docker for non-root use
sudo groupadd docker
sudo usermod -aG docker $USER

# Test Docker installation
sudo docker run hello-world
```

#### Install GTP5G Kernel Module

```bash
# Install build dependencies
sudo apt-get install -y build-essential gcc-12 linux-headers-$(uname -r) git

# Clone and build GTP5G
cd /usr/src
sudo git clone https://github.com/free5gc/gtp5g.git
cd gtp5g
sudo make clean && sudo make && sudo make install

# Load module
sudo modprobe gtp5g
echo "gtp5g" | sudo tee /etc/modules-load.d/gtp5g.conf

# Verify module loaded
lsmod | grep gtp5g
```

### Step 2: Manual MicroK8s Installation and Configuration

#### Install MicroK8s

```bash
# Install MicroK8s
sudo snap install microk8s --classic --channel=1.28/stable

# Configure user permissions
sudo usermod -aG microk8s $USER
mkdir -p ~/.kube
sudo chown -f -R $USER ~/.kube

# Restart session or run
newgrp microk8s

# Verify installation
microk8s status --wait-ready
```

#### Enable Required Addons

```bash
# Enable essential addons
microk8s enable dns
microk8s enable storage
microk8s enable helm3

# Verify addons
microk8s status
```

#### Configure CoreDNS for 3GPP Names

See **[KUBERNETES.md - CoreDNS Configuration](KUBERNETES.md#coredns-configuration-for-3gpp-network-names)** for complete DNS setup.

#### Create Namespaces

```bash
# Create HPLMN namespace
microk8s kubectl create namespace hplmn

# Create VPLMN namespace  
microk8s kubectl create namespace vplmn

# Verify namespaces
microk8s kubectl get namespaces
```

### Step 3: Manual Image Management

For building images manually, see **[DOCKER.md](DOCKER.md)** for complete instructions.

### Step 4: Manual Certificate Generation

#### Generate CA and Certificates

```bash
# Create certificate directory
mkdir -p scripts/cert/open5gs_tls
cd scripts/cert/open5gs_tls

# Generate Certificate Authority
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 \
    -out ca.crt -subj "/CN=SEPP Test CA"

# Generate HPLMN certificates
openssl genrsa -out sepp-hplmn-n32c.key 2048
openssl req -new -key sepp-hplmn-n32c.key -out sepp-hplmn-n32c.csr \
    -subj "/CN=sepp1.5gc.mnc001.mcc001.3gppnetwork.org"
openssl x509 -req -in sepp-hplmn-n32c.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out sepp-hplmn-n32c.crt -days 365 -sha256
rm sepp-hplmn-n32c.csr

# Repeat for all required certificates:
# - sepp-hplmn-n32f
# - sepp-vplmn-n32c  
# - sepp-vplmn-n32f

# Verify certificates
ls -la
```

#### Create Kubernetes Secrets

```bash
# Create HPLMN secrets
microk8s kubectl create secret generic sepp-ca \
    --from-file=ca.crt=ca.crt -n hplmn

microk8s kubectl create secret generic sepp-n32c \
    --from-file=key=sepp-hplmn-n32c.key \
    --from-file=cert=sepp-hplmn-n32c.crt -n hplmn

microk8s kubectl create secret generic sepp-n32f \
    --from-file=key=sepp-hplmn-n32f.key \
    --from-file=cert=sepp-hplmn-n32f.crt -n hplmn

# Create VPLMN secrets
microk8s kubectl create secret generic sepp-ca \
    --from-file=ca.crt=ca.crt -n vplmn

microk8s kubectl create secret generic sepp-n32c \
    --from-file=key=sepp-vplmn-n32c.key \
    --from-file=cert=sepp-vplmn-n32c.crt -n vplmn

microk8s kubectl create secret generic sepp-n32f \
    --from-file=key=sepp-vplmn-n32f.key \
    --from-file=cert=sepp-vplmn-n32f.crt -n vplmn
```

### Step 5: Manual MongoDB Deployment

#### Deploy MongoDB StatefulSet

```bash
# Create MongoDB StatefulSet manifest
cat > mongodb-statefulset.yaml << EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: hplmn
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
        - name: mongodb
          image: mongo:4.4
          command: ["mongod", "--bind_ip", "0.0.0.0", "--port", "27017"]
          ports:
            - containerPort: 27017
          volumeMounts:
            - name: db-data
              mountPath: /data/db
            - name: db-config
              mountPath: /data/configdb
  volumeClaimTemplates:
    - metadata:
        name: db-data
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: microk8s-hostpath
        resources:
          requests:
            storage: 1Gi
    - metadata:
        name: db-config
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: microk8s-hostpath
        resources:
          requests:
            storage: 500Mi
EOF

# Apply StatefulSet
microk8s kubectl apply -f mongodb-statefulset.yaml
```

#### Create MongoDB Service

```bash
# Create MongoDB service
cat > mongodb-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: hplmn
spec:
  type: NodePort
  selector:
    app: mongodb
  ports:
    - protocol: TCP
      port: 27017
      targetPort: 27017
      nodePort: 30017
EOF

# Apply service
microk8s kubectl apply -f mongodb-service.yaml

# Wait for MongoDB to be ready
microk8s kubectl wait --for=condition=ready pods -l app=mongodb -n hplmn --timeout=180s
```

### Step 6: Manual Network Function Deployment

#### Deploy HPLMN Components

```bash
# Deploy in proper order for dependencies

# 1. Deploy NRF first (service registry)
microk8s kubectl apply -f k8s-roaming/hplmn/nrf/

# 2. Deploy core data services
microk8s kubectl apply -f k8s-roaming/hplmn/udr/
microk8s kubectl apply -f k8s-roaming/hplmn/udm/
microk8s kubectl apply -f k8s-roaming/hplmn/ausf/

# 3. Deploy communication services
microk8s kubectl apply -f k8s-roaming/hplmn/scp/
microk8s kubectl apply -f k8s-roaming/hplmn/sepp/

# Wait for all pods to be ready
microk8s kubectl wait --for=condition=ready pods --all -n hplmn --timeout=300s
```

#### Deploy VPLMN Components

```bash
# Deploy in proper order

# 1. Deploy NRF first
microk8s kubectl apply -f k8s-roaming/vplmn/nrf/

# 2. Deploy data services
microk8s kubectl apply -f k8s-roaming/vplmn/udr/
microk8s kubectl apply -f k8s-roaming/vplmn/udm/
microk8s kubectl apply -f k8s-roaming/vplmn/ausf/

# 3. Deploy policy services
microk8s kubectl apply -f k8s-roaming/vplmn/pcf/
microk8s kubectl apply -f k8s-roaming/vplmn/bsf/
microk8s kubectl apply -f k8s-roaming/vplmn/nssf/

# 4. Deploy communication services
microk8s kubectl apply -f k8s-roaming/vplmn/scp/
microk8s kubectl apply -f k8s-roaming/vplmn/sepp/

# 5. Deploy session management
microk8s kubectl apply -f k8s-roaming/vplmn/smf/
microk8s kubectl apply -f k8s-roaming/vplmn/upf/

# 6. Deploy access management (last)
microk8s kubectl apply -f k8s-roaming/vplmn/amf/

# Wait for all pods to be ready
microk8s kubectl wait --for=condition=ready pods --all -n vplmn --timeout=300s
```

### Step 7: Manual Subscriber Management

#### Add Subscribers to MongoDB

```bash
# Get MongoDB pod name
MONGODB_POD=$(microk8s kubectl get pods -n hplmn -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

# Create subscriber addition script
cat > add-subscriber.js << EOF
db = db.getSiblingDB('open5gs');

db.subscribers.updateOne(
    { imsi: "001011234567891" },
    {
        \$setOnInsert: {
            "schema_version": NumberInt(1),
            "imsi": "001011234567891",
            "msisdn": [],
            "imeisv": "1110000000000000",
            "mme_host": [],
            "mm_realm": [],
            "purge_flag": [],
            "slice":[{
                "sst": NumberInt(1),
                "sd": "000001",
                "default_indicator": true,
                "session": [{
                    "name" : "internet",
                    "type" : NumberInt(3),
                    "qos" : {
                        "index": NumberInt(9),
                        "arp": {
                            "priority_level" : NumberInt(8),
                            "pre_emption_capability": NumberInt(1),
                            "pre_emption_vulnerability": NumberInt(1)
                        }
                    },
                    "ambr": {
                        "downlink": {"value": NumberInt(1), "unit": NumberInt(3)},
                        "uplink": {"value": NumberInt(1), "unit": NumberInt(3)}
                    },
                    "pcc_rule": [],
                    "_id": new ObjectId(),
                }],
                "_id": new ObjectId(),
            }],
            "security": {
                "k" : "465B5CE8B199B49FAA5F0A2EE238A6BC",
                "op" : null,
                "opc" : "E8ED289DEBA952E4283B54E88E6183CA",
                "amf" : "8000",
                "sqn" : NumberLong(1184)
            },
            "ambr" : {
                "downlink" : { "value": NumberInt(1), "unit": NumberInt(3)},
                "uplink" : { "value": NumberInt(1), "unit": NumberInt(3)}
            },
            "access_restriction_data": 32,
            "network_access_mode": 2,
            "subscriber_status": 0,
            "operator_determined_barring": 0,
            "subscribed_rau_tau_timer": 12,
            "__v": 0
        }
    },
    { upsert: true }
);

print("Subscriber added successfully");
EOF

# Copy and execute script
microk8s kubectl cp add-subscriber.js hplmn/$MONGODB_POD:/tmp/add-subscriber.js
microk8s kubectl exec -n hplmn $MONGODB_POD -- mongo --quiet /tmp/add-subscriber.js
```

---

## ✅ Post-Deployment Verification

### Universal Verification Steps (All Setup Methods)

```bash
# 1. Check all pods are running
microk8s kubectl get pods -n hplmn -o wide
microk8s kubectl get pods -n vplmn -o wide

# 2. Verify services are accessible
microk8s kubectl get services -n hplmn
microk8s kubectl get services -n vplmn

# 3. Test 3GPP DNS resolution
microk8s kubectl run dns-test --image=nicolaka/netshoot -it --rm -- bash
# Inside pod: nslookup nrf.5gc.mnc001.mcc001.3gppnetwork.org

# 4. Check TLS certificates
microk8s kubectl get secrets -n hplmn | grep sepp
microk8s kubectl get secrets -n vplmn | grep sepp

# 5. Verify MongoDB external access
./cli.sh mongodb-access --status

# 6. Check subscribers
./cli.sh subscribers --count-subscribers

# 7. Monitor component logs
microk8s kubectl logs -n hplmn deployment/nrf --tail=20
microk8s kubectl logs -n vplmn deployment/amf --tail=20
```

### Performance Verification

```bash
# Resource usage
microk8s kubectl top pods -n hplmn
microk8s kubectl top pods -n vplmn
microk8s kubectl top nodes

# Network connectivity test
microk8s kubectl exec -n hplmn deployment/scp -- curl -s http://nrf.5gc.mnc001.mcc001.3gppnetwork.org/nnrf-nfm/v1/nf-instances

# SEPP N32 interface test (if TLS configured)
microk8s kubectl exec -n hplmn deployment/sepp -- curl -k https://sepp-n32c.vplmn.svc.cluster.local:7778
```

---

## 🔗 Next Steps

After successful setup:

- **Configure External Access**: See [KUBERNETES.md - External Access](KUBERNETES.md#external-access-configuration)
- **Add More Subscribers**: Use [SCRIPTS.md - Subscriber Management](SCRIPTS.md#subscriber-management)
- **Monitor Deployment**: Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for monitoring commands
- **Scale Components**: See [KUBERNETES.md - Scaling](KUBERNETES.md#scaling-configuration)

---

## 📚 Related Documentation

- **[← Back to Main README](../README.md)**
- **[Docker Building Guide →](DOCKER.md)**
- **[Kubernetes Configuration →](KUBERNETES.md)**
- **[Scripts Reference →](SCRIPTS.md)**
- **[Troubleshooting Guide →](TROUBLESHOOTING.md)**