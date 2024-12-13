terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
  }

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

provider "helm" {
  kubernetes {
    host                   = ""
    cluster_ca_certificate = ""
    token                  = ""
  }
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
  }
}

resource "kubernetes_storage_class" "local_storage" {
  metadata {
    name = var.storage_class_name
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "WaitForFirstConsumer"
}

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
    storage_class_name = kubernetes_storage_class.local_storage.metadata[0].name
    persistent_volume_source {
      local {
        path = "/persistent-data/vault/vault-${each.key}"
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
    kubernetes_storage_class.local_storage
  ]
}



resource "helm_release" "vault" {
  name       = var.vault_service_name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_helm_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  # Pass vault_values dynamically
  dynamic "set" {
    for_each = var.vault_values
    content {
      name  = set.key
      value = set.value
    }
  }

  # Set the size of the data storage
  set {
    name  = "server.dataStorage.size"
    value = var.vault_storage_size
  }

  # Configure replicas for high availability
  set {
    name  = "server.ha.raft.replicas"
    value = tostring(var.vault_replicas)
  }

  # Specify the storage class for Vault
  set {
    name  = "server.dataStorage.storageClass"
    value = kubernetes_storage_class.local_storage.metadata[0].name
  }

  # Pass volumes as a YAML string
  set_sensitive {
    name  = "server.volumes"
    value = <<-EOT
      - name: vault-storage
        hostPath:
          path: /persistent-data/vault
    EOT
  }

  # Configure extraInitContainers
  set_sensitive {
    name  = "server.extraInitContainers"
    value = <<-EOT
      - name: init-create-folder
        image: busybox:latest
        command:
          - sh
          - "-c"
          - mkdir -p /persistent-data/vault/vault-{{ .PodName | replace "vault-" "" }} && chmod 777 /persistent-data/vault/vault-{{ .PodName | replace "vault-" "" }}
        volumeMounts:
          - name: vault-storage
            mountPath: /persistent-data/vault
    EOT
  }

  depends_on = [
    kubernetes_persistent_volume.vault_storage,
    kubernetes_namespace.vault
  ]
}