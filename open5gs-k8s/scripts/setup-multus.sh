#!/bin/bash

set -e

echo "☸️ Setting up Kubernetes with Multus CNI..."

# Initialize the Kubernetes cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Set up kubectl for your user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Allow scheduling on the master node (for single-node testing)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Install Flannel as the primary CNI
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Install Multus CNI
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml

# Create the network attachments
kubectl apply -f manifests/network/multus-networks.yaml

# Configure CoreDNS with custom entries
kubectl apply -f manifests/network/coredns-config.yaml

# Restart CoreDNS to apply changes
kubectl -n kube-system rollout restart deployment coredns

echo "✅ Kubernetes cluster with Multus CNI set up successfully"