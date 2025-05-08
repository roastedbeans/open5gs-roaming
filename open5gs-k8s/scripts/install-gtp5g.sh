#!/bin/bash

set -e

echo "📡 Installing GTP5G kernel module via DaemonSet..."

# Create the DaemonSet manifest
cat > gtp5g-installer.yaml <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gtp5g-installer
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: gtp5g-installer
  template:
    metadata:
      labels:
        name: gtp5g-installer
    spec:
      hostPID: true
      hostNetwork: true
      containers:
      - name: installer
        image: ubuntu:22.04
        securityContext:
          privileged: true
        command:
        - /bin/sh
        - -c
        - |
          apt-get update
          apt-get install -y build-essential git linux-headers-\$(uname -r)
          cd /tmp
          git clone https://github.com/free5gc/gtp5g.git
          cd gtp5g
          make clean
          make
          make install
          modprobe gtp5g
          echo "GTP5G module installed successfully"
          sleep infinity
EOF

# Apply the DaemonSet
kubectl apply -f gtp5g-installer.yaml

echo "👉 GTP5G installer DaemonSet deployed. Waiting for it to start..."
kubectl -n kube-system wait --for=condition=ready pod -l name=gtp5g-installer --timeout=120s

echo "✅ GTP5G installer started successfully. The GTP5G module should now be installed on all nodes."