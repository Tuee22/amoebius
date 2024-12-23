terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.2.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
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

# Service Account for Amoebius with admin privileges
resource "kubernetes_service_account_v1" "amoebius_admin" {
  metadata {
    name      = "amoebius-admin"
    namespace = kubernetes_namespace.amoebius.metadata[0].name
  }
}

# Cluster Role Binding for full cluster-admin privileges
resource "kubernetes_cluster_role_binding_v1" "amoebius_admin_binding" {
  metadata {
    name = "amoebius-admin-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.amoebius_admin.metadata[0].name
    namespace = kubernetes_namespace.amoebius.metadata[0].name
  }
}

# Amoebius Stateful Set
resource "kubernetes_stateful_set_v1" "amoebius" {
  metadata {
    name      = "amoebius"
    namespace = kubernetes_namespace.amoebius.metadata[0].name
  }
  spec {
    service_name = "amoebius"
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
        service_account_name = kubernetes_service_account_v1.amoebius_admin.metadata[0].name
        container {
          name  = "amoebius"
          image = var.amoebius_image
          
          port {
            container_port = 8080
          }
          
          security_context {
            privileged = true
          }
          
          volume_mount {
            name       = "amoebius-volume"
            mount_path = "/amoebius"
          }
        }
        
        volume {
          name = "amoebius-volume"
          host_path {
            path = "/amoebius"
            type = "Directory"
          }
        }
      }
    }
  }
}

# ClusterIP Service for StatefulSet
resource "kubernetes_service_v1" "amoebius" {
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