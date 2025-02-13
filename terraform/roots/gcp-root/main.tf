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
  # project, region from env or var
}

module "network" {
  source = "/amoebius/terraform/modules/network/gcp"

  region            = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "compute" {
  source            = "/amoebius/terraform/modules/compute"

  provider          = "gcp"
  availability_zones= var.availability_zones
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id
  ssh_user          = var.ssh_user
  vault_role_name   = var.vault_role_name
  no_verify_ssl     = var.no_verify_ssl

  instance_groups   = var.instance_groups
  instance_type_map = var.instance_type_map
}

output "instances_by_group" {
  value = module.compute.instances_by_group
}
