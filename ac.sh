#!/bin/sh
#
# ac.sh - Manage a Terraform-provisioned Kind cluster with 6 verbs:
#   check   : Validate installed versions of docker, terraform, and kubectl
#   apply   : Deploy/upgrade the cluster (no container wait here)
#   destroy : Destroy the Kind cluster
#   unseal  : Wait for 2 containers in "amoebius-0" (Vault + Linkerd), then unseal Vault
#   exec    : Open a bash shell in the "amoebius-0" pod (amoebius container)
#   status  : Check cluster, Linkerd, Vault deployment, and Vault seal status
#
# Usage:
#   ./ac.sh check
#   ./ac.sh apply
#   ./ac.sh destroy
#   ./ac.sh unseal
#   ./ac.sh exec
#   ./ac.sh status
#
# This script expects:
#   - Terraform config at "terraform/roots/deploy_amoebius_local".
#   - Post-apply, Terraform writes "kubeconfig" to the repo root, so "kubectl"
#     is automatically pointed to the correct cluster *within* this script.
#

set -eu  # Exit on error (-e) or if an uninitialized variable is used (-u).

##############################################################################
# MINIMAL VERSIONS -- Edit these as needed
##############################################################################
MIN_DOCKER_VERSION="27.5"
MIN_TERRAFORM_VERSION="1.10.0"
MIN_KUBECTL_VERSION="1.32"

##############################################################################
# Compare two semantic versions (e.g., 1.23.4 vs 1.20.0).
# Returns 0 if $1 >= $2, otherwise returns 1.
##############################################################################
version_ge() {
  ver1="$1"
  ver2="$2"

  major1=$(echo "$ver1" | cut -d. -f1)
  minor1=$(echo "$ver1" | cut -d. -f2)
  patch1=$(echo "$ver1" | cut -d. -f3)
  [ -z "$minor1" ] && minor1=0
  [ -z "$patch1" ] && patch1=0

  major2=$(echo "$ver2" | cut -d. -f1)
  minor2=$(echo "$ver2" | cut -d. -f2)
  patch2=$(echo "$ver2" | cut -d. -f3)
  [ -z "$minor2" ] && minor2=0
  [ -z "$patch2" ] && patch2=0

  # Compare each segment
  if [ "$major1" -gt "$major2" ]; then
    return 0
  elif [ "$major1" -lt "$major2" ]; then
    return 1
  fi

  if [ "$minor1" -gt "$minor2" ]; then
    return 0
  elif [ "$minor1" -lt "$minor2" ]; then
    return 1
  fi

  if [ "$patch1" -gt "$patch2" ]; then
    return 0
  elif [ "$patch1" -lt "$patch2" ]; then
    return 1
  fi

  # If we get here, they're equal
  return 0
}

##############################################################################
# Checks Docker, Terraform, and kubectl meet minimal versions and Docker is running.
#   $1 (optional) "silent" => only print errors, not success messages.
##############################################################################
check_requirements() {
  mode="${1:-}"

  # Check Docker
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found in PATH."
    exit 1
  fi

  docker_version_str=$(docker --version 2>/dev/null \
    | sed -n 's/^[Dd]ocker [Vv]ersion \([0-9][0-9.]*\).*/\1/p')

  if [ -z "$docker_version_str" ]; then
    echo "ERROR: Unable to parse Docker version."
    exit 1
  fi

  if ! version_ge "$docker_version_str" "$MIN_DOCKER_VERSION"; then
    echo "ERROR: Docker version $docker_version_str is less than required $MIN_DOCKER_VERSION"
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon not running or not accessible."
    exit 1
  fi

  # Check Terraform
  if ! command -v terraform >/dev/null 2>&1; then
    echo "ERROR: terraform not found in PATH."
    exit 1
  fi

  tf_version_str=$(terraform version 2>/dev/null \
    | sed -n '1s/^Terraform v*\([0-9.]*\).*/\1/p')

  if [ -z "$tf_version_str" ]; then
    echo "ERROR: Unable to parse Terraform version."
    exit 1
  fi

  if ! version_ge "$tf_version_str" "$MIN_TERRAFORM_VERSION"; then
    echo "ERROR: Terraform version $tf_version_str is less than required $MIN_TERRAFORM_VERSION"
    exit 1
  fi

  # Check kubectl
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "ERROR: kubectl not found in PATH."
    exit 1
  fi

  kb_version_str=$(kubectl version --client 2>/dev/null \
    | sed -n 's/^Client Version: v\{0,1\}\([0-9.]*\).*/\1/p')

  if [ -z "$kb_version_str" ]; then
    echo "ERROR: Unable to parse kubectl version (is it too old?)."
    exit 1
  fi

  if ! version_ge "$kb_version_str" "$MIN_KUBECTL_VERSION"; then
    echo "ERROR: kubectl version $kb_version_str is less than required $MIN_KUBECTL_VERSION"
    exit 1
  fi

  # Print success if not silent
  if [ "$mode" != "silent" ]; then
    echo "All requirements met:"
    echo "  Docker     >= $MIN_DOCKER_VERSION (found $docker_version_str)"
    echo "  Terraform >= $MIN_TERRAFORM_VERSION (found $tf_version_str)"
    echo "  kubectl   >= $MIN_KUBECTL_VERSION (found $kb_version_str)"
  fi
}

