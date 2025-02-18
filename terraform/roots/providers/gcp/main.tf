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
  project = var.region
}

# Minimal call to the new provider_root module
module "provider_root" {
  source = "/amoebius/terraform/modules/compute"

  provider           = "gcp"
  region             = var.region   # sometimes project ID or region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  instance_groups   = var.instance_groups
  instance_type_map = var.instance_type_map

  arm_default_image = var.arm_default_image
  x86_default_image = var.x86_default_image

  ssh_user        = var.ssh_user
  vault_role_name = var.vault_role_name
  no_verify_ssl   = var.no_verify_ssl
}

output "instances_by_group" {
  value = module.provider_root.instances_by_group
}

