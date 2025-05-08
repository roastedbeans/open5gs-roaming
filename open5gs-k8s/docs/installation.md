# Installation Guide

This guide provides step-by-step instructions for deploying Open5GS on Kubernetes.

## Prerequisites

- Kubernetes cluster (v1.20 or later)
- kubectl configured to communicate with your cluster
- Helm v3.0 or later
- Linux kernel with GTP5G module support
- Multus CNI support in your cluster

## Installation Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/your-org/open5gs-k8s.git
   cd open5gs-k8s
   ```

2. Install dependencies:

   ```bash
   ./scripts/install-deps.sh
   ```

3. Set up Multus CNI:

   ```bash
   ./scripts/setup-multus.sh
   ```

4. Deploy the infrastructure components:

   ```bash
   kubectl apply -f manifests/infrastructure/
   ```

5. Deploy the home network components:

   ```bash
   kubectl apply -f manifests/home-network/
   ```

6. Deploy the visiting network components:

   ```bash
   kubectl apply -f manifests/visiting-network/
   ```

7. Initialize subscriber data:
   ```bash
   kubectl apply -f manifests/test/init-subscriber.yaml
   ```

## Verifying the Installation

1. Check if all pods are running:

   ```bash
   kubectl get pods -n open5gs
   ```

2. Check the logs of key components:

   ```bash
   kubectl logs -n open5gs deployment/h-nrf
   kubectl logs -n open5gs deployment/h-amf
   kubectl logs -n open5gs deployment/h-smf
   ```

3. Test the network connectivity:
   ```bash
   kubectl apply -f manifests/test/packetrusher.yaml
   ```

## Troubleshooting

If you encounter any issues during installation:

1. Check the pod status:

   ```bash
   kubectl describe pod <pod-name> -n open5gs
   ```

2. Check the logs:

   ```bash
   kubectl logs <pod-name> -n open5gs
   ```

3. Verify network connectivity:
   ```bash
   kubectl exec -it <pod-name> -n open5gs -- ping <target-ip>
   ```

For more detailed troubleshooting information, please refer to the [Troubleshooting Guide](troubleshooting.md).

## Next Steps

After successful installation:

1. Configure your network settings in `manifests/network/multus-networks.yaml`
2. Set up your subscriber data in MongoDB
3. Configure the WebUI for monitoring
4. Set up packet capture for debugging

For more information, please refer to:

- [Architecture Overview](architecture.md)
- [Network Configuration](network-config.md)
- [Troubleshooting Guide](troubleshooting.md)
