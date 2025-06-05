# Scripts Reference Guide

This guide documents all scripts in the Open5GS roaming deployment project and their actual functionality.

## 📋 Quick Reference

| Script                    | Purpose                  | Usage                                    |
| ------------------------- | ------------------------ | ---------------------------------------- |
| `setup-k8s-roaming.sh`    | Complete automated setup | `./scripts/setup-k8s-roaming.sh v2.7.5`  |
| `install-dep.sh`          | Install dependencies     | `./scripts/install-dep.sh`               |
| `pull-docker-images.sh`   | Pull container images    | `./scripts/pull-docker-images.sh v2.7.5` |
| `kubectl-deploy-hplmn.sh` | Deploy HPLMN             | `./scripts/kubectl-deploy-hplmn.sh`      |
| `kubectl-deploy-vplmn.sh` | Deploy VPLMN             | `./scripts/kubectl-deploy-vplmn.sh`      |
| `mongodb-hplmn.sh`        | Deploy MongoDB           | `./scripts/mongodb-hplmn.sh`             |
| `subscribers.sh`          | Manage subscribers       | `./scripts/subscribers.sh --help`        |
| `cert-deploy.sh`          | Deploy certificates      | `./scripts/cert-deploy.sh`               |

---

## 🏗️ Core Setup Scripts

### setup-k8s-roaming.sh

**Purpose**: Complete automated deployment orchestrator

**What it does**:

1. Installs Docker CE
2. Installs MicroK8s 1.28
3. Pulls Open5GS container images from `docker.io/vinch05`
4. Generates TLS certificates for SEPP
5. Creates Kubernetes namespaces (`hplmn`, `vplmn`)
6. Deploys certificates as secrets

**Usage**:

```bash
# Full automated setup
./scripts/setup-k8s-roaming.sh v2.7.5

# Without version (defaults to v2.7.5)
./scripts/setup-k8s-roaming.sh
```

**Components pulled**:

- `base-open5gs`, `amf`, `ausf`, `bsf`, `nrf`, `nssf`, `pcf`, `sepp`, `smf`, `udm`, `udr`, `upf`, `webui`, `networkui`
- `corfr/tcpdump` for packet capture

### install-dep.sh

**Purpose**: Install system dependencies

**What it installs**:

1. **Docker CE** with buildx plugin
2. **Git** for repository management
3. **GTP5G kernel module** for 5G support
4. **Build tools** (gcc-12, linux-headers)

**Usage**:

```bash
./scripts/install-dep.sh
# ⚠️ Log out and back in after completion
```

**Post-installation**: User is added to `docker` group, requires re-login.

---

## 🚀 Deployment Scripts

### kubectl-deploy-hplmn.sh

**Purpose**: Deploy HPLMN components in correct order

**Deployment order**:

1. **NRF** (Network Repository Function) - Service registry
2. **UDR → UDM → AUSF** - User data management chain
3. **SEPP** - Security Edge Protection
4. **MongoDB** (if directory exists)
5. **WebUI** (if directory exists) - Port 30999
6. **NetworkUI** (if directory exists) - Port 30998

**Usage**:

```bash
./scripts/kubectl-deploy-hplmn.sh
```

**What it deploys per component**:

- `configmap.yaml` (if exists)
- `deployment.yaml`
- `service.yaml`

### kubectl-deploy-vplmn.sh

**Purpose**: Deploy VPLMN components in correct order

**Deployment order**:

1. **NRF** - Service registry
2. **UDR → UDM → AUSF** - User data management
3. **PCF → BSF → NSSF** - Policy functions
4. **SEPP → SMF** - Core functions
5. **UPF** - User plane function
6. **AMF** - Access management (deployed last)

**Usage**:

```bash
./scripts/kubectl-deploy-vplmn.sh
```

**Why order matters**: AMF connects to external RAN, so all internal services must be ready first.

---

## 🗄️ Database Scripts

### mongodb-hplmn.sh

**Purpose**: Deploy MongoDB StatefulSet for HPLMN

**What it creates**:

- **StatefulSet**: MongoDB 4.4 with persistent storage
- **ClusterIP Service**: Internal cluster access
- **NodePort Service**: External access (optional)
- **PVC**: 1Gi data storage + 500Mi config storage

**Usage**:

```bash
# Basic deployment
./scripts/mongodb-hplmn.sh

# With external access
./scripts/mongodb-hplmn.sh --with-nodeport --node-port 30017

# Custom storage
./scripts/mongodb-hplmn.sh --storage-size 2Gi
```

**Storage**: Uses `microk8s-hostpath` storage class by default.

### mongodb-access.sh

**Purpose**: Manage external MongoDB access

**Operations**:

- `--setup`: Create NodePort service (port 30017)
- `--remove`: Remove NodePort service
- `--status`: Show connection details
- `--test`: Test connectivity

**Usage**:

```bash
# Setup external access
./scripts/mongodb-access.sh --setup

# Check status
./scripts/mongodb-access.sh --status

# Remove external access
./scripts/mongodb-access.sh --remove
```

---

## 👥 Subscriber Management

### subscribers.sh

**Purpose**: Comprehensive subscriber management for 5G core

