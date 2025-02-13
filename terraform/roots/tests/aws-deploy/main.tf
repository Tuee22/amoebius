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
  # We do NOT set region here; the cluster module has a default for AWS if not overridden.
}

module "cluster" {
  source   = "/amoebius/terraform/modules/cluster"
  provider = "aws"
  # This will use the defaults from the cluster module, i.e. region = "us-east-1", zones = ["us-east-1a","us-east-1b","us-east-1c"], etc.
}

output "instances" {
  value = module.cluster.instances_by_group
}

output "subnet_cidrs" {
  value = module.cluster.subnet_cidrs
}
