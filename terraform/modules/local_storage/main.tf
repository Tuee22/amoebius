terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

provider "kubernetes" {
  # Typically inherits from root. If you have a separate provider block,
  # you can omit or override. For most simple module usage, you rely
  # on the parent's provider.
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
  # We will create N PVs, one for each item in range(var.volumes_count).
  for_each = toset([for i in range(var.volumes_count) : i])

  metadata {
    # Example: "data-vault-0", "data-vault-1", ...
    name = "${var.pvc_name_prefix}-${each.key}"
  }

  spec {
    capacity = {
      storage = var.storage_size
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name

    # Ties each PV to the matching PVC
    claim_ref {
      name      = "${var.pvc_name_prefix}-${each.key}"
      namespace = var.namespace
    }

    persistent_volume_source {
      host_path {
        path = "${var.path_base}/${each.key}"
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

  depends_on = [
    kubernetes_storage_class.this
  ]
}
