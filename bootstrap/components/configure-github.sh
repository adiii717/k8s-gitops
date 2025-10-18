#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load configuration
if [[ -f "${REPO_ROOT}/config.env" ]]; then
    source "${REPO_ROOT}/config.env"
fi

# Default values if not set in config
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
GITHUB_REPO_URL="${GITHUB_REPO_URL:-git@github.com:adiii717/k8s-gitops.git}"
GITHUB_SSH_KEY_PATH="${GITHUB_SSH_KEY_PATH:-~/.ssh/id_ed25519}"
GITHUB_SSH_KEY_NAME="${GITHUB_SSH_KEY_NAME:-id_ed25519}"

# Expand tilde in path
GITHUB_SSH_KEY_PATH="${GITHUB_SSH_KEY_PATH/#\~/$HOME}"

echo "Configuring ArgoCD with GitHub repository..."
echo ""

# Check if SSH key exists
if [[ ! -f "${GITHUB_SSH_KEY_PATH}" ]]; then
    echo "Error: SSH key not found at ${GITHUB_SSH_KEY_PATH}"
    exit 1
fi

# Read SSH private key
SSH_PRIVATE_KEY=$(cat "${GITHUB_SSH_KEY_PATH}")

# Create Kubernetes secret for SSH key
echo "Creating SSH key secret in ArgoCD namespace..."
kubectl create secret generic github-ssh-key \
    --from-literal=sshPrivateKey="${SSH_PRIVATE_KEY}" \
    -n ${ARGOCD_NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

# Label the secret for ArgoCD
kubectl label secret github-ssh-key \
    argocd.argoproj.io/secret-type=repository \
    -n ${ARGOCD_NAMESPACE} \
    --overwrite

# Add repository to ArgoCD
echo "Registering GitHub repository with ArgoCD..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: k8s-gitops-repo
  namespace: ${ARGOCD_NAMESPACE}
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ${GITHUB_REPO_URL}
  sshPrivateKey: |
$(echo "${SSH_PRIVATE_KEY}" | sed 's/^/    /')
EOF

echo ""
echo "======================================"
echo "GitHub configuration completed!"
echo "======================================"
echo ""
echo "Repository: ${GITHUB_REPO_URL}"
echo "SSH Key: ${GITHUB_SSH_KEY_PATH}"
echo ""
echo "ArgoCD is now configured to access your GitHub repository."
echo ""
