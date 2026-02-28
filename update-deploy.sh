#!/bin/bash
TAG=${1:-latest}

pgrep -x buildkitd > /dev/null || sudo buildkitd > /dev/null 2>&1 &
sleep 2

echo "Fetching freshest base image (tag: $TAG)..."
sudo nerdctl --namespace k8s.io pull ghcr.io/openclaw/openclaw:$TAG

echo "Building directly into Kubernetes' brain..."
sudo nerdctl --namespace k8s.io build --build-arg OPENCLAW_TAG=$TAG  -t ghcr.io/albindalbert/sententia:latest .

echo "Nuking the old pod..."
kubectl delete pod openclaw-gateway-0 -n openclaw

echo "Done! The new pod is spinning up."
