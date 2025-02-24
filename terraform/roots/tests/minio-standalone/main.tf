###############################################################################
# main.tf
###############################################################################
terraform {
  backend "kubernetes" {
    secret_suffix     = "minio-standalone"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }

  required_version = ">= 1.0.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  host                   = ""
  cluster_ca_certificate = ""
  token                  = ""
}

provider "helm" {
  kubernetes {
    host                   = ""
    cluster_ca_certificate = ""
    token                  = ""
  }
}

module "linkerd_namespace" {
  source    = "/amoebius/terraform/modules/linkerd_annotated_namespace"
  namespace = "minio-standalone"
}

module "local_storage" {
  source = "/amoebius/terraform/modules/local_storage"

  storage_class_name = "minio-local-storage"
  pvc_name_prefix    = "data-minio"
  namespace          = "minio-standalone"
  volumes_count      = 4
}

resource "helm_release" "minio" {
  name             = "minio"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "minio"
  version          = "15.0.4"
  namespace        = "minio-standalone"
  create_namespace = false

  set {
    name  = "mode"
    value = "distributed"
  }

  set {
    name  = "replicas"
    value = "4"
  }

  set {
    name  = "persistence.storageClass"
    value = module.local_storage.storage_class_name
  }

  set {
    name  = "persistence.size"
    value = "1Gi"
  }

  set {
    name  = "auth.rootUser"
    value = "admin"
  }

  set {
    name  = "auth.rootPassword"
    value = "admin123"
  }

  # Internal-only ClusterIP
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  depends_on = [
    module.linkerd_namespace,
    module.local_storage
  ]
}