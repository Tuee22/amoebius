terraform {
  backend "kubernetes" {
    secret_suffix     = "test-gcp-deploy"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  # project from environment
}

module "network" {
  source = "/amoebius/terraform/modules/network/gcp"
}

module "cluster" {
  source = "/amoebius/terraform/modules/compute/cluster"

  provider          = "gcp"
  availability_zones = ["us-central1-a","us-central1-b","us-central1-f"]
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id

  instance_groups = [
    {
      name           = "test_arm"
      category       = "arm_small"
      count_per_zone = 1
      image          = ""
    }
  ]
}

output "instances_by_group" {
  value = module.cluster.instances_by_group
}
