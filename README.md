# K8s GitOps

GitOps repository for Kubernetes application deployments using ArgoCD and Helm with App of Apps pattern.

## Overview

This repository implements a scalable GitOps workflow using:
- **ArgoCD** for continuous deployment
- **Helm** for package management
- **App of Apps pattern** for managing dozens of applications
- **Project-based organization** for clean separation of concerns

## Architecture

```
root-manifest (App of Apps)
    ├── devops (Project)
    │   ├── cert-manager
    │   ├── ingress-nginx
    │   └── metrics-server
    └── frontend (Project)
        ├── app1
        └── app2
```

## Repository Structure

```
.
├── argocd-manifest/             # Helm chart that generates ArgoCD resources
│   ├── Chart.yaml
│   ├── values.yaml             # Root configuration - enables/disables projects
│   ├── root-manifest.yaml      # Bootstrap file to deploy to ArgoCD
│   └── templates/
│       ├── projects.yaml       # Generates AppProjects
│       ├── applications.yaml   # Generates Applications
│       └── applicationsets.yaml # Generates ApplicationSets
├── projects/                    # Project-based organization
│   ├── devops/
│   │   ├── root.yaml           # Defines devops project + all tools
│   │   ├── cert-manager/
│   │   │   └── values.yaml     # Cert-manager helm values
│   │   ├── ingress-nginx/
│   │   │   └── values.yaml     # Ingress-nginx helm values
│   │   └── metrics-server/
│   │       └── values.yaml     # Metrics-server helm values
│   └── frontend/
│       ├── root.yaml           # Defines frontend project + all apps
│       └── app1/
│           └── values.yaml
├── charts/                      # Custom Helm charts (optional)
├── bootstrap/                   # Bootstrap scripts
│   ├── bootstrap.sh
│   └── components/
│       ├── argocd.sh
│       └── configure-github.sh
└── config.env                   # Configuration

```

## Quick Start

### 1. Install ArgoCD

```bash
cd bootstrap
./bootstrap.sh argocd
```

### 2. Configure GitHub Access

```bash
./bootstrap.sh configure-github
```

### 3. Deploy Root Manifest

```bash
kubectl apply -f argocd-manifest/root-manifest.yaml
```

This will:
1. Deploy the `root-manifest` Application
2. Root manifest reads `argocd-manifest/values.yaml` and creates project Applications
3. Each project Application reads its `projects/<project>/root.yaml`
4. Each root.yaml creates the Project and all its child Applications

## How It Works

### Three-Level Hierarchy

1. **Root Level** (`argocd-manifest/values.yaml`):
   ```yaml
   Applications:
     devops:
       enable: true  # Enable/disable entire project
       valueFiles:
         - $values/projects/devops/root.yaml
   ```

2. **Project Level** (`projects/devops/root.yaml`):
   ```yaml
   Projects:
     devops:
       enable: true
       description: DevOps tools

   ApplicationSets:
     cert-manager:
       enable: true  # Enable/disable individual app
       chartVersion: v1.13.2
       valueFiles:
         - $values/projects/devops/cert-manager/values.yaml
   ```

3. **Application Level** (`projects/devops/cert-manager/values.yaml`):
   ```yaml
   installCRDs: true
   replicaCount: 1
   resources:
     limits:
       cpu: 100m
   ```

### Adding New Applications

#### Add to Existing Project

1. Create values directory:
   ```bash
   mkdir -p projects/devops/my-new-tool
   ```

2. Create values file:
   ```bash
   cat > projects/devops/my-new-tool/values.yaml <<EOF
   # My tool helm values
   replicaCount: 1
   EOF
   ```

3. Add to project's root.yaml:
   ```yaml
   ApplicationSets:
     my-new-tool:
       enable: true
       syncWave: 4
       name: my-new-tool
       project: devops
       namespace: my-new-tool
       generators:
         - list:
             elements:
               - cluster: in-cluster
                 url: https://kubernetes.default.svc
                 chartVersion: 1.0.0
       sources:
         - chart: my-new-tool
           repoURL: https://charts.example.com
           targetRevision: '{{.chartVersion}}'
           helm:
             valueFiles:
               - $values/projects/devops/my-new-tool/values.yaml
         - repoURL: git@github.com:adiii717/k8s-gitops.git
           targetRevision: main
           ref: values
   ```

4. Commit and push - ArgoCD syncs automatically!

