# Projects Guide

This guide explains how to organize and manage applications using the project-based structure.

## Structure Overview

```
projects/
├── devops/              # DevOps tools project
│   ├── root.yaml        # Project definition + all applications
│   ├── cert-manager/
│   │   └── values.yaml
│   ├── ingress-nginx/
│   │   └── values.yaml
│   └── metrics-server/
│       └── values.yaml
└── frontend/            # Frontend apps project
    └── root.yaml
```

## How to Add Applications

### Quick Start: Add to Existing Project (DevOps)

1. **Create values directory**:
   ```bash
   mkdir -p projects/devops/prometheus
   ```

2. **Create values file** (`projects/devops/prometheus/values.yaml`):
   ```yaml
   # Prometheus Helm Values
   server:
     replicaCount: 1
     resources:
       limits:
         cpu: 500m
         memory: 512Mi
   ```

3. **Add to root.yaml** (`projects/devops/root.yaml`):
   ```yaml
   ApplicationSets:
     prometheus:
       enable: true
       syncWave: 4
       name: prometheus
       project: devops
       namespace: prometheus
       generators:
         - list:
             elements:
               - cluster: in-cluster
                 url: https://kubernetes.default.svc
                 chartVersion: 25.8.0
       sources:
         - chart: prometheus
           repoURL: https://prometheus-community.github.io/helm-charts
           targetRevision: '{{.chartVersion}}'
           helm:
             releaseName: prometheus
             valueFiles:
               - $values/projects/devops/prometheus/values.yaml
         - repoURL: git@github.com:adiii717/k8s-gitops.git
           targetRevision: main
           ref: values
   ```

4. **Commit and push**:
   ```bash
   git add projects/devops/
   git commit -m "feat(devops): add prometheus monitoring"
   git push
   ```

ArgoCD will automatically sync and deploy Prometheus!

## Project Types

### Infrastructure/DevOps Project

**Purpose**: System-level tools (cert-manager, ingress, monitoring)

**Example**: `projects/devops/root.yaml`

Uses **ApplicationSets** for Helm charts from external repositories.

### Application Project

**Purpose**: Business applications (frontend, backend, APIs)

**Example**: `projects/frontend/root.yaml`

Can use:
- **Applications** for custom charts in `charts/` directory
- **ApplicationSets** for external Helm charts

## Common Patterns

### Pattern 1: External Helm Chart

```yaml
ApplicationSets:
  grafana:
    enable: true
    syncWave: 5
    name: grafana
    project: devops
    namespace: grafana
    generators:
      - list:
          elements:
            - cluster: in-cluster
              url: https://kubernetes.default.svc
              chartVersion: 7.0.8
    sources:
      - chart: grafana
        repoURL: https://grafana.github.io/helm-charts
        targetRevision: '{{.chartVersion}}'
        helm:
          releaseName: grafana
          valueFiles:
            - $values/projects/devops/grafana/values.yaml
      - repoURL: git@github.com:adiii717/k8s-gitops.git
        targetRevision: main
        ref: values
```

### Pattern 2: Custom Helm Chart

```yaml
Applications:
  my-app:
    enable: true
    syncWave: 1
    name: my-app
    namespace: frontend
    project: frontend
    sources:
      - repoURL: git@github.com:adiii717/k8s-gitops.git
        targetRevision: main
        ref: values
      - repoURL: git@github.com:adiii717/k8s-gitops.git
        targetRevision: main
        path: charts/my-app
        helm:
          releaseName: my-app
          valueFiles:
            - $values/projects/frontend/my-app/values.yaml
```

### Pattern 3: Multi-Environment with ApplicationSet

```yaml
ApplicationSets:
  api-service:
    enable: true
    syncWave: 1
    name: api-service
    project: backend
    namespace: api-{{.environment}}
    generators:
      - list:
          elements:
            - cluster: dev
              url: https://dev-cluster
              environment: dev
              chartVersion: 1.0.0
              replicas: 1
            - cluster: prod
              url: https://prod-cluster
              environment: prod
              chartVersion: 1.0.0
              replicas: 3
    sources:
      - repoURL: git@github.com:adiii717/k8s-gitops.git
        targetRevision: main
        path: charts/api-service
        helm:
          releaseName: api-service-{{.environment}}
          valueFiles:
            - $values/projects/backend/api-service/{{.environment}}.yaml
      - repoURL: git@github.com:adiii717/k8s-gitops.git
        targetRevision: main
        ref: values
```

## Sync Waves

Control deployment order with `syncWave`:

