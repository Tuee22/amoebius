terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
  }
}

provider "kind" {}

provider "kubernetes" {
  host                   = kind_cluster.default.endpoint
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.default.endpoint
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
    client_certificate     = kind_cluster.default.client_certificate
    client_key             = kind_cluster.default.client_key
  }
}

locals {
  home_dir = pathexpand("~")
  data_dir = "${local.home_dir}/.local/share/kind-data"
}

resource "kind_cluster" "default" {
  name           = "kind-cluster"
  wait_for_ready = true
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    node {
      role = "control-plane"
      extra_mounts {
        host_path      = "${local.data_dir}"
        container_path = "/persistent-data"            
      }
      extra_mounts {
        host_path      = "${local.home_dir}/amoebius"
        container_path = "/amoebius"
      }
    }
  }
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }

  depends_on = [kind_cluster.default]
}

resource "kubernetes_storage_class" "local_storage" {
  metadata {
    name = "local-storage"
  }
  storage_provisioner  = "kubernetes.io/no-provisioner"
  volume_binding_mode  = "WaitForFirstConsumer"

  depends_on = [kind_cluster.default]
}

resource "kubernetes_persistent_volume" "vault_storage" {
  metadata {
    name = "vault-pv"
  }
  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.local_storage.metadata[0].name
    persistent_volume_source {
      local {
        path = "/persistent-data/vault"
      }
    }
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["kind-cluster-control-plane"]
          }
        }
      }
    }
  }
  depends_on = [kubernetes_storage_class.local_storage]
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.23.0"
  namespace  = kubernetes_namespace.vault.metadata[0].name

  set {
    name  = "server.dataStorage.enabled"
    value = "true"
  }

  set {
    name  = "server.dataStorage.storageClass"
    value = kubernetes_storage_class.local_storage.metadata[0].name
  }

  set {
    name  = "server.dataStorage.size"
    value = "10Gi"
  }

  set {
    name  = "server.dataStorage.accessMode"
    value = "ReadWriteOnce"
  }

  set {
    name  = "server.dataStorage.volumeName"
    value = kubernetes_persistent_volume.vault_storage.metadata[0].name
  }

  set {
    name  = "server.standalone.enabled"
    value = "true"
  }

  set {
    name  = "server.standalone.config"
    value = <<-EOT
      ui = true
      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
      }
      storage "file" {
        path = "/vault/data"
      }
    EOT
  }

  depends_on = [
    kubernetes_persistent_volume.vault_storage,
    kubernetes_namespace.vault
  ]
}

resource "null_resource" "vault_port_forward" {
  depends_on = [helm_release.vault]

  provisioner "local-exec" {
    command = <<-EOT
      nohup kubectl port-forward -n vault service/vault 8200:8200 > /dev/null 2>&1 &
      echo $! > ${path.module}/vault_port_forward.pid
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      if [ -f ${path.module}/vault_port_forward.pid ]; then
        pid=$(cat ${path.module}/vault_port_forward.pid)
        kill $pid || true
        rm ${path.module}/vault_port_forward.pid
      fi
    EOT
  }
}

resource "kubernetes_pod" "script_runner" {
  metadata {
    name = "script-runner"
    labels = {
      app = "script-runner"
    }
  }

  spec {
    restart_policy = "Always"

    container {
      image = "python:3.11-alpine"  # Lightweight Alpine-based Python image
      name  = "script-runner"
      
      command = ["/bin/sh", "-c", "tail -f /dev/null"]
      
      volume_mount {
        name       = "amoebius-volume"
        mount_path = "/amoebius"
      }

      env {
        name  = "PYTHONPATH"
        value = "$PYTHONPATH:/amoebius/python"
      }

      # Add any additional packages you might need
      # For example, if you need git:
      # command = ["/bin/sh", "-c", "tail -f /dev/null"]
    }

    volume {
      name = "amoebius-volume"
      host_path {
        path = "/amoebius"
        type = "Directory"
      }
    }

    node_selector = {
      "kubernetes.io/hostname" = "kind-cluster-control-plane"
    }
  }

  depends_on = [kind_cluster.default]
}

output "vault_api_addr" {
  value = "http://localhost:8200"
}

output "vault_ui_url" {
  value       = "http://localhost:8200/ui"
  description = "URL for accessing the Vault UI"
}

output "kubeconfig" {
  value     = kind_cluster.default.kubeconfig
  sensitive = true
}