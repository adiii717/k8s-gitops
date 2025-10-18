#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

# Load configuration
if [[ -f "${REPO_ROOT}/config.env" ]]; then
    source "${REPO_ROOT}/config.env"
fi

# Default values if not set in config
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-5.51.4}"
ENVIRONMENT="${ENVIRONMENT:-local-k8s}"

echo "Installing ArgoCD via Helm in ${ENVIRONMENT} environment..."

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: Helm is not installed. Please install Helm first."
    exit 1
fi

# Switch context if specified
if [[ -n "${KUBE_CONTEXT}" ]]; then
    kubectl config use-context "${KUBE_CONTEXT}"
fi

# Create namespace
kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add ArgoCD Helm repository
echo "Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD using Helm
echo "Installing ArgoCD chart version ${ARGOCD_CHART_VERSION}..."
helm install argocd argo/argo-cd \
  --namespace ${ARGOCD_NAMESPACE} \
  --version ${ARGOCD_CHART_VERSION} \
  --create-namespace \
  --wait \
  --timeout 10m

# Wait for secret to be created
echo "Waiting for initial admin secret..."
sleep 5

# Extract initial admin password
ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

# Save to .env file
echo "# ArgoCD Credentials" > "${ENV_FILE}"
echo "ARGOCD_ADMIN_PASSWORD=${ARGOCD_PASSWORD}" >> "${ENV_FILE}"
echo "ARGOCD_NAMESPACE=${ARGOCD_NAMESPACE}" >> "${ENV_FILE}"
echo "ARGOCD_CHART_VERSION=${ARGOCD_CHART_VERSION}" >> "${ENV_FILE}"
echo "ENVIRONMENT=${ENVIRONMENT}" >> "${ENV_FILE}"

echo ""
echo "======================================"
echo "ArgoCD installation completed!"
echo "======================================"
echo ""
echo "Installed via: Helm Chart (version ${ARGOCD_CHART_VERSION})"
echo "Initial Admin Password: ${ARGOCD_PASSWORD}"
echo ""
echo "Credentials saved to: ${ENV_FILE}"
echo ""
echo "To access ArgoCD:"
echo "1. Port forward: kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:443"
echo "2. Login at: https://localhost:8080"
echo "   Username: admin"
echo "   Password: ${ARGOCD_PASSWORD}"
echo ""
echo "Note: ArgoCD is now installed via Helm and can be managed by ArgoCD itself later."
echo ""