##############################################################################
# Wait for the "amoebius-0" pod to have TWO containers (Vault + Linkerd),
# then ensure the pod is fully Ready. We show messages so the user knows
# what we're doing and why.
##############################################################################
wait_for_amoebius_pod() {
  pod="amoebius-0"
  ns="amoebius"

  echo "Checking if Linkerd injection completed for pod '$pod'..."
  echo "We expect 2 containers: the main Vault container plus the Linkerd sidecar."

  echo "Waiting for the second container to appear in pod/$pod..."
  while true
  do
    container_count=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null \
      | wc -w \
      | tr -d '[:space:]')

    if [ "$container_count" -ge 2 ] 2>/dev/null; then
      echo "  Found $container_count containers in pod/$pod. Proceeding..."
      break
    fi
    echo "  Currently $container_count container(s). Retrying in 5s..."
    sleep 5
  done

  echo "Now waiting for pod/$pod to be fully Ready..."
  kubectl wait --for=condition=Ready pod/"$pod" -n "$ns" --timeout=300s
  echo "Pod '$pod' is Ready with 2 containers (Vault + Linkerd)."
}

##############################################################################
# Temporarily set KUBECONFIG to "./kubeconfig" if it exists,
# so that kubectl commands in this script refer to the correct cluster.
# This does NOT persist outside the script.
##############################################################################
export_if_kubeconfig_exists() {
  kube_file="${PWD}/kubeconfig"
  if [ -f "$kube_file" ]; then
    export KUBECONFIG="$kube_file"
  fi
}

##############################################################################
# status:
#   1) Cluster: is it running? (kubectl get nodes)
#   2) Linkerd: is namespace linkerd present, is there >=1 pod, and do a short
#      wait (1s) to see if all pods become Ready.
#   3) Vault: do we see the secret that Terraform created (e.g. "terraform-state-vault")?
#   4) Vault sealed or unsealed: if vault ns has pods, do a short wait (1s) for them.
##############################################################################
print_status() {
  echo "=== Status Report ==="

  # 1) Cluster up?
  if ! kubectl get nodes >/dev/null 2>&1; then
    echo "Kind cluster: NOT RUNNING or unreachable"
    return 0
  fi
  echo "Kind cluster: RUNNING"

  # 2) Linkerd check
  echo ""
  echo "=== Checking Linkerd ==="
  if ! kubectl get ns linkerd >/dev/null 2>&1; then
    echo "Linkerd: NOT DEPLOYED (no 'linkerd' namespace)"
  else
    linkerd_pods=$(kubectl get pods -n linkerd --no-headers 2>/dev/null || true)
    linkerd_count=$(echo "$linkerd_pods" | wc -l | tr -d '[:space:]')
    if [ "$linkerd_count" -lt 1 ]; then
      echo "Linkerd: NAMESPACE FOUND but no pods"
    else
      echo "Linkerd: Found $linkerd_count pod(s) in 'linkerd' namespace"
      echo "Checking if all Linkerd pods are Ready..."
      # We do a short 1-second wait here because this is just a status check.
      # If pods aren't ready within that time, we assume not all are ready.
      if kubectl wait --for=condition=Ready pods -n linkerd --all --timeout=1s >/dev/null 2>&1; then
        echo "Linkerd: all pods appear Ready."
      else
        echo "Linkerd: some pods are not Ready."
      fi
    fi
  fi

  # 3) Vault
  echo ""
  echo "=== Checking Vault Deployment ==="
  # Replace "terraform-state-vault" with the correct secret name if needed
  if ! kubectl -n amoebius get secret terraform-state-vault >/dev/null 2>&1; then
    echo "Vault: NOT DEPLOYED (no secret 'terraform-state-vault' in amoebius)"
    echo "Vault seal status: N/A"
  else
    echo "Vault: DEPLOYED (found secret 'terraform-state-vault' in amoebius)"

    # 4) Check sealed/unsealed
    vault_pods=$(kubectl get pods -n vault --no-headers 2>/dev/null || true)
    if [ -z "$vault_pods" ]; then
      echo "Vault sealed/unsealed status: UNKNOWN (no pods in 'vault' namespace?)"
    else
      echo "Found vault pods in 'vault' namespace. Checking if they're Ready (1s wait)..."
      if kubectl wait --for=condition=Ready pods -n vault --all --timeout=1s >/dev/null 2>&1; then
        echo "Vault seal status: UNSEALED (all vault pods are Ready)"
      else
        echo "Vault seal status: SEALED or PARTIALLY READY (not all vault pods are 2/2 within 1s)"
      fi
    fi
  fi

  echo ""
  echo "=== End Status ==="
}

##############################################################################
# Main entrypoint
##############################################################################
cmd="${1:-}"

if [ -z "$cmd" ]; then
  echo "Usage: $0 {check|apply|destroy|unseal|exec|status}"
  exit 1
fi

case "$cmd" in
  check)
    check_requirements
    ;;
  apply)
    check_requirements "silent"
    terraform -chdir=terraform/roots/deploy_amoebius_local init
    terraform -chdir=terraform/roots/deploy_amoebius_local apply -auto-approve
    ;;
  destroy)
    check_requirements "silent"
    terraform -chdir=terraform/roots/deploy_amoebius_local destroy -auto-approve
    ;;
  unseal)
    check_requirements "silent"
    export_if_kubeconfig_exists

    # Now do the wait in unseal (not apply):
    wait_for_amoebius_pod

    echo "Attempting to unseal Vault in the 'amoebius-0' pod..."
    kubectl exec -n amoebius -c amoebius -it amoebius-0 -- amoebctl secrets.vault unseal
    ;;
  exec)
    check_requirements "silent"
    export_if_kubeconfig_exists
    echo "Launching a bash shell inside 'amoebius-0' (amoebius container)..."
    kubectl exec -n amoebius -c amoebius -it amoebius-0 -- bash
    ;;
  status)
    check_requirements "silent"
    export_if_kubeconfig_exists
    print_status
    ;;
  *)
    echo "Usage: $0 {check|apply|destroy|unseal|exec|status}"
    exit 1
    ;;
esac