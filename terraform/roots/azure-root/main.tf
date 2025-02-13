terraform {
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
  source = "/amoebius/terraform/modules/network/azure"

  region            = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "compute" {
  source           = "/amoebius/terraform/modules/compute"

  provider         = "azure"
  availability_zones = var.availability_zones
  subnet_ids       = module.network.subnet_ids
  security_group_id= module.network.security_group_id
  ssh_user         = var.ssh_user
  vault_role_name  = var.vault_role_name
  no_verify_ssl    = var.no_verify_ssl

  instance_groups   = var.instance_groups
  instance_type_map = var.instance_type_map
}

output "instances_by_group" {
  value = module.compute.instances_by_group
}
