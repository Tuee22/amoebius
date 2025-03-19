#####################################################################
# This module:
# 1) Creates the amoebius-admin ServiceAccount and cluster role binding
# 2) Deploys a StatefulSet + Service for amoebius
# 3) Installs/updates the registry-creds operator via Helm
# 4) Creates our own Docker config Secret for in-pod Docker CLI usage
#####################################################################

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
  }
}

#####################################################################
# Locals
#####################################################################
locals {
  dockerhub_enabled = var.dockerhub_username != "" && var.dockerhub_password != ""
}

#####################################################################
# registry-creds Operator via Helm (for cluster-wide pulls)
#####################################################################
resource "helm_release" "registry_creds" {
  name             = "registry-creds"
  repository       = "https://kir4h.github.io/charts"
  chart            = "registry-creds"
  version          = var.registry_creds_chart_version
  namespace        = "kube-system"
  create_namespace = false

  # If username/password are both blank, do unauthenticated pulls
  values = [
    yamlencode({
      registryList = {
        dockerhub = {
          enabled  = local.dockerhub_enabled
          username = var.dockerhub_username
          password = var.dockerhub_password
        }
      }
    })
  ]
}

#####################################################################
# Docker config Secret (for in-pod Docker CLI)
#####################################################################
resource "kubernetes_secret_v1" "dockerhub_config" {
  count = local.dockerhub_enabled ? 1 : 0

  metadata {
    name      = var.dockerhub_secret_name
    namespace = var.namespace
  }

  # Must be type "kubernetes.io/dockerconfigjson" for Docker CLI usage
  type = "kubernetes.io/dockerconfigjson"

  # Provide the RAW JSON as a string. 
  # Terraform automatically base64-encodes data fields.
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          username = var.dockerhub_username
          password = var.dockerhub_password
          auth     = base64encode("${var.dockerhub_username}:${var.dockerhub_password}")
        }
      }
    })
  }

  depends_on = [helm_release.registry_creds]
}

#####################################################################
# Create ServiceAccount + Binding
#####################################################################
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

#####################################################################
# Deploy Amoebius StatefulSet
#####################################################################
resource "kubernetes_stateful_set_v1" "amoebius" {
  # Ensure Helm release + secret exist before creating pods
  depends_on = [
    helm_release.registry_creds,
    kubernetes_secret_v1.dockerhub_config
  ]

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

          # This overrides the default ENTRYPOINT/CMD of the Docker image for testing
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

          # Conditionally mount /var/run/docker.sock if requested
          dynamic "volume_mount" {
            for_each = var.mount_docker_socket ? [1] : []
            content {
              name       = "docker-sock"
              mount_path = "/var/run/docker.sock"
              read_only  = false
            }
          }

          # If DockerHub creds are enabled, mount the secret as ~/.docker/config.json
          dynamic "volume_mount" {
            for_each = local.dockerhub_enabled ? [1] : []
            content {
              name       = "docker-config-vol"
              mount_path = "/root/.docker"
              read_only  = true
            }
          }

          # The Docker CLI will look for config in /root/.docker/config.json
          # If you run as a different user, adjust DOCKER_CONFIG and mount path.
          env {
            name  = "DOCKER_CONFIG"
            value = "/root/.docker"
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
              type = "Socket"
            }
          }
        }

        # If DockerHub creds are set, mount the Terraform-managed secret
        dynamic "volume" {
          for_each = local.dockerhub_enabled ? [1] : []
          content {
            name = "docker-config-vol"

            secret {
              secret_name = var.dockerhub_secret_name

              items {
                key  = ".dockerconfigjson"
                path = "config.json"
              }
            }
          }
        }
      }
    }
  }
}

#####################################################################
# Expose Amoebius Service
#####################################################################
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