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

provider "kubernetes" {
  host = module.minikube_cluster.host
  client_certificate     = module.minikube_cluster.client_certificate
  client_key             = module.minikube_cluster.client_key
  cluster_ca_certificate = module.minikube_cluster.cluster_ca_certificate
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "example-namespacez"
  }
}
