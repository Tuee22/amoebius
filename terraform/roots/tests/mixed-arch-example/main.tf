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
  region = "us-east-1"
}

module "network" {
  source = "/amoebius/terraform/modules/network/aws"
  # default vpc_cidr, zones
}

module "cluster" {
  source = "/amoebius/terraform/modules/compute/cluster"

  provider = "aws"
  region   = "us-east-1"

  availability_zones = ["us-east-1a","us-east-1b","us-east-1c"]
  subnet_ids         = module.network.subnet_ids
  security_group_id  = module.network.security_group_id

  instance_groups = [
    # One group is ARM, another is x86
    {
      name           = "arm_nodes"
      category       = "arm_small"
      count_per_zone = 1
      image          = "" # default 24.04 ARM
    },
    {
      name           = "x86_nodes"
      category       = "x86_medium"
      count_per_zone = 1
      image          = "" # default 24.04 x86
    }
  ]
}

output "instances_by_group" {
  value = module.cluster.instances_by_group
}
