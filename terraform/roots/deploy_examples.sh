#!/usr/bin/env bash
#
# This script demonstrates how to deploy "simple" or "ha" clusters for each provider root
# using separate Terraform workspaces. We override variables as needed, or keep defaults.

set -e

# Example: A "simple" AWS cluster
echo "=== AWS: Simple cluster in workspace 'aws-simple' ==="
cd aws-root
terraform workspace new aws-simple || terraform workspace select aws-simple
terraform init
terraform plan -var 'instance_groups=[{name="test_group",category="x86_small",count_per_zone=1}]'
terraform apply -auto-approve -var 'instance_groups=[{name="test_group",category="x86_small",count_per_zone=1}]'
# If you want to destroy:
# terraform destroy -auto-approve -var 'instance_groups=[{name="test_group",category="x86_small",count_per_zone=1}]'
cd ..

# Example: A "HA" AWS cluster: arm + x86
echo "=== AWS: HA cluster in workspace 'aws-ha' ==="
cd aws-root
terraform workspace new aws-ha || terraform workspace select aws-ha
terraform plan -var 'instance_groups=[
  {name="arm_nodes",category="arm_small",count_per_zone=1},
  {name="x86_nodes",category="x86_medium",count_per_zone=1}
]'
terraform apply -auto-approve -var 'instance_groups=[
  {name="arm_nodes",category="arm_small",count_per_zone=1},
  {name="x86_nodes",category="x86_medium",count_per_zone=1}
]'
cd ..

echo "=== Azure: Simple ==="
cd azure-root
terraform workspace new azure-simple || terraform workspace select azure-simple
terraform init
terraform plan -var 'instance_groups=[{name="test_arm",category="arm_small",count_per_zone=1}]'
# ... terraform apply ...
cd ..

echo "=== GCP: Simple ==="
cd gcp-root
terraform workspace new gcp-simple || terraform workspace select gcp-simple
terraform init
terraform plan -var 'instance_groups=[{name="test_arm",category="arm_small",count_per_zone=1}]'
# ... terraform apply ...
cd ..

echo "Done with examples!"
