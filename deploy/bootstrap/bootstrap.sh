#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${SCRIPT_DIR}/chart"

usage() {
  cat <<'USAGE'
Usage:
  deploy/bootstrap/bootstrap.sh <cluster-name> [--env-file <path>] [--release <name>] [--dry-run]

Description:
  Bootstraps planner deployment objects into a target cluster using Helm,
  assuming Argo CD is already installed:
    1) Runtime Secret from env vars
    2) Argo CD AppProject
    3) Argo CD Application

Cluster kubeconfig is resolved as:
  $HOME/remote-kube/<cluster-name>/config

Cluster values file is resolved as:
  deploy/bootstrap/values/<cluster-name>.yaml

Environment variables are loaded from:
  --env-file (if provided), otherwise $HOME/remote-kube/<cluster-name>/planner.env
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is missing: $1" >&2
    exit 1
  fi
}

yaml_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

cluster_name=""
env_file=""
release_name="planner-bootstrap"
dry_run="false"

while (($# > 0)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --env-file)
      shift
      env_file="${1:-}"
      if [[ -z "${env_file}" ]]; then
        echo "--env-file requires a path argument." >&2
        usage
        exit 1
      fi
      ;;
    --release)
      shift
      release_name="${1:-}"
      if [[ -z "${release_name}" ]]; then
        echo "--release requires a value." >&2
        usage
        exit 1
      fi
      ;;
    --dry-run)
      dry_run="true"
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "${cluster_name}" ]]; then
        echo "Cluster name provided more than once: ${cluster_name}, $1" >&2
        usage
        exit 1
      fi
      cluster_name="$1"
      ;;
  esac
  shift || true
done

if [[ -z "${cluster_name}" ]]; then
  echo "Cluster name is required." >&2
  usage
  exit 1
fi

require_cmd helm

kubeconfig_path="${HOME}/remote-kube/${cluster_name}/config"
cluster_values_file="${SCRIPT_DIR}/values/${cluster_name}.yaml"
if [[ -z "${env_file}" ]]; then
  env_file="${HOME}/remote-kube/${cluster_name}/planner.env"
fi

if [[ ! -f "${kubeconfig_path}" ]]; then
  echo "Kubeconfig not found: ${kubeconfig_path}" >&2
  exit 1
fi

if [[ ! -f "${cluster_values_file}" ]]; then
  echo "Cluster values file not found: ${cluster_values_file}" >&2
  echo "Create it based on deploy/bootstrap/values/proxmox.yaml or hetzner.yaml." >&2
  exit 1
fi

if [[ ! -f "${env_file}" ]]; then
  echo "Env file not found: ${env_file}" >&2
  echo "Create it with KEY=VALUE lines for runtime environment variables." >&2
  exit 1
fi

secret_values_file="$(mktemp)"
trap 'rm -f "${secret_values_file}"' EXIT

{
  echo "secrets:"
  echo "  env:"
} > "${secret_values_file}"

has_secret_key="false"
while IFS= read -r line || [[ -n "${line}" ]]; do
  line="${line%$'\r'}"
  [[ -z "${line}" || "${line}" == \#* ]] && continue

  if [[ "${line}" != *=* ]]; then
    echo "Invalid env line (expected KEY=VALUE): ${line}" >&2
    exit 1
  fi

  key="${line%%=*}"
  value="${line#*=}"

  if [[ ! "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Invalid env var name: ${key}" >&2
    exit 1
  fi

  escaped_value="$(yaml_escape "${value}")"
  printf '    %s: "%s"\n' "${key}" "${escaped_value}" >> "${secret_values_file}"
  has_secret_key="true"
done < "${env_file}"

if [[ "${has_secret_key}" != "true" ]]; then
  echo "Env file does not contain any KEY=VALUE entries: ${env_file}" >&2
  exit 1
fi

helm_args=(
  upgrade --install "${release_name}" "${CHART_DIR}"
  --namespace argocd
  --kubeconfig "${kubeconfig_path}"
  -f "${cluster_values_file}"
  -f "${secret_values_file}"
  --set-string "cluster.name=${cluster_name}"
)

if [[ "${dry_run}" == "true" ]]; then
  helm_args+=(--dry-run --debug)
fi

echo "Bootstrapping planner deployment on cluster '${cluster_name}'"
echo "Using kubeconfig: ${kubeconfig_path}"
echo "Using values file: ${cluster_values_file}"
echo "Using env file: ${env_file}"

helm "${helm_args[@]}"

echo "Bootstrap completed successfully."
