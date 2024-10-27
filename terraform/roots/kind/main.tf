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

resource "kubernetes_namespace" "amoebius" {
  metadata {
    name = "amoebius"
  }

  depends_on = [kind_cluster.default]
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
          cluster: ${var.cluster_name}
          user: ${var.cluster_name}-user
      current-context: ${var.cluster_name}
    EOT
  }

  depends_on = [kind_cluster.default, kubernetes_namespace.amoebius]
}

# Amoebius Stateful Set

resource "kubernetes_stateful_set" "amoebius" {
  metadata {
    name      = "amoebius"
    namespace = kubernetes_namespace.amoebius.metadata[0].name
  }

  spec {
    service_name = "amoebius" # This must match the Service name below
    replicas     = 1

    selector {
      match_labels = {
        app = "amoebius"
      }
    }

    template {
      metadata {
        labels = {
          app = "amoebius"
        }
      }

      spec {
        container {
          name  = "amoebius"
          image = var.amoebius_image

          # Add ports if necessary
          port {
            container_port = 8080
          }

          # Enable privileged mode
          security_context {
            privileged = true
          }
        }
      }
    }
  }
}

# ClusterIP Service for StatefulSet
resource "kubernetes_service" "amoebius" {
  metadata {
    name      = "amoebius"
    namespace = kubernetes_namespace.amoebius.metadata[0].name
    labels = {
      app = "amoebius"
    }
  }

  spec {
    selector = {
      app = "amoebius"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}
