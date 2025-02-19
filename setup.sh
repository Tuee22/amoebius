#!/usr/bin/env bash
set -euo pipefail

# Minimal Terraform fixes ONLY: no mass permission or line-ending changes.
# Run this from /amoebius. It updates the necessary .tf files so the
# "provider_deployment" Python script can run without the known errors.

# 1) Fix local module path in vm_secret/main.tf so it doesn't escape the package
echo "Patching vm_secret/main.tf to use an absolute path for 'vault_secret'..."
vm_secret_tf="terraform/modules/ssh/vm_secret/main.tf"
if [[ -f "$vm_secret_tf" ]]; then
  sed -i 's@source = "../vault_secret"@source = "/amoebius/terraform/modules/ssh/vault_secret"@' "$vm_secret_tf"
  echo "  Updated $vm_secret_tf"
else
  echo "  Warning: $vm_secret_tf not found; skipping."
fi

# 2) Remove duplicate "instances_by_group" output block from cluster/outputs.tf
#    so that the one in main.tf doesn't clash.
echo "Removing duplicate 'instances_by_group' output from cluster/outputs.tf..."
cluster_outputs_tf="terraform/modules/cluster/outputs.tf"
if [[ -f "$cluster_outputs_tf" ]]; then
  # Delete everything from 'output "instances_by_group"' up to the closing brace
  sed -i '/output "instances_by_group"/,/^}/d' "$cluster_outputs_tf"
  echo "  Removed 'instances_by_group' from $cluster_outputs_tf"
else
  echo "  Warning: $cluster_outputs_tf not found; skipping."
fi

# 3) In compute/main.tf, we can't do source = "/x/${var.cloud_provider}",
#    so we create a local block (if not present) and reference it for 'network' and 'vm' submodules.
compute_main_tf="terraform/modules/compute/main.tf"

if [[ -f "$compute_main_tf" ]]; then
  echo "Patching $compute_main_tf to remove direct var interpolation in 'source'..."

  # If we haven’t already inserted a locals block, we'll insert one after the `terraform {` block.
  # We'll do a naive check for 'locals {' to avoid duplicating it.
  if ! grep -q 'locals {' "$compute_main_tf"; then
    # Insert a local block that chooses the correct path based on var.cloud_provider
    # We'll place it right after the `terraform {` line to keep it near the top.
    sed -i '/^terraform {/a \
locals {\n\
  network_source = ( var.cloud_provider == \"aws\" ? \"/amoebius/terraform/modules/network/aws\" : ( var.cloud_provider == \"azure\" ? \"/amoebius/terraform/modules/network/azure\" : ( var.cloud_provider == \"gcp\" ? \"/amoebius/terraform/modules/network/gcp\" : \"\" ) ) )\n\
  vm_source = ( var.cloud_provider == \"aws\" ? \"./aws\" : ( var.cloud_provider == \"azure\" ? \"./azure\" : ( var.cloud_provider == \"gcp\" ? \"./gcp\" : \"\" ) ) )\n\
}\n' "$compute_main_tf"
    echo "  Inserted a new locals block in $compute_main_tf"
  else
    echo "  'locals {' block already present; skipping insertion."
  fi

  # Replace the line for module "network" that references /amoebius/terraform/modules/network/${var.cloud_provider}
  # with 'source = local.network_source'
  sed -i 's@source = "/amoebius/terraform/modules/network/${var.cloud_provider}".*@source = local.network_source@' "$compute_main_tf"

  # Replace the line for module "vm" that references "./${var.cloud_provider}" with 'source = local.vm_source'
  sed -i 's@source = "./${var.cloud_provider}".*@source = local.vm_source@' "$compute_main_tf"

  echo "  Updated the 'source' references in $compute_main_tf"
else
  echo "  Warning: $compute_main_tf not found; skipping."
fi

echo "Done. Please try the original 'python -m amoebius.tests.provider_deployment' command again."