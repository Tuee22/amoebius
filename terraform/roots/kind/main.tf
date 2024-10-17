# Terraform Providers and Settings

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

# Kind Cluster

resource "kind_cluster" "default" {
  name           = var.cluster_name
  wait_for_ready = true
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    node {
      role = "control-plane"
      extra_mounts {
        host_path      = pathexpand(var.data_dir)
        container_path = "/persistent-data"
      }
      extra_mounts {
        host_path      = pathexpand(var.amoebius_dir)
        container_path = "/amoebius"
      }
    }
  }
}

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

# Kubernetes Namespace

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
  }

  depends_on = [kind_cluster.default]
}

# Storage Class

resource "kubernetes_storage_class" "local_storage" {
  metadata {
    name = var.storage_class_name
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "WaitForFirstConsumer"

  depends_on = [kind_cluster.default]
}

# Folders for Persistent Volumes

# Add these resources before the kubernetes_persistent_volume resource


# Update the kubernetes_persistent_volume resource

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

# Helm Release for Vault

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
    value = kubernetes_storage_class.local_storage.metadata[0].name
  }

  depends_on = [
    kubernetes_persistent_volume.vault_storage,
    kubernetes_namespace.vault
  ]
}

# Script Runner Pod

resource "kubernetes_pod" "script_runner" {
  metadata {
    name      = "script-runner"
    namespace = var.vault_namespace  # Place the pod in the 'vault' namespace
    labels = {
      app = "script-runner"
    }
  }

  spec {
    restart_policy = "Always"

    container {
      image   = var.script_runner_image
      name    = "script-runner"

      # Security context at the container level
      security_context {
        privileged = true
      }
      
      command = ["/bin/sh", "-c", "tail -f /dev/null"]
      
      volume_mount {
        name       = "amoebius-volume"
        mount_path = "/amoebius"
      }

      env {
        name  = "PYTHONPATH"
        value = "$PYTHONPATH:/amoebius/python"
      }
    }

    volume {
      name = "amoebius-volume"
      host_path {
        path = "/amoebius"
        type = "Directory"
      }
    }

    node_selector = {
      "kubernetes.io/hostname" = "${var.cluster_name}-control-plane"
    }
  }

  depends_on = [kind_cluster.default,kubernetes_namespace.vault]
}

# Port Forwarding

resource "null_resource" "port_forward" {
  for_each = {
    for pf in var.port_forwards :
    "${pf.namespace}-${pf.service_name}-${pf.local_port}-${pf.remote_port}" => pf
  }

  depends_on = [helm_release.vault]

  provisioner "local-exec" {
    command = <<-EOT
      nohup kubectl port-forward -n ${each.value.namespace} service/${each.value.service_name} ${each.value.local_port}:${each.value.remote_port} > /dev/null 2>&1 &
      echo $! > ${path.module}/port_forward_${each.key}.pid
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      if [ -f ${path.module}/port_forward_${each.key}.pid ]; then
        pid=$(cat ${path.module}/port_forward_${each.key}.pid)
        kill $pid || true
        rm ${path.module}/port_forward_${each.key}.pid
      fi
    EOT
  }
}