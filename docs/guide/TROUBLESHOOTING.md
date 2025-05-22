# Troubleshooting Guide for Open5GS

This guide provides comprehensive troubleshooting solutions for common issues encountered during Open5GS deployment and operation. Use this guide to diagnose and resolve problems quickly.

## 📋 Table of Contents

- [Quick Diagnostic Commands](#quick-diagnostic-commands)
- [Pod and Container Issues](#pod-and-container-issues)
- [Service and Network Issues](#service-and-network-issues)
- [DNS Resolution Problems](#dns-resolution-problems)
- [Certificate and TLS Issues](#certificate-and-tls-issues)
- [MongoDB and Database Issues](#mongodb-and-database-issues)
- [Image and Registry Issues](#image-and-registry-issues)
- [Performance and Resource Issues](#performance-and-resource-issues)
- [MicroK8s Specific Issues](#microk8s-specific-issues)
- [Subscriber Management Issues](#subscriber-management-issues)

---

## 🔍 Quick Diagnostic Commands

### System Status Check

```bash
# Check overall cluster status
microk8s status
microk8s kubectl cluster-info

# Check all pods across namespaces
microk8s kubectl get pods -A

# Check critical system pods
microk8s kubectl get pods -n kube-system

# Check Open5GS pods
microk8s kubectl get pods -n hplmn -o wide
microk8s kubectl get pods -n vplmn -o wide
```

### Resource Overview

```bash
# Check node resources
microk8s kubectl describe nodes
microk8s kubectl top nodes

# Check pod resource usage
microk8s kubectl top pods -n hplmn
microk8s kubectl top pods -n vplmn

# Check persistent volumes
microk8s kubectl get pv
microk8s kubectl get pvc -A
```

### Network and Service Check

```bash
# Check services
microk8s kubectl get services -n hplmn
microk8s kubectl get services -n vplmn

# Check endpoints
microk8s kubectl get endpoints -n hplmn
microk8s kubectl get endpoints -n vplmn

# Check ingress (if enabled)
microk8s kubectl get ingress -A
```

---

## 🔧 Pod and Container Issues

### Issue: Pods Stuck in Pending State

**Symptoms:**
```bash
NAME                    READY   STATUS    RESTARTS   AGE
nrf-xxx                 0/1     Pending   0          5m
```

**Diagnostic Steps:**
```bash
# Check pod details
microk8s kubectl describe pod nrf-xxx -n hplmn

# Check node resources
microk8s kubectl describe nodes

# Check storage availability
microk8s kubectl get pv
microk8s status | grep storage
```

**Common Causes and Solutions:**

#### Insufficient Resources
```bash
# Check resource requests vs available
microk8s kubectl describe nodes | grep -A 5 "Allocated resources"

# Solution: Scale down other pods or add more resources
microk8s kubectl scale deployment nrf --replicas=1 -n hplmn
```

#### Storage Issues
```bash
# Check if storage addon is enabled
microk8s status | grep storage

# Enable storage if needed
microk8s enable storage

# Check storage class
microk8s kubectl get storageclass
```

#### Image Pull Issues
```bash
# Check image pull status
microk8s kubectl describe pod pod-name -n namespace | grep -A 10 Events

# Solution: Pull images manually
./cli.sh pull-images -t v2.7.5
```

### Issue: Pods in CrashLoopBackOff

**Symptoms:**
```bash
NAME                    READY   STATUS             RESTARTS   AGE
amf-xxx                 0/1     CrashLoopBackOff   5          10m
```

**Diagnostic Steps:**
```bash
# Check pod logs
microk8s kubectl logs pod-name -n namespace
microk8s kubectl logs pod-name -n namespace --previous

# Check pod events
microk8s kubectl describe pod pod-name -n namespace
```

**Common Causes and Solutions:**

#### Configuration Issues
```bash
# Check configmap
microk8s kubectl get configmap -n namespace
microk8s kubectl describe configmap component-config -n namespace

# Edit configuration
microk8s kubectl edit configmap component-config -n namespace

# Restart deployment
microk8s kubectl rollout restart deployment/component -n namespace
```

#### Missing Dependencies
```bash
# Check if required services are running
microk8s kubectl get pods -n hplmn | grep nrf
microk8s kubectl get pods -n hplmn | grep mongodb

# Ensure proper deployment order
./cli.sh deploy-hplmn  # Deploy HPLMN first
sleep 30
./cli.sh deploy-vplmn  # Then VPLMN
```

#### Resource Limits
```bash
# Check resource limits
microk8s kubectl describe pod pod-name -n namespace | grep -A 5 Limits

# Increase resources if needed
microk8s kubectl edit deployment component -n namespace
# Modify resources.limits.memory and resources.limits.cpu
```

### Issue: Pods Not Ready

**Symptoms:**
```bash
NAME                    READY   STATUS    RESTARTS   AGE
smf-xxx                 0/1     Running   0          5m
```

**Diagnostic Steps:**
```bash
# Check readiness probe
microk8s kubectl describe pod pod-name -n namespace | grep -A 5 "Readiness"

# Check pod logs for startup issues
microk8s kubectl logs pod-name -n namespace
```

**Solutions:**
```bash
# Increase readiness probe timeout
microk8s kubectl edit deployment component -n namespace
# Modify readinessProbe.timeoutSeconds and initialDelaySeconds

# Check service endpoints
microk8s kubectl get endpoints component -n namespace
```

---

## 🌐 Service and Network Issues

### Issue: Service Communication Failures

**Symptoms:**
- Services cannot reach each other
- Connection refused errors in logs
- Empty service endpoints

**Diagnostic Steps:**
```bash
# Check service status
microk8s kubectl get services -n hplmn -o wide

# Check endpoints
microk8s kubectl get endpoints -n hplmn

# Test service connectivity
microk8s kubectl exec -n hplmn deployment/nrf -- curl -v http://scp.hplmn.svc.cluster.local
```

**Solutions:**

#### Missing or Incorrect Service Configuration
```bash
# Check service configuration
microk8s kubectl describe service component -n namespace

# Verify selectors match pod labels
microk8s kubectl get pods -n namespace --show-labels
microk8s kubectl describe service component -n namespace | grep Selector
```

#### Port Configuration Issues
```bash
# Check if ports match between service and deployment
microk8s kubectl describe service component -n namespace
microk8s kubectl describe deployment component -n namespace | grep -A 5 Ports

# Test specific port
microk8s kubectl exec -n namespace deployment/component -- netstat -tlnp
```

#### Network Policy Restrictions
```bash
# Check network policies
microk8s kubectl get networkpolicy -A

# Temporarily disable to test
microk8s kubectl delete networkpolicy policy-name -n namespace
```

### Issue: External Access Not Working

**Symptoms:**
- Cannot access services from outside cluster
- NodePort services not responding
- Connection timeouts from external clients

**Diagnostic Steps:**
```bash
# Check NodePort services
microk8s kubectl get services -n namespace | grep NodePort

# Check firewall
sudo ufw status
sudo iptables -L -n | grep port-number

# Check if port is listening
sudo netstat -tlnp | grep port-number
```

**Solutions:**

#### NodePort Service Issues
```bash
# Verify NodePort configuration
microk8s kubectl describe service service-name -n namespace

# Test from cluster node
curl http://localhost:nodeport

# Check service type
microk8s kubectl patch service service-name -n namespace -p '{"spec":{"type":"NodePort"}}'
```

#### Firewall Configuration
```bash
# Allow port through firewall
sudo ufw allow port-number

# For MongoDB external access
sudo ufw allow 30017

# For AMF NGAP
sudo ufw allow 31412
```

---

## 🌍 DNS Resolution Problems

### Issue: 3GPP FQDN Resolution Failures

**Symptoms:**
```bash
nslookup: can't resolve 'nrf.5gc.mnc001.mcc001.3gppnetwork.org'
```

**Diagnostic Steps:**
```bash
# Test DNS resolution from pod
microk8s kubectl run dns-test --image=nicolaka/netshoot -it --rm -- nslookup nrf.5gc.mnc001.mcc001.3gppnetwork.org

# Check CoreDNS configuration
microk8s kubectl get configmap coredns -n kube-system -o yaml

# Check CoreDNS pods
microk8s kubectl get pods -n kube-system | grep coredns
```

**Solutions:**

#### Missing DNS Rewrite Rules
```bash
# Edit CoreDNS configuration
microk8s kubectl edit configmap coredns -n kube-system

# Add missing rewrite rules (see KUBERNETES.md for complete rules)
# Example:
rewrite name nrf.5gc.mnc001.mcc001.3gppnetwork.org nrf.hplmn.svc.cluster.local

# Restart CoreDNS
microk8s kubectl rollout restart deployment/coredns -n kube-system
```

#### Incorrect DNS Configuration
```bash
# Verify DNS service
microk8s kubectl get service -n kube-system | grep dns

# Check DNS resolution path
microk8s kubectl exec -n hplmn deployment/nrf -- cat /etc/resolv.conf

# Test internal DNS
microk8s kubectl exec -n hplmn deployment/nrf -- nslookup nrf.hplmn.svc.cluster.local
```

#### CoreDNS Pod Issues
```bash
# Check CoreDNS logs
microk8s kubectl logs -n kube-system deployment/coredns

# Restart CoreDNS if needed
microk8s kubectl delete pods -n kube-system -l k8s-app=kube-dns
```

### Issue: Internal Service Resolution Fails

**Symptoms:**
```bash
nslookup: can't resolve 'scp.hplmn.svc.cluster.local'
```

**Solutions:**
```bash
# Check if service exists
microk8s kubectl get service scp -n hplmn

# Check DNS addon
microk8s status | grep dns
microk8s enable dns  # if not enabled

# Test different DNS queries
microk8s kubectl exec -n hplmn deployment/nrf -- nslookup scp
microk8s kubectl exec -n hplmn deployment/nrf -- nslookup scp.hplmn
microk8s kubectl exec -n hplmn deployment/nrf -- nslookup scp.hplmn.svc.cluster.local
```

---

## 🔐 Certificate and TLS Issues

### Issue: TLS Handshake Failures

**Symptoms:**
```bash
TLS handshake error
SSL certificate verify failed
```

**Diagnostic Steps:**
```bash
# Check certificates exist
microk8s kubectl get secrets -n hplmn | grep sepp
microk8s kubectl get secrets -n vplmn | grep sepp

# Verify certificate content
microk8s kubectl get secret sepp-n32c -n hplmn -o yaml

# Check certificate validity
microk8s kubectl get secret sepp-n32c -n hplmn -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

**Solutions:**

#### Missing Certificates
```bash
# Regenerate certificates
./cli.sh generate-certs

# Deploy certificates
./cli.sh deploy-certs

# Verify deployment
microk8s kubectl describe secret sepp-n32c -n hplmn
```

#### Expired Certificates
```bash
# Check certificate expiration
microk8s kubectl get secret sepp-n32c -n hplmn -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# Regenerate if expired
cd scripts/cert
./generate-sepp-certs.sh
cd ../..
./cli.sh deploy-certs
```

#### Certificate Mounting Issues
```bash
# Check if certificates are mounted in pods
microk8s kubectl describe pod sepp-pod-name -n hplmn | grep -A 10 Mounts

# Check file permissions
microk8s kubectl exec -n hplmn deployment/sepp -- ls -la /etc/open5gs/tls/
```

### Issue: CA Certificate Problems

**Symptoms:**
```bash
certificate signed by unknown authority
```

**Solutions:**
```bash
# Check CA secret
microk8s kubectl get secret sepp-ca -n hplmn -o yaml

# Verify CA is in trust store
microk8s kubectl exec -n hplmn deployment/sepp -- ls -la /etc/open5gs/tls/ca/

# Recreate CA secret if needed
microk8s kubectl delete secret sepp-ca -n hplmn
microk8s kubectl create secret generic sepp-ca \
    --from-file=ca.crt=scripts/cert/open5gs_tls/ca.crt -n hplmn
```

---

## 🗄️ MongoDB and Database Issues

### Issue: MongoDB Connection Failures

**Symptoms:**
```bash
MongoNetworkError: failed to connect to server
```

**Diagnostic Steps:**
```bash
# Check MongoDB pod status
microk8s kubectl get pods -n hplmn -l app=mongodb

# Check MongoDB logs
microk8s kubectl logs -n hplmn -l app=mongodb

# Test internal connectivity
microk8s kubectl exec -n hplmn deployment/udr -- mongo mongodb.hplmn.svc.cluster.local:27017 --eval "db.adminCommand('ping')"
```

**Solutions:**

#### MongoDB Pod Not Running
```bash
# Check MongoDB deployment
microk8s kubectl describe deployment mongodb -n hplmn

# Check storage issues
microk8s kubectl get pvc -n hplmn
microk8s kubectl describe pvc -n hplmn

# Restart MongoDB
microk8s kubectl rollout restart statefulset/mongodb -n hplmn
```

#### Storage Issues
```bash
# Check persistent volume status
microk8s kubectl get pv | grep hplmn

# Check storage class
microk8s kubectl get storageclass
microk8s enable storage  # if needed

# Fix storage permissions
microk8s kubectl exec -n hplmn mongodb-0 -- chown -R mongodb:mongodb /data/db
```

#### Network Connectivity
```bash
# Check MongoDB service
microk8s kubectl get service mongodb -n hplmn

# Test port connectivity
microk8s kubectl exec -n hplmn deployment/udr -- telnet mongodb.hplmn.svc.cluster.local 27017

# Check MongoDB configuration
microk8s kubectl exec -n hplmn mongodb-0 -- mongo --eval "db.adminCommand('getCmdLineOpts')"
```

### Issue: External MongoDB Access Not Working

**Symptoms:**
- Cannot connect to MongoDB from outside cluster
- Connection timeouts on NodePort

**Diagnostic Steps:**
```bash
# Check external access setup
./cli.sh mongodb-access --status

# Test connectivity
./cli.sh mongodb-access --test

# Check NodePort service
microk8s kubectl get service mongodb-external -n hplmn
```

**Solutions:**
```bash
# Setup external access
./cli.sh mongodb-access --setup

# Check firewall
sudo ufw allow 30017

# Test from local machine
mongo --host your-vm-ip --port 30017

# Check if VM port is accessible
telnet your-vm-ip 30017
```

### Issue: Subscriber Operations Failing

**Symptoms:**
```bash
Error: MongoDB pod not found
ERROR: Failed to add subscriber
```

**Diagnostic Steps:**
```bash
# Check subscriber script
./cli.sh subscribers --count-subscribers

# Check MongoDB connectivity
MONGODB_POD=$(microk8s kubectl get pods -n hplmn -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
echo $MONGODB_POD
```

**Solutions:**
```bash
# Ensure MongoDB is running
microk8s kubectl get pods -n hplmn -l app=mongodb

# Test MongoDB access
microk8s kubectl exec -n hplmn $MONGODB_POD -- mongo --eval "db.adminCommand('ping')"

# Check database and collection
microk8s kubectl exec -n hplmn $MONGODB_POD -- mongo open5gs --eval "db.subscribers.count()"

# Re-run subscriber operation
./cli.sh subscribers --add-single --imsi 001011234567891
```

---

## 📦 Image and Registry Issues

### Issue: Image Pull Errors

**Symptoms:**
```bash
Failed to pull image "your-registry/nrf:v2.7.5": rpc error: code = Unknown
```

**Diagnostic Steps:**
```bash
# Check if images exist locally
docker images | grep nrf

# Test registry connectivity
ping docker.io
curl -I https://registry-1.docker.io/v2/

# Check authentication
docker login
```

**Solutions:**

#### Missing Images
```bash
# Pull images manually
./cli.sh pull-images -t v2.7.5

# Build images if needed (see DOCKER.md)
cd /path/to/open5gs
docker buildx bake

# Tag and push if using custom registry
./cli.sh docker-deploy -u your-username
```

#### Registry Authentication
```bash
# Login to registry
docker login your-registry.com

# Check credentials
cat ~/.docker/config.json

# Create registry secret if needed
microk8s kubectl create secret docker-registry regcred \
    --docker-server=your-registry.com \
    --docker-username=your-user \
    --docker-password=your-password
```

#### Wrong Image References
```bash
# Check deployment image references
microk8s kubectl describe deployment nrf -n hplmn | grep Image

# Update image references
./cli.sh update-configs

# Or manually update
find k8s-roaming/ -name "*.yaml" -exec sed -i 's|old-registry|new-registry|g' {} \;
```

### Issue: Image Version Mismatches

**Symptoms:**
- Different component versions causing compatibility issues
- Components failing to start due to API mismatches

**Solutions:**
```bash
# Check current image versions
microk8s kubectl describe deployments -n hplmn | grep Image
microk8s kubectl describe deployments -n vplmn | grep Image

# Update all images to same version
find k8s-roaming/ -name "*.yaml" -exec sed -i 's|:v[0-9\.]*|:v2.7.5|g' {} \;

# Restart deployments
microk8s kubectl rollout restart deployment -n hplmn
microk8s kubectl rollout restart deployment -n vplmn
```

---

## 📊 Performance and Resource Issues

### Issue: High CPU/Memory Usage

**Symptoms:**
```bash
# Pods showing high resource usage
NAME                    CPU(cores)   MEMORY(bytes)
amf-xxx                 500m         800Mi
```

**Diagnostic Steps:**
```bash
# Check resource usage
microk8s kubectl top pods -n hplmn
microk8s kubectl top pods -n vplmn
microk8s kubectl top nodes

# Check resource limits
microk8s kubectl describe pods -n hplmn | grep -A 5 Limits
```

**Solutions:**

#### Increase Resource Limits
```bash
# Edit deployment to increase limits
microk8s kubectl edit deployment component -n namespace

# Example resource configuration:
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

#### Scale Horizontally
```bash
# Scale deployment
microk8s kubectl scale deployment nrf --replicas=3 -n hplmn

# Setup horizontal pod autoscaler
microk8s kubectl autoscale deployment nrf --cpu-percent=70 --min=1 --max=5 -n hplmn
```

#### Optimize Configuration
```bash
# Reduce log verbosity
microk8s kubectl edit configmap component-config -n namespace
# Change log level from debug to info

# Optimize component settings
# Review Open5GS configuration for performance tuning
```

### Issue: Slow Pod Startup

**Symptoms:**
- Pods taking long time to become ready
- Services not available quickly enough

**Solutions:**
```bash
# Adjust readiness probe timing
microk8s kubectl edit deployment component -n namespace

# Example probe configuration:
readinessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 10  # Reduce if startup is fast
  periodSeconds: 5
  timeoutSeconds: 3
```

---

## ☸️ MicroK8s Specific Issues

### Issue: MicroK8s Not Starting

**Symptoms:**
```bash
microk8s is not running
```

**Solutions:**
```bash
# Check MicroK8s status
microk8s status

# Start MicroK8s
microk8s start

# Check system resources
free -h
df -h

# Restart if needed
microk8s stop
microk8s start
```

### Issue: Addon Issues

**Symptoms:**
- DNS addon not working
- Storage addon failing
- Registry addon unavailable

**Diagnostic Steps:**
```bash
# Check addon status
microk8s status

# Check addon logs
microk8s kubectl logs -n kube-system deployment/coredns
```

**Solutions:**
```bash
# Disable and re-enable addon
microk8s disable dns
microk8s enable dns

# Check addon dependencies
microk8s inspect  # Generates diagnostic report

# Reset addon if needed
microk8s reset  # WARNING: This removes all data
```

### Issue: kubectl Permission Denied

**Symptoms:**
```bash
The connection to the server localhost:8080 was refused
```

**Solutions:**
```bash
# Check if user is in microk8s group
groups $USER

# Add user to group
sudo usermod -aG microk8s $USER

# Log out and back in, or run:
newgrp microk8s

# Set up kubectl config
microk8s config > ~/.kube/config
```

---

## 👥 Subscriber Management Issues

### Issue: Subscriber Addition Fails

**Symptoms:**
```bash
ERROR: Failed to add subscriber 001011234567891
```

**Diagnostic Steps:**
```bash
# Check IMSI format
./cli.sh subscribers --add-single --imsi 001011234567891

# Check MongoDB connectivity
./cli.sh mongodb-access --test

# Check subscriber script
./cli.sh subscribers --count-subscribers
```

**Solutions:**
```bash
# Verify IMSI format (15 digits)
./cli.sh subscribers --add-single --imsi 001011234567891

# Check MongoDB is accessible
microk8s kubectl get pods -n hplmn -l app=mongodb

# Try manual MongoDB access
MONGODB_POD=$(microk8s kubectl get pods -n hplmn -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
microk8s kubectl exec -n hplmn $MONGODB_POD -- mongo open5gs --eval "db.subscribers.count()"
```

### Issue: Bulk Subscriber Operations Timeout

**Symptoms:**
- Large subscriber ranges failing
- Timeout errors during batch processing

**Solutions:**
```bash
# Reduce batch size
./cli.sh subscribers --add-range --start-imsi 001011234567891 --end-imsi 001011234567900 --batch-size 5

# Process in smaller ranges
./cli.sh subscribers --add-range --start-imsi 001011234567891 --end-imsi 001011234567895
./cli.sh subscribers --add-range --start-imsi 001011234567896 --end-imsi 001011234567900

# Check MongoDB performance
microk8s kubectl exec -n hplmn mongodb-0 -- mongo --eval "db.stats()"
```

---

## 🚨 Emergency Procedures

### Complete System Reset

If everything fails and you need to start fresh:

```bash
# 1. Clean all Kubernetes resources
./cli.sh clean-k8s -n hplmn --delete-pv --force
./cli.sh clean-k8s -n vplmn --delete-pv --force

# 2. Clean Docker resources
./cli.sh clean-docker --force

# 3. Reset MicroK8s (WARNING: Removes all data)
microk8s reset

# 4. Reinstall and setup
microk8s enable dns storage
./cli.sh setup-roaming --full-setup

# 5. Redeploy
./cli.sh deploy-roaming
```

### Backup and Restore

```bash
# Backup MongoDB data
microk8s kubectl exec -n hplmn mongodb-0 -- mongodump --out /tmp/backup
microk8s kubectl cp hplmn/mongodb-0:/tmp/backup ./mongodb-backup

# Backup Kubernetes configurations
microk8s kubectl get all -n hplmn -o yaml > hplmn-backup.yaml
microk8s kubectl get all -n vplmn -o yaml > vplmn-backup.yaml

# Restore MongoDB data
microk8s kubectl cp ./mongodb-backup hplmn/mongodb-0:/tmp/restore
microk8s kubectl exec -n hplmn mongodb-0 -- mongorestore /tmp/restore
```

---

## 📞 Getting Help

### Collecting Diagnostic Information

```bash
# Generate system report
microk8s inspect > system-report.tar.gz

# Collect logs
mkdir logs
microk8s kubectl logs -n hplmn deployment/nrf > logs/nrf.log
microk8s kubectl logs -n vplmn deployment/amf > logs/amf.log
microk8s kubectl logs -n hplmn -l app=mongodb > logs/mongodb.log

# System information
kubectl version > logs/versions.txt
microk8s status > logs/microk8s-status.txt
docker images > logs/images.txt
```

### Support Channels

- **GitHub Issues**: Create detailed issue with logs and steps to reproduce
- **Documentation**: Check related guides in `docs/` directory
- **Community Forums**: Open5GS GitHub Discussions
- **Official Docs**: [Open5GS Documentation](https://open5gs.org/open5gs/docs/)

### Issue Report Template

```markdown
## Issue Description
Brief description of the problem

## Environment
- OS: Ubuntu 22.04
- MicroK8s version: 1.28
- Open5GS version: v2.7.5
- Deployment method: Automated/Manual

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Logs and Output
```
[Paste relevant logs here]
```

## Additional Context
Any other relevant information
```

---

## 🔗 Related Documentation

- **[← Back to Main README](../README.md)**
- **[Setup Guide](SETUP.md)** - For deployment instructions
- **[Docker Guide](DOCKER.md)** - For container issues
- **[Kubernetes Guide](KUBERNETES.md)** - For K8s-specific problems
- **[Scripts Reference](SCRIPTS.md)** - For automation issues