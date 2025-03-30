terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.25.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# We create a single Resource Group here in the root
resource "azurerm_resource_group" "main" {
  name     = "${terraform.workspace}-azure-rg"
  location = var.region
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/azure/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  resource_group_name = azurerm_resource_group.main.name
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/azure/cluster"

  subnet_ids_by_zone = {
    for idx, z in var.availability_zones :
    z => element(module.network.subnet_ids, idx)
  }

  availability_zones  = var.availability_zones
  security_group_id   = module.network.security_group_id
  deployment          = var.deployment
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  # Pass the same RG name into the cluster module
  resource_group_name = azurerm_resource_group.main.name
  location            = var.region

  # Additional param used for naming
  workspace = terraform.workspace
}
