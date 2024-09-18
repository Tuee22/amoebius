# Root module config
terraform {
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "0.4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}


module "minikube_cluster" {
  source = "../../terraform-modules/minikube"

  # Pass the required inputs
  cluster_name = var.cluster_name
  local_folder = var.local_folder
  mount_folder = var.mount_folder
}

