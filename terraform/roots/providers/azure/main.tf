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

module "compute" {
  source = "/amoebius/terraform/modules/compute"

  cloud_provider       = "azure"
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  arm_default_image   = var.arm_default_image
  x86_default_image   = var.x86_default_image
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl
}
