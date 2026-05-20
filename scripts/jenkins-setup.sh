#!/usr/bin/env bash
set -euo pipefail

# Helper: prepare the local machine so the 'jenkins' system user can access
# Docker and Minikube. Run this locally as your user (it uses sudo).

echo "Adding jenkins user to docker group..."
sudo usermod -aG docker jenkins || true

echo "Restarting jenkins service..."
sudo systemctl restart jenkins

echo "Copying kube config and minikube certs to jenkins home..."
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp -f ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube

sudo mkdir -p /var/lib/jenkins/.minikube
sudo cp -r ~/.minikube/profiles /var/lib/jenkins/.minikube/ || true
if [ -f ~/.minikube/ca.crt ]; then
  sudo cp -f ~/.minikube/ca.crt /var/lib/jenkins/.minikube/
fi
sudo chown -R jenkins:jenkins /var/lib/jenkins/.minikube

echo "Done. Jenkins should now be able to access Docker (if Docker socket permissions allow) and Minikube config."
