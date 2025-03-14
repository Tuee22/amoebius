terraform {
  backend "kubernetes" {
    secret_suffix     = "vault"
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
      version = "~> 2.25.1"
    }
    # NOTE: We REMOVE the vault provider. Not needed for deploying Vault via Helm.
  }
}

provider "kubernetes" {
  host                   = ""
  cluster_ca_certificate = ""
  token                  = ""
}

################################################################################
# 1) Linkerd-annotated namespace
################################################################################
module "vault_namespace" {
  source = "/amoebius/terraform/modules/linkerd_annotated_namespace"
  namespace = var.vault_namespace
}

################################################################################
# 2) local_storage module
################################################################################
module "local_storage" {
  source = "/amoebius/terraform/modules/local_storage"

  storage_class_name   = var.storage_class_name
  volumes_count        = var.vault_replicas
  pvc_name_prefix      = var.pvc_name_prefix
  namespace            = module.vault_namespace.namespace
  storage_size         = var.vault_storage_size
  node_affinity_values = ["${var.cluster_name}-control-plane"]
}

################################################################################
# 3) Vault ServiceAccount
################################################################################
resource "kubernetes_service_account_v1" "vault_service_account" {
  metadata {
    name      = "${var.vault_service_name}-service-account"
    namespace = module.vault_namespace.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
    annotations = {
      "meta.helm.sh/release-name"      = "vault"
      "meta.helm.sh/release-namespace" = "vault"
    }
  }
  automount_service_account_token = true
}

################################################################################
# 4) Vault ClusterRole + Binding
################################################################################
resource "kubernetes_cluster_role" "vault_cluster_role" {
  metadata {
    name = "${var.vault_service_name}-cluster-role"
  }

  rule {
    api_groups = ["authentication.k8s.io"]
    resources  = ["tokenreviews"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "vault_cluster_role_binding" {
  metadata {
    name = "${var.vault_service_name}-cluster-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.vault_cluster_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.vault_service_account.metadata[0].name
    namespace = module.vault_namespace.namespace
  }
}

################################################################################
# 5) Helm Release: Vault (no vault provider needed)
################################################################################
resource "helm_release" "vault" {
  name       = var.vault_service_name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_helm_chart_version
  namespace  = module.vault_namespace.namespace

  dynamic "set" {
    for_each = var.vault_values
    content {
      name  = set.key
      value = set.value
    }
  }

  # replicate your old sets
  set {
    name  = "server.dataStorage.size"
    value = var.vault_storage_size
  }
  set {
    name  = "server.dataStorage.storageClass"
    value = var.storage_class_name
  }
  set {
    name  = "server.ha.raft.config"
    value = <<-HCL
      ui = true
      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
      }
      storage "raft" {
        path    = "/vault/data"
        node_id = "{{ .NodeID }}"
        %{for i in range(var.vault_replicas)}
        retry_join {
          leader_api_addr = "http://${var.vault_service_name}-${i}.${var.vault_service_name}-internal:8200"
        }
        %{endfor}
      }
      service_registration "kubernetes" {}
    HCL
  }

  set {
    name  = "server.ha.replicas"
    value = tostring(var.vault_replicas)
  }
  set {
    name  = "server.serviceAccount.name"
    value = kubernetes_service_account_v1.vault_service_account.metadata[0].name
  }

  wait = true

  depends_on = [
    module.local_storage,
    module.vault_namespace
  ]
}
