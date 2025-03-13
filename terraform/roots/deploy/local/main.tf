terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

# Deploy the Kind cluster
module "kind" {
  source         = "../../../modules/k8s/kind"
  cluster_name   = var.cluster_name
  data_dir       = var.data_dir
  amoebius_dir   = var.amoebius_dir
}

# Deploy Amoebius into the newly created Kind cluster
module "amoebius" {
  source                  = "../../../modules/amoebius"
  host                    = module.kind.host
  cluster_ca_certificate  = module.kind.cluster_ca_certificate
  client_certificate      = module.kind.client_certificate
  client_key              = module.kind.client_key

  amoebius_image          = var.amoebius_image
  namespace               = var.namespace
  apply_linkerd_policy    = var.apply_linkerd_policy
}