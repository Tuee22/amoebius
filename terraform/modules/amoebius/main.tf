terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

# Kubernetes provider using the 4 connection parameters
provider "kubernetes" {
  host                   = var.host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
}

# If you use a module for Linkerd-annotated namespaces, call it here.
# Otherwise, you can replace this with a simple kubernetes_namespace resource.
module "amoebius_namespace" {
  source                  = "../../modules/linkerd_annotated_namespace"
  host                    = var.host
  cluster_ca_certificate  = var.cluster_ca_certificate
  client_certificate      = var.client_certificate
  client_key              = var.client_key

  namespace              = var.namespace
  apply_linkerd_policy   = var.apply_linkerd_policy
}

# Service Account for Amoebius
resource "kubernetes_service_account_v1" "amoebius_admin" {
  metadata {
    name      = "amoebius-admin"
    namespace = module.amoebius_namespace.namespace
  }
}

# ClusterRoleBinding granting cluster-admin to the above Service Account
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
    namespace = module.amoebius_namespace.namespace
  }
}

# Amoebius StatefulSet
resource "kubernetes_stateful_set_v1" "amoebius" {
  metadata {
    name      = "amoebius"
    namespace = module.amoebius_namespace.namespace
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

          # Example: override entrypoint to do an infinite sleep
          # command = ["/bin/sh", "-c", "sleep infinity"]

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

# ClusterIP Service for Amoebius
resource "kubernetes_service_v1" "amoebius" {
  metadata {
    name      = "amoebius"
    namespace = module.amoebius_namespace.namespace
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