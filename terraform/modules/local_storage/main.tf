terraform {
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

resource "kubernetes_storage_class" "this" {
  metadata {
    name = var.storage_class_name
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode  = var.volume_binding_mode
  reclaim_policy       = var.reclaim_policy
}

resource "kubernetes_persistent_volume" "this" {
  for_each = toset([for i in range(var.volumes_count) : i])

  metadata {
    # e.g. "vault-local-0", "vault-local-1", ...
    # Using storage_class_name in the PV name:
    name = "${var.storage_class_name}-${each.key}"
  }

  spec {
    capacity = {
      storage = var.storage_size
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.this.metadata[0].name

    claim_ref {
      name      = "${var.pvc_name_prefix}-${each.key}"
      namespace = var.namespace
    }

    persistent_volume_source {
      host_path {
        path = "${var.base_host_path}/${var.storage_class_name}/${var.storage_class_name}-${each.key}"
        type = "DirectoryOrCreate"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = var.node_affinity_key
            operator = "In"
            values   = var.node_affinity_values
          }
        }
      }
    }
  }
}
