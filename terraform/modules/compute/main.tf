###################################################################
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

