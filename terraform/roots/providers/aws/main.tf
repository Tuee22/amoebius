terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}

module "network" {
  source             = "/amoebius/terraform/modules/providers/aws/network"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/providers/aws/cluster"

  availability_zones  = var.availability_zones
  subnet_ids          = module.network.subnet_ids
  security_group_id   = module.network.security_group_id
  instance_groups     = var.instance_groups
  instance_type_map   = var.instance_type_map
  ssh_user            = var.ssh_user
  vault_role_name     = var.vault_role_name
  no_verify_ssl       = var.no_verify_ssl

  resource_group_name = ""
  location            = var.region

  arm_default_image = var.arm_default_image
  x86_default_image = var.x86_default_image
}

