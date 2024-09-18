# Root module configuration

provider "local" {}

module "minikube_cluster" {
  source = "./modules/minikube"  # Path to your generic module

  # Pass the required inputs
  cluster_name = var.cluster_name
  local_folder = var.local_folder
  mount_folder = var.mount_folder
}

# Use the Kubernetes provider from the Minikube cluster setup
provider "kubernetes" {
  host = module.minikube_cluster.host
  client_certificate     = module.minikube_cluster.client_certificate
  client_key             = module.minikube_cluster.client_key
  cluster_ca_certificate = module.minikube_cluster.cluster_ca_certificate
}

# Example Kubernetes resource using the Kubernetes provider configured by the module
resource "kubernetes_namespace" "example" {
  metadata {
    name = "example-namespace"
  }
}

# Additional Kubernetes resources could go here...
