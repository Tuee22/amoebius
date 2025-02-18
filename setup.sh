#!/usr/bin/env bash
#
# refactor_remove_submodule_map.sh
#
# This script refactors /amoebius/terraform/modules/compute/main.tf to:
#   - dynamically set the module "vm" source = "./${var.cloud_provider}"
#   - ensures all submodules (aws, azure, gcp) have the same variables
#
# Usage:
#   cd /amoebius
#   ./refactor_remove_submodule_map.sh

set -euo pipefail

backup_and_write() {
  local target="$1"
  local content="$2"

  if [ -f "$target" ]; then
    cp "$target" "${target}.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  echo "$content" > "$target"
  echo "Wrote $target"
}

###############################################################################
# 1) Overwrite variables.tf in each of {aws, azure, gcp} submodules so they match
###############################################################################
UNIFIED_SUBMODULE_VARS='variable "vm_name" {
  description = "The name to assign the VM."
  type        = string
}

variable "public_key_openssh" {
  description = "Public key in OpenSSH format."
  type        = string
}

variable "ssh_user" {
  description = "SSH username."
  type        = string
}

variable "image" {
  description = "AMI / Image reference for the VM."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type, Azure size, or GCP machine type."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet/vNet subnetwork to place this VM in."
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group / NSG / firewall to use."
  type        = string
}

variable "zone" {
  description = "AZ or zone in which to place the VM."
  type        = string
}

variable "workspace" {
  description = "Terraform workspace name, used to generate resource names."
  type        = string
}

variable "resource_group_name" {
  description = "For Azure usage; can be ignored by AWS/GCP."
  type        = string
  default     = ""
}

variable "location" {
  description = "For Azure usage (location); can be ignored by AWS/GCP."
  type        = string
  default     = ""
}
'

backup_and_write "terraform/modules/compute/aws/variables.tf"   "$UNIFIED_SUBMODULE_VARS"
backup_and_write "terraform/modules/compute/azure/variables.tf" "$UNIFIED_SUBMODULE_VARS"
backup_and_write "terraform/modules/compute/gcp/variables.tf"   "$UNIFIED_SUBMODULE_VARS"

###############################################################################
# 2) Overwrite /amoebius/terraform/modules/compute/main.tf so it uses
#    "source = \"./${var.cloud_provider}\"" in a single module block
###############################################################################
MAIN_TF_CONTENT='###################################################################
# /amoebius/terraform/modules/compute/main.tf
#
# Single module "vm" with "source = "./${var.cloud_provider}"
#
# That means your subdirectories:
#   /amoebius/terraform/modules/compute/aws
#   /amoebius/terraform/modules/compute/azure
#   /amoebius/terraform/modules/compute/gcp
# must share an identical set of variables (done above).
#
# Terraform 0.13+ is required to interpolate a var in the source argument.
###################################################################
terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

module "network" {
  source = "/amoebius/terraform/modules/network/${var.cloud_provider}"

  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

locals {
  final_instance_groups = [
    for g in var.instance_groups : {
      name           = g.name
      category       = g.category
      count_per_zone = g.count_per_zone
      image = (
        length(try(g.image, "")) > 0
        ? g.image
        : (
            startswith(g.category, "arm_")
            ? var.arm_default_image
            : var.x86_default_image
          )
      )
    }
  ]

  expanded = flatten([
    for group_obj in local.final_instance_groups : [
      for z in var.availability_zones : {
        group_name     = group_obj.name
        category       = group_obj.category
        zone           = z
        count_per_zone = group_obj.count_per_zone
        custom_image   = group_obj.image
      }
    ]
  ])

  final_list = flatten([
    for e in local.expanded : [
      for i in range(e.count_per_zone) : {
        group_name   = e.group_name
        category     = e.category
        zone         = e.zone
        custom_image = e.custom_image
      }
    ]
  ])

  all_specs = [
    for idx, item in final_list : {
      group_name    = item.group_name
      zone          = item.zone
      instance_type = lookup(var.instance_type_map, item.category, "UNDEFINED_TYPE")
      image         = item.custom_image
    }
  ]
}

# Generate an SSH key for each VM
resource "tls_private_key" "all" {
  count     = length(local.final_list)
  algorithm = "RSA"
  rsa_bits  = 4096
}

# SINGLE dynamic source block
module "vm" {
  count  = length(local.all_specs)
  source = "./${var.cloud_provider}"  # e.g. "./aws" or "./azure" or "./gcp"

  vm_name             = "${terraform.workspace}-${local.all_specs[count.index].group_name}-${count.index}"
  public_key_openssh  = tls_private_key.all[count.index].public_key_openssh
  ssh_user            = var.ssh_user
  image               = local.all_specs[count.index].image
  instance_type       = local.all_specs[count.index].instance_type
  subnet_id           = element(module.network.subnet_ids, index(var.availability_zones, local.all_specs[count.index].zone))
  security_group_id   = module.network.security_group_id
  zone                = local.all_specs[count.index].zone
  workspace           = terraform.workspace
  resource_group_name = ""   # used by Azure submodule
  location            = var.region # for Azure, if needed
}

# For storing private keys in Vault
module "vm_secret" {
  source = "/amoebius/terraform/modules/ssh/vm_secret"
  count  = length(local.all_specs)

  vm_name         = module.vm[count.index].vm_name
  public_ip       = module.vm[count.index].public_ip
  private_key_pem = tls_private_key.all[count.index].private_key_pem
  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  vault_prefix    = "/amoebius/ssh/${var.cloud_provider}/${terraform.workspace}"
  depends_on      = [module.vm]
}

locals {
  results = [
    for idx, spec in local.all_specs : {
      group_name = local.final_list[idx].group_name
      name       = module.vm[idx].vm_name
      private_ip = module.vm[idx].private_ip
      public_ip  = module.vm[idx].public_ip
      vault_path = module.vm_secret[idx].vault_path
    }
  ]

  instances_by_group = {
    for g in var.instance_groups : g.name => [
      for r in local.results : r if r.group_name == g.name
    ]
  }
}
'

backup_and_write "terraform/modules/compute/main.tf" "${MAIN_TF_CONTENT}"

echo "Successfully removed submodule_map. Now /amoebius/terraform/modules/compute/main.tf uses 'source = \"./${var.cloud_provider}\"' for a single VM module block."
echo "Terraform 0.13+ is required. All submodules (aws, azure, gcp) have the same variable sets."