#!/usr/bin/env bash
#
# deploy_examples.sh
#
# USAGE:
#   1) Ensure you have the following folder structure:
#        /amoebius/terraform/roots/providers/aws
#        /amoebius/terraform/roots/providers/azure
#        /amoebius/terraform/roots/providers/gcp
#        /amoebius/terraform/modules/cluster
#        /amoebius/terraform/modules/compute
#        /amoebius/terraform/modules/network
#        /amoebius/terraform/modules/ssh
#
#      Each provider's root folder should call "/amoebius/terraform/modules/cluster"
#      to deploy the multi-VM cluster, which in turn calls the single-VM "/amoebius/terraform/modules/compute".
#
#   2) Make sure 'terraform' is installed and any required environment variables
#      (AWS credentials, Azure credentials, GCP project/credentials) are set.
#
#   3) Make this script executable:
#        chmod +x deploy_examples.sh
#
#   4) Run it specifying which provider you'd like to deploy:
#        ./deploy_examples.sh aws
#        ./deploy_examples.sh azure
#        ./deploy_examples.sh gcp
#
#      Or deploy all:
#        ./deploy_examples.sh all
#
#   5) This script:
#        - Sets local defaults for each provider (region, zones, instance_type_map).
#        - Uses real Ubuntu 20.04 images (ARM & x86) per provider.
#        - Creates or selects a Terraform workspace named "multiarch" in each provider's root.
#        - Applies a cluster with 3 instance groups: ARM nodes, x86 nodes, and GPU nodes.
#
#   6) After the deployment finishes, you can explore the generated infrastructure
#      (VM instances, network resources), or run 'terraform destroy' in the same workspace
#      to clean up resources if you no longer need them.
#
################################################################################

set -e

###################################
# 1) Paths to each master root
###################################
AWS_ROOT="/amoebius/terraform/roots/providers/aws"
AZURE_ROOT="/amoebius/terraform/roots/providers/azure"
GCP_ROOT="/amoebius/terraform/roots/providers/gcp"

###################################
# 2) Real Ubuntu 20.04 images
#    (ARM & x86) for each provider
###################################
# AWS region: us-east-1
AWS_ARM_2004="ami-0f687bb67f1b42e80"    # Focal 20.04 ARM64
AWS_X86_2004="ami-042e8287309f5df03"   # Focal 20.04 x86_64

# Azure region: eastus (example URNs or custom image IDs)
AZURE_ARM_2004="Canonical:0001-com-ubuntu-server-focal:20_04-lts-arm64:latest"
AZURE_X86_2004="Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest"

# GCP region: us-central1
GCP_ARM_2004="projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts-arm64"
GCP_X86_2004="projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"

###################################
# 3) Regions & zones (3 zones)
###################################
AWS_REGION="us-east-1"
AWS_ZONES='["us-east-1a","us-east-1b","us-east-1c"]'

AZURE_REGION="eastus"
AZURE_ZONES='["1","2","3"]'

GCP_REGION="us-central1"
GCP_ZONES='["us-central1-a","us-central1-b","us-central1-f"]'

###################################
# 4) 9-key instance_type_map
#    (arm_small, arm_medium, ...)
###################################
AWS_INSTANCE_TYPE_MAP='{
  "arm_small":    "t4g.micro",
  "arm_medium":   "t4g.small",
  "arm_large":    "t4g.large",
  "x86_small":    "t3.micro",
  "x86_medium":   "t3.small",
  "x86_large":    "t3.large",
  "nvidia_small": "g4dn.xlarge",
  "nvidia_medium":"g4dn.4xlarge",
  "nvidia_large": "g4dn.8xlarge"
}'

AZURE_INSTANCE_TYPE_MAP='{
  "arm_small":      "Standard_D2ps_v5",
  "arm_medium":     "Standard_D4ps_v5",
  "arm_large":      "Standard_D8ps_v5",
  "x86_small":      "Standard_D2s_v5",
  "x86_medium":     "Standard_D4s_v5",
  "x86_large":      "Standard_D8s_v5",
  "nvidia_small":   "Standard_NC4as_T4_v3",
  "nvidia_medium":  "Standard_NC8as_T4_v3",
  "nvidia_large":   "Standard_NC16as_T4_v3"
}'

