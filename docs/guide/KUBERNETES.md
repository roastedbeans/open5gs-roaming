# Kubernetes Guide for Open5GS

This guide covers MicroK8s deployment and configuration for Open5GS 5G Core Network with roaming capabilities.

## 📋 Quick Reference

| Component   | Purpose              | Namespace     |
| ----------- | -------------------- | ------------- |
| **HPLMN**   | Home Network         | `hplmn`       |
| **VPLMN**   | Visited Network      | `vplmn`       |
| **CoreDNS** | 3GPP FQDN resolution | `kube-system` |
| **MongoDB** | Subscriber database  | `hplmn`       |

---

## ☸️ MicroK8s Setup

### Installation

```bash
# Install MicroK8s
sudo snap install microk8s --classic --channel=1.28/stable

# Add user to microk8s group
sudo usermod -aG microk8s $USER

# Log out and back in, then verify
microk8s status --wait-ready
```

### Enable Required Addons

```bash
# Enable essential addons
microk8s enable dns storage helm3

# Optional addons for additional features
microk8s enable dashboard        # Web dashboard
microk8s enable registry        # Local registry
microk8s enable ingress         # Ingress controller
microk8s enable metrics-server  # Resource metrics
```

### Create Namespaces

```bash
# Create namespaces for HPLMN and VPLMN
microk8s kubectl create namespace hplmn
microk8s kubectl create namespace vplmn

# Verify namespaces
microk8s kubectl get namespaces
```

---

## 🌐 CoreDNS Configuration for 3GPP Network Names

### Why DNS Rewrite Rules Are Needed

5G networks use specific FQDN patterns defined by 3GPP standards:

- **HPLMN**: `service.5gc.mnc001.mcc001.3gppnetwork.org`
- **VPLMN**: `service.5gc.mnc070.mcc999.3gppnetwork.org`

These must be mapped to Kubernetes internal DNS names.

### Configure CoreDNS

```bash
# Edit CoreDNS configuration
microk8s kubectl edit configmap coredns -n kube-system
```

**Add these rewrite rules to the Corefile section:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
      errors
      health {
        lameduck 5s
      }
      ready
      
      # HPLMN DNS Rewrite Rules (MNC: 001, MCC: 001)
      rewrite name nrf.5gc.mnc001.mcc001.3gppnetwork.org nrf.hplmn.svc.cluster.local
      rewrite name udr.5gc.mnc001.mcc001.3gppnetwork.org udr.hplmn.svc.cluster.local
      rewrite name udm.5gc.mnc001.mcc001.3gppnetwork.org udm.hplmn.svc.cluster.local
      rewrite name ausf.5gc.mnc001.mcc001.3gppnetwork.org ausf.hplmn.svc.cluster.local
      rewrite name sepp.5gc.mnc001.mcc001.3gppnetwork.org sepp.hplmn.svc.cluster.local
      rewrite name sepp1.5gc.mnc001.mcc001.3gppnetwork.org sepp-n32c.hplmn.svc.cluster.local
      rewrite name sepp2.5gc.mnc001.mcc001.3gppnetwork.org sepp-n32f.hplmn.svc.cluster.local
      
      # VPLMN DNS Rewrite Rules (MNC: 070, MCC: 999)
      rewrite name nrf.5gc.mnc070.mcc999.3gppnetwork.org nrf.vplmn.svc.cluster.local
      rewrite name udr.5gc.mnc070.mcc999.3gppnetwork.org udr.vplmn.svc.cluster.local
      rewrite name udm.5gc.mnc070.mcc999.3gppnetwork.org udm.vplmn.svc.cluster.local
      rewrite name pcf.5gc.mnc070.mcc999.3gppnetwork.org pcf.vplmn.svc.cluster.local
      rewrite name upf.5gc.mnc070.mcc999.3gppnetwork.org upf.vplmn.svc.cluster.local
      rewrite name smf.5gc.mnc070.mcc999.3gppnetwork.org smf.vplmn.svc.cluster.local
      rewrite name amf.5gc.mnc070.mcc999.3gppnetwork.org amf.vplmn.svc.cluster.local
      rewrite name bsf.5gc.mnc070.mcc999.3gppnetwork.org bsf.vplmn.svc.cluster.local
      rewrite name nssf.5gc.mnc070.mcc999.3gppnetwork.org nssf.vplmn.svc.cluster.local
      rewrite name ausf.5gc.mnc070.mcc999.3gppnetwork.org ausf.vplmn.svc.cluster.local
      rewrite name sepp.5gc.mnc070.mcc999.3gppnetwork.org sepp.vplmn.svc.cluster.local
      rewrite name sepp1.5gc.mnc070.mcc999.3gppnetwork.org sepp-n32c.vplmn.svc.cluster.local
      rewrite name sepp2.5gc.mnc070.mcc999.3gppnetwork.org sepp-n32f.vplmn.svc.cluster.local
      
      kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
        ttl 30
      }
      prometheus :9153
      forward . /etc/resolv.conf {
        max_concurrent 1000
      }
      cache 30
      loop
      reload
      loadbalance
    }
