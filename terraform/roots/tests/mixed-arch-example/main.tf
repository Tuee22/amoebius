terraform {
  backend "kubernetes" {
    secret_suffix     = "mixed-arch-example"
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
  # region/creds from env
}

module "network" {
  source = "/amoebius/terraform/modules/network/aws"
  # default: us-east-1, 3 AZs
}

module "compute" {
  source = "/amoebius/terraform/modules/compute/universal"

  provider = "aws"

  availability_zones = ["us-east-1a","us-east-1b","us-east-1c"]
  subnet_ids         = module.network.subnet_ids
  security_group_id  = module.network.security_group_id

  instance_groups = [
    {
      name           = "arm_server"
      category       = "arm_small"
      count_per_zone = 1
    },
    {
      name           = "x86_server"
      category       = "x86_medium"
      count_per_zone = 1
    }
  ]
}

output "instances_by_group" {
  value = module.compute.instances_by_group
}
