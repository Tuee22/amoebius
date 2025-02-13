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
  # We do NOT set location here; the cluster module defaults to "eastus" if not overridden.
}

module "cluster" {
  source   = "/amoebius/terraform/modules/cluster"
  provider = "azure"
  # Defaults from cluster module: region="eastus", zones=["1","2","3"], etc.
}

output "instances_by_group" {
  value = module.cluster.instances_by_group
}
