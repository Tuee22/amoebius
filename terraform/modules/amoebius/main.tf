#####################################################################
# modules/amoebius/main.tf
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

locals {
  # Hardcode the name of the Docker config secret
  dockerhub_secret_name = "amoebius-dockerhub-cred"

  # True if both username + password are provided
  dockerhub_enabled = var.dockerhub_username != "" && var.dockerhub_password != ""
}

#####################################################################
# 1) Deploy registry-creds operator via Helm (for cluster-wide pulls)
#####################################################################
resource "helm_release" "registry_creds" {
  name             = "registry-creds"
  repository       = "https://kir4h.github.io/charts"
  chart            = "registry-creds"
  version          = var.registry_creds_chart_version
  namespace        = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      registryList = {
        dockerhub = {
          enabled  = local.dockerhub_enabled
          username = var.dockerhub_username
          password = var.dockerhub_password
        }
      }
      # ensure all SAs are patched for node-level pulls
      patchAllServiceAccounts = true

      # Explicitly set the container pull policy
      image = {
        pullPolicy = "IfNotPresent"
      }
    })
  ]
}

#####################################################################
# 2) Docker config Secret (for in-pod Docker CLI usage)
#####################################################################
resource "kubernetes_secret_v1" "dockerhub_config" {
  count = local.dockerhub_enabled ? 1 : 0

  metadata {
    name      = local.dockerhub_secret_name
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"

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
# 3) 'amoebius-admin' ServiceAccount + cluster role binding
#####################################################################
resource "kubernetes_service_account_v1" "amoebius_admin" {
  metadata {
    name      = "amoebius-admin"
    namespace = var.namespace
  }

  // Insert your secrets here as well
  image_pull_secret {
    name = "gcr-secret"
  }
  image_pull_secret {
    name = "awsecr-cred"
  }
  image_pull_secret {
    name = "dpr-secret"
  }
  image_pull_secret {
    name = "acr-secret"
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
# 4) Deploy Amoebius (StatefulSet)
#####################################################################
resource "kubernetes_stateful_set_v1" "amoebius" {
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

        #####################################################################
        # If DockerHub creds are enabled, attach the known secret
        # for node-level pulls
        #####################################################################
        dynamic "image_pull_secrets" {
          for_each = local.dockerhub_enabled ? [1] : []
          content {
            name = local.dockerhub_secret_name
          }
        }

        container {
          name  = "amoebius"
          image = var.amoebius_image

          # This overrides the default ENTRYPOINT/CMD of the Docker image for testing
          # command = ["/bin/sh", "-c", "sleep infinity"]


          image_pull_policy = "IfNotPresent"  # avoids re-pulling if tag == :latest

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

          ###################################################################
          # If user wants to mount /var/run/docker.sock
          ###################################################################
          dynamic "volume_mount" {
            for_each = var.mount_docker_socket ? [1] : []
            content {
              name       = "docker-sock"
              mount_path = "/var/run/docker.sock"
              read_only  = false
            }
          }

          ###################################################################
          # If DockerHub creds are enabled, mount the secret for in-container CLI
          ###################################################################
          dynamic "volume_mount" {
            for_each = local.dockerhub_enabled ? [1] : []
            content {
              name       = "docker-config-vol"
              mount_path = "/root/.docker"
              read_only  = true
            }
          }

          # Docker CLI inside the container will look in /root/.docker/config.json
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

        #####################################################################
        # If DockerHub creds are set, mount the user-managed secret
        #####################################################################
        dynamic "volume" {
          for_each = local.dockerhub_enabled ? [1] : []
          content {
            name = "docker-config-vol"

            secret {
              secret_name = local.dockerhub_secret_name

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
# 5) Expose Amoebius Service (ClusterIP)
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