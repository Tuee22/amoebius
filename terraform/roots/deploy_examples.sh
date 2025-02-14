#!/usr/bin/env bash
#
# Simple demonstration of using the master roots with multiple workspaces.
#

set -e

# Example: AWS "simple" cluster
echo "=== AWS SIMPLE ==="
cd aws-root
terraform init
terraform workspace new simple || terraform workspace select simple
terraform apply -auto-approve -var 'instance_groups=[{
  name           = "x86_demo",
  category       = "x86_small",
  count_per_zone = 1
}]'
cd ..

# Example: AWS "ha" cluster with both ARM and x86
echo "=== AWS HA ==="
cd aws-root
terraform workspace new ha || terraform workspace select ha
terraform apply -auto-approve -var 'instance_groups=[
  { name="arm_nodes",category="arm_small",count_per_zone=1 },
  { name="x86_nodes",category="x86_small",count_per_zone=2 }
]'
cd ..

# Example: Azure with a single ARM group
echo "=== AZURE SIMPLE ==="
cd ../azure-root
terraform init
terraform workspace new simple || terraform workspace select simple
terraform apply -auto-approve -var 'instance_groups=[{
  name="arm_machine",
  category="arm_small",
  count_per_zone=1
}]'
cd ..

# Example: GCP with an x86 group
echo "=== GCP SIMPLE ==="
cd ../gcp-root
terraform init
terraform workspace new simple || terraform workspace select simple
terraform apply -auto-approve -var 'instance_groups=[{
  name="x86_nodes",
  category="x86_small",
  count_per_zone=1
}]'
cd ..

echo "=== Examples deployed! ==="
