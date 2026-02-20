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
- `--argocd-namespace <name>`: defaults to `argocd`
- `--dry-run`: renders and validates without applying

## Inputs

- Kubeconfig: `$HOME/remote-kube/<cluster-name>/config`
- Cluster values: `deploy/bootstrap/values/<cluster-name>.yaml`
- Runtime env vars file:
  `KEY=VALUE` lines loaded into the Kubernetes Secret
- Existing Argo CD installation in the target cluster (default namespace: `argocd`)

## Automatic Argo CD Drift Exclusion

After bootstrap apply, the script patches `argocd-cm` to exclude `cilium.io/CiliumIdentity`
from Argo CD diff/prune tracking. This prevents permanent `OutOfSync` on Cilium-managed
identities that are not part of this app's Git source.

## Security Notes

- Do not commit real secrets in Git.
- Keep `planner.env` outside the repo, with strict file permissions.
- Rotate credentials periodically.

## Image Update Flow

- Docker publish workflow builds `sha-<commit>` images and pushes multi-arch manifests.
- The same workflow updates `deploy/charts/planner/values.yaml` with that immutable tag.
- Argo CD then picks up the Git change and deploys the new image on sync.
