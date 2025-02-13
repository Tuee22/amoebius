terraform {
  backend "kubernetes" {
    secret_suffix     = "ha-aws"
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
  # We can override region if we like, or rely on cluster's default: "us-east-1"
}

module "cluster" {
  source   = "/amoebius/terraform/modules/cluster"
  provider = "aws"

  # Example custom instance groups for a HA scenario:
  instance_groups = [
    {
      name           = "control_plane"
      architecture   = "arm"
      size           = "small"
      count_per_zone = 1
    },
    {
      name           = "workers"
      architecture   = "x86"
      size           = "medium"
      count_per_zone = 2
    }
  ]

  # If we want a custom region:
  # region = "us-east-2"

  # If we want custom disk size, etc:
  # disk_size_gb = 40
}

output "ha_cluster" {
  value = module.cluster.instances_by_group
}