```

### Apply DNS Configuration

```bash
# Restart CoreDNS to apply changes
microk8s kubectl rollout restart deployment/coredns -n kube-system

# Verify DNS resolution
microk8s kubectl run test-dns --image=nicolaka/netshoot -it --rm -- nslookup nrf.5gc.mnc001.mcc001.3gppnetwork.org
```

---

## 🏗️ Network Function Deployment

### HPLMN Deployment Order

```bash
# Deploy HPLMN components in order
./scripts/kubectl-deploy-hplmn.sh
```

**Deployment order**:

1. **NRF** - Network Repository Function (service registry)
2. **UDR → UDM → AUSF** - User data management chain
3. **SEPP** - Security Edge Protection Proxy
4. **MongoDB** - Database (if exists)
5. **WebUI** - Management interface (port 30999)

### VPLMN Deployment Order

```bash
# Deploy VPLMN components in order
./scripts/kubectl-deploy-vplmn.sh
```

**Deployment order**:

1. **NRF** - Service registry
2. **UDR → UDM → AUSF** - User data management
3. **PCF → BSF → NSSF** - Policy functions
4. **SEPP → SMF** - Core functions
5. **UPF** - User plane function
6. **AMF** - Access management (deployed last)

### Why Order Matters

- **NRF first**: Other services register with NRF
- **Data services before policy**: UDM/UDR provide data for policy decisions
- **AMF last**: Connects to external RAN, needs all internal services ready

---

## 💾 Storage Management

### MongoDB StatefulSet

```bash
# Deploy MongoDB for HPLMN
./scripts/mongodb-hplmn.sh

# With external access
./scripts/mongodb-hplmn.sh --with-nodeport --node-port 30017
```

**Storage configuration**:

- **Storage Class**: `microk8s-hostpath`
- **Data Storage**: 1Gi (configurable)
- **Config Storage**: 500Mi (configurable)
- **Persistence**: StatefulSet with PVC

### Persistent Volumes

```bash
# Check storage status
microk8s kubectl get pv
microk8s kubectl get pvc -A

# View storage usage
microk8s kubectl describe pvc -n hplmn
```

---

## 🔐 TLS and Security

### Certificate Management

```bash
# Generate SEPP certificates
cd k8s-roaming/cert
./generate-sepp-certs.sh

# Deploy certificates as secrets
./scripts/cert-deploy.sh

# Verify secrets
microk8s kubectl get secrets -n hplmn | grep sepp
microk8s kubectl get secrets -n vplmn | grep sepp
```

### SEPP N32 Interface Certificates

- **N32-C Interface**: Consumer interface certificates
- **N32-F Interface**: Forwarder interface certificates
- **CA Certificate**: Root certificate authority
- **Validity**: 365 days, RSA 2048-bit, SHA-256

---

## 🌐 Service Architecture

### Service Types

| Service Type     | Purpose                 | Access          |
| ---------------- | ----------------------- | --------------- |
| **ClusterIP**    | Internal communication  | Cluster only    |
| **NodePort**     | External access         | Node IP + Port  |
| **LoadBalancer** | External load balancing | Cloud providers |

### HPLMN Services

```bash
# Check HPLMN services
microk8s kubectl get services -n hplmn

