terraform {
  backend "kubernetes" {
    secret_suffix     = "test-aws-deploy"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  # region, credentials from environment
}

module "network" {
  source = "/amoebius/terraform/modules/network/aws"
  # default cidr = 10.0.0.0/16
}

module "compute" {
  source = "/amoebius/terraform/modules/compute/universal"

  provider = "aws"

  availability_zones = ["us-east-1a","us-east-1b","us-east-1c"]
  subnet_ids         = module.network.subnet_ids
  security_group_id  = module.network.security_group_id

  instance_groups = [
    {
      name           = "test_group"
      category       = "x86_small"
      count_per_zone = 1
      # no custom image => default 24.04
    }
  ]
}

output "instances_by_group" {
  value = module.compute.instances_by_group
}
