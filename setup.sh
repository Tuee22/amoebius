#!/usr/bin/env bash
#
# refactor.sh
#
# 1) Remove old .tf files in /amoebius/terraform/roots/providers/<provider> if they exist.
# 2) FORCE remove any existing /amoebius/terraform/modules/providers/<provider>/network
#    and /amoebius/terraform/modules/providers/<provider>/compute,
#    then move the modules/network/<provider> & modules/compute/<provider> directories.
# 3) Remove /amoebius/terraform/modules/cluster and /amoebius/terraform/modules/compute if they exist.
# 4) Overwrite each provider root with main.tf, variables.tf, outputs.tf
#    - No defaults in variables.tf
# 5) Idempotent: if files/dirs were already moved or removed, no errors.

set -euo pipefail

###############################################################################
# 0) Helper function to remove old .tf files for each provider
###############################################################################
remove_old_root_files() {
  local provider="$1"
  local root_dir="/amoebius/terraform/roots/providers/${provider}"

  echo "Removing old TF in ${root_dir} (if any)..."
  rm -f "${root_dir}/main.tf"      2>/dev/null || true
  rm -f "${root_dir}/variables.tf" 2>/dev/null || true
  rm -f "${root_dir}/outputs.tf"   2>/dev/null || true
}

###############################################################################
# 1) Remove old root .tf files
###############################################################################
for provider in aws azure gcp; do
  remove_old_root_files "${provider}"
done

###############################################################################
# 2) Force-move modules/network/<provider> => modules/providers/<provider>/network
###############################################################################
echo "Moving modules/network/<provider> => modules/providers/<provider>/network (forcing remove if needed)..."

# Make sure the "providers" subfolders exist
mkdir -p "/amoebius/terraform/modules/providers/aws" \
         "/amoebius/terraform/modules/providers/azure" \
         "/amoebius/terraform/modules/providers/gcp"

for provider in aws azure gcp; do
  local_src="/amoebius/terraform/modules/network/${provider}"
  local_dst="/amoebius/terraform/modules/providers/${provider}/network"

  if [ -d "${local_src}" ]; then
    # Force remove old target if it exists
    if [ -d "${local_dst}" ]; then
      echo "  Removing existing ${local_dst}..."
      rm -rf "${local_dst}"
    fi
    echo "  Moving ${local_src} => ${local_dst}..."
    mv "${local_src}" "${local_dst}"
  else
    echo "  Skipping network/${provider}; not found."
  fi
done

# Remove now-empty network/ folder if it exists
if [ -d "/amoebius/terraform/modules/network" ]; then
  rm -rf "/amoebius/terraform/modules/network"
  echo "Removed empty /amoebius/terraform/modules/network"
fi

###############################################################################
# 3) Force-move modules/compute/<provider> => modules/providers/<provider>/compute
###############################################################################
echo "Moving modules/compute/<provider> => modules/providers/<provider>/compute..."

