# Planner Bootstrap

Bootstraps runtime secrets and Argo CD resources to a target cluster with Helm.
Argo CD itself is not installed by this bootstrap.

## What It Creates

- `Secret` with runtime environment variables
- `AppProject` (optional, enabled by default)
- `Application` with Argo CD Image Updater annotations

## Usage

```bash
deploy/bootstrap/bootstrap.sh <cluster-name>
```

Example:

```bash
deploy/bootstrap/bootstrap.sh proxmox
```

Optional flags:

- `--env-file <path>`: defaults to `$HOME/remote-kube/<cluster-name>/planner.env`
- `--release <name>`: defaults to `planner-bootstrap`
- `--dry-run`: renders and validates without applying

## Inputs

- Kubeconfig: `$HOME/remote-kube/<cluster-name>/config`
- Cluster values: `deploy/bootstrap/values/<cluster-name>.yaml`
- Runtime env vars file:
  `KEY=VALUE` lines loaded into the Kubernetes Secret
- Existing Argo CD installation in the target cluster (default namespace: `argocd`)

## Security Notes

- Do not commit real secrets in Git.
- Keep `planner.env` outside the repo, with strict file permissions.
- Rotate credentials periodically.
