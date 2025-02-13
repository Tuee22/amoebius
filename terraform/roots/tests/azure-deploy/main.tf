terraform {
  backend "kubernetes" {
    secret_suffix     = "test-azure-deploy"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "network" {
  source = "/amoebius/terraform/modules/network/azure"
  region = "eastus"
}

module "cluster" {
  source = "/amoebius/terraform/modules/compute/cluster"

  provider          = "azure"
  region            = "eastus"  # might be used if we had data sources
  availability_zones = ["1","2","3"]
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