**Operations**:

- `--add-range`: Add multiple subscribers
- `--add`: Add single subscriber
- `--list`: List all subscribers
- `--count`: Count subscribers
- `--delete-all`: Remove all subscribers

**Usage**:

```bash
# Add subscriber range
./scripts/subscribers.sh --add-range --start-imsi 001011234567891 --end-imsi 001011234567900

# Add single subscriber
./scripts/subscribers.sh --add --imsi 001011234567891

# List all subscribers
./scripts/subscribers.sh --list

# Count subscribers
./scripts/subscribers.sh --count

# Delete all subscribers
./scripts/subscribers.sh --delete-all
```

**Default values**:

- **Key**: `465B5CE8B199B49FAA5F0A2EE238A6BC`
- **OPC**: `E8ED289DEBA952E4283B54E88E6183CA`
- **Batch size**: 100 subscribers per operation

**Custom authentication**:

```bash
./scripts/subscribers.sh --add --imsi 001011234567891 --key CUSTOM_KEY --opc CUSTOM_OPC
```

---

## 🔐 Certificate Management

### cert-deploy.sh

**Purpose**: Deploy TLS certificates as Kubernetes secrets

**What it creates**:

- **CA secrets**: `sepp-ca` in both namespaces
- **N32C secrets**: `sepp-n32c` (consumer interface)
- **N32F secrets**: `sepp-n32f` (forwarder interface)

**Usage**:

```bash
./scripts/cert-deploy.sh
```

**Certificate mapping**:

- **HPLMN**: `sepp-hplmn-n32c.crt/key`, `sepp-hplmn-n32f.crt/key`
- **VPLMN**: `sepp-vplmn-n32c.crt/key`, `sepp-vplmn-n32f.crt/key`

---

## 🐳 Image Management

### pull-docker-images.sh

**Purpose**: Pull all required container images

**Images pulled**:

```bash
# Open5GS components from docker.io/vinch05
vinch05/base-open5gs:v2.7.5
vinch05/amf:v2.7.5
vinch05/ausf:v2.7.5
vinch05/bsf:v2.7.5
vinch05/nrf:v2.7.5
vinch05/nssf:v2.7.5
vinch05/pcf:v2.7.5
vinch05/sepp:v2.7.5
vinch05/smf:v2.7.5
vinch05/udm:v2.7.5
vinch05/udr:v2.7.5
vinch05/upf:v2.7.5
vinch05/webui:v2.7.5
vinch05/networkui:v2.7.5

# Utility images
corfr/tcpdump
```

**Usage**:

```bash
# Pull latest version
./scripts/pull-docker-images.sh v2.7.5

# Pull default version
./scripts/pull-docker-images.sh
```

### docker-deploy.sh

**Purpose**: Push images to Docker Hub

**What it does**:

1. Tags local images with Docker Hub username
2. Pushes all Open5GS images to registry
3. Provides status feedback

**Usage**:

```bash
# Set username and push
DOCKERHUB_USERNAME="your-username" ./scripts/docker-deploy.sh

# Or edit script to set username permanently
```

---

## 🧹 Cleanup Scripts

### microk8s-clean.sh

**Purpose**: Clean MicroK8s deployment

**What it removes**:

- All pods in `hplmn` and `vplmn` namespaces
- Persistent Volume Claims
- Secrets
- ConfigMaps
- Services

**Usage**:

```bash
./scripts/microk8s-clean.sh
```

### docker-clean.sh

**Purpose**: Clean Docker images and containers

**What it removes**:

- Stopped containers
- Unused images
- Open5GS specific images

**Usage**:

```bash
./scripts/docker-clean.sh
```

---

## 🔧 Utility Scripts

### restart-pods.sh

**Purpose**: Restart all pods in a namespace

**Usage**:

```bash
# Restart HPLMN pods
./scripts/restart-pods.sh hplmn

# Restart VPLMN pods
./scripts/restart-pods.sh vplmn
```

### get-status.sh

**Purpose**: Get comprehensive status of deployment

**Usage**:

```bash
./scripts/get-status.sh
```

### pcap-capture.sh

**Purpose**: Start packet capture for debugging

**Usage**:

```bash
./scripts/pcap-capture.sh
```

---

## 🔍 Debugging Scripts

### mongodb44-setup.sh

**Purpose**: Setup MongoDB 4.4 with specific configuration

### coredns-rewrite.sh

**Purpose**: Configure CoreDNS rewrite rules for 3GPP FQDNs

### update.sh

**Purpose**: Update deployment configurations

---

## 📝 Script Dependencies

**Execution order for full deployment**:

1. `install-dep.sh` (requires logout/login)
2. `setup-k8s-roaming.sh`
3. `kubectl-deploy-hplmn.sh`
4. `kubectl-deploy-vplmn.sh`
5. `subscribers.sh` (optional)

**Common script paths**:

- All scripts expect to be run from repository root
- Kubernetes manifests in `k8s-roaming/`
- Certificates in `k8s-roaming/cert/`

**Environment requirements**:

- Ubuntu 22.04 LTS
- Root/sudo access
- Docker group membership
- MicroK8s group membership
