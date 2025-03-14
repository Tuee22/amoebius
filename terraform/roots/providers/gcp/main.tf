terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  region = var.region
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/gcp/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/gcp/cluster"
  subnet_ids_by_zone = {
    for idx, z in var.availability_zones :
    z => element(module.network.subnet_ids, idx)
  }

  availability_zones  = var.availability_zones
  security_group_id   = module.network.security_group_id
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  resource_group_name = ""
  location            = var.region
}