if [ -d "/amoebius/terraform/modules/compute" ]; then
  for provider in aws azure gcp; do
    local_src="/amoebius/terraform/modules/compute/${provider}"
    local_dst="/amoebius/terraform/modules/providers/${provider}/compute"

    if [ -d "${local_src}" ]; then
      # Check if there's an extra nested folder e.g. compute/aws/aws
      nested="${local_src}/${provider}"
      if [ -d "${nested}" ]; then
        # Remove old target if it exists
        if [ -d "${local_dst}" ]; then
          echo "  Removing existing ${local_dst}..."
          rm -rf "${local_dst}"
        fi
        mkdir -p "${local_dst}"
        echo "  Found nested folder ${nested}; moving contents => ${local_dst}..."
        mv "${nested}"/* "${local_dst}"
      else
        # No nested folder
        if [ -d "${local_dst}" ]; then
          echo "  Removing existing ${local_dst}..."
          rm -rf "${local_dst}"
        fi
        echo "  Moving ${local_src} => ${local_dst}..."
        mv "${local_src}" "${local_dst}"
      fi
    else
      echo "  Skipping compute/${provider}; not found."
    fi
  done
fi

# Remove now-empty compute/ folder if it exists
if [ -d "/amoebius/terraform/modules/compute" ]; then
  rm -rf "/amoebius/terraform/modules/compute"
  echo "Removed empty /amoebius/terraform/modules/compute"
fi

###############################################################################
# 4) Remove /amoebius/terraform/modules/cluster if it exists
###############################################################################
if [ -d "/amoebius/terraform/modules/cluster" ]; then
  rm -rf "/amoebius/terraform/modules/cluster"
  echo "Removed /amoebius/terraform/modules/cluster"
fi

###############################################################################
# 5) Overwrite each provider root with main.tf, variables.tf, outputs.tf
#    (no defaults in variables)
###############################################################################
echo "Creating new provider root files (main.tf, variables.tf, outputs.tf) with no defaults..."

COMMON_VARIABLES_NO_DEFAULT='variable "region" {
  type        = string
  description = "Cloud region (e.g. us-west-1)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of zones/AZs."
}

variable "instance_type_map" {
  type        = map(string)
  description = "Map of category => instance type."
}

variable "arm_default_image" {
  type        = string
  description = "Default ARM image if none is specified."
}

variable "x86_default_image" {
  type        = string
  description = "Default x86 image if none is specified."
}

variable "instance_groups" {
  type = list(object({
    name           = string
    category       = string
    count_per_zone = number
    image          = optional(string, null)
  }))
  description = "All instance group definitions."
}

variable "ssh_user" {
  type        = string
  description = "SSH username."
}

variable "vault_role_name" {
  type        = string
  description = "Vault role name for storing SSH keys."
}

variable "no_verify_ssl" {
  type        = bool
  description = "If true, skip SSL verification for Vault calls."
}
'

COMMON_OUTPUTS='output "instances_by_group" {
  description = "Map of group_name => list of VM objects (name, private_ip, public_ip, vault_path)."
  value       = module.cluster.instances_by_group
}
'

AWS_MAIN='terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/aws/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/aws/cluster"

  availability_zones  = var.availability_zones
  subnet_ids          = module.network.subnet_ids
  security_group_id   = module.network.security_group_id
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  resource_group_name = ""
  location            = var.region

  arm_default_image = var.arm_default_image
  x86_default_image = var.x86_default_image
}
'

AZURE_MAIN='terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/azure/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/azure/cluster"

  availability_zones  = var.availability_zones
  subnet_ids          = module.network.subnet_ids
  security_group_id   = module.network.security_group_id
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  resource_group_name = module.network.resource_group_name
  location            = var.region

  arm_default_image = var.arm_default_image
  x86_default_image = var.x86_default_image
}
'

GCP_MAIN='terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "google" {
  project = var.region
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/gcp/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/gcp/cluster"

  availability_zones  = var.availability_zones
  subnet_ids          = module.network.subnet_ids
  security_group_id   = module.network.security_group_id
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  resource_group_name = ""
  location            = var.region

  arm_default_image = var.arm_default_image
  x86_default_image = var.x86_default_image
}
'

###############################################################################
# Write AWS
###############################################################################
mkdir -p "/amoebius/terraform/roots/providers/aws"
echo "${AWS_MAIN}" > "/amoebius/terraform/roots/providers/aws/main.tf"
echo "${COMMON_VARIABLES_NO_DEFAULT}" > "/amoebius/terraform/roots/providers/aws/variables.tf"
echo "${COMMON_OUTPUTS}" > "/amoebius/terraform/roots/providers/aws/outputs.tf"

###############################################################################
# Write Azure
###############################################################################
mkdir -p "/amoebius/terraform/roots/providers/azure"
echo "${AZURE_MAIN}" > "/amoebius/terraform/roots/providers/azure/main.tf"
echo "${COMMON_VARIABLES_NO_DEFAULT}" > "/amoebius/terraform/roots/providers/azure/variables.tf"
echo "${COMMON_OUTPUTS}" > "/amoebius/terraform/roots/providers/azure/outputs.tf"

###############################################################################
# Write GCP
###############################################################################
mkdir -p "/amoebius/terraform/roots/providers/gcp"
echo "${GCP_MAIN}" > "/amoebius/terraform/roots/providers/gcp/main.tf"
echo "${COMMON_VARIABLES_NO_DEFAULT}" > "/amoebius/terraform/roots/providers/gcp/variables.tf"
echo "${COMMON_OUTPUTS}" > "/amoebius/terraform/roots/providers/gcp/outputs.tf"

###############################################################################
# Done
###############################################################################
echo "
Refactor complete (idempotent + forced) !
------------------------------------------
1) Removed old .tf files under each provider root if they existed.
2) Force-removed existing target dirs under modules/providers/<provider> (network/compute),
   then moved modules/network/<provider> + modules/compute/<provider>.
3) Removed /amoebius/terraform/modules/cluster + /amoebius/terraform/modules/compute if found.
4) Wrote new main.tf, variables.tf, outputs.tf in each provider root, with no variable defaults.
5) Because we do 'rm -rf' on the target directories prior to 'mv', we won't see 'Directory not empty' errors.

Be sure you wanted to overwrite any pre-existing provider code in those directories!
If everything is correct, you can now run Terraform from each provider root as needed.
"