GCP_INSTANCE_TYPE_MAP='{
  "arm_small":    "t2a-standard-1",
  "arm_medium":   "t2a-standard-2",
  "arm_large":    "t2a-standard-4",
  "x86_small":    "e2-small",
  "x86_medium":   "e2-standard-4",
  "x86_large":    "e2-standard-8",
  "nvidia_small": "a2-highgpu-1g",
  "nvidia_medium":"a2-highgpu-2g",
  "nvidia_large": "a2-highgpu-4g"
}'

###################################
# 5) JSON array for instance_groups
#    with ARM, x86, GPU nodes
###################################
function build_aws_instance_groups() {
cat <<EOF
[
  {
    "name": "arm_nodes",
    "category": "arm_small",
    "count_per_zone": 1,
    "image": "${AWS_ARM_2004}"
  },
  {
    "name": "x86_nodes",
    "category": "x86_medium",
    "count_per_zone": 2,
    "image": "${AWS_X86_2004}"
  },
  {
    "name": "gpu_nodes",
    "category": "nvidia_small",
    "count_per_zone": 1,
    "image": "${AWS_X86_2004}"
  }
]
EOF
}

function build_azure_instance_groups() {
cat <<EOF
[
  {
    "name": "arm_nodes",
    "category": "arm_small",
    "count_per_zone": 1,
    "image": "${AZURE_ARM_2004}"
  },
  {
    "name": "x86_nodes",
    "category": "x86_medium",
    "count_per_zone": 2,
    "image": "${AZURE_X86_2004}"
  },
  {
    "name": "gpu_nodes",
    "category": "nvidia_small",
    "count_per_zone": 1,
    "image": "${AZURE_X86_2004}"
  }
]
EOF
}

function build_gcp_instance_groups() {
cat <<EOF
[
  {
    "name": "arm_nodes",
    "category": "arm_small",
    "count_per_zone": 1,
    "image": "${GCP_ARM_2004}"
  },
  {
    "name": "x86_nodes",
    "category": "x86_medium",
    "count_per_zone": 2,
    "image": "${GCP_X86_2004}"
  },
  {
    "name": "gpu_nodes",
    "category": "nvidia_small",
    "count_per_zone": 1,
    "image": "${GCP_X86_2004}"
  }
]
EOF
}

###################################
# 6) Deploy functions
###################################
function deploy_aws() {
  echo "=== Deploying multi-arch cluster on AWS ==="
  cd "${AWS_ROOT}"
  terraform init
  terraform workspace new multiarch || terraform workspace select multiarch
  terraform apply -auto-approve \
    -var "region=${AWS_REGION}" \
    -var "availability_zones=${AWS_ZONES}" \
    -var "instance_type_map=${AWS_INSTANCE_TYPE_MAP}" \
    -var "instance_groups=$(build_aws_instance_groups)"
  cd - > /dev/null
}

function deploy_azure() {
  echo "=== Deploying multi-arch cluster on Azure ==="
  cd "${AZURE_ROOT}"
  terraform init
  terraform workspace new multiarch || terraform workspace select multiarch
  terraform apply -auto-approve \
    -var "region=${AZURE_REGION}" \
    -var "availability_zones=${AZURE_ZONES}" \
    -var "instance_type_map=${AZURE_INSTANCE_TYPE_MAP}" \
    -var "instance_groups=$(build_azure_instance_groups)"
  cd - > /dev/null
}

function deploy_gcp() {
  echo "=== Deploying multi-arch cluster on GCP ==="
  cd "${GCP_ROOT}"
  terraform init
  terraform workspace new multiarch || terraform workspace select multiarch
  terraform apply -auto-approve \
    -var "region=${GCP_REGION}" \
    -var "availability_zones=${GCP_ZONES}" \
    -var "instance_type_map=${GCP_INSTANCE_TYPE_MAP}" \
    -var "instance_groups=$(build_gcp_instance_groups)"
  cd - > /dev/null
}

###################################
# 7) MAIN
###################################
case "$1" in
  "aws")
    deploy_aws
    ;;
  "azure")
    deploy_azure
    ;;
  "gcp")
    deploy_gcp
    ;;
  "all")
    deploy_aws
    deploy_azure
    deploy_gcp
    ;;
  *)
    echo "Usage: $0 [aws|azure|gcp|all]"
    exit 1
    ;;
esac

echo "=== Deployment(s) finished successfully! ==="
