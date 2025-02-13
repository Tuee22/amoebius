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
  # region must be passed in the cluster module or defaulted there to "us-central1" if not overridden.
}

module "cluster" {
  source   = "/amoebius/terraform/modules/cluster"
  provider = "gcp"
  # Will use default region="us-central1", zones=["us-central1-a","us-central1-b","us-central1-f"], etc.
}

output "instances_by_group" {
  value = module.cluster.instances_by_group
}