### Adding New Projects

1. Create project structure:
   ```bash
   mkdir -p projects/backend
   ```

2. Create root.yaml:
   ```bash
   cat > projects/backend/root.yaml <<EOF
   global:
     argocdNamespace: argocd

   Projects:
     backend:
       enable: true
       syncWave: -1
       name: backend
       description: Backend services
       destinations:
         - namespace: '*'
           server: https://kubernetes.default.svc
       sourceRepos:
         - '*'

   Applications:
     api-service:
       enable: true
       syncWave: 1
       name: api-service
       namespace: backend
       project: backend
       sources:
         - repoURL: git@github.com:adiii717/k8s-gitops.git
           targetRevision: main
           path: charts/api-service
           helm:
             valueFiles:
               - $values/projects/backend/api-service/values.yaml
         - repoURL: git@github.com:adiii717/k8s-gitops.git
           targetRevision: main
           ref: values
   EOF
   ```

3. Enable in root manifest (`argocd-manifest/values.yaml`):
   ```yaml
   Applications:
     backend:
       enable: true
       syncWave: 102
       name: backend
       sources:
         - repoURL: git@github.com:adiii717/k8s-gitops.git
           targetRevision: main
           ref: values
         - repoURL: git@github.com:adiii717/k8s-gitops.git
           targetRevision: main
           path: argocd-manifest
           helm:
             releaseName: backend
             valueFiles:
               - $values/projects/backend/root.yaml
   ```

## Configuration

Edit `config.env`:

```bash
# ArgoCD Configuration
ARGOCD_NAMESPACE=argocd
ARGOCD_CHART_VERSION=5.51.4

# GitHub Configuration
GITHUB_REPO_URL=git@github.com:adiii717/k8s-gitops.git
GITHUB_SSH_KEY_PATH=~/.ssh/id_ed25519

# GitOps Configuration
ARGOCD_MANIFEST_PATH=argocd-manifest
ROOT_MANIFEST_NAME=root-manifest
PROJECTS_PATH=projects
```

## Accessing ArgoCD

```bash
# Get password
cat .env

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Username: admin
# Password: (from .env)
```

## Features

✅ **Scalable**: Add dozens of applications by just adding values files

✅ **Project-Based**: Clean separation (devops, frontend, backend, etc.)

✅ **Hierarchical**: Three-level structure (Root → Project → Application)

✅ **Version Control**: Chart versions defined in root.yaml

✅ **Enable/Disable**: Toggle entire projects or individual apps

✅ **Sync Waves**: Control deployment order with syncWave

✅ **Multiple Sources**: Support for Helm repos and Git repos

✅ **ApplicationSets**: Parameterize deployments across environments

## Advanced Features

### Sync Waves

Control deployment order:
```yaml
syncWave: 1  # Deploy first
syncWave: 2  # Deploy second
syncWave: 3  # Deploy third
```

### ApplicationSets with Generators

Deploy same app to multiple clusters/environments:
```yaml
ApplicationSets:
  my-app:
    generators:
      - list:
          elements:
            - cluster: dev
              url: https://dev-cluster
              chartVersion: 1.0.0
            - cluster: prod
              url: https://prod-cluster
              chartVersion: 1.0.1
```

### Custom Charts

Place custom Helm charts in `charts/` directory and reference them:
```yaml
sources:
  - repoURL: git@github.com:adiii717/k8s-gitops.git
    targetRevision: main
    path: charts/my-custom-app
```

## Cleanup

```bash
# Remove all ArgoCD resources
bash ~/devops/scripts/cleanup-argocd.sh
```

## Commit Convention

Follow Semantic Commit Messages:

```
feat(devops): add prometheus monitoring
fix(frontend): resolve nginx configuration
docs(readme): update installation steps
chore(deps): bump cert-manager to v1.14
```

## Troubleshooting

### Check Application Status
```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

### Check Project Status
```bash
kubectl get appprojects -n argocd
```

### Force Sync
```bash
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'
```

## Best Practices

1. **Enable Gradually**: Start with `enable: false`, test, then enable
2. **Use Sync Waves**: Define clear deployment order
3. **Version Everything**: Pin chart versions in root.yaml
4. **Small Commits**: One app/change per commit
5. **Test Locally**: Use `helm template` to validate before committing
6. **Document Values**: Comment your values files

## License

Created by adilm717@gmail.com for freelance projects.
