 terraform {
  backend "kubernetes" {
    secret_suffix     = "annotate-amoebius-linkerd"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

provider "kubernetes" {
  host                   = ""
  cluster_ca_certificate = ""
  token                  = ""
}

module "vault_namespace" {
  source = "/amoebius/terraform/modules/linkerd_annotated_namespace"
  namespace = "amoebius"
  create_namespace = false
}