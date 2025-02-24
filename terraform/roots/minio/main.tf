terraform {
  backend "kubernetes" {
    secret_suffix     = "minio"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

provider "kubernetes" {
  host                   = ""
  token                  = ""
  cluster_ca_certificate = ""
}

module "minio_namespace" {
  source = "/amoebius/terraform/modules/linkerd_annotated_namespace"

  namespace            = var.minio_namespace
  create_namespace     = true
  apply_linkerd_policy = false
}

module "local_storage" {
  source = "/amoebius/terraform/modules/local_storage"

  storage_class_name   = var.storage_class_name
  volumes_count        = var.minio_replicas
  pvc_name_prefix      = "data-minio"
  namespace            = module.minio_namespace.namespace
  storage_size         = var.minio_storage_size
  node_affinity_values = ["${var.cluster_name}-control-plane"]
}

resource "kubernetes_secret" "minio_creds" {
  metadata {
    name      = "minio-kms-approle"
    namespace = module.minio_namespace.namespace
  }
  type = "Opaque"

  data = {
    approle_id     = base64encode("YOUR_VAULT_APPROLE_ID")
    approle_secret = base64encode("YOUR_VAULT_APPROLE_SECRET")
  }
}

resource "helm_release" "minio" {
  name       = var.minio_release_name
  repository = "https://helm.min.io/"
  chart      = "minio"
  version    = var.minio_helm_chart_version
  namespace  = module.minio_namespace.namespace

  set {
    name  = "mode"
    value = "standalone"
  }
  set {
    name  = "replicas"
    value = tostring(var.minio_replicas)
  }

  # Basic admin user/password for MinIO
  set {
    name  = "rootUser"
    value = var.minio_root_user
  }
  set {
    name  = "rootPassword"
    value = var.minio_root_password
  }

  # Vault KMS ENV config
  set {
    name  = "env.MINIO_KMS_VAULT_ENDPOINT"
    value = var.vault_addr
  }
  set {
    name  = "env.MINIO_KMS_VAULT_AUTH_TYPE"
    value = "approle"
  }
  set {
    name  = "env.MINIO_KMS_VAULT_APPROLE_ID"
    value = "${base64decode(kubernetes_secret.minio_creds.data["approle_id"])}"
  }
  set {
    name  = "env.MINIO_KMS_VAULT_APPROLE_SECRET"
    value = "${base64decode(kubernetes_secret.minio_creds.data["approle_secret"])}"
  }
  set {
    name  = "env.MINIO_KMS_VAULT_KEY_NAME"
    value = var.minio_vault_key
  }

  # Local PV config
  set {
    name  = "persistence.storageClass"
    value = module.local_storage.storage_class_name
  }
  set {
    name  = "persistence.size"
    value = var.minio_storage_size
  }

  depends_on = [
    module.local_storage
  ]
}
