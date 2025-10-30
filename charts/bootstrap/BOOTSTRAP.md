# Bootstrap Helm Chart

Consolidates ArgoCD bootstrap process into a single Helm command. Replaces manual kubectl operations for secrets and root application.

## Usage

### SSH Authentication
```bash
helm install bootstrap charts/bootstrap \
  --set-file github.auth.sshPrivateKey=$HOME/.ssh/id_ed25519 \
  -n argocd
```

### Token Authentication
```bash
helm install bootstrap charts/bootstrap \
  --set github.auth.method=token \
  --set github.auth.token=ghp_your_token_here \
  -n argocd
```

## What Gets Created

- GitHub SSH/token secrets
- ArgoCD repository registration
- Root ArgoCD Application (triggers App of Apps pattern)

## Verification

```bash
kubectl get secrets -n argocd | grep github
kubectl get application root-manifest -n argocd
```

## Configuration

| Parameter | Default |
|-----------|---------|
| `github.auth.method` | `ssh` |
| `github.repository.url` | `git@github.com:adiii717/k8s-gitops.git` |
| `rootApplication.targetRevision` | `main` |
| `rootApplication.path` | `argocd-manifest` |

See `values.yaml` for all options.
