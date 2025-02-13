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

# This is the MASTER for AWS. 
# Variables: region, availability_zones, instance_type_map, instance_groups, etc.
# Then we call the network module and the universal compute.

module "network" {
  source = "/amoebius/terraform/modules/network/aws"

  region            = var.region
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

# We'll feed the universal compute module
module "compute" {
  source = "/amoebius/terraform/modules/compute"

  provider          = "aws"
  availability_zones = var.availability_zones
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id
  ssh_user          = var.ssh_user
  vault_role_name   = var.vault_role_name
  no_verify_ssl     = var.no_verify_ssl

  instance_groups = var.instance_groups

  # Finally, we pass a map from category => instance_type from the root
  instance_type_map = var.instance_type_map
}

output "instances_by_group" {
  value = module.compute.instances_by_group
}
