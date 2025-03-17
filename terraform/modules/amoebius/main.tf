#####################################################################
# No local provider block: we rely on the root-level "kubernetes" provider
# This module no longer creates the namespace. We assume the namespace
# is already created at the root level.
#####################################################################

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.1"
    }
  }
}

resource "kubernetes_service_account_v1" "amoebius_admin" {
  metadata {
    name      = "amoebius-admin"
    namespace = var.namespace
  }
}

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
    namespace = var.namespace
  }
}

resource "kubernetes_stateful_set_v1" "amoebius" {
  metadata {
    name      = "amoebius"
    namespace = var.namespace
    labels = {
      app = "amoebius"
    }
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

          # for testing
          # command = ["/bin/sh", "-c", "sleep infinity"]

          security_context {
            privileged = true
          }

          volume_mount {
            name       = "amoebius-volume"
            mount_path = "/amoebius"
          }

          # Conditionally mount /var/run/docker.sock if requested
          dynamic "volume_mount" {
            for_each = var.mount_docker_socket ? [1] : []
            content {
              name       = "docker-sock"
              mount_path = "/var/run/docker.sock"
              read_only  = false
            }
          }
        }

        volume {
          name = "amoebius-volume"
          host_path {
            path = "/amoebius"
            type = "Directory"
          }
        }

        # Conditionally create a HostPath volume for docker.sock
        dynamic "volume" {
          for_each = var.mount_docker_socket ? [1] : []
          content {
            name = "docker-sock"
            host_path {
              path = "/var/run/docker.sock"
              # If "Socket" is unsupported by your K8s, replace with "File"
              type = "Socket"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "amoebius" {
  metadata {
    name      = "amoebius"
    namespace = var.namespace
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