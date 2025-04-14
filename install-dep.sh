#!/bin/bash

set -e

echo "💻 Starting complete environment setup for Docker, MongoDB, Git, and GTP5G..."

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

sudo docker run hello-world

# === MongoDB Install ===
echo "🍃 Installing MongoDB..."

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl enable mongod
sudo systemctl start mongod
sudo systemctl status mongod --no-pager

# === Git Install ===
echo "🐙 Installing Git..."

sudo apt-get update
sudo apt-get install -y git

git --version

read -p "👉 Enter your Git username: " git_username
read -p "👉 Enter your Git email: " git_email
git config --global user.name "$git_username"
git config --global user.email "$git_email"
git config --global --list

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

lsmod | grep gtp5g || echo "⚠️ Module not loaded. Check build logs."

echo "🎯 All installations completed!"
