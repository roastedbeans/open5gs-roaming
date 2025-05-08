#!/bin/bash

set -e

echo "👤 Creating test subscriber in MongoDB..."

kubectl apply -f manifests/test/init-subscriber.yaml

echo "⏳ Waiting for subscriber initialization job to complete..."
kubectl wait --for=condition=complete job/init-subscriber --timeout=60s

echo "✅ Subscriber initialization complete"
kubectl logs job/init-subscriber