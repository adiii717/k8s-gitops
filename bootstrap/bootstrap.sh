#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPONENTS_DIR="${SCRIPT_DIR}/components"
CONFIG_FILE="${REPO_ROOT}/config.env"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load configuration
if [[ -f "${CONFIG_FILE}" ]]; then
    echo -e "${YELLOW}Loading configuration from config.env...${NC}"
    source "${CONFIG_FILE}"
    echo -e "Environment: ${ENVIRONMENT:-local-k8s}"
    echo ""
fi

# Available components
AVAILABLE_COMPONENTS=("argocd" "configure-github")

usage() {
    echo "Usage: $0 [component1] [component2] ..."
    echo ""
    echo "Available components:"
    for component in "${AVAILABLE_COMPONENTS[@]}"; do
        echo "  - ${component}"
    done
    echo ""
    echo "Examples:"
    echo "  $0 argocd              # Install only ArgoCD"
    echo "  $0 argocd cert-manager # Install multiple components"
    echo "  $0 all                 # Install all components"
    exit 1
}

check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    local missing_tools=false

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed${NC}"
        missing_tools=true
    fi

    # Check Helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}Error: Helm is not installed${NC}"
        echo -e "${YELLOW}To install Helm, run:${NC}"
        echo ""
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install helm"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        else
            echo "  Visit: https://helm.sh/docs/intro/install/"
        fi
        echo ""
        missing_tools=true
    fi

    if [[ "$missing_tools" == "true" ]]; then
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Unable to connect to Kubernetes cluster${NC}"
        exit 1
    fi

    echo -e "${GREEN}Prerequisites check passed${NC}"
    echo ""
}

install_component() {
    local component=$1
    local component_script="${COMPONENTS_DIR}/${component}.sh"

    if [[ ! -f "${component_script}" ]]; then
        echo -e "${RED}Error: Component '${component}' not found${NC}"
        return 1
    fi

    echo -e "${GREEN}Installing ${component}...${NC}"
    chmod +x "${component_script}"
    bash "${component_script}"
    echo ""
}

# Main execution
if [[ $# -eq 0 ]]; then
    usage
fi

check_prerequisites

# Process arguments
if [[ "$1" == "all" ]]; then
    for component in "${AVAILABLE_COMPONENTS[@]}"; do
        install_component "${component}"
    done
else
    for component in "$@"; do
        install_component "${component}"
    done
fi

echo -e "${GREEN}Bootstrap completed successfully!${NC}"
