terraform {
  backend "kubernetes" {
    secret_suffix     = "vault"
    load_config_file  = false
    namespace         = "amoebius"
    in_cluster_config = true
  }
}

provider "kubernetes" {
  host                   = ""
  cluster_ca_certificate = ""
  token                  = ""
}

# Kubernetes namespace for Vault
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
  }
}

# Kubernetes storage class
resource "kubernetes_storage_class" "hostpath_storage_class" {
  metadata {
    name = var.storage_class_name
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode  = "WaitForFirstConsumer"
  reclaim_policy       = "Retain"
}

# Persistent volumes for Vault
resource "kubernetes_persistent_volume" "vault_storage" {
  for_each = { for idx in range(var.vault_replicas) : idx => idx }

  metadata {
    name = "vault-pv-${each.key}"
    labels = {
      pvIndex = "${each.key}"
    }
  }

  spec {
    capacity = {
      storage = var.vault_storage_size
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.hostpath_storage_class.metadata[0].name

    persistent_volume_source {
      host_path {
        path = "/persistent-data/vault/vault-${each.key}"
        type = "DirectoryOrCreate"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["${var.cluster_name}-control-plane"]
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_storage_class.hostpath_storage_class
  ]
}

# Vault Helm deployment
resource "helm_release" "vault" {
  name       = var.vault_service_name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_helm_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  dynamic "set" {
    for_each = var.vault_values
    content {
      name  = set.key
      value = set.value
    }
  }

  set {
    name  = "server.dataStorage.size"
    value = var.vault_storage_size
  }

  set {
    name  = "server.ha.raft.config"
    value = <<-EOT
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
    EOT
  }

  set {
    name  = "server.ha.raft.replicas"
    value = tostring(var.vault_replicas)
  }

  set {
    name  = "server.dataStorage.storageClass"
    value = kubernetes_storage_class.hostpath_storage_class.metadata[0].name
  }

  set {
    name  = "server.serviceAccount.name"
    value = "${var.vault_service_name}"
  }

  depends_on = [
    kubernetes_persistent_volume.vault_storage,
    kubernetes_namespace.vault
  ]
}

# Vault RBAC
resource "kubernetes_cluster_role" "vault_admin" {
  metadata {
    name = "vault-admin"
  }

  rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["apps", "extensions"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["authentication.k8s.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "vault_admin_binding" {
  metadata {
    name = "vault-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.vault_admin.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "${var.vault_service_name}"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
}