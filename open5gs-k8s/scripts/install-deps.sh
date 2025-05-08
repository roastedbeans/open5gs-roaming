#!/bin/bash

set -e

echo "💻 Starting environment setup: Docker, Git, GTP5G..."

# === Docker Install ===
echo "🐳 Installing Docker..."

sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
echo "👤 Adding user '$USER' to Docker group..."
sudo groupadd docker || true
sudo usermod -aG docker $USER

echo "🚨 Logout and login back OR run: newgrp docker"

# === Kubernetes Install ===
echo "☸️ Installing Kubernetes..."

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# === GTP5G Install ===
echo "📡 Installing GTP5G module for 5G kernel support..."

sudo apt-get install -y build-essential linux-headers-$(uname -r) git

cd /usr/src
if [ -d "gtp5g" ]; then
    echo "⚠️ Existing gtp5g directory found, removing..."
    sudo rm -rf gtp5g
fi

sudo git clone https://github.com/free5gc/gtp5g.git
cd gtp5g

sudo make clean
sudo make
sudo make install

if lsmod | grep -q gtp5g; then
    echo "✅ GTP5G module loaded successfully!"
else
    sudo modprobe gtp5g
fi

echo "gtp5g" | sudo tee /etc/modules-load.d/gtp5g.conf

echo "🎯 All installations complete! Docker, Kubernetes, and GTP5G are ready!"