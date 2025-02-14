terraform {
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
  project = var.region  # or set from env
}

module "network" {
  source = "/amoebius/terraform/modules/network/gcp"

  region            = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

locals {
  final_instance_groups = [
    for g in var.instance_groups : {
      name           = g.name
      category       = g.category
      count_per_zone = g.count_per_zone
      image = (
        length(try(g.image,"")) > 0
        ? g.image
        : (
          startswith(g.category, "arm_") ? var.arm_default_image : var.x86_default_image
        )
      )
    }
  ]
}

module "compute" {
  source = "/amoebius/terraform/modules/compute"

  provider          = "gcp"
  availability_zones= var.availability_zones
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id

  instance_groups   = local.final_instance_groups
  instance_type_map = var.instance_type_map

  ssh_user         = var.ssh_user
  vault_role_name  = var.vault_role_name
  no_verify_ssl    = var.no_verify_ssl
}
