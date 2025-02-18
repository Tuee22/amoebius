###################################################################
# provider_root/main.tf
#
# A single module that does the repeated:
#   - call to modules/network/<provider>
#   - final_instance_groups logic (ARM vs x86 default images)
#   - call to modules/compute (the universal compute module)
#   - outputs instances_by_group
#
# All 3 providers' roots can simply invoke this sub-module now.
###################################################################
terraform {
  # This is a module, so typically no backend here
  required_providers {
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

# 1) Use the provider-specific network module
module "network" {
  source = "/amoebius/terraform/modules/network/${var.provider}"

  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# 2) Build final_instance_groups to apply per-group "default ARM or x86 image" logic.
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
}

# 3) Call the universal /amoebius/terraform/modules/compute module
module "compute" {
  source = "/amoebius/terraform/modules/compute"

  cloud_provider      = var.provider
  availability_zones  = var.availability_zones
  subnet_ids          = module.network.subnet_ids
  security_group_id   = module.network.security_group_id
  instance_groups     = local.final_instance_groups
  instance_type_map   = var.instance_type_map

  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl

  # For Azure sub-module, if present:
  resource_group_name = try(module.network.resource_group_name, "")
  # For Azure, "region" can be used as location. Some people prefer:
  location = try(var.region, "")
}
