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

# Kubernetes Namespaces

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
  }

  depends_on = [kind_cluster.default]
}

resource "kubernetes_namespace" "amoebius" {
  metadata {
    name = "amoebius"
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

# Persistent Volumes

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

# Kubeconfig Secret

resource "kubernetes_secret" "kubeconfig" {
  metadata {
    name      = "kubeconfig-secret-${var.cluster_name}"
    namespace = kubernetes_namespace.amoebius.metadata[0].name
  }

  data = {
    "config" = <<-EOT
      apiVersion: v1
      kind: Config
      clusters:
      - name: ${var.cluster_name}
        cluster:
          certificate-authority-data: ${base64encode(kind_cluster.default.cluster_ca_certificate)}
          server: https://kubernetes.default.svc
      users:
      - name: ${var.cluster_name}-user
        user:
          client-certificate-data: ${base64encode(kind_cluster.default.client_certificate)}
          client-key-data: ${base64encode(kind_cluster.default.client_key)}
      contexts:
      - name: ${var.cluster_name}
        context:
          cluster: kind-${var.cluster_name}
          user: kind-${var.cluster_name}-user
      current-context: kind-${var.cluster_name}
    EOT
  }

  depends_on = [kind_cluster.default, kubernetes_namespace.amoebius]
}

# Amoebius Pod

resource "kubernetes_pod" "amoebius" {
  metadata {
    name      = "amoebius"
    namespace = kubernetes_namespace.amoebius.metadata[0].name
    labels = {
      app = "amoebius"
    }
  }

  spec {
    restart_policy = "Always"

    container {
      image   = var.script_runner_image
      name    = "amoebius"

      security_context {
        privileged = true
      }
      
      command = ["/bin/sh", "-c", "tail -f /dev/null"]
      
      volume_mount {
        name       = "amoebius-volume"
        mount_path = "/amoebius"
      }

      volume_mount {
        name       = "kubeconfig"
        mount_path = "/root/.kube"
        read_only  = true
      }

      env {
        name  = "PYTHONPATH"
        value = "$PYTHONPATH:/amoebius/python"
      }

      env {
        name  = "KUBECONFIG"
        value = "/root/.kube/config"
      }
    }

    volume {
      name = "amoebius-volume"
      host_path {
        path = "/amoebius"
        type = "Directory"
      }
    }

    volume {
      name = "kubeconfig"
      secret {
        secret_name = kubernetes_secret.kubeconfig.metadata[0].name
        items {
          key  = "config"
          path = "config"
        }
      }
    }

    node_selector = {
      "kubernetes.io/hostname" = "${var.cluster_name}-control-plane"
    }
  }

  depends_on = [kind_cluster.default, kubernetes_namespace.amoebius, kubernetes_secret.kubeconfig]
}