# Service endpoints
microk8s kubectl get endpoints -n hplmn
```

### VPLMN Services

```bash
# Check VPLMN services
microk8s kubectl get services -n vplmn

# Service endpoints
microk8s kubectl get endpoints -n vplmn
```

---

## 🔍 External Access

### Web Interfaces

- **Open5GS WebUI**: `http://NODE_IP:30999`
- **NetworkUI**: `http://NODE_IP:30998`

### MongoDB External Access

```bash
# Setup external MongoDB access
./scripts/mongodb-access.sh --setup

# Check access status
./scripts/mongodb-access.sh --status

# Remove external access
./scripts/mongodb-access.sh --remove
```

### Get Node IP

```bash
# Get node external IP
microk8s kubectl get nodes -o wide

# Or get internal IP
hostname -I | awk '{print $1}'
```

---

## 📊 Monitoring and Debugging

### Pod Status

```bash
# Check all pods
microk8s kubectl get pods -A

# Check specific namespace
microk8s kubectl get pods -n hplmn -o wide
microk8s kubectl get pods -n vplmn -o wide

# Describe problematic pods
microk8s kubectl describe pod POD_NAME -n NAMESPACE
```

### Logs

```bash
# View pod logs
microk8s kubectl logs -n hplmn deployment/nrf
microk8s kubectl logs -n vplmn deployment/amf

# Follow logs in real-time
microk8s kubectl logs -f -n hplmn deployment/nrf

# Previous container logs
microk8s kubectl logs -p POD_NAME -n NAMESPACE
```

### Resource Usage

```bash
# Node resource usage
microk8s kubectl top nodes

# Pod resource usage
microk8s kubectl top pods -n hplmn
microk8s kubectl top pods -n vplmn
```

---

## 🔧 Troubleshooting

### Common Issues

#### Pods Stuck in Pending

```bash
# Check node resources
microk8s kubectl describe nodes

# Check storage
microk8s kubectl get pv

# Check events
microk8s kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'
```

#### DNS Resolution Issues

```bash
# Test DNS from pod
microk8s kubectl exec -n hplmn deployment/nrf -- nslookup nrf.5gc.mnc001.mcc001.3gppnetwork.org

# Check CoreDNS logs
microk8s kubectl logs -n kube-system deployment/coredns
```

#### Service Communication Failures

```bash
# Check service endpoints
microk8s kubectl get endpoints -n NAMESPACE

# Test service connectivity
microk8s kubectl exec -n hplmn deployment/nrf -- curl -v http://udm.hplmn.svc.cluster.local
```

### Restart Components

```bash
# Restart all pods in namespace
./scripts/restart-pods.sh hplmn
./scripts/restart-pods.sh vplmn

# Restart specific deployment
microk8s kubectl rollout restart deployment/nrf -n hplmn
```

---

## 🧹 Cleanup

### Clean Namespaces

```bash
# Clean specific namespace
microk8s kubectl delete all --all -n hplmn
microk8s kubectl delete pvc --all -n hplmn

# Clean using script
./scripts/microk8s-clean.sh
```

### Reset MicroK8s

```bash
# Reset MicroK8s completely
microk8s reset

# Remove MicroK8s
sudo snap remove microk8s
```

---

## 📚 Reference

### Network Identifiers

- **HPLMN**: MNC=001, MCC=001
- **VPLMN**: MNC=070, MCC=999

### Default Ports

- **HTTP Services**: 80
- **MongoDB**: 27017
- **WebUI**: 30999 (NodePort)
- **NetworkUI**: 30998 (NodePort)
- **MongoDB External**: 30017 (NodePort)

### Useful Commands

```bash
# Get all resources in namespace
microk8s kubectl get all -n hplmn

# Watch pod status
microk8s kubectl get pods -n hplmn -w

# Port forward to service
microk8s kubectl port-forward -n hplmn service/mongodb 27017:27017

# Execute commands in pod
microk8s kubectl exec -it -n hplmn deployment/nrf -- bash
```