```yaml
# Deploy in this order:
syncWave: -1   # ArgoCD Project (first)
syncWave: 1    # cert-manager (second)
syncWave: 2    # ingress-nginx (third)
syncWave: 3    # metrics-server (fourth)
syncWave: 4    # prometheus (fifth)
syncWave: 5    # grafana (sixth)
```

## Enable/Disable Applications

### Disable Single Application

In `projects/devops/root.yaml`:
```yaml
ApplicationSets:
  prometheus:
    enable: false  # Disabled - won't be deployed
```

### Disable Entire Project

In `argocd-manifest/values.yaml`:
```yaml
Applications:
  devops:
    enable: false  # Entire devops project disabled
```

## Creating New Project

1. **Create directory structure**:
   ```bash
   mkdir -p projects/backend
   ```

2. **Create root.yaml** (`projects/backend/root.yaml`):
   ```yaml
   global:
     argocdNamespace: argocd

   Projects:
     backend:
       enable: true
       syncWave: -1
       name: backend
       description: Backend services and APIs
       labels:
         team: backend
         category: services
       clusterResourceWhitelist:
         - group: '*'
           kind: '*'
       destinations:
         - namespace: '*'
           server: https://kubernetes.default.svc
       sourceRepos:
         - '*'

   Applications:
     api-gateway:
       enable: true
       syncWave: 1
       name: api-gateway
       namespace: backend
       project: backend
       sources:
         - repoURL: git@github.com:adiii717/k8s-gitops.git
           targetRevision: main
           path: charts/api-gateway
           helm:
             releaseName: api-gateway
             valueFiles:
               - $values/projects/backend/api-gateway/values.yaml
         - repoURL: git@github.com:adiii717/k8s-gitops.git
           targetRevision: main
           ref: values
   ```

3. **Enable in root manifest** (`argocd-manifest/values.yaml`):
   ```yaml
   Applications:
     backend:
       enable: true
       syncWave: 102
       name: backend
       description: Backend services
       namespace: argocd
       project: argocd-manifest
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

4. **Commit and push**:
   ```bash
   git add projects/backend argocd-manifest/values.yaml
   git commit -m "feat(backend): add backend project"
   git push
   ```

## Tips

1. **Start Disabled**: Set `enable: false` initially, test with `helm template`, then enable
2. **Use Sync Waves**: Ensure dependencies deploy first (e.g., cert-manager before ingress)
3. **Pin Versions**: Always specify `chartVersion` in generators
4. **Small Commits**: One application per commit for easier troubleshooting
5. **Namespace Strategy**:
   - Infrastructure tools: `devops-*` namespaces
   - Applications: Named namespaces (`frontend-app1`, `backend-api`)
6. **Value Organization**:
   - Simple: Single `values.yaml` per app
   - Complex: Multiple environment files (`dev.yaml`, `staging.yaml`, `prod.yaml`)

## Troubleshooting

### Application Not Appearing

1. Check if enabled:
   ```bash
   # Check project-level root.yaml
   grep "enable:" projects/devops/root.yaml

   # Check root manifest
   grep "enable:" argocd-manifest/values.yaml
   ```

2. Check ArgoCD application:
   ```bash
   kubectl get applications -n argocd
   kubectl describe application devops -n argocd
   ```

### Sync Failed

```bash
# Get application details
kubectl get application <app-name> -n argocd -o yaml

# Check sync status
kubectl describe application <app-name> -n argocd | grep -A 10 "Sync:"

# Manual sync
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'
```

### Test Before Deploying

```bash
# Test Helm rendering locally
cd argocd-manifest
helm template . -f values.yaml -f ../projects/devops/root.yaml

# Validate syntax
helm lint .
```

## Examples by Use Case

### Use Case: Monitoring Stack

```bash
# Add Prometheus
mkdir -p projects/devops/prometheus
# ... add values and update root.yaml

# Add Grafana
mkdir -p projects/devops/grafana
# ... add values and update root.yaml

# Add Loki
mkdir -p projects/devops/loki
# ... add values and update root.yaml
```

### Use Case: Service Mesh

```bash
# Add Istio
mkdir -p projects/devops/istio
# ... add values and update root.yaml with syncWave: 1

# Add Kiali (depends on Istio)
mkdir -p projects/devops/kiali
# ... add values and update root.yaml with syncWave: 2
```

### Use Case: Multi-Tenant Applications

```bash
# Create tenants project
mkdir -p projects/tenants

# Add tenant-specific apps
mkdir -p projects/tenants/tenant-a
mkdir -p projects/tenants/tenant-b

# Each tenant gets isolated namespace and resources
```

## Next Steps

1. Review `projects/devops/root.yaml` for complete example
2. Add your first tool to the devops project
3. Create your own project (backend, data, etc.)
4. Set up monitoring and observability stack
